import Foundation

/// Unit system configuration for measurements
/// Stores user's preferred unit system for future conversion/import features
@MainActor
class UnitsConfiguration: ObservableObject {

    @Published var preferredSystem: UnitSystem {
        didSet {
            UserDefaults.standard.set(preferredSystem.rawValue, forKey: Keys.preferredSystem)
        }
    }

    init() {
        // Load saved preference or default to imperial
        let savedValue = UserDefaults.standard.string(forKey: Keys.preferredSystem)

        if let saved = savedValue, let system = UnitSystem(rawValue: saved) {
            self.preferredSystem = system
        } else {
            // Default to imperial for all users
            self.preferredSystem = .imperial
        }
    }

    private enum Keys {
        static let preferredSystem = "units_preferred_system"
    }
}

// MARK: - Unit System

enum UnitSystem: String, CaseIterable, Identifiable {
    case imperial = "Imperial"
    case metric = "Metric"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .imperial: return "Imperial (cups, oz)"
        case .metric: return "Metric (ml, g)"
        }
    }

    var description: String {
        switch self {
        case .imperial: return "Cups, tablespoons, ounces, pounds"
        case .metric: return "Milliliters, grams, kilograms"
        }
    }
}
