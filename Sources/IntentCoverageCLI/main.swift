import Foundation
import IntentCoverageCore
import IntentCoverageGenerator

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("intentcoverage: \(message)\n".utf8)); exit(code)
}
let help = """
IntentCoverage 0.1.0 — explainable App Intents source coverage

  intentcoverage analyze <project> [--json] [--output <report.json>]
  intentcoverage explain <capability> <project>
  intentcoverage generate <capability> <project> --output <new-directory>
  intentcoverage check <project> --baseline <report.json>
  intentcoverage doctor

Analysis is local and deterministic. Runtime validation is reported separately.
Generation supports the reviewed TaskFlow search adapter and never applies files.
"""
var args = Array(CommandLine.arguments.dropFirst())
@MainActor func option(_ name: String) throws -> String? {
    guard let index = args.firstIndex(of: name) else { return nil }
    guard args.indices.contains(index + 1), !args[index + 1].hasPrefix("--") else { throw AnalysisError.invalid("Missing value for \(name)") }
    let value = args[index + 1]; args.removeSubrange(index...index + 1); return value
}
@MainActor func flag(_ name: String) -> Bool { guard let i = args.firstIndex(of: name) else { return false }; args.remove(at: i); return true }
@MainActor func requireCount(_ count: Int) throws { guard args.count == count, !args.contains(where: { $0.hasPrefix("--") }) else { throw AnalysisError.invalid("Invalid arguments. Use --help.") } }
func root(_ path: String) -> URL { URL(fileURLWithPath: path, isDirectory: true) }

do {
    guard let command = args.first else { print(help); exit(0) }; args.removeFirst()
    switch command {
    case "--help", "help", "-h": print(help)
    case "--version": print("0.1.0")
    case "analyze":
        let json = flag("--json"); let output = try option("--output"); try requireCount(1)
        let report = try Analyzer().analyze(root: root(args[0]))
        if let output { try report.json().write(to: URL(fileURLWithPath: output), options: .atomic) }
        print(json ? String(decoding: try report.json(), as: UTF8.self) : report.terminal())
    case "explain":
        try requireCount(2); let report = try Analyzer().analyze(root: root(args[1]))
        guard let cap = report.capabilities.first(where: { $0.id == args[0] }) else { throw AnalysisError.invalid("Unknown capability: \(args[0])") }
        print("\(cap.name) [\(cap.status)]\n\(cap.reason)\nOperation: \(cap.symbol)\nEffect: \(cap.effect)\nReview: \(cap.reviewState)")
        for evidence in cap.evidence { print("  \(evidence.file):\(evidence.line) · \(evidence.symbol) (\(evidence.kind))") }
        print("Mapped intents: \(cap.intents.isEmpty ? "none" : cap.intents.joined(separator: ", "))")
    case "generate":
        guard let output = try option("--output") else { throw AnalysisError.invalid("Generation requires --output <new-directory>") }; try requireCount(2)
        for file in try Generator().generate(capabilityID: args[0], root: root(args[1]), output: root(output)) { print(file.path) }
    case "check":
        guard let baseline = try option("--baseline") else { throw AnalysisError.invalid("Missing --baseline") }; try requireCount(1)
        let old = try JSONDecoder().decode(Report.self, from: Data(contentsOf: URL(fileURLWithPath: baseline)))
        let new = try Analyzer().analyze(root: root(args[0]))
        guard old.scope == new.scope, old.toolVersion == new.toolVersion else { throw AnalysisError.invalid("Incomparable baseline: scope or analyzer version changed") }
        var failures: [String] = []
        for previous in old.capabilities {
            guard let current = new.capabilities.first(where: { $0.id == previous.id }) else { failures.append("Capability disappeared: \(previous.id)"); continue }
            if current.eligibility != previous.eligibility || current.reason != previous.reason { failures.append("Eligibility decision changed: \(current.id)") }
            let removed = Set(previous.intents).subtracting(current.intents)
            if !removed.isEmpty { failures.append("Mapped intent removed: \(current.id) (\(removed.sorted().joined(separator: ", ")))") }
        }
        for cap in new.capabilities where !old.capabilities.contains(where: { $0.id == cap.id }) { failures.append("New capability needs baseline review: \(cap.id)") }
        for previous in old.intents {
            if let current = new.intents.first(where: { $0.name == previous.name }), previous.parameters != current.parameters {
                failures.append("Intent parameter names changed: \(current.name)")
            }
        }
        if new.coverage.unreviewed > 0 { failures.append("Unreviewed candidates: \(new.coverage.unreviewed)") }
        print(new.terminal())
        guard failures.isEmpty else { fail(failures.joined(separator: "\n"), code: 2) }
        print("Baseline check passed. Runtime tests were not executed.")
    case "doctor":
        try requireCount(0)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select"); p.arguments = ["-p"]
        let pipe = Pipe(); p.standardOutput = pipe; try p.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw AnalysisError.invalid("Full Xcode installation is required for app validation") }
        var developer = ProcessInfo.processInfo.environment["DEVELOPER_DIR"] ?? String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if developer.hasSuffix(".app") { developer += "/Contents/Developer" }
        let frameworks = ["/Platforms/iPhoneOS.platform/Developer/Library/Frameworks/AppIntentsTesting.framework", "/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/AppIntentsTesting.framework"]
        let available = frameworks.contains { FileManager.default.fileExists(atPath: developer + $0) }
        print("Developer directory: \(developer)\nAppIntentsTesting framework: \(available ? "present" : "absent")\nRuntime requirement: iOS 27+ on the physical iPhone 12\nRuntime status: not checked\nScanner: local; no API key required")
    default: throw AnalysisError.invalid("Unknown command: \(command). Use --help.")
    }
} catch { fail(error.localizedDescription) }
