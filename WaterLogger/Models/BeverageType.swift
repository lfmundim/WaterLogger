import Foundation

enum BeverageType: String, Codable, CaseIterable {
    case water
    case herbalTea
    case juice
    case soda
    case coffee
    case alcohol

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
