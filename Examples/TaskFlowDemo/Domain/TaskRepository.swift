import Foundation

public struct TaskRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var dueDate: Date?
    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false, dueDate: Date? = nil) {
        self.id = id; self.title = title; self.isCompleted = isCompleted; self.dueDate = dueDate
    }
}

public enum TaskError: Error, LocalizedError, Equatable {
    case emptyTitle, notFound
    public var errorDescription: String? {
        switch self { case .emptyTitle: "Give your task a title."; case .notFound: "This task no longer exists." }
    }
}

/// All mutations persist before publishing new state. UI and intents share this actor.
public actor TaskRepository {
    public static let shared: TaskRepository = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        // Only a UUID is accepted, so a launch argument cannot choose an arbitrary file.
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--test-store"), args.indices.contains(index + 1),
           let id = UUID(uuidString: args[index + 1]) {
            return TaskRepository(url: base.appendingPathComponent("TaskFlowTests/\(id.uuidString).json"))
        }
        #endif
        return TaskRepository(url: base.appendingPathComponent("TaskFlow/tasks.json"))
    }()
    private let url: URL
    public init(url: URL) { self.url = url }

    private func load() throws -> [TaskRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([TaskRecord].self, from: Data(contentsOf: url))
    }
    private func save(_ records: [TaskRecord]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(records).write(to: url, options: .atomic)
    }
    public func allTasks() throws -> [TaskRecord] { try load() }
    public func tasks(for identifiers: [UUID]) throws -> [TaskRecord] {
        let records = try load()
        return identifiers.compactMap { id in records.first { $0.id == id } }
    }
    @discardableResult public func createTask(title: String) throws -> TaskRecord {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw TaskError.emptyTitle }
        var records = try load()
        let record = TaskRecord(title: cleaned)
        records.append(record); try save(records); return record
    }
    @discardableResult public func completeTask(id: UUID) throws -> TaskRecord {
        var records = try load()
        guard let index = records.firstIndex(where: { $0.id == id }) else { throw TaskError.notFound }
        records[index].isCompleted = true; try save(records); return records[index]
    }
    public func deleteTask(id: UUID) throws {
        var records = try load()
        guard let index = records.firstIndex(where: { $0.id == id }) else { throw TaskError.notFound }
        records.remove(at: index); try save(records)
    }
    /// Empty queries return all tasks; matching ignores case and diacritics and preserves creation order.
    public func searchTasks(query: String) throws -> [TaskRecord] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return try load().filter { cleaned.isEmpty || $0.title.range(of: cleaned, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) != nil }
    }
    @discardableResult public func changeDueDate(id: UUID, date: Date?) throws -> TaskRecord {
        var records = try load()
        guard let index = records.firstIndex(where: { $0.id == id }) else { throw TaskError.notFound }
        records[index].dueDate = date; try save(records); return records[index]
    }
}
