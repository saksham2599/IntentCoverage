import Foundation

public struct Evidence: Codable, Equatable, Sendable {
    public var file: String
    public var line: Int
    public var symbol: String
    public var kind: String
    public init(file: String, line: Int, symbol: String, kind: String) {
        self.file = file; self.line = line; self.symbol = symbol; self.kind = kind
    }
}
public struct IntentInfo: Codable, Equatable, Sendable {
    public var name: String
    public var evidence: Evidence
    public var parameters: [String]
    public var discoverable: Bool
    public var calls: [String]
}
public struct Capability: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var symbol: String
    public var effect: String
    public var eligibility: String
    public var reason: String
    public var reviewState: String
    public var evidence: [Evidence]
    public var intents: [String]
    public var status: String { eligibility == "excluded" ? "EXCLUDED" : intents.isEmpty ? "MISSING" : "EXPOSED" }
}
public struct AnalysisConfiguration: Codable, Sendable {
    public struct Decision: Codable, Sendable {
        public var eligibility: String
        public var reason: String
        public init(eligibility: String, reason: String) { self.eligibility = eligibility; self.reason = reason }
    }
    public var schemaVersion: Int
    public var sourceRoots: [String]
    public var decisions: [String: Decision]
    public init(sourceRoots: [String] = ["."], decisions: [String: Decision] = [:]) {
        schemaVersion = 1; self.sourceRoots = sourceRoots; self.decisions = decisions
    }
}
public struct CoverageSummary: Codable, Equatable, Sendable {
    public var eligible: Int
    public var exposed: Int
    public var unreviewed: Int
    public var percent: Double?
    public init(eligible: Int, exposed: Int, unreviewed: Int, basis: String) {
        self.eligible = eligible; self.exposed = exposed; self.unreviewed = unreviewed; self.basis = basis
        self.percent = eligible == 0 ? nil : Double(exposed) / Double(eligible) * 100
    }
    public var basis: String
}
public struct Report: Codable, Sendable {
    public var schemaVersion = 1
    public var toolVersion = "0.1.0"
    public var project: String
    public var scope: [String]
    public var sourceDigest: String
    public var capabilities: [Capability]
    public var intents: [IntentInfo]
    public var entities: [String]
    public var queries: [String]
    public var shortcutsProviders: [String]
    public var diagnostics: [String]
    public var runtimeValidation = "not_run"
    public var siriExperience = "not_checked"
    public var coverage: CoverageSummary {
        let eligible = capabilities.filter { $0.eligibility == "eligible" }
        return .init(eligible: eligible.count, exposed: eligible.filter { !$0.intents.isEmpty }.count,
                     unreviewed: capabilities.filter { $0.reviewState == "unreviewed" }.count,
                     basis: capabilities.contains { $0.reviewState == "unreviewed" } ? "provisional_source_mapping" : "reviewed_source_mapping")
    }
    enum CodingKeys: String, CodingKey {
        case schemaVersion, toolVersion, project, scope, sourceDigest, capabilities, intents, entities, queries, shortcutsProviders, diagnostics, runtimeValidation, siriExperience, coverage
    }
    public init(project: String, scope: [String], sourceDigest: String, capabilities: [Capability], intents: [IntentInfo], entities: [String], queries: [String], shortcutsProviders: [String], diagnostics: [String]) {
        self.project = project; self.scope = scope; self.sourceDigest = sourceDigest
        self.capabilities = capabilities; self.intents = intents; self.entities = entities
        self.queries = queries; self.shortcutsProviders = shortcutsProviders; self.diagnostics = diagnostics
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else { throw AnalysisError.invalid("Unsupported report schema") }
        toolVersion = try c.decode(String.self, forKey: .toolVersion)
        project = try c.decode(String.self, forKey: .project); scope = try c.decode([String].self, forKey: .scope)
        sourceDigest = try c.decode(String.self, forKey: .sourceDigest)
        capabilities = try c.decode([Capability].self, forKey: .capabilities)
        intents = try c.decode([IntentInfo].self, forKey: .intents)
        entities = try c.decode([String].self, forKey: .entities); queries = try c.decode([String].self, forKey: .queries)
        shortcutsProviders = try c.decode([String].self, forKey: .shortcutsProviders)
        diagnostics = try c.decode([String].self, forKey: .diagnostics)
        runtimeValidation = try c.decode(String.self, forKey: .runtimeValidation)
        siriExperience = try c.decode(String.self, forKey: .siriExperience)
        guard try c.decode(CoverageSummary.self, forKey: .coverage) == coverage else { throw AnalysisError.invalid("Report coverage does not match capabilities") }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion); try c.encode(toolVersion, forKey: .toolVersion)
        try c.encode(project, forKey: .project); try c.encode(scope, forKey: .scope)
        try c.encode(sourceDigest, forKey: .sourceDigest); try c.encode(capabilities, forKey: .capabilities)
        try c.encode(intents, forKey: .intents); try c.encode(entities, forKey: .entities)
        try c.encode(queries, forKey: .queries); try c.encode(shortcutsProviders, forKey: .shortcutsProviders)
        try c.encode(diagnostics, forKey: .diagnostics); try c.encode(runtimeValidation, forKey: .runtimeValidation)
        try c.encode(siriExperience, forKey: .siriExperience); try c.encode(coverage, forKey: .coverage)
    }
    public func json() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
    public func terminal() -> String {
        let score = coverage.percent.map { String(format: "%.0f%%", $0) } ?? "N/A"
        var lines = ["IntentCoverage · \(project)", "", "App Intent source coverage: \(score) (\(coverage.exposed)/\(coverage.eligible))", "Basis: \(coverage.basis)", "Unreviewed candidates: \(coverage.unreviewed)", ""]
        for cap in capabilities { lines.append("\(cap.status == "EXPOSED" ? "✓" : "○") \(cap.name)  [\(cap.status)]  \(cap.intents.joined(separator: ", "))") }
        lines += ["", "Runtime validation: \(runtimeValidation)", "Siri experience: \(siriExperience)"]
        lines += diagnostics.map { "Note: \($0)" }; return lines.joined(separator: "\n")
    }
}
public enum AnalysisError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): message } }
}
