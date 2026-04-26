import Foundation

extension Date {
    enum TimeAgoStyle {
        case short    // "ahora" / "5m" / "3h" / "2d"
        case long     // "ahora mismo" / "hace 5 min" / "hace 3 h" / "hace 2 d"
    }

    func timeAgo(style: TimeAgoStyle = .short, reference: Date = Date()) -> String {
        let secs = Int(reference.timeIntervalSince(self))
        switch style {
        case .short:
            if secs < 60 { return "ahora" }
            let mins = secs / 60
            if mins < 60 { return "\(mins)m" }
            let hrs = mins / 60
            if hrs < 24 { return "\(hrs)h" }
            return "\(hrs / 24)d"
        case .long:
            if secs < 60 { return "ahora mismo" }
            let mins = secs / 60
            if mins < 60 { return "hace \(mins) min" }
            let hrs = mins / 60
            if hrs < 24 { return "hace \(hrs) h" }
            return "hace \(hrs / 24) d"
        }
    }
}
