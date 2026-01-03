import Foundation

/// Unit system configuration for measurements
/// Stores user's preferred unit system for future conversion/import features
@MainActor
class UnitsConfiguration: ObservableObject {
    static let shared = UnitsConfiguration()

    @Published var preferredSystem: UnitSystem {
        didSet {
            UserDefaults.standard.set(preferredSystem.rawValue, forKey: Keys.preferredSystem)
        }
    }

    private init() {
        // Default to user's locale
        let savedValue = UserDefaults.standard.string(forKey: Keys.preferredSystem)

        if let saved = savedValue, let system = UnitSystem(rawValue: saved) {
            self.preferredSystem = system
        } else {
            // Auto-detect based on locale
            let locale = Locale.current
            let usesMetric = locale.measurementSystem == .metric
            self.preferredSystem = usesMetric ? .metric : .imperial
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
        case .imperial: return "Imperial (US)"
        case .metric: return "Metric"
        }
    }

    var description: String {
        switch self {
        case .imperial: return "Cups, tablespoons, ounces, pounds"
        case .metric: return "Milliliters, grams, kilograms"
        }
    }
}
