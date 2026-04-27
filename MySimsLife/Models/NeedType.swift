import SwiftUI

// MARK: - Need Type

enum NeedType: String, CaseIterable, Codable, Identifiable {
    case health
    case energy
    case nutrition
    case hydration
    case bladder
    case exercise
    case hygiene
    case environment
    case social
    case leisure

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .health:      return "Salud"
        case .energy:      return "Energía"
        case .nutrition:   return "Nutrición"
        case .hydration:   return "Hidratación"
        case .bladder:     return "Vejiga"
        case .exercise:    return "Ejercicio"
        case .hygiene:     return "Higiene"
        case .environment: return "Entorno"
        case .social:      return "Social"
        case .leisure:     return "Ocio"
        }
    }

    var icon: String {
        switch self {
        case .health:      return "cross.case.fill"
        case .energy:      return "bolt.fill"
        case .nutrition:   return "fork.knife"
        case .hydration:   return "drop.fill"
        case .bladder:     return "toilet.fill"
        case .exercise:    return "figure.run"
        case .hygiene:     return "shower.fill"
        case .environment: return "house.fill"
        case .social:      return "person.2.fill"
        case .leisure:     return "gamecontroller.fill"
        }
    }

    /// Decay rate per hour. 0 = manual-only (doesn't drop on its own).
    var decayRatePerHour: Double {
        switch self {
        case .health:      return 0       // manual-only — only changes when user logs an ailment
        case .energy:      return 6.25
        case .nutrition:   return 6.0
        case .hydration:   return 7.0
        case .bladder:     return 12.5    // ~8h to empty
        case .exercise:    return 4.17
        case .hygiene:     return 4.17
        case .environment: return 2.5
        case .social:      return 2.08
        case .leisure:     return 3.5
        }
    }

    /// Whether this need decays automatically. False for manual-only needs like health.
    var decaysAutomatically: Bool { decayRatePerHour > 0 }

    var moodWeight: Double {
        switch self {
        case .health:      return 1.8
        case .energy:      return 1.5
        case .nutrition:   return 1.3
        case .hydration:   return 1.2
        case .bladder:     return 1.0
        case .exercise:    return 1.0
        case .hygiene:     return 0.8
        case .environment: return 0.7
        case .social:      return 1.1
        case .leisure:     return 0.9
        }
    }

    /// Hue 0–360 — elegant signature color per need (dusty pastel palette)
    var hue: Double {
        switch self {
        case .health:      return 145   // sage green
        case .energy:      return 38    // champagne
        case .nutrition:   return 22    // honey caramel
        case .hydration:   return 195   // dusty teal
        case .bladder:     return 50    // amber yellow
        case .exercise:    return 335   // dusty rose
        case .hygiene:     return 158   // sage mint
        case .environment: return 258   // soft lavender
        case .social:      return 295   // muted orchid
        case .leisure:     return 220   // indigo blue
        }
    }

    var emoji: String {
        switch self {
        case .health:      return "🩺"
        case .energy:      return "⚡"
        case .nutrition:   return "🍽"
        case .hydration:   return "💧"
        case .bladder:     return "🚽"
        case .exercise:    return "🏃"
        case .hygiene:     return "🚿"
        case .environment: return "🏠"
        case .social:      return "👥"
        case .leisure:     return "🎮"
        }
    }

    var sortOrder: Int {
        switch self {
        case .health:      return 0
        case .energy:      return 1
        case .nutrition:   return 2
        case .hydration:   return 3
        case .bladder:     return 4
        case .exercise:    return 5
        case .hygiene:     return 6
        case .environment: return 7
        case .social:      return 8
        case .leisure:     return 9
        }
    }

    static let sorted: [NeedType] = allCases.sorted { $0.sortOrder < $1.sortOrder }

    // MARK: - Quick Actions

    var quickActions: [QuickAction] {
        switch self {
        case .health:
            return [
                QuickAction(name: "Estoy sano",       icon: "heart.fill",            boost: 100),
                QuickAction(name: "Recuperándome",    icon: "leaf.fill",             boost: 30),
                QuickAction(name: "Cansancio fuerte", icon: "zzz",                   boost: -25),
                QuickAction(name: "Resfriado",        icon: "wind.snow",             boost: -30),
                QuickAction(name: "Gripe",            icon: "thermometer.high",      boost: -50),
                QuickAction(name: "Migraña",          icon: "brain.head.profile",    boost: -40),
                QuickAction(name: "Mal del estómago", icon: "exclamationmark.bubble.fill", boost: -35),
                QuickAction(name: "Lesión / dolor",   icon: "bandage.fill",          boost: -30),
            ]
        case .bladder:
            return [
                QuickAction(name: "Pis claro",      icon: "drop.fill",             boost: 100),
                QuickAction(name: "Pis amarillo",   icon: "drop.fill",             boost: 80),
                QuickAction(name: "Pis oscuro",     icon: "drop.triangle.fill",    boost: 60),
                QuickAction(name: "Caca normal",    icon: "checkmark.seal.fill",   boost: 100),
                QuickAction(name: "Caca blanda",    icon: "exclamationmark.triangle.fill", boost: 60),
                QuickAction(name: "Caca dura",      icon: "exclamationmark.triangle.fill", boost: 60),
                QuickAction(name: "Aguanté mucho",  icon: "clock.fill",            boost: -10),
            ]
        case .energy:
            return [
                QuickAction(name: "Dormí 8h",   icon: "bed.double.fill",  boost: 100),
                QuickAction(name: "Dormí 7h",   icon: "bed.double.fill",  boost: 85),
                QuickAction(name: "Dormí 6h",   icon: "bed.double.fill",  boost: 70),
                QuickAction(name: "Siesta",      icon: "powersleep",       boost: 25),
                QuickAction(name: "Descansé",    icon: "sofa.fill",        boost: 10),
                QuickAction(name: "Insomnio",    icon: "moon.zzz.fill",   boost: -20),
                QuickAction(name: "Mala noche",  icon: "bed.double.fill",  boost: -15),
            ]
        case .nutrition:
            return [
                QuickAction(name: "Desayuno",      icon: "cup.and.saucer.fill",              boost: 50),
                QuickAction(name: "Almuerzo",      icon: "takeoutbag.and.cup.and.straw.fill", boost: 55),
                QuickAction(name: "Cena",          icon: "fork.knife",                        boost: 50),
                QuickAction(name: "Snack sano",    icon: "carrot.fill",                       boost: 20),
                QuickAction(name: "Comida basura", icon: "flame.fill",                        boost: -10),
                QuickAction(name: "Saltó comida",  icon: "xmark.circle.fill",                 boost: -15),
            ]
        case .hydration:
            return [
                QuickAction(name: "Agua",      icon: "waterbottle.fill",    boost: 30),
                QuickAction(name: "Café",      icon: "cup.and.saucer.fill", boost: 18),
                QuickAction(name: "Té",        icon: "mug.fill",            boost: 22),
                QuickAction(name: "Zumo",      icon: "wineglass.fill",      boost: 22),
                QuickAction(name: "Alcohol",   icon: "wineglass.fill",      boost: -12),
                QuickAction(name: "Sin beber", icon: "xmark.circle.fill",   boost: -8),
            ]
        case .exercise:
            return [
                QuickAction(name: "Gym",            icon: "dumbbell.fill",    boost: 65),
                QuickAction(name: "Caminata",       icon: "figure.walk",      boost: 35),
                QuickAction(name: "Correr",         icon: "figure.run",       boost: 55),
                QuickAction(name: "Deporte",        icon: "sportscourt.fill", boost: 65),
                QuickAction(name: "Estiramientos",  icon: "figure.cooldown",  boost: 20),
                QuickAction(name: "Día sedentario", icon: "chair.fill",       boost: -10),
            ]
        case .hygiene:
            return [
                QuickAction(name: "Ducha",        icon: "shower.fill",          boost: 65),
                QuickAction(name: "Lavé dientes", icon: "mouth.fill",           boost: 20),
                QuickAction(name: "Skincare",     icon: "face.smiling.inverse", boost: 20),
                QuickAction(name: "Arreglé",      icon: "comb.fill",            boost: 25),
            ]
        case .environment:
            return [
                QuickAction(name: "Limpié casa",     icon: "sparkles",              boost: 55),
                QuickAction(name: "Ordené escritorio", icon: "desktopcomputer",     boost: 30),
                QuickAction(name: "Hice la cama",    icon: "bed.double.fill",       boost: 20),
                QuickAction(name: "Lavé platos",     icon: "sink.fill",             boost: 25),
                QuickAction(name: "Ventilé",         icon: "wind",                  boost: 15),
                QuickAction(name: "Desorden",        icon: "xmark.circle.fill",     boost: -15),
            ]
        case .social:
            return [
                QuickAction(name: "Vi amigos",   icon: "person.3.fill",               boost: 55),
                QuickAction(name: "Familia",     icon: "house.fill",                   boost: 50),
                QuickAction(name: "Llamada",     icon: "phone.fill",                   boost: 30),
                QuickAction(name: "Mensajes",    icon: "message.fill",                 boost: 15),
                QuickAction(name: "Cita",        icon: "heart.fill",                   boost: 60),
                QuickAction(name: "Discusión",   icon: "exclamationmark.bubble.fill",  boost: -20),
                QuickAction(name: "Aislamiento", icon: "person.slash.fill",            boost: -10),
            ]
        case .leisure:
            return [
                QuickAction(name: "Videojuegos", icon: "gamecontroller.fill",  boost: 40),
                QuickAction(name: "Peli/Serie",  icon: "tv.fill",              boost: 35),
                QuickAction(name: "Música",      icon: "headphones",           boost: 20),
                QuickAction(name: "Hobby",       icon: "paintbrush.fill",      boost: 45),
                QuickAction(name: "Leí",         icon: "book.fill",            boost: 30),
                QuickAction(name: "Medité",      icon: "brain.head.profile",   boost: 35),
                QuickAction(name: "Estudié",     icon: "graduationcap.fill",   boost: 40),
                QuickAction(name: "Salí",        icon: "map.fill",             boost: 40),
                QuickAction(name: "Doomscrolling", icon: "iphone.gen3",        boost: -12),
                QuickAction(name: "Aburrimiento",  icon: "face.dashed.fill",   boost: -10),
            ]
        }
    }

    var positiveActions: [QuickAction] {
        quickActions.filter { $0.boost > 0 }
    }

    var negativeActions: [QuickAction] {
        quickActions.filter { $0.boost < 0 }
    }
}

// MARK: - Quick Action

struct QuickAction: Identifiable, Equatable, Hashable {
    let name: String
    let icon: String
    let boost: Double
    var needType: NeedType = .energy

    /// Stable identity so SwiftUI doesn't recreate the chip on every parent render.
    var id: String { "\(needType.rawValue):\(name)" }
    var isNegative: Bool { boost < 0 }
}

