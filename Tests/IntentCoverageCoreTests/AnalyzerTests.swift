import Foundation
import Testing
@testable import IntentCoverageCore
import IntentCoverageGenerator

struct AnalyzerTests {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    func fixture(_ source: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("IntentCoverageFixture-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try source.write(to: root.appendingPathComponent("Fixture.swift"), atomically: true, encoding: .utf8)
        return root
    }
    @Test func realDemoDiscoversFiveAndTwoWithoutUsingDecisionManifestAsOracle() throws {
        let demo = project.appendingPathComponent("Examples/TaskFlowDemo")
        let report = try Analyzer().analyze(root: demo)
        #expect(Set(report.capabilities.map(\.id)) == ["create_task", "complete_task", "delete_task", "search_tasks", "change_due_date"])
        #expect(report.coverage.eligible == 5 && report.coverage.exposed == 2 && report.coverage.percent == 40)
        #expect(report.runtimeValidation == "not_run")
        #expect(report.entities == ["TaskEntity"])
        #expect(report.queries == ["TaskEntityQuery"])
        #expect(report.shortcutsProviders == ["TaskFlowShortcuts"])
        #expect(report.intents.first { $0.name == "CreateTaskIntent" }?.parameters == ["title"])
        let decoded = try JSONDecoder().decode(Report.self, from: report.json())
        #expect(decoded.coverage == report.coverage)
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("IntentCoverageDemo-\(UUID())")
        defer { try? FileManager.default.removeItem(at: copy) }
        try FileManager.default.copyItem(at: demo, to: copy)
        try FileManager.default.removeItem(at: copy.appendingPathComponent(".intentcoverage.json"))
        let discovered = try Analyzer().analyze(root: copy)
        #expect(Set(discovered.capabilities.map(\.id)) == Set(report.capabilities.map(\.id)))
        #expect(discovered.coverage.unreviewed == 5)
        #expect(discovered.capabilities.first { $0.id == "delete_task" }?.eligibility == "needs_review")
    }
    @Test func generationDoesNotChangeCoverageUntilAccepted() throws {
        let demo = project.appendingPathComponent("Examples/TaskFlowDemo")
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("IntentCoverageGeneration-\(UUID())")
        let copy = parent.appendingPathComponent("App"), output = parent.appendingPathComponent("Candidate")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        try FileManager.default.copyItem(at: demo, to: copy)
        let before = try Analyzer().analyze(root: copy)
        let files = try Generator().generate(capabilityID: "search_tasks", root: copy, output: output)
        #expect(files.count == 3)
        #expect(try Analyzer().analyze(root: copy).coverage.percent == 40)
        #expect(throws: (any Error).self) { try Generator().generate(capabilityID: "search_tasks", root: copy, output: output) }
        try FileManager.default.copyItem(at: output.appendingPathComponent("SearchTasksIntent.swift"), to: copy.appendingPathComponent("Intents/SearchTasksIntent.swift"))
        let after = try Analyzer().analyze(root: copy)
        #expect(after.coverage.percent == 60)
        #expect(after.sourceDigest != before.sourceDigest)
        #expect(after.runtimeValidation == "not_run")
    }
    @Test func generatorRefusesChangedContract() throws {
        let demo = project.appendingPathComponent("Examples/TaskFlowDemo")
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("IntentCoverageContract-\(UUID())")
        defer { try? FileManager.default.removeItem(at: copy) }
        try FileManager.default.copyItem(at: demo, to: copy)
        let entity = copy.appendingPathComponent("Intents/TaskEntity.swift")
        try (String(contentsOf: entity, encoding: .utf8) + "\n// Contract changed\n").write(to: entity, atomically: true, encoding: .utf8)
        #expect(throws: (any Error).self) { try Generator().generate(capabilityID: "search_tasks", root: copy, output: copy.appendingPathComponent(".intentcoverage/candidate")) }
    }
    @Test func commentsQueriesAndHiddenIntentsDoNotInflateExposure() throws {
        let root = try fixture("""
        import SwiftUI
        // struct Fake: AppIntent {}
        let text = "struct Fiction: AppIntent {}"
        actor Notes { func searchNotes(query: String) {} }
        struct Screen: View {
            var body: some View { Button("Search") { Notes.shared.searchNotes(query: "a") } }
        }
        struct Query: EntityStringQuery { func entities() { Notes.shared.searchNotes(query: "a") } }
        struct Unrelated: OtherFramework.AppIntent { func perform() { Notes.shared.searchNotes(query: "a") } }
        struct Hidden: AppIntents.AppIntent {
            static let isDiscoverable = false
            func perform() { Notes.shared.searchNotes(query: "a") }
        }
        #if DEBUG
        struct DebugIntent: AppIntent { func perform() { Notes.shared.searchNotes(query: "a") } }
        #endif
        """)
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try Analyzer().analyze(root: root)
        #expect(report.capabilities.count == 1 && report.coverage.exposed == 0)
        #expect(report.intents.map(\.name) == ["Hidden"])
    }
    @Test func extensionConformanceAndDuplicateUIEvidence() throws {
        let root = try fixture("""
        actor Notes { func createNote() {} }
        struct Screen: View { var body: some View { Button("Create") { Notes.shared.createNote() }; Button("Again") { Notes.shared.createNote() } } }
        struct CreateNoteIntent { func perform() { Notes.shared.createNote() } }
        extension CreateNoteIntent: AppIntents.AppIntent {}
        """)
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try Analyzer().analyze(root: root)
        #expect(report.coverage.eligible == 1 && report.coverage.exposed == 1)
        #expect(report.capabilities[0].evidence.count == 3)
    }
    @Test func localProtocolInheritanceDoesNotCountProtocolAsIntent() throws {
        let root = try fixture("""
        protocol TaskAction: AppIntent {}
        actor Notes { func createNote() {} }
        struct Screen: View { var body: some View { Button("New") { Notes.shared.createNote() } } }
        struct AddNote: TaskAction { func perform() { Notes.shared.createNote() } }
        """)
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try Analyzer().analyze(root: root)
        #expect(report.intents.map(\.name) == ["AddNote"])
        #expect(report.coverage.exposed == 1)
    }
    @Test func malformedSourceAndEscapingRootsFailClosed() throws {
        let root = try fixture("struct Broken {")
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: (any Error).self) { try Analyzer().analyze(root: root) }
        let config = AnalysisConfiguration(sourceRoots: [".."])
        try JSONEncoder().encode(config).write(to: root.appendingPathComponent(".intentcoverage.json"))
        #expect(throws: (any Error).self) { try Analyzer().analyze(root: root) }
    }
    @Test func zeroDenominatorIsNotPerfectCoverage() throws {
        let root = try fixture("struct Empty {}")
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try Analyzer().analyze(root: root).coverage.percent == nil)
    }
}
