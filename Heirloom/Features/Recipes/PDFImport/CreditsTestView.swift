//
//  CreditsTestView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//  Test harness for credits system
//

import SwiftUI
import SwiftData
import PDFKit

/// Test harness for credits system
/// Access via: Deep link or debug menu
struct CreditsTestView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth

    // Services
    private var logger: LoggingService { ServiceContainer.shared.resolve(LoggingService.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    // State
    @State private var userCredits: UserCredits?
    @State private var storeManager: CreditStoreManager?
    @State private var showStoreView = false
    @State private var showCostSheet = false
    @State private var testPDFURL: URL?
    @State private var costBreakdown: PDFCostCalculator.CostBreakdown?
    @State private var testLog: [String] = []
    @State private var refreshTrigger = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 60))
                            .foregroundColor(HeirloomColors.familyGreen)

                        Text("Credits System Test")
                            .font(.title.bold())

                        Text("Test all credits functionality")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // User Credits Info
                    if let userCredits = userCredits {
                        UserCreditsCard(userCredits: userCredits)
                            .id("\(userCredits.creditsBalance)-\(userCredits.tierCreditsUsed)")
                    } else {
                        Text("Initializing user credits...")
                            .foregroundColor(.secondary)
                    }

                    // Test Actions
                    VStack(spacing: 12) {
                        Text("Test Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Test 1: Show Store
                        Button {
                            showStoreView = true
                        } label: {
                            TestActionButton(
                                icon: "cart.fill",
                                title: "Open Credits Store",
                                description: "Test purchase flow (fake purchases enabled)"
                            )
                        }

                        // Test 2: Simulate PDF Cost Calculation
                        Button {
                            Task {
                                await testPDFCostCalculation()
                            }
                        } label: {
                            TestActionButton(
                                icon: "doc.text.magnifyingglass",
                                title: "Test PDF Cost Calculator",
                                description: "Simulate text-rich vs scanned PDF detection"
                            )
                        }

                        // Test 3: Show Cost Sheet
                        Button {
                            showMockCostSheet()
                        } label: {
                            TestActionButton(
                                icon: "doc.badge.gearshape",
                                title: "Show Cost Breakdown Sheet",
                                description: "Test the pre-import cost UI"
                            )
                        }

                        // Test 4: Deduct Credits
                        Button {
                            deductTestCredits(5)
                        } label: {
                            TestActionButton(
                                icon: "minus.circle",
                                title: "Deduct 5 Credits",
                                description: "Test quota deduction logic"
                            )
                        }

                        // Test 5: Add Credits Manually
                        Button {
                            addTestCredits(25)
                        } label: {
                            TestActionButton(
                                icon: "plus.circle",
                                title: "Add 25 Credits (Manual)",
                                description: "Test credit addition (simulates purchase)"
                            )
                        }

                        // Test 6: Reset Tier Credits
                        Button {
                            resetTierCredits()
                        } label: {
                            TestActionButton(
                                icon: "arrow.clockwise",
                                title: "Reset Tier Credits",
                                description: "Reset tier credits to full allocation"
                            )
                        }

                        // Test 7: Queue PDF for Tomorrow
                        Button {
                            Task {
                                await testQueuePDF()
                            }
                        } label: {
                            TestActionButton(
                                icon: "calendar.badge.plus",
                                title: "Queue PDF for Tomorrow",
                                description: "Test queue functionality"
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Test Log
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Log")
                            .font(.headline)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(testLog.enumerated()), id: \.offset) { _, log in
                                    Text(log)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showStoreView, onDismiss: {
                // Refresh UI when returning from store
                refreshTrigger += 1
            }) {
                if let storeManager = storeManager {
                    CreditsStoreView(storeManager: storeManager)
                }
            }
            .sheet(isPresented: $showCostSheet) {
                if let costBreakdown = costBreakdown, let userCredits = userCredits {
                    CreditsCostSheet(
                        costBreakdown: costBreakdown,
                        userCredits: userCredits,
                        onConfirm: { generateAIImages in
                            log("✅ User confirmed import (AI images: \(generateAIImages))")
                            showCostSheet = false
                        },
                        onBuyCredits: {
                            log("💳 User wants to buy credits")
                            showCostSheet = false
                            showStoreView = true
                        },
                        onQueueForTomorrow: {
                            log("📅 User queued PDF for tomorrow")
                            showCostSheet = false
                        }
                    )
                }
            }
            .task {
                await setupTest()
            }
            .id(refreshTrigger)
        }
    }

    // MARK: - Setup

    private func setupTest() async {
        log("🚀 Initializing credits test harness...")

        // Get or create user credits
        guard let userId = firebaseAuth.currentUser?.uid else {
            log("❌ No authenticated user - using test user ID")
            let testUserId = "test-user-\(UUID().uuidString.prefix(8))"
            await createUserCredits(userId: testUserId)
            return
        }

        await createUserCredits(userId: userId)
    }

    @MainActor
    private func createUserCredits(userId: String) async {
        var descriptor = FetchDescriptor<UserCredits>()
        descriptor.predicate = #Predicate<UserCredits> { credits in
            credits.userId == userId
        }

        do {
            let existing = try modelContext.fetch(descriptor).first

            if let existing = existing {
                userCredits = existing
                log("✅ Found existing user credits")
                log("   Purchased: \(existing.creditsBalance)")
                log("   Tier (\(existing.tierType)): \(existing.tierCreditsRemaining)/\(existing.currentTierType.creditAllocation)")
            } else {
                let newCredits = UserCredits(userId: userId)
                modelContext.insert(newCredits)
                try modelContext.save()
                userCredits = newCredits
                log("✅ Created new user credits")
                log("   Purchased: 0")
                log("   Tier (trial): \(UserCredits.trialCredits)/\(UserCredits.trialCredits)")
            }

            // Initialize store manager
            storeManager = CreditStoreManager(
                logger: logger,
                analytics: analytics,
                modelContext: modelContext,
                userId: userId
            )
            log("✅ Store manager initialized")

        } catch {
            log("❌ Error setting up user credits: \(error.localizedDescription)")
        }
    }

    // MARK: - Test Actions

    private func testPDFCostCalculation() async {
        log("🧪 Testing PDF cost calculation...")

        guard let userCredits = userCredits else {
            log("❌ No user credits available")
            return
        }

        // Create mock PDF URLs for testing
        let mockPDFs = [
            ("TextRich.pdf", PDFCostCalculator.PDFContentType.textRich),
            ("Scanned.pdf", PDFCostCalculator.PDFContentType.scanned),
            ("Mixed.pdf", PDFCostCalculator.PDFContentType.mixed)
        ]

        // Simulate classification
        var totalCredits = 0
        var classifications: [URL: PDFCostCalculator.PDFContentType] = [:]

        for (name, type) in mockPDFs {
            let url = URL(fileURLWithPath: "/tmp/\(name)")
            classifications[url] = type
            totalCredits += type.creditCost
            log("   \(name): \(type.displayName) = \(type.creditCost) credits")
        }

        let breakdown = PDFCostCalculator.CostBreakdown(
            totalCredits: totalCredits,
            textRichCount: 1,
            scannedCount: 1,
            mixedCount: 1,
            classifications: classifications,
            canAfford: userCredits.availableToday >= totalCredits,
            needsCredits: max(0, totalCredits - userCredits.availableToday),
            estimatedTotalPages: 50  // Mock: ~25 recipes
        )

        costBreakdown = breakdown

        log("✅ Total cost: \(totalCredits) credits")
        log("   Available: \(userCredits.availableToday) credits")
        log("   Can afford: \(breakdown.canAfford ? "YES" : "NO")")
    }

    private func showMockCostSheet() {
        guard let userCredits = userCredits else {
            log("❌ No user credits available")
            return
        }

        log("📊 Showing cost breakdown sheet...")

        // Create mock breakdown
        costBreakdown = PDFCostCalculator.CostBreakdown(
            totalCredits: 7,
            textRichCount: 2,
            scannedCount: 1,
            mixedCount: 0,
            classifications: [:],
            canAfford: userCredits.availableToday >= 7,
            needsCredits: max(0, 7 - userCredits.availableToday),
            estimatedTotalPages: 100  // Mock: ~50 recipes
        )

        showCostSheet = true
    }

    private func deductTestCredits(_ amount: Int) {
        guard let userCredits = userCredits else {
            log("❌ No user credits available")
            return
        }

        log("➖ Attempting to deduct \(amount) credits...")

        do {
            try userCredits.deductCredits(amount)
            try modelContext.save()
            refreshTrigger += 1
            log("✅ Deducted \(amount) credits")
            log("   Remaining: \(userCredits.availableToday) credits")
        } catch {
            log("❌ Failed to deduct credits: \(error.localizedDescription)")
        }
    }

    private func addTestCredits(_ amount: Int) {
        guard let userCredits = userCredits else {
            log("❌ No user credits available")
            return
        }

        log("➕ Adding \(amount) credits...")

        userCredits.addPurchasedCredits(amount)

        do {
            try modelContext.save()
            refreshTrigger += 1
            log("✅ Added \(amount) credits")
            log("   New balance: \(userCredits.creditsBalance)")
            log("   Available today: \(userCredits.availableToday)")
        } catch {
            log("❌ Failed to save: \(error.localizedDescription)")
        }
    }

    private func resetTierCredits() {
        guard let userCredits = userCredits else {
            log("❌ No user credits available")
            return
        }

        log("🔄 Resetting tier credits...")

        // Reset tier credits to full allocation
        userCredits.tierCreditsUsed = 0
        userCredits.tierCreditResetDate = Date()

        do {
            try modelContext.save()
            refreshTrigger += 1
            log("✅ Tier credits reset")
            log("   Tier: \(userCredits.tierType)")
            log("   Available: \(userCredits.tierCreditsRemaining)/\(userCredits.currentTierType.creditAllocation)")
        } catch {
            log("❌ Failed to save: \(error.localizedDescription)")
        }
    }

    private func testQueuePDF() async {
        guard let userCredits = userCredits else {
            log("❌ No user credits available")
            return
        }

        log("📅 Testing queue PDF for tomorrow...")

        // Create a mock PDF URL
        let mockURL = URL(fileURLWithPath: "/tmp/TestCookbook.pdf")

        do {
            let queued = try QueuedPDFImport.queuePDF(
                url: mockURL,
                creditCost: 5,
                userId: userCredits.userId,
                context: modelContext
            )

            try modelContext.save()

            log("✅ PDF queued successfully")
            log("   Name: \(queued.pdfName)")
            log("   Cost: \(queued.creditCost) credits")
            log("   Scheduled for: \(queued.scheduledFor)")

        } catch {
            log("❌ Failed to queue PDF: \(error.localizedDescription)")
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testLog.append("[\(timestamp)] \(message)")
        logger.info(message, category: .general)
    }
}

// MARK: - User Credits Card

struct UserCreditsCard: View {
    @Bindable var userCredits: UserCredits

    var body: some View {
        VStack(spacing: 16) {
            // Balance
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Purchased Credits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(userCredits.creditsBalance)")
                        .font(.title.bold())
                        .foregroundColor(HeirloomColors.familyGreen)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Tier Credits (\(userCredits.tierType))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(userCredits.tierCreditsRemaining)/\(userCredits.currentTierType.creditAllocation)")
                        .font(.title.bold())
                        .foregroundColor(.green)
                }
            }

            Divider()

            // Total available
            HStack {
                Text("Total Available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(userCredits.availableCredits) credits")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // Reset time (only for premium with monthly reset)
            if userCredits.hasPeriodicReset, let resetTime = userCredits.tierResetTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                    Text("Resets \(resetTime, style: .relative)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Test Action Button

struct TestActionButton: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(HeirloomColors.familyGreen)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    CreditsTestView()
        .modelContainer(for: [UserCredits.self, QueuedPDFImport.self])
}
