import Foundation
import SwiftData

@Model
final class ActivityLog {
    var id: UUID = UUID()
    var needType: String = ""
    var actionName: String = ""
    var actionIcon: String = "circle"
    var boostAmount: Double = 0
    var timestamp: Date = Date()
    var notes: String?

    init(needType: NeedType, actionName: String, actionIcon: String, boostAmount: Double, notes: String? = nil) {
        self.id = UUID()
        self.needType = needType.rawValue
        self.actionName = actionName
        self.actionIcon = actionIcon
        self.boostAmount = boostAmount
        self.timestamp = Date()
        self.notes = notes
    }

    var need: NeedType? {
        NeedType(rawValue: needType)
    }
}
