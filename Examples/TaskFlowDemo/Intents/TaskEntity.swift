import AppIntents
import Foundation

struct TaskEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Task"
    static let defaultQuery = TaskEntityQuery()
    let id: UUID
    @Property(title: "Title") var title: String
    @Property(title: "Completed") var isCompleted: Bool
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
    init(record: TaskRecord) { id = record.id; title = record.title; isCompleted = record.isCompleted }
}
struct TaskEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [TaskEntity] { try await TaskRepository.shared.tasks(for: identifiers).map(TaskEntity.init) }
    func suggestedEntities() async throws -> [TaskEntity] { try await TaskRepository.shared.allTasks().map(TaskEntity.init) }
    func entities(matching string: String) async throws -> [TaskEntity] { try await TaskRepository.shared.searchTasks(query: string).map(TaskEntity.init) }
}
