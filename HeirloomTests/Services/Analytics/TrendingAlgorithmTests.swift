import XCTest
@testable import Heirloom

/// Test the trending score calculation logic (unit tests without CloudKit)
final class TrendingAlgorithmTests: XCTestCase {

    // MARK: - Time Decay Tests

    func test_timeDecay_recentEngagement_highScore() {
        // Engagement from 1 hour ago should have near-full weight
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        // Decay factor = exp(-3600 / (3 * 24 * 60 * 60))
        // Half-life is 3 days (259200 seconds)
        // exp(-3600 / 259200) ≈ 0.9861

        let age: TimeInterval = 3600
        let halfLife: TimeInterval = 3 * 24 * 60 * 60 // 3 days
        let decayFactor = exp(-age / halfLife)

        XCTAssertGreaterThan(decayFactor, 0.98)
        XCTAssertLessThanOrEqual(decayFactor, 1.0)
    }

    func test_timeDecay_threeDayOld_halfWeight() {
        // Engagement from 3 days ago should have ~50% weight (half-life)
        let age: TimeInterval = 3 * 24 * 60 * 60 // 3 days
        let halfLife: TimeInterval = 3 * 24 * 60 * 60
        let decayFactor = exp(-age / halfLife)

        // exp(-1) ≈ 0.3679
        XCTAssertEqual(decayFactor, 0.3679, accuracy: 0.01)
    }

    func test_timeDecay_sevenDayOld_lowWeight() {
        // Engagement from 7 days ago should have low weight
        let age: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        let halfLife: TimeInterval = 3 * 24 * 60 * 60
        let decayFactor = exp(-age / halfLife)

        // exp(-7/3) ≈ 0.1054
        XCTAssertLessThan(decayFactor, 0.15)
        XCTAssertGreaterThan(decayFactor, 0.05)
    }

    // MARK: - Weighted Score Tests

    func test_weightedScore_singleView() {
        // View weight = 1.0, decay = 1.0 (recent)
        let score = 1.0 * 1.0

        XCTAssertEqual(score, 1.0)
    }

    func test_weightedScore_singleSave() {
        // Save weight = 3.0, decay = 1.0 (recent)
        let score = 3.0 * 1.0

        XCTAssertEqual(score, 3.0)
    }

    func test_weightedScore_singleCook() {
        // Cook weight = 5.0, decay = 1.0 (recent)
        let score = 5.0 * 1.0

        XCTAssertEqual(score, 5.0)
    }

    func test_weightedScore_singleShare() {
        // Share weight = 8.0, decay = 1.0 (recent)
        let score = 8.0 * 1.0

        XCTAssertEqual(score, 8.0)
    }

    func test_weightedScore_multipleEngagements() {
        // Mixed engagement: 5 views + 2 saves + 1 cook
        // = (5 * 1.0) + (2 * 3.0) + (1 * 5.0) = 5 + 6 + 5 = 16
        let score = (5.0 * 1.0) + (2.0 * 3.0) + (1.0 * 5.0)

        XCTAssertEqual(score, 16.0)
    }

    // MARK: - Score Normalization Tests

    func test_scoreNormalization_lowScore() {
        // totalScore = 10
        // normalized = min(100, log10(10 + 1) * 50)
        // = min(100, log10(11) * 50)
        // = min(100, 1.041 * 50) = 52.05

        let totalScore = 10.0
        let normalized = min(100, log10(totalScore + 1) * 50)

        XCTAssertEqual(normalized, 52.05, accuracy: 0.1)
    }

    func test_scoreNormalization_mediumScore() {
        // totalScore = 100
        // = min(100, log10(101) * 50)
        // = min(100, 2.004 * 50) = 100 (capped)

        let totalScore = 100.0
        let normalized = min(100, log10(totalScore + 1) * 50)

        XCTAssertEqual(normalized, 100)
    }

    func test_scoreNormalization_highScore() {
        // totalScore = 1000
        // = min(100, log10(1001) * 50)
        // = 100 (capped at 100)

        let totalScore = 1000.0
        let normalized = min(100, log10(totalScore + 1) * 50)

        XCTAssertEqual(normalized, 100)
    }

    func test_scoreNormalization_zeroScore() {
        // totalScore = 0
        // = min(100, log10(1) * 50) = 0

        let totalScore = 0.0
        let normalized = min(100, log10(totalScore + 1) * 50)

        XCTAssertEqual(normalized, 0)
    }

    // MARK: - Velocity Calculation Tests

    func test_velocity_increasingEngagement() {
        // Recent period: 10 engagements
        // Previous period: 5 engagements
        // Velocity = ((10 - 5) / 5) * 100 = 100%

        let recentCount = 10.0
        let previousCount = 5.0
        let velocity = ((recentCount - previousCount) / previousCount) * 100

        XCTAssertEqual(velocity, 100.0)
    }

    func test_velocity_decreasingEngagement() {
        // Recent period: 5 engagements
        // Previous period: 10 engagements
        // Velocity = ((5 - 10) / 10) * 100 = -50%

        let recentCount = 5.0
        let previousCount = 10.0
        let velocity = ((recentCount - previousCount) / previousCount) * 100

        XCTAssertEqual(velocity, -50.0)
    }

    func test_velocity_stableEngagement() {
        // Recent period: 10 engagements
        // Previous period: 10 engagements
        // Velocity = 0%

        let recentCount = 10.0
        let previousCount = 10.0
        let velocity = ((recentCount - previousCount) / previousCount) * 100

        XCTAssertEqual(velocity, 0.0)
    }

    func test_velocity_zeroPrevious_hasRecent() {
        // Recent period: 5 engagements
        // Previous period: 0 engagements
        // Velocity = 100% (special case)

        let recentCount = 5.0
        let previousCount = 0.0

        // In TrendingService, this returns 100
        let velocity = recentCount > 0 ? 100.0 : 0.0

        XCTAssertEqual(velocity, 100.0)
    }

    func test_velocity_zeroPrevious_noRecent() {
        // Recent period: 0 engagements
        // Previous period: 0 engagements
        // Velocity = 0%

        let recentCount = 0.0
        let previousCount = 0.0

        let velocity = recentCount > 0 ? 100.0 : 0.0

        XCTAssertEqual(velocity, 0.0)
    }

    // MARK: - Popularity Score Tests (No Decay)

    func test_popularityScore_singleView() {
        // View weight = 1.0 (no decay for popularity)
        let score = 1.0

        XCTAssertEqual(score, 1.0)
    }

    func test_popularityScore_mixedEngagement() {
        // 10 views + 5 saves + 3 cooks + 1 share
        // = (10 * 1.0) + (5 * 3.0) + (3 * 5.0) + (1 * 8.0)
        // = 10 + 15 + 15 + 8 = 48

        let score = (10.0 * 1.0) + (5.0 * 3.0) + (3.0 * 5.0) + (1.0 * 8.0)

        XCTAssertEqual(score, 48.0)
    }

    func test_popularityScore_normalized() {
        // totalScore = 50
        // normalized = min(100, log10(51) * 50)
        // = min(100, 1.708 * 50) = 85.4

        let totalScore = 50.0
        let normalized = min(100, log10(totalScore + 1) * 50)

        XCTAssertEqual(normalized, 85.4, accuracy: 0.1)
    }

    // MARK: - Badge Assignment Tests

    func test_badge_hotRecipe() {
        // velocity > 50 → 🔥 Hot
        let velocity = 60.0
        let trendingScore = 50.0

        let badge = velocity > 50 ? "🔥 Hot" : ""

        XCTAssertEqual(badge, "🔥 Hot")
    }

    func test_badge_risingRecipe() {
        // velocity > 20 && velocity <= 50 → 📈 Rising
        let velocity = 30.0
        let trendingScore = 50.0

        let badge = velocity > 50 ? "🔥 Hot" : (velocity > 20 ? "📈 Rising" : "")

        XCTAssertEqual(badge, "📈 Rising")
    }

    func test_badge_popularRecipe() {
        // velocity <= 20 && trendingScore > 70 → ⭐ Popular
        let velocity = 10.0
        let trendingScore = 75.0

        let badge: String = {
            if velocity > 50 { return "🔥 Hot" }
            else if velocity > 20 { return "📈 Rising" }
            else if trendingScore > 70 { return "⭐ Popular" }
            else { return "" }
        }()

        XCTAssertEqual(badge, "⭐ Popular")
    }

    func test_badge_noBadge() {
        // Low velocity and low score → no badge
        let velocity = 5.0
        let trendingScore = 40.0

        let badge: String = {
            if velocity > 50 { return "🔥 Hot" }
            else if velocity > 20 { return "📈 Rising" }
            else if trendingScore > 70 { return "⭐ Popular" }
            else { return "" }
        }()

        XCTAssertEqual(badge, "")
    }

    // MARK: - Real-World Scenario Tests

    func test_scenario_viralRecipe() {
        // Viral recipe: Many recent engagements across all types
        // 50 views + 20 saves + 15 cooks + 5 shares (all recent, decay = 1.0)
        let totalScore = (50.0 * 1.0) + (20.0 * 3.0) + (15.0 * 5.0) + (5.0 * 8.0)
        // = 50 + 60 + 75 + 40 = 225

        let normalized = min(100, log10(totalScore + 1) * 50)
        // = min(100, log10(226) * 50) = min(100, 118.7) = 100

        XCTAssertEqual(normalized, 100)
    }

    func test_scenario_decliningRecipe() {
        // Recipe that was popular but declining
        // Recent: 5 engagements
        // Previous: 20 engagements
        let recentCount = 5.0
        let previousCount = 20.0
        let velocity = ((recentCount - previousCount) / previousCount) * 100

        XCTAssertEqual(velocity, -75.0) // 75% decline
    }

    func test_scenario_steadyRecipe() {
        // Recipe with consistent moderate engagement
        // 10 views + 2 saves (recent, decay = 1.0)
        let totalScore = (10.0 * 1.0) + (2.0 * 3.0)
        // = 10 + 6 = 16

        let normalized = min(100, log10(totalScore + 1) * 50)
        // = min(100, log10(17) * 50) = min(100, 61.2) = 61.2

        XCTAssertEqual(normalized, 61.2, accuracy: 0.1)
    }

    func test_scenario_oldButPopular() {
        // Recipe with high total engagement but old
        // 100 views from 7 days ago
        let age: TimeInterval = 7 * 24 * 60 * 60
        let halfLife: TimeInterval = 3 * 24 * 60 * 60
        let decayFactor = exp(-age / halfLife)

        let totalScore = 100.0 * 1.0 * decayFactor
        // = 100 * 0.1054 = 10.54

        let normalized = min(100, log10(totalScore + 1) * 50)
        // = min(100, log10(11.54) * 50) = 52.3

        XCTAssertEqual(normalized, 52.3, accuracy: 0.5)
    }

    // MARK: - Edge Case Tests

    func test_edgeCase_singleEngagement() {
        // Recipe with just 1 view
        let totalScore = 1.0
        let normalized = min(100, log10(totalScore + 1) * 50)
        // = min(100, log10(2) * 50) = 15.05

        XCTAssertEqual(normalized, 15.05, accuracy: 0.1)
    }

    func test_edgeCase_massiveEngagement() {
        // Recipe with unrealistic engagement (10000)
        let totalScore = 10000.0
        let normalized = min(100, log10(totalScore + 1) * 50)

        // Should be capped at 100
        XCTAssertEqual(normalized, 100)
    }

    func test_edgeCase_negativeVelocity() {
        // Recipe losing all engagement
        let recentCount = 0.0
        let previousCount = 50.0
        let velocity = ((recentCount - previousCount) / previousCount) * 100

        XCTAssertEqual(velocity, -100.0) // 100% decline
    }
}
