import Foundation
import IntentCoverageCore

/// V1 deliberately supports one reviewed adapter contract, not arbitrary architecture rewriting.
public struct Generator {
    public init() {}
    public func generate(capabilityID: String, root: URL, output: URL) throws -> [URL] {
        let report = try Analyzer().analyze(root: root)
        guard let cap = report.capabilities.first(where: { $0.id == capabilityID }) else { throw AnalysisError.invalid("Capability not found: \(capabilityID)") }
        guard cap.eligibility == "eligible", cap.reviewState == "reviewed" else { throw AnalysisError.invalid("Review capability eligibility before generation") }
        guard cap.intents.isEmpty else { throw AnalysisError.invalid("Capability already has an intent") }
        let bindingURL = root.appendingPathComponent(".intentcoverage-generation.json")
        guard FileManager.default.fileExists(atPath: bindingURL.path) else { throw AnalysisError.invalid("No reviewed generation binding. V1 supports the TaskFlow search adapter; see docs/generation.md.") }
        let binding = try JSONDecoder().decode(Binding.self, from: Data(contentsOf: bindingURL))
        guard binding.schemaVersion == 1, binding.adapter == "taskflow-search-v1", cap.id == "search_tasks", cap.symbol == "TaskRepository.searchTasks", report.entities.contains("TaskEntity"), binding.bundleIdentifier.range(of: "^[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)+$", options: .regularExpression) != nil else { throw AnalysisError.invalid("Unsupported or incompatible generation binding") }
        // Pin the domain/entity contract so templates cannot silently target changed APIs.
        for (relative, expected) in binding.contractDigests {
            let file = root.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
            let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
            guard file.path.hasPrefix(resolvedRoot.path + "/"), try digest(Data(contentsOf: file)) == expected else { throw AnalysisError.invalid("Generation contract changed: \(relative). Review and refresh the binding before generating.") }
        }
        guard Set(binding.contractDigests.keys) == ["Domain/TaskRepository.swift", "Intents/TaskEntity.swift"] else { throw AnalysisError.invalid("Incomplete generation contract") }
        let out = output.standardizedFileURL.resolvingSymlinksInPath()
        let sourceRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        // Never put candidate files directly into scanned app source roots.
        for source in report.scope {
            let sourceURL = sourceRoot.appendingPathComponent(source).standardizedFileURL
            if out.path == sourceURL.path || out.path.hasPrefix(sourceURL.path + "/") { throw AnalysisError.invalid("Output must be outside scanned source roots; generated files require review") }
        }
        guard !FileManager.default.fileExists(atPath: out.path) else { throw AnalysisError.invalid("Output already exists; choose a new directory") }
        try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = out.deletingLastPathComponent().appendingPathComponent(".generation-\(UUID())")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: staging) }
        let contents = ["SearchTasksIntent.swift": Self.searchIntent, "TaskFlowIntentTests.swift": Self.integrationTests(bundle: binding.bundleIdentifier),
                        "REVIEW.md": """
                        # Candidate generation — review required

                        Source digest: \(report.sourceDigest)
                        Capability: \(cap.id)
                        Binding: taskflow-search-v1

                        Add SearchTasksIntent.swift to the app target's Intents directory after review.
                        Add TaskFlowIntentTests.swift only to a separate iOS 27+ UI test target.
                        Regenerate the example Xcode project, build and run on the physical iPhone 12.
                        The tests create an isolated store using a UUID launch argument and assert Create,
                        Complete and Search behavior plus a nonmatching search. They require Xcode 27 and iOS 27.
                        Source generation is not compile proof or runtime proof. Keep reports separate.
                        No existing source files were changed by this command.
                        """]
        for (name, content) in contents { try content.write(to: staging.appendingPathComponent(name), atomically: true, encoding: .utf8) }
        try FileManager.default.moveItem(at: staging, to: out)
        return contents.keys.sorted().map { out.appendingPathComponent($0) }
    }
    struct Binding: Decodable { var schemaVersion: Int; var adapter: String; var bundleIdentifier: String; var contractDigests: [String: String] }
    public static let searchIntent = """
    import AppIntents

    struct SearchTasksIntent: AppIntent {
        static let title: LocalizedStringResource = "Search Tasks"
        static let description = IntentDescription("Find tasks by title and return them to your shortcut.")
        @Parameter(title: "Query") var query: String
        static var parameterSummary: some ParameterSummary { Summary("Search tasks for \\(\\.$query)") }
        func perform() async throws -> some IntentResult & ReturnsValue<[TaskEntity]> {
            let records = try await TaskRepository.shared.searchTasks(query: query)
            return .result(value: records.map(TaskEntity.init))
        }
    }
    """
    public static func integrationTests(bundle: String) -> String {
        """
        import XCTest
        import AppIntentsTesting

        // Dedicated UI testing target; minimum iOS 27. Never imported by the app.
        @available(iOS 27.0, *)
        final class TaskFlowIntentTests: XCTestCase {
            @MainActor func testCreateCompleteAndSearchThroughSystem() async throws {
                let app = XCUIApplication(bundleIdentifier: "\(bundle)")
                app.launchArguments = ["--test-store", UUID().uuidString]
                app.launch()
                defer { app.terminate() }
                let definitions = IntentDefinitions(bundleIdentifier: "\(bundle)")
                let created = try await definitions.intents["CreateTaskIntent"]
                    .makeIntent(title: "Orchid launch").run()
                let entity: AnyAppEntity = try created.value
                let title: String = try entity.title
                XCTAssertEqual(title, "Orchid launch")
                _ = try await definitions.intents["CreateTaskIntent"]
                    .makeIntent(title: "Buy milk").run()
                let completed = try await definitions.intents["CompleteTaskIntent"]
                    .makeIntent(task: entity).run()
                let done: Bool = try completed.value.isCompleted
                XCTAssertTrue(done)
                let search = try await definitions.intents["SearchTasksIntent"]
                    .makeIntent(query: "ORCHID").run()
                let matches: [AnyAppEntity] = try search.value
                XCTAssertEqual(matches.count, 1)
                let match = try XCTUnwrap(matches.first)
                let matchTitle: String = try match.title
                XCTAssertEqual(matchTitle, "Orchid launch")
                let missing = try await definitions.intents["SearchTasksIntent"]
                    .makeIntent(query: "not-present-9c17").run()
                let absent: [AnyAppEntity] = try missing.value
                XCTAssertTrue(absent.isEmpty)
            }
        }
        """
    }
}
