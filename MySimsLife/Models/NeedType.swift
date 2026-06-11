import SwiftUI

// MARK: - Need Type

enum NeedType: String, CaseIterable, Codable, Identifiable {
    case health
    case mentalHealth
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
        case .health:        return String(localized: "Salud física")
        case .mentalHealth:  return String(localized: "Salud mental")
        case .energy:        return String(localized: "Energía")
        case .nutrition:     return String(localized: "Nutrición")
        case .hydration:     return String(localized: "Hidratación")
        case .bladder:       return String(localized: "Baño")
        case .exercise:      return String(localized: "Ejercicio")
        case .hygiene:       return String(localized: "Higiene")
        case .environment:   return String(localized: "Entorno")
        case .social:        return String(localized: "Social")
        case .leisure:       return String(localized: "Ocio")
        }
    }

    var icon: String {
        switch self {
        case .health:        return "cross.case.fill"
        case .mentalHealth:  return "brain.head.profile"
        case .energy:        return "bolt.fill"
        case .nutrition:     return "fork.knife"
        case .hydration:     return "drop.fill"
        case .bladder:       return "toilet.fill"
        case .exercise:      return "figure.run"
        case .hygiene:       return "shower.fill"
        case .environment:   return "house.fill"
        case .social:        return "person.2.fill"
        case .leisure:       return "gamecontroller.fill"
        }
    }

    /// Decay rate per hour. 0 = manual-only (doesn't drop on its own).
    var decayRatePerHour: Double {
        switch self {
        case .health:        return 0       // manual-only — only changes when user logs an ailment
        case .mentalHealth:  return 1.5     // slow drift downward — needs upkeep
        case .energy:        return 6.25
        case .nutrition:     return 6.0
        case .hydration:     return 7.0
        case .bladder:       return 12.5    // ~8h to empty
        case .exercise:      return 4.17
        case .hygiene:       return 4.17
        case .environment:   return 2.5
        case .social:        return 2.08
        case .leisure:       return 3.5
        }
    }

    /// Whether this need decays automatically. False for manual-only needs like health.
    var decaysAutomatically: Bool { decayRatePerHour > 0 }

    var moodWeight: Double {
        switch self {
        case .health:        return 1.8
        case .mentalHealth:  return 1.6
        case .energy:        return 1.5
        case .nutrition:     return 1.3
        case .hydration:     return 1.2
        case .bladder:       return 1.0
        case .exercise:      return 1.0
        case .hygiene:       return 0.8
        case .environment:   return 0.7
        case .social:        return 1.1
        case .leisure:       return 0.9
        }
    }

    /// Hue 0–360 — elegant signature color per need (dusty pastel palette)
    var hue: Double {
        switch self {
        case .health:        return 145   // sage green
        case .mentalHealth:  return 280   // serene violet
        case .energy:        return 38    // champagne
        case .nutrition:     return 22    // honey caramel
        case .hydration:     return 195   // dusty teal
        case .bladder:       return 50    // amber yellow
        case .exercise:      return 335   // dusty rose
        case .hygiene:       return 158   // sage mint
        case .environment:   return 258   // soft lavender
        case .social:        return 295   // muted orchid
        case .leisure:       return 220   // indigo blue
        }
    }

    var sortOrder: Int {
        switch self {
        case .health:        return 0
        case .mentalHealth:  return 1
        case .energy:        return 2
        case .nutrition:     return 3
        case .hydration:     return 4
        case .bladder:       return 5
        case .exercise:      return 6
        case .hygiene:       return 7
        case .environment:   return 8
        case .social:        return 9
        case .leisure:       return 10
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
                QuickAction(name: "Alergia",          icon: "allergens.fill",        boost: -20),
                QuickAction(name: "Mareo",            icon: "ear.fill",              boost: -25),
                QuickAction(name: "Lesión / dolor",   icon: "bandage.fill",          boost: -30),
            ]
        case .mentalHealth:
            return [
                QuickAction(name: "Tranquilo",        icon: "leaf.circle.fill",      boost: 20),
                QuickAction(name: "Medité",           icon: "brain.head.profile",    boost: 35),
                QuickAction(name: "Diario",           icon: "book.closed.fill",      boost: 25),
                QuickAction(name: "Terapia",          icon: "heart.text.square.fill", boost: 50),
                QuickAction(name: "Respiración",      icon: "wind",                  boost: 20),
                QuickAction(name: "Gratitud",         icon: "sparkles",              boost: 25),
                QuickAction(name: "Naturaleza",       icon: "tree.fill",             boost: 30),
                QuickAction(name: "Me desahogué",     icon: "drop.fill",             boost: 25),
                QuickAction(name: "Estresado",        icon: "exclamationmark.triangle.fill", boost: -25),
                QuickAction(name: "Ansiedad",         icon: "heart.slash",           boost: -35),
                QuickAction(name: "Triste",           icon: "cloud.heavyrain.fill",  boost: -25),
                QuickAction(name: "Mal humor",        icon: "cloud.fill",            boost: -20),
                QuickAction(name: "Discusión fuerte", icon: "bubble.left.and.bubble.right.fill", boost: -25),
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
                QuickAction(name: "Dormí <5h",  icon: "bed.double.fill",  boost: 40),
                QuickAction(name: "Siesta",     icon: "powersleep",       boost: 25),
                QuickAction(name: "Descansé",   icon: "sofa.fill",        boost: 10),
                QuickAction(name: "Insomnio",   icon: "moon.zzz.fill",    boost: -20),
                QuickAction(name: "Mala noche", icon: "bed.double.fill",  boost: -15),
            ]
        case .nutrition:
            return [
                QuickAction(name: "Desayuno",      icon: "cup.and.saucer.fill",              boost: 50),
                QuickAction(name: "Almuerzo",      icon: "takeoutbag.and.cup.and.straw.fill", boost: 55),
                QuickAction(name: "Cena",          icon: "fork.knife",                        boost: 50),
                QuickAction(name: "Cociné en casa", icon: "frying.pan.fill",                  boost: 30),
                QuickAction(name: "Snack sano",    icon: "carrot.fill",                       boost: 20),
                QuickAction(name: "Snack dulce",   icon: "birthday.cake.fill",                boost: -8),
                QuickAction(name: "Comida basura", icon: "flame.fill",                        boost: -10),
                QuickAction(name: "Saltó comida",  icon: "xmark.circle.fill",                 boost: -15),
            ]
        case .hydration:
            return [
                QuickAction(name: "Agua",      icon: "waterbottle.fill",       boost: 30),
                QuickAction(name: "Café",      icon: "cup.and.saucer.fill",    boost: 18),
                QuickAction(name: "Té",        icon: "mug.fill",               boost: 22),
                QuickAction(name: "Zumo",      icon: "wineglass.fill",         boost: 22),
                QuickAction(name: "Refresco",  icon: "bubbles.and.sparkles.fill", boost: -8),
                QuickAction(name: "Alcohol",   icon: "wineglass.fill",         boost: -12),
                QuickAction(name: "Sin beber", icon: "xmark.circle.fill",      boost: -8),
            ]
        case .exercise:
            return [
                QuickAction(name: "Gym",            icon: "dumbbell.fill",    boost: 65),
                QuickAction(name: "Caminata",       icon: "figure.walk",      boost: 35),
                QuickAction(name: "Correr",         icon: "figure.run",       boost: 55),
                QuickAction(name: "Bici",           icon: "bicycle",          boost: 50),
                QuickAction(name: "Yoga",           icon: "figure.yoga",      boost: 40),
                QuickAction(name: "Deporte",        icon: "sportscourt.fill", boost: 65),
                QuickAction(name: "Estiramientos",  icon: "figure.cooldown",  boost: 20),
                QuickAction(name: "Día sedentario", icon: "chair.fill",       boost: -10),
            ]
        case .hygiene:
            return [
                QuickAction(name: "Ducha",        icon: "shower.fill",          boost: 65),
                QuickAction(name: "Lavé dientes", icon: "mouth.fill",           boost: 20),
                QuickAction(name: "Hilo dental",  icon: "scissors",             boost: 15),
                QuickAction(name: "Skincare",     icon: "face.smiling.inverse", boost: 20),
                QuickAction(name: "Arreglé",      icon: "comb.fill",            boost: 25),
                QuickAction(name: "No me lavé",   icon: "exclamationmark.circle.fill", boost: -25),
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
    /// Canonical (Spanish) key. Stays stable so it can be persisted, synced,
    /// and aggregated regardless of the user's UI language.
    let name: String
    let icon: String
    let boost: Double
    var needType: NeedType = .energy

    /// Stable identity so SwiftUI doesn't recreate the chip on every parent render.
    var id: String { "\(needType.rawValue):\(name)" }
    var isNegative: Bool { boost < 0 }

    /// Display string in the user's locale. Custom actions typed by the user
    /// fall through to `name` because they aren't in the catalog.
    var localizedName: String {
        Bundle.main.localizedString(forKey: name, value: name, table: nil)
    }
}

// MARK: - Need Plans (onboarding presets)

/// Pre-built sets of needs offered as one-tap presets in the onboarding's
/// "categorías" step. Tiers are cumulative — each one adds categories on top
/// of the previous, so users can pick a depth that matches the commitment
/// they're ready for. Individual toggles remain available; plans only seed
/// the initial selection.
enum NeedPlan: String, CaseIterable, Identifiable {
    case essential   // 4 — los pilares
    case balanced    // 7 — los pilares + cuidado básico + relación humana
    case detailed    // 9 — añade hidratación y ocio
    case complete    // 11 — todas

    var id: String { rawValue }

    var label: String {
        switch self {
        case .essential: return String(localized: "Esencial")
        case .balanced:  return String(localized: "Equilibrado")
        case .detailed:  return String(localized: "Detallado")
        case .complete:  return String(localized: "Completo")
        }
    }

    /// SF Symbol that hints at the plan's character. Used in the chip picker
    /// so users can scan tiers visually before reading.
    var icon: String {
        switch self {
        case .essential: return "leaf.fill"        // lo básico, raíz
        case .balanced:  return "scalemass.fill"   // balance
        case .detailed:  return "chart.bar.fill"   // más granularidad
        case .complete:  return "sparkles"         // todo
        }
    }

    var needs: Set<NeedType> {
        switch self {
        case .essential: return Self.essentialSet
        case .balanced:  return Self.balancedSet
        case .detailed:  return Self.detailedSet
        case .complete:  return Self.completeSet
        }
    }

    var count: Int { needs.count }

    // Pre-built once at type init so SwiftUI re-renders don't rebuild
    // each Set via `.union(...)` on every body evaluation.
    /// Esencial — only the four categories whose daily log effort is
    /// genuinely minimal: sleep (1×), exercise (0–1×), hygiene (1–2×),
    /// mental health (intentional, not constant). Heavy-logging
    /// categories (nutrition 3–5×, hydration 5–8×) live in Equilibrado
    /// or above so people don't burn out on the default plan.
    private static let essentialSet: Set<NeedType> = [.energy, .exercise, .hygiene, .mentalHealth]
    private static let balancedSet:  Set<NeedType> = essentialSet.union([.nutrition, .social, .health])
    private static let detailedSet:  Set<NeedType> = balancedSet.union([.hydration, .leisure])
    private static let completeSet:  Set<NeedType> = Set(NeedType.allCases)

    /// Pick the plan whose set exactly matches `selection`, or `nil` if the
    /// user has a custom mix (used to highlight the chip in the editor).
    static func matching(_ selection: Set<NeedType>) -> NeedPlan? {
        Self.allCases.first { $0.needs == selection }
    }
}
