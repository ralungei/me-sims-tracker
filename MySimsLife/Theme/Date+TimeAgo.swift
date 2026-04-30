import Foundation

extension Date {
    /// Human-friendly label for a date in the future: "hoy", "mañana", "en N días",
    /// or an absolute date string for further dates. Uses the user's current
    /// locale via `String(localized:)`.
    func relativeFutureLabel(reference: Date = Date()) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: reference),
                                      to: cal.startOfDay(for: self)).day ?? 0
        if days <= 0 { return String(localized: "hoy") }
        if days == 1 { return String(localized: "mañana") }
        if days <= 14 { return String(localized: "en \(days) días") }
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f.string(from: self)
    }

    enum TimeAgoStyle {
        case short    // "ahora" / "5m" / "3h" / "2d"
        case long     // "ahora mismo" / "hace 5 min" / "hace 3 h" / "hace 2 d"
    }

    func timeAgo(style: TimeAgoStyle = .short, reference: Date = Date()) -> String {
        let secs = Int(reference.timeIntervalSince(self))
        switch style {
        case .short:
            if secs < 60 { return String(localized: "ahora") }
            let mins = secs / 60
            if mins < 60 { return String(localized: "\(mins)m") }
            let hrs = mins / 60
            if hrs < 24 { return String(localized: "\(hrs)h") }
            return String(localized: "\(hrs / 24)d")
        case .long:
            if secs < 60 { return String(localized: "ahora mismo") }
            let mins = secs / 60
            if mins < 60 { return String(localized: "hace \(mins) min") }
            let hrs = mins / 60
            if hrs < 24 { return String(localized: "hace \(hrs) h") }
            return String(localized: "hace \(hrs / 24) d")
        }
    }
}
