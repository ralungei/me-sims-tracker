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
    /// User asked to be notified when the task is due.
    var notify: Bool = false

    init(title: String, dueDate: Date? = nil, notes: String? = nil, notify: Bool = false) {
        self.id = UUID()
        self.title = title
        self.dueDate = dueDate
        self.notes = notes
        self.isDone = false
        self.createdAt = Date()
        self.notify = notify
    }

    var isOverdue: Bool {
        guard let due = dueDate, !isDone else { return false }
        return due < Date()
    }

    var isToday: Bool {
        guard let due = dueDate else { return true }   // no date → "today" bucket
        return Calendar.current.isDateInToday(due)
    }

    /// Whether `dueDate` has a meaningful hour/minute (i.e. the user set a
    /// specific time, not just a date).
    var hasSpecificTime: Bool {
        guard let due = dueDate else { return false }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: due)
        return (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
    }
}

extension LifeTask: Identifiable {}
