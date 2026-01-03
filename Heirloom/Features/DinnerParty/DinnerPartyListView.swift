import SwiftUI
import SwiftData

struct DinnerPartyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DinnerParty.mealTime, order: .forward) private var dinnerParties: [DinnerParty]

    @State private var showCreateParty = false
    @State private var selectedParty: DinnerParty?

    var upcomingParties: [DinnerParty] {
        dinnerParties.filter { !$0.isPast }
    }

    var pastParties: [DinnerParty] {
        dinnerParties.filter { $0.isPast }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if dinnerParties.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: HeirloomSpacing.lg) {
                            // Upcoming parties
                            if !upcomingParties.isEmpty {
                                VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                                    Text("Upcoming")
                                        .font(HeirloomFonts.title3)
                                        .foregroundStyle(HeirloomColors.primaryText)
                                        .padding(.horizontal)

                                    ForEach(upcomingParties, id: \.id) { party in
                                        dinnerPartyCard(party)
                                    }
                                }
                            }

                            // Past parties
                            if !pastParties.isEmpty {
                                VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                                    Text("Past Events")
                                        .font(HeirloomFonts.title3)
                                        .foregroundStyle(HeirloomColors.primaryText)
                                        .padding(.horizontal)

                                    ForEach(pastParties.prefix(10), id: \.id) { party in
                                        dinnerPartyCard(party)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Dinner Parties")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateParty = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateParty) {
                DinnerPartyEditorView()
            }
            .sheet(item: $selectedParty) { party in
                DinnerPartyDetailView(party: party)
            }
        }
    }

    // MARK: - Dinner Party Card

    private func dinnerPartyCard(_ party: DinnerParty) -> some View {
        Button {
            selectedParty = party
        } label: {
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                // Header with name and guest count
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(party.name)
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.primaryText)

                        if let description = party.desc {
                            Text(description)
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(party.guestCount)")
                            .font(HeirloomFonts.bodyBold)
                    }
                    .foregroundStyle(HeirloomColors.familyGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(HeirloomColors.familyGreen.opacity(0.1))
                    .cornerRadius(16)
                }

                Divider()
                    .padding(.vertical, 4)

                // Meal time and status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(party.mealTime.formatted(date: .abbreviated, time: .omitted))
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text(party.mealTime.formatted(date: .omitted, time: .shortened))
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    statusBadge(party)
                }

                // Recipe count and timing
                HStack(spacing: HeirloomSpacing.lg) {
                    stat(icon: "fork.knife", value: "\(party.recipeCount)", label: "recipes")
                    stat(icon: "clock", value: timeDisplay(party), label: "total")

                    Spacer()

                    if party.isInProgress {
                        NavigationLink {
                            DinnerPartyActiveView(party: party)
                        } label: {
                            Text("Cook Now")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(HeirloomColors.tomato)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteParty(party)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Status Badge

    private func statusBadge(_ party: DinnerParty) -> some View {
        Group {
            if party.isInProgress {
                Label("In Progress", systemImage: "circle.fill")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(16)
            } else if party.isUpcoming {
                Text(party.displayTimeStatus)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            } else {
                Text("Completed")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }

    // MARK: - Stat Display

    private func stat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
            Text(value)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
            Text(label)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private func timeDisplay(_ party: DinnerParty) -> String {
        let total = party.totalPrepTime + party.totalCookTime
        if total >= 60 {
            let hours = total / 60
            let minutes = total % 60
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }
        return "\(total)m"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Dinner Parties", systemImage: "fork.knife")
        } description: {
            Text("Create a dinner party to coordinate cooking multiple recipes for your guests")
        } actions: {
            Button("Create Dinner Party") {
                showCreateParty = true
            }
            .buttonStyle(.borderedProminent)
            .tint(HeirloomColors.tomato)
        }
    }

    // MARK: - Actions

    private func deleteParty(_ party: DinnerParty) {
        let partyId = party.id
        modelContext.delete(party)

        do {
            try modelContext.save()

            // Delete from Firebase if active
            if BackendConfig.shared.isFirebaseActive {
                Task {
                    do {
                        try await FirebaseSyncService.shared.deleteDinnerParty(partyId)
                        print("✅ Dinner party deleted from Firebase")
                    } catch {
                        print("⚠️ Failed to delete dinner party from Firebase: \(error.localizedDescription)")
                    }
                }
            }

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            ToastManager.shared.success(title: "Dinner party deleted")
        } catch {
            ToastManager.shared.error(
                title: "Failed to delete",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview {
    DinnerPartyListView()
        .modelContainer(for: DinnerParty.self, inMemory: true)
        .toastContainer()
}
