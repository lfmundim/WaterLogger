import Foundation

/// The category of a logged drink.
///
/// Each case carries a `hydrationCoefficient` that scales the raw volume
/// down to its effective hydration contribution. For example, 250 ml of coffee
/// (coefficient 0.8) counts as 200 ml toward the daily goal.
enum BeverageType: String, Codable, CaseIterable {
    case water
    case herbalTea
    case juice
    case soda
    case coffee
    case alcohol

    /// A multiplier applied to the logged volume to compute effective hydration.
    ///
    /// Values range from 1.0 (pure hydration, e.g. water) down to 0.0 (alcohol,
    /// which does not count toward the goal at all).
    var hydrationCoefficient: Double {
        switch self {
        case .water:     return 1.0
        case .herbalTea: return 1.0
        case .juice:     return 0.9
        case .soda:      return 0.85
        case .coffee:    return 0.8
        case .alcohol:   return 0.0
        }
    }

    /// A localised name suitable for display in the UI (e.g. picker labels).
    var displayName: LocalizedStringResource {
        switch self {
        case .water:     return "Water"
        case .herbalTea: return "Herbal Tea"
        case .juice:     return "Juice"
        case .soda:      return "Soda"
        case .coffee:    return "Coffee"
        case .alcohol:   return "Alcohol"
        }
    }

    /// The SF Symbol name used to represent this beverage in the UI.
    var systemImage: String {
        switch self {
        case .water:     return "drop.fill"
        case .herbalTea: return "cup.and.heat.waves.fill"
        case .juice:     return "carrot.fill"
        case .soda:      return "bubbles.and.sparkles.fill"
        case .coffee:    return "mug.fill"
        case .alcohol:   return "wineglass.fill"
        }
    }
}
