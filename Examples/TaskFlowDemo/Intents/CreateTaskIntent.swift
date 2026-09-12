import AppIntents

struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Task"
    static let description = IntentDescription("Add a task to TaskFlow.")
    @Parameter(title: "Title") var title: String
    static var parameterSummary: some ParameterSummary { Summary("Create \(\.$title)") }
    func perform() async throws -> some IntentResult & ReturnsValue<TaskEntity> {
        let record = try await TaskRepository.shared.createTask(title: title)
        return .result(value: TaskEntity(record: record))
    }
}
