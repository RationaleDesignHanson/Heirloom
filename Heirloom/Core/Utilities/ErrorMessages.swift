import Foundation

// MARK: - Error Message
/// User-friendly error message with recovery instructions
struct ErrorMessage {
    let title: String
    let message: String
    let helpArticleId: String?

    init(title: String, message: String, helpArticleId: String? = nil) {
        self.title = title
        self.message = message
        self.helpArticleId = helpArticleId
    }
}

// MARK: - Heirloom Error
/// Categorized errors with user-friendly messages
enum HeirloomError {
    // MARK: - Recipe Errors
    case recipeSaveFailed(underlyingError: Error?)
    case recipeDeleteFailed(underlyingError: Error?)
    case recipeImportFailed(underlyingError: Error?)
    case recipeImportNoData
    case recipeImportInvalidURL
    case recipeImportNetworkError
    case recipeExportFailed(underlyingError: Error?)

    // MARK: - Shopping List Errors
    case shoppingListAddFailed(underlyingError: Error?)
    case shoppingListRemoveFailed(underlyingError: Error?)
    case shoppingListExportFailed(underlyingError: Error?)
    case shoppingListNoItems

    // MARK: - Image Errors
    case imageLoadFailed
    case imageSaveFailed
    case imageDeleteFailed
    case imageTooBig

    // MARK: - Data Management Errors
    case dataCorrupted
    case dataClearFailed(underlyingError: Error?)
    case dataSyncFailed(underlyingError: Error?)
    case dataExportFailed(underlyingError: Error?)

    // MARK: - Network Errors
    case networkUnavailable
    case networkTimeout
    case serverError

    // MARK: - Permission Errors
    case photoLibraryPermissionDenied
    case cameraPermissionDenied
    case notificationPermissionDenied
    case remindersPermissionDenied

    // MARK: - CloudKit Errors
    case cloudKitNotAvailable
    case cloudKitSyncFailed
    case cloudKitQuotaExceeded

    // MARK: - OCR/AI Errors
    case ocrFailed
    case aiExtractionFailed(underlyingError: Error?)
    case aiExtractionNoRecipes
    case aiExtractionInvalidResponse

    // MARK: - Collection Errors
    case collectionCreateFailed(underlyingError: Error?)
    case collectionDeleteFailed(underlyingError: Error?)
    case collectionEditFailed(underlyingError: Error?)

    // MARK: - Dinner Party Errors
    case dinnerPartyCreateFailed(underlyingError: Error?)
    case dinnerPartyDeleteFailed(underlyingError: Error?)
    case dinnerPartyEditFailed(underlyingError: Error?)

    // MARK: - Generic Errors
    case unknown(underlyingError: Error?)

    // MARK: - Error Message
    var errorMessage: ErrorMessage {
        switch self {
        // Recipe Errors
        case .recipeSaveFailed(let error):
            return ErrorMessage(
                title: "Failed to Save Recipe",
                message: "We couldn't save your recipe. Please try again. If the problem persists, try restarting the app.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "troubleshooting-save-errors"
            )

        case .recipeDeleteFailed(let error):
            return ErrorMessage(
                title: "Failed to Delete Recipe",
                message: "We couldn't delete the recipe. Please try again. If the problem persists, try restarting the app.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "troubleshooting-delete-errors"
            )

        case .recipeImportFailed(let error):
            return ErrorMessage(
                title: "Import Failed",
                message: "We couldn't import the recipe. Please check the URL and try again. Make sure the website is accessible.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "importing-recipes"
            )

        case .recipeImportNoData:
            return ErrorMessage(
                title: "No Recipe Found",
                message: "We couldn't find any recipe data at this URL. Try copying the recipe text directly or taking a photo of it instead.",
                helpArticleId: "importing-recipes"
            )

        case .recipeImportInvalidURL:
            return ErrorMessage(
                title: "Invalid URL",
                message: "The URL you entered doesn't appear to be valid. Please check the URL and try again.",
                helpArticleId: "importing-recipes"
            )

        case .recipeImportNetworkError:
            return ErrorMessage(
                title: "Network Error",
                message: "We couldn't connect to the recipe website. Please check your internet connection and try again.",
                helpArticleId: "troubleshooting-network-errors"
            )

        case .recipeExportFailed(let error):
            return ErrorMessage(
                title: "Export Failed",
                message: "We couldn't export the recipe. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "sharing-recipes"
            )

        // Shopping List Errors
        case .shoppingListAddFailed(let error):
            return ErrorMessage(
                title: "Failed to Add to Shopping List",
                message: "We couldn't add this recipe to your shopping list. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "using-shopping-list"
            )

        case .shoppingListRemoveFailed(let error):
            return ErrorMessage(
                title: "Failed to Remove from Shopping List",
                message: "We couldn't remove this recipe from your shopping list. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "using-shopping-list"
            )

        case .shoppingListExportFailed(let error):
            return ErrorMessage(
                title: "Export to Reminders Failed",
                message: "We couldn't export your shopping list to Reminders. Please make sure Heirloom has permission to access Reminders in Settings.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "using-shopping-list"
            )

        case .shoppingListNoItems:
            return ErrorMessage(
                title: "Nothing to Export",
                message: "All items in your shopping list are checked off. Uncheck some items to export them to Reminders.",
                helpArticleId: "using-shopping-list"
            )

        // Image Errors
        case .imageLoadFailed:
            return ErrorMessage(
                title: "Failed to Load Image",
                message: "We couldn't load the image. It may have been deleted or moved. Try taking a new photo.",
                helpArticleId: "adding-recipe-photos"
            )

        case .imageSaveFailed:
            return ErrorMessage(
                title: "Failed to Save Image",
                message: "We couldn't save the image. Please check your device storage and try again.",
                helpArticleId: "adding-recipe-photos"
            )

        case .imageDeleteFailed:
            return ErrorMessage(
                title: "Failed to Delete Image",
                message: "We couldn't delete the image. Please try again.",
                helpArticleId: "adding-recipe-photos"
            )

        case .imageTooBig:
            return ErrorMessage(
                title: "Image Too Large",
                message: "This image is too large to save. Please choose a smaller image or take a new photo.",
                helpArticleId: "adding-recipe-photos"
            )

        // Data Management Errors
        case .dataCorrupted:
            return ErrorMessage(
                title: "Data Corrupted",
                message: "Some of your app data appears to be corrupted. We recommend backing up your recipes (if possible) and reinstalling the app. Contact support if you need help.",
                helpArticleId: "troubleshooting-data-errors"
            )

        case .dataClearFailed(let error):
            return ErrorMessage(
                title: "Failed to Clear Data",
                message: "We couldn't clear your app data. Please try restarting the app.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "troubleshooting-data-errors"
            )

        case .dataSyncFailed(let error):
            return ErrorMessage(
                title: "Sync Failed",
                message: "We couldn't sync your data with iCloud. Please check your internet connection and iCloud settings.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "syncing-with-icloud"
            )

        case .dataExportFailed(let error):
            return ErrorMessage(
                title: "Export Failed",
                message: "We couldn't export your data. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "backing-up-recipes"
            )

        // Network Errors
        case .networkUnavailable:
            return ErrorMessage(
                title: "No Internet Connection",
                message: "You're not connected to the internet. Some features may not work until you're back online.",
                helpArticleId: "troubleshooting-network-errors"
            )

        case .networkTimeout:
            return ErrorMessage(
                title: "Request Timed Out",
                message: "The request took too long to complete. Please check your internet connection and try again.",
                helpArticleId: "troubleshooting-network-errors"
            )

        case .serverError:
            return ErrorMessage(
                title: "Server Error",
                message: "The server encountered an error. Please try again later.",
                helpArticleId: "troubleshooting-network-errors"
            )

        // Permission Errors
        case .photoLibraryPermissionDenied:
            return ErrorMessage(
                title: "Photo Access Required",
                message: "Heirloom needs permission to access your photos. Please enable photo access in Settings > Heirloom > Photos.",
                helpArticleId: "permissions"
            )

        case .cameraPermissionDenied:
            return ErrorMessage(
                title: "Camera Access Required",
                message: "Heirloom needs permission to use your camera. Please enable camera access in Settings > Heirloom > Camera.",
                helpArticleId: "permissions"
            )

        case .notificationPermissionDenied:
            return ErrorMessage(
                title: "Notification Access Required",
                message: "Heirloom needs permission to send you notifications for cooking timers. Please enable notifications in Settings > Heirloom > Notifications.",
                helpArticleId: "permissions"
            )

        case .remindersPermissionDenied:
            return ErrorMessage(
                title: "Reminders Access Required",
                message: "Heirloom needs permission to create reminders for your shopping list. Please enable reminders access in Settings > Heirloom > Reminders.",
                helpArticleId: "permissions"
            )

        // CloudKit Errors
        case .cloudKitNotAvailable:
            return ErrorMessage(
                title: "iCloud Not Available",
                message: "iCloud sync is not available. Please make sure you're signed in to iCloud in Settings and that iCloud Drive is enabled.",
                helpArticleId: "syncing-with-icloud"
            )

        case .cloudKitSyncFailed:
            return ErrorMessage(
                title: "iCloud Sync Failed",
                message: "We couldn't sync your data with iCloud. Your data is still safe on this device. We'll try syncing again when you're back online.",
                helpArticleId: "syncing-with-icloud"
            )

        case .cloudKitQuotaExceeded:
            return ErrorMessage(
                title: "iCloud Storage Full",
                message: "Your iCloud storage is full. Please free up space in iCloud or upgrade your storage plan to continue syncing.",
                helpArticleId: "syncing-with-icloud"
            )

        // OCR/AI Errors
        case .ocrFailed:
            return ErrorMessage(
                title: "Text Recognition Failed",
                message: "We couldn't read the text from this image. Try taking a clearer photo with better lighting, or type the recipe manually.",
                helpArticleId: "importing-from-photos"
            )

        case .aiExtractionFailed(let error):
            return ErrorMessage(
                title: "AI Extraction Failed",
                message: "We couldn't extract recipe data from the text. Try editing the text and submitting again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "ai-recipe-extraction"
            )

        case .aiExtractionNoRecipes:
            return ErrorMessage(
                title: "No Recipes Found",
                message: "We couldn't find any recipes in this text. Make sure the text includes recipe ingredients and instructions.",
                helpArticleId: "ai-recipe-extraction"
            )

        case .aiExtractionInvalidResponse:
            return ErrorMessage(
                title: "Invalid AI Response",
                message: "The AI service returned an unexpected response. Please try again.",
                helpArticleId: "ai-recipe-extraction"
            )

        // Collection Errors
        case .collectionCreateFailed(let error):
            return ErrorMessage(
                title: "Failed to Create Collection",
                message: "We couldn't create the collection. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "organizing-recipes"
            )

        case .collectionDeleteFailed(let error):
            return ErrorMessage(
                title: "Failed to Delete Collection",
                message: "We couldn't delete the collection. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "organizing-recipes"
            )

        case .collectionEditFailed(let error):
            return ErrorMessage(
                title: "Failed to Edit Collection",
                message: "We couldn't save your changes to the collection. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "organizing-recipes"
            )

        // Dinner Party Errors
        case .dinnerPartyCreateFailed(let error):
            return ErrorMessage(
                title: "Failed to Create Dinner Party",
                message: "We couldn't create the dinner party. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "dinner-parties"
            )

        case .dinnerPartyDeleteFailed(let error):
            return ErrorMessage(
                title: "Failed to Delete Dinner Party",
                message: "We couldn't delete the dinner party. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "dinner-parties"
            )

        case .dinnerPartyEditFailed(let error):
            return ErrorMessage(
                title: "Failed to Edit Dinner Party",
                message: "We couldn't save your changes to the dinner party. Please try again.\n\nTechnical details: \(error?.localizedDescription ?? "Unknown error")",
                helpArticleId: "dinner-parties"
            )

        // Generic Errors
        case .unknown(let error):
            if let error = error {
                return ErrorMessage(
                    title: "Something Went Wrong",
                    message: "An unexpected error occurred. Please try again.\n\nTechnical details: \(error.localizedDescription)",
                    helpArticleId: "troubleshooting"
                )
            } else {
                return ErrorMessage(
                    title: "Something Went Wrong",
                    message: "An unexpected error occurred. Please try again. If the problem persists, try restarting the app.",
                    helpArticleId: "troubleshooting"
                )
            }
        }
    }

    // MARK: - Show Error
    /// Display error toast with user-friendly message
    @MainActor
    func show() {
        let message = errorMessage
        ToastManager.shared.error(title: message.title, message: message.message)
    }
}

// MARK: - ErrorMessages Helper
/// Convenience methods for showing errors
@MainActor
enum ErrorMessages {
    // MARK: - Recipe Errors
    static func showRecipeSaveError(_ error: Error?) {
        HeirloomError.recipeSaveFailed(underlyingError: error).show()
    }

    static func showRecipeDeleteError(_ error: Error?) {
        HeirloomError.recipeDeleteFailed(underlyingError: error).show()
    }

    static func showRecipeImportError(_ error: Error?) {
        HeirloomError.recipeImportFailed(underlyingError: error).show()
    }

    // MARK: - Shopping List Errors
    static func showShoppingListAddError(_ error: Error?) {
        HeirloomError.shoppingListAddFailed(underlyingError: error).show()
    }

    static func showShoppingListRemoveError(_ error: Error?) {
        HeirloomError.shoppingListRemoveFailed(underlyingError: error).show()
    }

    static func showShoppingListExportError(_ error: Error?) {
        HeirloomError.shoppingListExportFailed(underlyingError: error).show()
    }

    // MARK: - Data Management Errors
    static func showDataClearError(_ error: Error?) {
        HeirloomError.dataClearFailed(underlyingError: error).show()
    }

    static func showDataSyncError(_ error: Error?) {
        HeirloomError.dataSyncFailed(underlyingError: error).show()
    }

    // MARK: - Collection Errors
    static func showCollectionCreateError(_ error: Error?) {
        HeirloomError.collectionCreateFailed(underlyingError: error).show()
    }

    static func showCollectionDeleteError(_ error: Error?) {
        HeirloomError.collectionDeleteFailed(underlyingError: error).show()
    }

    static func showCollectionEditError(_ error: Error?) {
        HeirloomError.collectionEditFailed(underlyingError: error).show()
    }

    // MARK: - Dinner Party Errors
    static func showDinnerPartyCreateError(_ error: Error?) {
        HeirloomError.dinnerPartyCreateFailed(underlyingError: error).show()
    }

    static func showDinnerPartyDeleteError(_ error: Error?) {
        HeirloomError.dinnerPartyDeleteFailed(underlyingError: error).show()
    }

    static func showDinnerPartyEditError(_ error: Error?) {
        HeirloomError.dinnerPartyEditFailed(underlyingError: error).show()
    }

    // MARK: - Generic Error
    static func showGenericError(_ error: Error?) {
        HeirloomError.unknown(underlyingError: error).show()
    }
}
