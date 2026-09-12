import Foundation
import CryptoKit
import SwiftParser
import SwiftSyntax

private struct Call { var symbol: String; var evidence: Evidence }
private struct Method { var name: String; var signature: String; var evidence: Evidence; var calls: [Call]; var parameters: [String] }
private struct Nominal { var name: String; var inherited: [String]; var evidence: Evidence; var methods: [Method]; var calls: [Call]; var hidden: Bool; var conditional: Bool; var parameters: [String]; var primary: Bool; var isProtocol: Bool }

private final class CallVisitor: SyntaxVisitor {
    let file: String
    let converter: SourceLocationConverter
    var calls: [Call] = []
    init(file: String, converter: SourceLocationConverter) { self.file = file; self.converter = converter; super.init(viewMode: .sourceAccurate) }
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // Deliberately supports explicit Type.shared.method or Type.method only.
        // Instance receivers need compiler-backed resolution and are not guessed.
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base {
            let parts = base.trimmedDescription.split(separator: ".").map(String.init)
            if (parts.count == 1 || (parts.count == 2 && parts[1] == "shared")),
               let type = parts.first, type.first?.isUppercase == true {
                let symbol = "\(type).\(member.declName.baseName.text)"
                calls.append(.init(symbol: symbol, evidence: .init(file: file, line: node.startLocation(converter: converter).line, symbol: symbol, kind: "call")))
            }
        }
        return .visitChildren
    }
}
private final class FileVisitor: SyntaxVisitor {
    let file: String
    let converter: SourceLocationConverter
    var types: [Nominal] = []
    init(file: String, tree: SourceFileSyntax) { self.file = file; converter = .init(fileName: file, tree: tree); super.init(viewMode: .sourceAccurate) }
    func capture(_ name: String, inheritance: InheritanceClauseSyntax?, members: MemberBlockSyntax, node: some SyntaxProtocol) {
        let inherited = inheritance?.inheritedTypes.map { inherited -> String in
            let raw = inherited.type.trimmedDescription
            let pieces = raw.split(separator: ".")
            if pieces.count == 2 && ["AppIntents", "SwiftUI"].contains(String(pieces[0])) { return String(pieces[1]) }
            return raw
        } ?? []
        let calls = CallVisitor(file: file, converter: converter); calls.walk(members)
        var methods: [Method] = []
        for member in members.members {
            guard let fn = member.decl.as(FunctionDeclSyntax.self) else { continue }
            let collector = CallVisitor(file: file, converter: converter)
            if let body = fn.body { collector.walk(body) }
            let params = fn.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text }
            methods.append(.init(name: fn.name.text, signature: fn.signature.trimmedDescription,
                                 evidence: .init(file: file, line: fn.startLocation(converter: converter).line, symbol: "\(name).\(fn.name.text)", kind: "declaration"),
                                 calls: collector.calls, parameters: params))
        }
        let parameters = members.members.flatMap { member -> [String] in
            guard let property = member.decl.as(VariableDeclSyntax.self), property.attributes.contains(where: { element in
                element.as(AttributeSyntax.self)?.attributeName.trimmedDescription.split(separator: ".").last == "Parameter"
            }) else { return [] }
            return property.bindings.map { $0.pattern.trimmedDescription }
        }
        let hidden = members.members.contains { member in
            guard let property = member.decl.as(VariableDeclSyntax.self) else { return false }
            return property.bindings.contains { binding in
                binding.pattern.trimmedDescription == "isDiscoverable" &&
                (binding.initializer?.value.trimmedDescription != "true" && binding.accessorBlock?.trimmedDescription.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression) != "{true}")
            }
        }
        var ancestor = node.parent; var conditional = false
        while let current = ancestor { if current.is(IfConfigDeclSyntax.self) { conditional = true }; ancestor = current.parent }
        types.append(.init(name: name, inherited: inherited,
                           evidence: .init(file: file, line: node.startLocation(converter: converter).line, symbol: name, kind: "type"),
                           methods: methods, calls: calls.calls, hidden: hidden, conditional: conditional, parameters: parameters, primary: !node.is(ExtensionDeclSyntax.self), isProtocol: node.is(ProtocolDeclSyntax.self)))
    }
    override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { capture(n.name.text, inheritance: n.inheritanceClause, members: n.memberBlock, node: n); return .visitChildren }
    override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { capture(n.name.text, inheritance: n.inheritanceClause, members: n.memberBlock, node: n); return .visitChildren }
    override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { capture(n.name.text, inheritance: n.inheritanceClause, members: n.memberBlock, node: n); return .visitChildren }
    override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { capture(n.name.text, inheritance: n.inheritanceClause, members: n.memberBlock, node: n); return .visitChildren }
    override func visit(_ n: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { capture(n.name.text, inheritance: n.inheritanceClause, members: n.memberBlock, node: n); return .visitChildren }
    override func visit(_ n: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind { capture(n.extendedType.trimmedDescription, inheritance: n.inheritanceClause, members: n.memberBlock, node: n); return .visitChildren }
}

public struct Analyzer {
    public init() {}
    public func analyze(root: URL) throws -> Report {
        let root = root.standardizedFileURL.resolvingSymlinksInPath()
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &directory), directory.boolValue else { throw AnalysisError.invalid("Project directory does not exist: \(root.path)") }
        let configURL = root.appendingPathComponent(".intentcoverage.json")
        let config = try FileManager.default.fileExists(atPath: configURL.path) ? JSONDecoder().decode(AnalysisConfiguration.self, from: Data(contentsOf: configURL)) : AnalysisConfiguration()
        guard config.schemaVersion == 1, !config.sourceRoots.isEmpty else { throw AnalysisError.invalid("Invalid configuration schema or empty source roots") }
        for (id, decision) in config.decisions {
            guard ["eligible", "excluded", "needs_review"].contains(decision.eligibility), !decision.reason.isEmpty else { throw AnalysisError.invalid("Invalid decision for \(id)") }
        }
        var files = Set<URL>()
        let excluded = Set([".build", ".git", ".swiftpm", ".intentcoverage", "Tests", "test", "tests", "node_modules", "Pods", "Carthage", "DerivedData", "build"])
        for source in config.sourceRoots {
            let url = root.appendingPathComponent(source).standardizedFileURL.resolvingSymlinksInPath()
            guard url.path == root.path || url.path.hasPrefix(root.path + "/") else { throw AnalysisError.invalid("Source root escapes project: \(source)") }
            guard FileManager.default.fileExists(atPath: url.path) else { throw AnalysisError.invalid("Source root missing: \(source)") }
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else { throw AnalysisError.invalid("Cannot enumerate \(source)") }
            for case let file as URL in enumerator {
                let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                let name = file.lastPathComponent
                if values.isSymbolicLink == true || excluded.contains(name) || name.hasSuffix("Tests") || name.hasSuffix(".xcodeproj") || name.hasSuffix(".xcworkspace") { enumerator.skipDescendants(); continue }
                if file.pathExtension == "swift" && values.isDirectory != true { files.insert(file) }
            }
        }
        guard !files.isEmpty else { throw AnalysisError.invalid("No Swift source files found in selected roots") }
        var types: [Nominal] = []; var hash = SHA256()
        // Include policy in the digest so decisions invalidate stale receipts too.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        hash.update(data: try encoder.encode(config))
        for file in files.sorted(by: { $0.path < $1.path }) {
            let relative = String(file.path.dropFirst(root.path.count + 1))
            let data = try Data(contentsOf: file)
            guard let source = String(data: data, encoding: .utf8) else { throw AnalysisError.invalid("Non UTF-8 source: \(relative)") }
            hash.update(data: Data(relative.utf8)); hash.update(data: Data([0])); hash.update(data: data)
            let tree = Parser.parse(source: source)
            guard !tree.hasError else { throw AnalysisError.invalid("Swift syntax errors in \(relative); refusing a misleading partial score") }
            let visitor = FileVisitor(file: relative, tree: tree); visitor.walk(tree); types += visitor.types
        }
        let grouped = Dictionary(grouping: types, by: \.name)
        // Merge local extensions; ambiguous duplicate primary declarations remain unresolved.
        let inherited = grouped.mapValues { Set($0.flatMap(\.inherited)) }
        func conforms(_ type: String, _ names: Set<String>, seen: Set<String> = []) -> Bool {
            guard !seen.contains(type) else { return false }
            let parents = inherited[type] ?? []
            return !parents.isDisjoint(with: names) || parents.contains { conforms($0, names, seen: seen.union([type])) }
        }
        let intentProtocols: Set<String> = ["AppIntent", "OpenIntent", "DeleteIntent", "SetValueIntent", "AudioPlaybackIntent", "LiveActivityIntent", "WidgetConfigurationIntent", "AppConfigurationIntent"]
        var intents: [IntentInfo] = []
        for name in grouped.keys.sorted() where conforms(name, intentProtocols) && !grouped[name]!.allSatisfy(\.isProtocol) {
            let declarations = grouped[name]!
            guard declarations.filter(\.primary).count <= 1, !declarations.contains(where: \.conditional), let first = declarations.first else { continue }
            let params = declarations.flatMap(\.methods).first { $0.name == "perform" }?.calls ?? []
            intents.append(.init(name: name, evidence: first.evidence, parameters: declarations.flatMap(\.parameters).sorted(), discoverable: !declarations.contains(where: \.hidden), calls: Array(Set(params.map(\.symbol))).sorted()))
        }
        let uiCalls = types.filter { conforms($0.name, ["View", "App"]) && !$0.conditional }.flatMap(\.calls)
        let methods = types.filter { !$0.conditional }.flatMap(\.methods)
        let methodGroups = Dictionary(grouping: methods, by: { $0.evidence.symbol })
        var capabilities: [Capability] = []
        var diagnostics = ["Source mapping only; Xcode target membership and runtime behavior are not inferred.", "Discovery supports explicit Type.shared.method calls from SwiftUI View/App types. Instance receivers, macro expansion, conditional declarations and dynamic dispatch need review."]
        for symbol in Set(uiCalls.map(\.symbol)).sorted() {
            guard let matches = methodGroups[symbol], matches.count == 1, let method = matches.first else {
                if methodGroups[symbol] != nil { diagnostics.append("Ambiguous overload: \(symbol)") }; continue
            }
            let words = method.name.replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression).split(separator: " ").map(String.init)
            guard let verb = words.first, ["create", "complete", "delete", "search", "change", "archive", "share", "rename", "duplicate", "add", "remove", "update"].contains(verb.lowercased()) else { continue }
            let id = words.map { $0.lowercased() }.joined(separator: "_")
            let decision = config.decisions[id]
            let effect = ["delete", "remove"].contains(verb.lowercased()) ? "destructive" : verb.lowercased() == "search" ? "read" : "write"
            capabilities.append(.init(id: id, name: words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " "), symbol: symbol, effect: effect,
                                     eligibility: decision?.eligibility ?? (effect == "destructive" ? "needs_review" : "eligible"),
                                     reason: decision?.reason ?? "UI calls an explicit domain operation; eligibility needs developer review.",
                                     reviewState: decision == nil ? "unreviewed" : "reviewed",
                                     evidence: [method.evidence] + uiCalls.filter { $0.symbol == symbol }.map(\.evidence),
                                     intents: intents.filter { $0.discoverable && $0.calls.contains(symbol) }.map(\.name)))
        }
        let ids = capabilities.map(\.id)
        guard Set(ids).count == ids.count else { throw AnalysisError.invalid("Capability ID collision; narrow source roots or rename ambiguous operations before scoring") }
        for key in config.decisions.keys.sorted() where !ids.contains(key) { diagnostics.append("Reviewed capability not rediscovered: \(key)") }
        return Report(project: root.lastPathComponent, scope: config.sourceRoots.sorted(), sourceDigest: hash.finalize().map { String(format: "%02x", $0) }.joined(),
                      capabilities: capabilities.sorted { $0.id < $1.id }, intents: intents,
                      entities: grouped.keys.filter { conforms($0, ["AppEntity", "IndexedEntity", "TransientAppEntity"]) }.sorted(),
                      queries: grouped.keys.filter { conforms($0, ["EntityQuery", "EntityStringQuery", "EnumerableEntityQuery", "EntityPropertyQuery"]) }.sorted(),
                      shortcutsProviders: grouped.keys.filter { conforms($0, ["AppShortcutsProvider"]) }.sorted(), diagnostics: diagnostics)
    }
}
