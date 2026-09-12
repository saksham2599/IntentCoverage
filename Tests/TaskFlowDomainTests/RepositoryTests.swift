import Foundation
import Testing
@testable import TaskFlowDomain

struct RepositoryTests {
    func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("IntentCoverageTests-\(UUID())/tasks.json") }
    @Test func persistenceAndFiveOperations() async throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = TaskRepository(url: url)
        let first = try await repo.createTask(title: "  Café launch  ")
        let second = try await repo.createTask(title: "Buy milk")
        #expect(first.title == "Café launch")
        #expect(try await TaskRepository(url: url).allTasks().count == 2)
        #expect(try await repo.searchTasks(query: "CAFE").map(\.id) == [first.id])
        #expect(try await repo.searchTasks(query: "absent").isEmpty)
        #expect(try await repo.searchTasks(query: " ").map(\.id) == [first.id, second.id])
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(try await repo.changeDueDate(id: first.id, date: date).dueDate == date)
        #expect(try await repo.completeTask(id: first.id).isCompleted)
        #expect(try await repo.completeTask(id: first.id).isCompleted)
        let cleared = try await repo.changeDueDate(id: first.id, date: nil)
        #expect(cleared.dueDate == nil && cleared.isCompleted && cleared.title == first.title)
        try await repo.deleteTask(id: first.id)
        #expect(try await repo.tasks(for: [first.id, second.id]).map(\.id) == [second.id])
        await #expect(throws: TaskError.notFound) { try await repo.deleteTask(id: first.id) }
        await #expect(throws: TaskError.emptyTitle) { try await repo.createTask(title: " \n ") }
    }
    @Test func corruptStoreIsNotOverwritten() async throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let invalid = Data("not JSON".utf8); try invalid.write(to: url)
        await #expect(throws: (any Error).self) { try await TaskRepository(url: url).createTask(title: "No data loss") }
        #expect(try Data(contentsOf: url) == invalid)
    }
    @Test func concurrentWritesAreSerialized() async throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = TaskRepository(url: url)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<30 { group.addTask { _ = try await repo.createTask(title: "Task \(i)") } }
            try await group.waitForAll()
        }
        #expect(try await repo.allTasks().count == 30)
    }
}
