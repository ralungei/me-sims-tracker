import Foundation

extension Date {
    /// Human-friendly label for a date in the future: "hoy", "mañana", "en N días",
    /// or an absolute "d MMM" string for further dates.
    func relativeFutureLabel(reference: Date = Date()) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: reference),
                                      to: cal.startOfDay(for: self)).day ?? 0
        if days <= 0 { return "hoy" }
        if days == 1 { return "mañana" }
        if days <= 14 { return "en \(days) días" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM"
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
