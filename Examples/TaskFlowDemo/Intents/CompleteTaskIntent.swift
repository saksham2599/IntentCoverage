import AppIntents

struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static let description = IntentDescription("Mark a task as complete.")
    @Parameter(title: "Task") var task: TaskEntity
    static var parameterSummary: some ParameterSummary { Summary("Complete \(\.$task)") }
    func perform() async throws -> some IntentResult & ReturnsValue<TaskEntity> {
        let record = try await TaskRepository.shared.completeTask(id: task.id)
        return .result(value: TaskEntity(record: record))
    }
}
