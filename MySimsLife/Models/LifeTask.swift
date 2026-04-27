import SwiftUI
import SwiftData

// MARK: - LifeTask (one-off agenda item, syncs via CloudKit)

@Model
final class LifeTask {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var dueDate: Date?
    var isDone: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    init(title: String, dueDate: Date? = nil, notes: String? = nil) {
        self.id = UUID()
        self.title = title
        self.dueDate = dueDate
        self.notes = notes
        self.isDone = false
        self.createdAt = Date()
    }

    var isOverdue: Bool {
        guard let due = dueDate, !isDone else { return false }
        return due < Date()
    }

    var isToday: Bool {
        guard let due = dueDate else { return true }   // no date → "today" bucket
        return Calendar.current.isDateInToday(due)
    }
}
