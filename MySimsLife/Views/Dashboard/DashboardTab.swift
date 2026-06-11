import SwiftUI

// MARK: - Dashboard tabs

enum DashboardTab: String, CaseIterable, Identifiable {
    case needs, aspirations, botiquin, agenda

    var id: String { rawValue }

    var label: String {
        switch self {
        case .needs:        return String(localized: "Necesidades")
        case .aspirations:  return String(localized: "Aspiraciones")
        case .agenda:       return String(localized: "Agenda")
        case .botiquin:     return String(localized: "Botiquín")
        }
    }

    var icon: String {
        switch self {
        case .needs:        return "chart.bar.xaxis"
        case .aspirations:  return "flag.pattern.checkered"
        case .agenda:       return "checklist"
        case .botiquin:     return "pills.fill"
        }
    }
}
