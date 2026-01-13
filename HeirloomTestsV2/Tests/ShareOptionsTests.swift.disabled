import Testing
import Foundation

@testable import Heirloom

@Suite("Share Options Tests")
struct ShareOptionsTests {

    // MARK: - Initialization Tests

    @Test("ShareOptions initializes with default values")
    func testInit_WithDefaults_SetsDefaultValues() {
        // Act
        let options = ShareOptions()

        // Assert
        #expect(options.includeCardBack == true)
        #expect(options.includeRating == true)
        #expect(options.includeNotes == true)
        #expect(options.includePinnedComments == true)
        #expect(options.includeAllComments == false)
        #expect(options.includeCookingHistory == false)
        #expect(options.includeStickers == true)
        #expect(options.personalMessage == nil)
        #expect(options.sharerName == nil)
        #expect(options.shareType == .heirloom)
        #expect(options.allowReSharing == true)
        #expect(options.expirationDuration == .sevenDays)
        #expect(options.notifyOnAccept == true)
    }

    @Test("ShareOptions initializes with custom content inclusion")
    func testInit_WithCustomContentInclusion_SetsValues() {
        // Act
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeAllComments: true,
            includeCookingHistory: true,
            includeStickers: false
        )

        // Assert
        #expect(options.includeCardBack == false)
        #expect(options.includeRating == false)
        #expect(options.includeNotes == false)
        #expect(options.includePinnedComments == false)
        #expect(options.includeAllComments == true)
        #expect(options.includeCookingHistory == true)
        #expect(options.includeStickers == false)
    }

    @Test("ShareOptions initializes with personal message")
    func testInit_WithPersonalMessage_SetsMessage() {
        // Act
        let options = ShareOptions(personalMessage: "Enjoy this family recipe!")

        // Assert
        #expect(options.personalMessage == "Enjoy this family recipe!")
    }

    @Test("ShareOptions initializes with sharer name")
    func testInit_WithSharerName_SetsName() {
        // Act
        let options = ShareOptions(sharerName: "Jane Doe")

        // Assert
        #expect(options.sharerName == "Jane Doe")
    }

    @Test("ShareOptions initializes with share type")
    func testInit_WithShareType_SetsType() {
        // Act
        let options = ShareOptions(shareType: .generic)

        // Assert
        #expect(options.shareType == .generic)
    }

    @Test("ShareOptions initializes with re-sharing disabled")
    func testInit_WithReShareDisabled_DisablesReShare() {
        // Act
        let options = ShareOptions(allowReSharing: false)

        // Assert
        #expect(options.allowReSharing == false)
    }

    @Test("ShareOptions initializes with custom expiration")
    func testInit_WithCustomExpiration_SetsExpiration() {
        // Act
        let options = ShareOptions(expirationDuration: .thirtyDays)

        // Assert
        #expect(options.expirationDuration == .thirtyDays)
    }

    @Test("ShareOptions initializes with no expiration")
    func testInit_WithNoExpiration_SetsNever() {
        // Act
        let options = ShareOptions(expirationDuration: .never)

        // Assert
        #expect(options.expirationDuration == .never)
    }

    @Test("ShareOptions initializes with nil expiration")
    func testInit_WithNilExpiration_SetsNil() {
        // Act
        let options = ShareOptions(expirationDuration: nil)

        // Assert
        #expect(options.expirationDuration == nil)
    }

    @Test("ShareOptions initializes with notify disabled")
    func testInit_WithNotifyDisabled_DisablesNotify() {
        // Act
        let options = ShareOptions(notifyOnAccept: false)

        // Assert
        #expect(options.notifyOnAccept == false)
    }

    // MARK: - ShareType Enum Tests

    @Test("ShareType heirloom has correct raw value")
    func testShareType_Heirloom_RawValue() {
        // Assert
        #expect(ShareOptions.ShareType.heirloom.rawValue == "heirloom")
    }

    @Test("ShareType generic has correct raw value")
    func testShareType_Generic_RawValue() {
        // Assert
        #expect(ShareOptions.ShareType.generic.rawValue == "generic")
    }

    @Test("ShareType heirloom has correct display name")
    func testShareType_Heirloom_DisplayName() {
        // Assert
        #expect(ShareOptions.ShareType.heirloom.displayName == "Heirloom")
    }

    @Test("ShareType generic has correct display name")
    func testShareType_Generic_DisplayName() {
        // Assert
        #expect(ShareOptions.ShareType.generic.displayName == "Generic")
    }

    @Test("ShareType heirloom has descriptive text")
    func testShareType_Heirloom_Description() {
        // Act
        let description = ShareOptions.ShareType.heirloom.description

        // Assert
        #expect(description.contains("modify"))
        #expect(description.contains("version"))
    }

    @Test("ShareType generic has descriptive text")
    func testShareType_Generic_Description() {
        // Act
        let description = ShareOptions.ShareType.generic.description

        // Assert
        #expect(description.contains("one-time copy"))
        #expect(description.contains("No modification"))
    }

    @Test("ShareType heirloom has correct icon name")
    func testShareType_Heirloom_IconName() {
        // Assert
        #expect(ShareOptions.ShareType.heirloom.iconName == "arrow.triangle.branch")
    }

    @Test("ShareType generic has correct icon name")
    func testShareType_Generic_IconName() {
        // Assert
        #expect(ShareOptions.ShareType.generic.iconName == "doc.on.doc")
    }

    @Test("ShareType allCases includes both types")
    func testShareType_AllCases_IncludesBothTypes() {
        // Assert
        #expect(ShareOptions.ShareType.allCases.count == 2)
        #expect(ShareOptions.ShareType.allCases.contains(.heirloom))
        #expect(ShareOptions.ShareType.allCases.contains(.generic))
    }

    // MARK: - ExpirationDuration Enum Tests

    @Test("ExpirationDuration oneDay has correct raw value")
    func testExpirationDuration_OneDay_RawValue() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.oneDay.rawValue == 1)
    }

    @Test("ExpirationDuration threeDays has correct raw value")
    func testExpirationDuration_ThreeDays_RawValue() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.threeDays.rawValue == 3)
    }

    @Test("ExpirationDuration sevenDays has correct raw value")
    func testExpirationDuration_SevenDays_RawValue() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.sevenDays.rawValue == 7)
    }

    @Test("ExpirationDuration thirtyDays has correct raw value")
    func testExpirationDuration_ThirtyDays_RawValue() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.thirtyDays.rawValue == 30)
    }

    @Test("ExpirationDuration ninetyDays has correct raw value")
    func testExpirationDuration_NinetyDays_RawValue() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.ninetyDays.rawValue == 90)
    }

    @Test("ExpirationDuration never has correct raw value")
    func testExpirationDuration_Never_RawValue() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.never.rawValue == 0)
    }

    @Test("ExpirationDuration oneDay has correct display name")
    func testExpirationDuration_OneDay_DisplayName() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.oneDay.displayName == "1 Day")
    }

    @Test("ExpirationDuration threeDays has correct display name")
    func testExpirationDuration_ThreeDays_DisplayName() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.threeDays.displayName == "3 Days")
    }

    @Test("ExpirationDuration sevenDays has correct display name")
    func testExpirationDuration_SevenDays_DisplayName() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.sevenDays.displayName == "7 Days")
    }

    @Test("ExpirationDuration thirtyDays has correct display name")
    func testExpirationDuration_ThirtyDays_DisplayName() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.thirtyDays.displayName == "30 Days")
    }

    @Test("ExpirationDuration ninetyDays has correct display name")
    func testExpirationDuration_NinetyDays_DisplayName() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.ninetyDays.displayName == "90 Days")
    }

    @Test("ExpirationDuration never has correct display name")
    func testExpirationDuration_Never_DisplayName() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.never.displayName == "Never")
    }

    @Test("ExpirationDuration never has special description")
    func testExpirationDuration_Never_Description() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.never.description == "Link never expires")
    }

    @Test("ExpirationDuration oneDay has expiration description")
    func testExpirationDuration_OneDay_Description() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.oneDay.description.contains("expires after"))
    }

    @Test("ExpirationDuration never returns nil expiration date")
    func testExpirationDuration_Never_ExpirationDate() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.never.expirationDate == nil)
    }

    @Test("ExpirationDuration oneDay returns future date")
    func testExpirationDuration_OneDay_ExpirationDate() {
        // Arrange
        let now = Date()

        // Act
        let expirationDate = ShareOptions.ExpirationDuration.oneDay.expirationDate

        // Assert
        #expect(expirationDate != nil)
        #expect(expirationDate! > now)
    }

    @Test("ExpirationDuration sevenDays returns date 7 days in future")
    func testExpirationDuration_SevenDays_ExpirationDate() {
        // Arrange
        let now = Date()
        let expectedDate = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        // Act
        let expirationDate = ShareOptions.ExpirationDuration.sevenDays.expirationDate!

        // Assert - Allow 1 second tolerance for execution time
        let difference = abs(expirationDate.timeIntervalSince(expectedDate))
        #expect(difference < 1.0)
    }

    @Test("ExpirationDuration never has infinity icon")
    func testExpirationDuration_Never_IconName() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.never.iconName == "infinity")
    }

    @Test("ExpirationDuration oneDay has clock icon")
    func testExpirationDuration_OneDay_IconName() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.oneDay.iconName == "clock.fill")
    }

    @Test("ExpirationDuration allCases includes all six durations")
    func testExpirationDuration_AllCases_IncludesAll() {
        // Assert
        #expect(ShareOptions.ExpirationDuration.allCases.count == 6)
        #expect(ShareOptions.ExpirationDuration.allCases.contains(.oneDay))
        #expect(ShareOptions.ExpirationDuration.allCases.contains(.threeDays))
        #expect(ShareOptions.ExpirationDuration.allCases.contains(.sevenDays))
        #expect(ShareOptions.ExpirationDuration.allCases.contains(.thirtyDays))
        #expect(ShareOptions.ExpirationDuration.allCases.contains(.ninetyDays))
        #expect(ShareOptions.ExpirationDuration.allCases.contains(.never))
    }

    // MARK: - Preset Tests

    @Test("ShareOptions default preset has heirloom settings")
    func testPreset_Default_HasHeirloomSettings() {
        // Act
        let options = ShareOptions.default

        // Assert
        #expect(options.shareType == .heirloom)
        #expect(options.includeCardBack == true)
        #expect(options.includeRating == true)
        #expect(options.includeNotes == true)
        #expect(options.includePinnedComments == true)
        #expect(options.includeAllComments == false)
        #expect(options.includeCookingHistory == false)
        #expect(options.expirationDuration == .sevenDays)
    }

    @Test("ShareOptions minimal preset excludes personalization")
    func testPreset_Minimal_ExcludesPersonalization() {
        // Act
        let options = ShareOptions.minimal

        // Assert
        #expect(options.shareType == .generic)
        #expect(options.includeCardBack == false)
        #expect(options.includeRating == false)
        #expect(options.includeNotes == false)
        #expect(options.includePinnedComments == false)
        #expect(options.includeAllComments == false)
        #expect(options.includeCookingHistory == false)
        #expect(options.includeStickers == false)
    }

    @Test("ShareOptions full preset includes everything")
    func testPreset_Full_IncludesEverything() {
        // Act
        let options = ShareOptions.full

        // Assert
        #expect(options.shareType == .heirloom)
        #expect(options.includeCardBack == true)
        #expect(options.includeRating == true)
        #expect(options.includeNotes == true)
        #expect(options.includePinnedComments == true)
        #expect(options.includeAllComments == true)
        #expect(options.includeCookingHistory == true)
        #expect(options.includeStickers == true)
        #expect(options.allowReSharing == true)
        #expect(options.expirationDuration == .never)
    }

    @Test("ShareOptions collaborative preset has heirloom tracking")
    func testPreset_Collaborative_HasHeirloomTracking() {
        // Act
        let options = ShareOptions.collaborative

        // Assert
        #expect(options.shareType == .heirloom)
        #expect(options.includeCardBack == true)
        #expect(options.includeRating == true)
        #expect(options.includeNotes == true)
        #expect(options.includePinnedComments == true)
        #expect(options.allowReSharing == true)
        #expect(options.expirationDuration == .never)
    }

    // MARK: - Inclusion Summary Tests

    @Test("ShareOptions inclusionSummary shows recipe only when nothing included")
    func testInclusionSummary_WithNoInclusions_ShowsRecipeOnly() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false
        )

        // Act
        let summary = options.inclusionSummary

        // Assert
        #expect(summary == "Recipe only")
    }

    @Test("ShareOptions inclusionSummary shows single item format")
    func testInclusionSummary_WithSingleItem_ShowsSingleFormat() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: true,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false
        )

        // Act
        let summary = options.inclusionSummary

        // Assert
        #expect(summary == "Recipe + rating")
    }

    @Test("ShareOptions inclusionSummary shows multiple items with and")
    func testInclusionSummary_WithMultipleItems_ShowsMultipleFormat() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: true,
            includeRating: true,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false
        )

        // Act
        let summary = options.inclusionSummary

        // Assert
        #expect(summary.contains("Recipe + "))
        #expect(summary.contains(" and "))
    }

    @Test("ShareOptions inclusionSummary includes card back")
    func testInclusionSummary_WithCardBack_IncludesCardBack() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: true,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false
        )

        // Act
        let summary = options.inclusionSummary

        // Assert
        #expect(summary.contains("card back"))
    }

    // MARK: - Includes Personalization Tests

    @Test("ShareOptions includesPersonalization true when card back included")
    func testIncludesPersonalization_WithCardBack_ReturnsTrue() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: true,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false
        )

        // Assert
        #expect(options.includesPersonalization == true)
    }

    @Test("ShareOptions includesPersonalization true when rating included")
    func testIncludesPersonalization_WithRating_ReturnsTrue() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: true,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false
        )

        // Assert
        #expect(options.includesPersonalization == true)
    }

    @Test("ShareOptions includesPersonalization true when notes included")
    func testIncludesPersonalization_WithNotes_ReturnsTrue() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: true,
            includePinnedComments: false,
            includeStickers: false
        )

        // Assert
        #expect(options.includesPersonalization == true)
    }

    @Test("ShareOptions includesPersonalization true when comments included")
    func testIncludesPersonalization_WithComments_ReturnsTrue() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: true,
            includeStickers: false
        )

        // Assert
        #expect(options.includesPersonalization == true)
    }

    @Test("ShareOptions includesPersonalization true when stickers included")
    func testIncludesPersonalization_WithStickers_ReturnsTrue() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: true
        )

        // Assert
        #expect(options.includesPersonalization == true)
    }

    @Test("ShareOptions includesPersonalization false when nothing included")
    func testIncludesPersonalization_WithNothing_ReturnsFalse() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false
        )

        // Assert
        #expect(options.includesPersonalization == false)
    }

    // MARK: - Privacy Level Tests

    @Test("ShareOptions privacyLevel returns Public when no personalization")
    func testPrivacyLevel_WithNoPersonalization_ReturnsPublic() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false
        )

        // Assert
        #expect(options.privacyLevel == "Public")
    }

    @Test("ShareOptions privacyLevel returns Very Personal with all comments")
    func testPrivacyLevel_WithAllComments_ReturnsVeryPersonal() {
        // Arrange
        let options = ShareOptions(
            includeAllComments: true
        )

        // Assert
        #expect(options.privacyLevel == "Very Personal")
    }

    @Test("ShareOptions privacyLevel returns Very Personal with cooking history")
    func testPrivacyLevel_WithCookingHistory_ReturnsVeryPersonal() {
        // Arrange
        let options = ShareOptions(
            includeCookingHistory: true
        )

        // Assert
        #expect(options.privacyLevel == "Very Personal")
    }

    @Test("ShareOptions privacyLevel returns Personal with basic personalization")
    func testPrivacyLevel_WithBasicPersonalization_ReturnsPersonal() {
        // Arrange
        let options = ShareOptions(
            includeCardBack: true,
            includeAllComments: false,
            includeCookingHistory: false
        )

        // Assert
        #expect(options.privacyLevel == "Personal")
    }

    // MARK: - Property Mutation Tests

    @Test("ShareOptions properties can be modified")
    func testProperties_CanBeModified() {
        // Arrange
        var options = ShareOptions()

        // Act
        options.includeCardBack = false
        options.shareType = .generic
        options.personalMessage = "Test message"
        options.expirationDuration = .oneDay

        // Assert
        #expect(options.includeCardBack == false)
        #expect(options.shareType == .generic)
        #expect(options.personalMessage == "Test message")
        #expect(options.expirationDuration == .oneDay)
    }

    // MARK: - Edge Case Tests

    @Test("ShareOptions can include all comments without pinned comments")
    func testEdgeCase_AllCommentsWithoutPinned() {
        // Act
        let options = ShareOptions(
            includePinnedComments: false,
            includeAllComments: true
        )

        // Assert
        #expect(options.includePinnedComments == false)
        #expect(options.includeAllComments == true)
    }

    @Test("ShareOptions can have empty personal message")
    func testEdgeCase_EmptyPersonalMessage() {
        // Act
        let options = ShareOptions(personalMessage: "")

        // Assert
        #expect(options.personalMessage == "")
    }

    @Test("ShareOptions can have very long personal message")
    func testEdgeCase_LongPersonalMessage() {
        // Arrange
        let longMessage = String(repeating: "This is a very long personal message. ", count: 50)

        // Act
        let options = ShareOptions(personalMessage: longMessage)

        // Assert
        #expect(options.personalMessage == longMessage)
        #expect(options.personalMessage!.count > 1500)
    }

    @Test("ShareOptions generic type with full inclusions")
    func testEdgeCase_GenericWithFullInclusions() {
        // Act
        let options = ShareOptions(
            includeCardBack: true,
            includeRating: true,
            includeNotes: true,
            includePinnedComments: true,
            includeAllComments: true,
            includeCookingHistory: true,
            includeStickers: true,
            shareType: .generic
        )

        // Assert
        #expect(options.shareType == .generic)
        #expect(options.includesPersonalization == true)
    }

    @Test("ShareOptions heirloom type with minimal inclusions")
    func testEdgeCase_HeirloomWithMinimalInclusions() {
        // Act
        let options = ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeStickers: false,
            shareType: .heirloom
        )

        // Assert
        #expect(options.shareType == .heirloom)
        #expect(options.includesPersonalization == false)
    }

    @Test("ShareOptions never expires with re-sharing disabled")
    func testEdgeCase_NeverExpiresNoReShare() {
        // Act
        let options = ShareOptions(
            allowReSharing: false,
            expirationDuration: .never
        )

        // Assert
        #expect(options.allowReSharing == false)
        #expect(options.expirationDuration == .never)
    }
}
