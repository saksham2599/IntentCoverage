import SwiftUI

@main
struct TaskFlowApp: App {
    var body: some Scene { WindowGroup { TaskListView() } }
}

struct TaskListView: View {
    @State private var records: [TaskRecord] = []
    @State private var title = ""
    @State private var query = ""
    @State private var error: String?
    @State private var pendingDelete: TaskRecord?
    @State private var editingDate: TaskRecord?
    @State private var selectedDate = Date()
    @State private var busy = false
    private enum Field: Hashable { case title, search }
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme
    private var ink: Color { colorScheme == .dark ? Color(red: 0.91, green: 0.94, blue: 0.88) : Color(red: 0.13, green: 0.24, blue: 0.23) }
    private var accent: Color { colorScheme == .dark ? Color(red: 0.57, green: 0.77, blue: 0.64) : Color(red: 0.22, green: 0.43, blue: 0.37) }
    private var canvas: Color { colorScheme == .dark ? Color(red: 0.06, green: 0.10, blue: 0.09) : Color(red: 0.96, green: 0.96, blue: 0.92) }
    private var card: Color { colorScheme == .dark ? Color(red: 0.11, green: 0.16, blue: 0.14) : .white }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A LITTLE SPACE TO FOCUS").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(accent)
                        Text("Make room for\nwhat matters.").font(.system(size: 37, weight: .semibold, design: .serif)).foregroundStyle(ink)
                        Text("\(records.filter { !$0.isCompleted }.count) open · \(records.filter(\.isCompleted).count) complete")
                            .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("taskSummary")
                    }.padding(.top, 8)
                    HStack(spacing: 12) {
                        TextField("What needs doing?", text: $title).focused($focusedField, equals: .title).accessibilityIdentifier("newTaskTitle").submitLabel(.done).onSubmit { create() }
                        Button(action: create) { Image(systemName: "plus").font(.headline).frame(width: 44, height: 44).background(accent, in: Circle()).foregroundStyle(colorScheme == .dark ? canvas : .white) }
                            .accessibilityLabel("Add task").accessibilityIdentifier("addTask").disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.padding(12).background(card.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(accent)
                        TextField("Find a task", text: $query).focused($focusedField, equals: .search).accessibilityIdentifier("searchTasks").autocorrectionDisabled()
                        if !query.isEmpty { Button { focusedField = nil; query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
                    }.padding(14).background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                    if records.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: query.isEmpty ? "leaf" : "magnifyingglass").font(.largeTitle).foregroundStyle(accent)
                            Text(query.isEmpty ? "Start with one small thing." : "No matching tasks.").font(.headline)
                            Text(query.isEmpty ? "Your tasks stay on this iPhone." : "Try another word or clear your search.").font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 48).accessibilityIdentifier("emptyState")
                    } else {
                        VStack(spacing: 12) { ForEach(records) { record in row(record) } }
                    }
                    Text("TASKFLOW").font(.caption2.weight(.semibold)).tracking(3).foregroundStyle(accent.opacity(0.6)).frame(maxWidth: .infinity).padding(.top, 12)
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(canvas)
            .navigationTitle("Today").navigationBarTitleDisplayMode(.inline)
            .task(id: query) { await refresh() }
            .refreshable { await refresh() }
            .alert("Something needs attention", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
            .alert("Delete this task?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), presenting: pendingDelete) { record in
                Button("Delete task", role: .destructive) { delete(record) }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { record in Text(record.title) }
            .sheet(item: $editingDate) { record in
                NavigationStack {
                    Form {
                        Text(record.title).font(.headline)
                        DatePicker("Due date", selection: $selectedDate, displayedComponents: .date).datePickerStyle(.graphical)
                        Button("Remove due date") { changeDate(record, date: nil) }.accessibilityIdentifier("removeDueDate")
                    }.navigationTitle("Plan a day").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingDate = nil } }
                            ToolbarItem(placement: .confirmationAction) { Button("Save") { changeDate(record, date: selectedDate) }.accessibilityIdentifier("saveDueDate") }
                        }
                }.presentationDetents([.large])
            }
        }.tint(accent)
    }
    private func row(_ record: TaskRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { complete(record) } label: { Image(systemName: record.isCompleted ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(accent).frame(width: 36, height: 44) }
                .accessibilityLabel(record.isCompleted ? "Completed \(record.title)" : "Complete \(record.title)").disabled(record.isCompleted)
            VStack(alignment: .leading, spacing: 7) {
                Text(record.title).font(.body.weight(.medium)).strikethrough(record.isCompleted).foregroundStyle(record.isCompleted ? .secondary : ink)
                if let date = record.dueDate { Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar").font(.caption).foregroundStyle(accent).accessibilityIdentifier("dueDate-\(record.title)") }
                HStack(spacing: 18) {
                    Button("Plan day") { focusedField = nil; selectedDate = record.dueDate ?? Date(); editingDate = record }.accessibilityLabel("Plan \(record.title)")
                    Button("Delete", role: .destructive) { focusedField = nil; pendingDelete = record }.accessibilityLabel("Delete \(record.title)")
                }.font(.caption).padding(.top, 3)
            }.padding(.vertical, 9)
            Spacer(minLength: 0)
        }.padding(12).background(card.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }
    @MainActor private func refresh() async {
        do {
            let requestedQuery = query
            let result = try await TaskRepository.shared.searchTasks(query: requestedQuery)
            guard !Task.isCancelled, requestedQuery == query else { return }
            records = result
        } catch { self.error = error.localizedDescription }
    }
    private func create() {
        guard !busy else { return }; busy = true; focusedField = nil
        let input = title
        Task { @MainActor in
            defer { busy = false }
            do { _ = try await TaskRepository.shared.createTask(title: input); title = ""; await refresh() }
            catch { self.error = error.localizedDescription }
        }
    }
    private func complete(_ record: TaskRecord) {
        focusedField = nil
        Task { @MainActor in
            do { _ = try await TaskRepository.shared.completeTask(id: record.id); await refresh() }
            catch { self.error = error.localizedDescription }
        }
    }
    private func delete(_ record: TaskRecord) {
        pendingDelete = nil
        Task { @MainActor in
            do { try await TaskRepository.shared.deleteTask(id: record.id); await refresh() }
            catch { self.error = error.localizedDescription }
        }
    }
    private func changeDate(_ record: TaskRecord, date: Date?) {
        Task { @MainActor in
            do { _ = try await TaskRepository.shared.changeDueDate(id: record.id, date: date); editingDate = nil; await refresh() }
            catch { self.error = error.localizedDescription }
        }
    }
}
