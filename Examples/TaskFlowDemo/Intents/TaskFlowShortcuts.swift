import AppIntents

struct TaskFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CreateTaskIntent(), phrases: ["Create a task in \(.applicationName)"], shortTitle: "Create Task", systemImageName: "plus.circle")
        AppShortcut(intent: CompleteTaskIntent(), phrases: ["Complete a task in \(.applicationName)"], shortTitle: "Complete Task", systemImageName: "checkmark.circle")
    }
}
