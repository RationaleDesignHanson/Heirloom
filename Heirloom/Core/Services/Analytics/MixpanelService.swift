import Foundation
#if canImport(Mixpanel)
import Mixpanel

// MARK: - Mixpanel Service
@MainActor
class MixpanelService: AnalyticsServiceProtocol {

    private var mixpanel: MixpanelInstance?
    private let isProduction: Bool

    init() {
        #if DEBUG
        self.isProduction = false
        #else
        self.isProduction = true
        #endif
    }

    // MARK: - Initialization
    func initialize() {
        // Production token: Replace with your actual Mixpanel token
        let token = isProduction ? "YOUR_PRODUCTION_TOKEN" : "YOUR_DEV_TOKEN"

        mixpanel = Mixpanel.initialize(
            token: token,
            trackAutomaticEvents: true
        )

        // Set initial properties
        mixpanel?.identify(distinctId: getDeviceIdentifier())
        mixpanel?.people.set(properties: [
            "Platform": "iOS",
            "App Version": getAppVersion(),
            "Build Number": getBuildNumber(),
            "Device Model": getDeviceModel(),
            "iOS Version": getIOSVersion()
        ])

        Log.info("Mixpanel analytics initialized", category: .general, metadata: ["environment": isProduction ? "Production" : "Development"])
    }

    // MARK: - Event Tracking
    func track(event: AnalyticsEvent, properties: [String: Any]?) {
        var allProperties: [String: MixpanelType] = [:]

        // Convert properties to MixpanelType
        if let props = properties {
            for (key, value) in props {
                if let mixpanelValue = value as? MixpanelType {
                    allProperties[key] = mixpanelValue
                }
            }
        }

        allProperties["Environment"] = isProduction ? "Production" : "Development"
        allProperties["Timestamp"] = Date().ISO8601Format()

        mixpanel?.track(event: event.rawValue, properties: allProperties)

        #if DEBUG
        Log.debug("Mixpanel analytics event tracked", category: .general, metadata: ["event": event.rawValue])
        if let props = properties {
            Log.debug("Mixpanel event properties", category: .general, metadata: props)
        }
        #endif
    }

    // MARK: - Recipe Events
    func trackRecipeViewed(recipe: Recipe) {
        track(event: .recipeViewed, properties: [
            "Recipe ID": recipe.id.uuidString,
            "Recipe Title": recipe.title,
            "Source Type": recipe.sourceType?.rawValue ?? "unknown",
            "Has Image": recipe.imageFileName != nil,
            "Times Cooked": recipe.timesCooked,
            "Is Favorite": recipe.isFavorite
        ])
    }

    func trackRecipeCreated(recipe: Recipe) {
        track(event: .recipeCreated, properties: [
            "Recipe ID": recipe.id.uuidString,
            "Source Type": recipe.sourceType?.rawValue ?? "unknown",
            "Has Image": recipe.imageFileName != nil,
            "Ingredient Count": recipe.ingredients?.count ?? 0,
            "Instruction Count": recipe.instructions.count,
            "Has Notes": recipe.notes != nil
        ])
    }

    func trackRecipeEdited(recipe: Recipe) {
        track(event: .recipeEdited, properties: [
            "Recipe ID": recipe.id.uuidString,
            "Recipe Title": recipe.title
        ])
    }

    func trackRecipeDeleted(recipeTitle: String) {
        track(event: .recipeDeleted, properties: [
            "Recipe Title": recipeTitle
        ])
    }

    func trackRecipeFavorited(recipe: Recipe, isFavorite: Bool) {
        track(event: isFavorite ? .recipeFavorited : .recipeUnfavorited, properties: [
            "Recipe ID": recipe.id.uuidString,
            "Recipe Title": recipe.title
        ])
    }

    func trackShoppingListToggle(recipe: Recipe, isInList: Bool) {
        track(event: isInList ? .addedToShoppingList : .removedFromShoppingList, properties: [
            "Recipe ID": recipe.id.uuidString,
            "Recipe Title": recipe.title,
            "Ingredient Count": recipe.ingredients?.count ?? 0
        ])
    }

    func trackSearch(query: String, resultCount: Int) {
        track(event: .searchPerformed, properties: [
            "Query": query,
            "Result Count": resultCount
        ])
    }

    func updateUserProperties(totalRecipes: Int, favoriteRecipes: Int) {
        mixpanel?.people.set(properties: [
            "Total Recipes": totalRecipes,
            "Favorite Recipes": favoriteRecipes,
            "Last Active": Date().ISO8601Format()
        ])
    }

    // MARK: - Helper Methods
    private func getDeviceIdentifier() -> String {
        // Use a consistent identifier (not IDFA for privacy)
        if let uuid = UserDefaults.standard.string(forKey: "DeviceUUID") {
            return uuid
        }
        let uuid = UUID().uuidString
        UserDefaults.standard.set(uuid, forKey: "DeviceUUID")
        return uuid
    }

    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? "Unknown"
    }

    private func getIOSVersion() -> String {
        UIDevice.current.systemVersion
    }

    // MARK: - Flush
    func flush() {
        mixpanel?.flush()
    }
}
#endif
