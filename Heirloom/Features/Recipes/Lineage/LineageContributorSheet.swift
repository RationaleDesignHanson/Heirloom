//
//  LineageContributorSheet.swift
//  Heirloom
//
//  Phase 8: Lineage Integration - Contributor Profile View
//  Shows contributor info from lineage with connection context
//

import SwiftUI

/// Sheet showing contributor profile from lineage
struct LineageContributorSheet: View {
    let contributor: ContributorInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    if contributor.hasAccount {
                        accountProfileContent
                    } else {
                        legacyProfileContent
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Contributor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Account Profile Content

    private var accountProfileContent: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            // Avatar
            profileAvatar

            // Name
            Text(contributor.displayName)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            // Connection indicator
            if contributor.isConnected {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HeirloomColors.familyGreen)
                    Text("Connected")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.familyGreen)
                }
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.vertical, HeirloomSpacing.sm)
                .background(HeirloomColors.familyGreen.opacity(0.1))
                .cornerRadius(20)
            }

            // Context badge
            contextBadge

            Spacer()
        }
    }

    // MARK: - Legacy Profile Content

    private var legacyProfileContent: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            // Avatar with initials
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            HeirloomColors.familyGreen.opacity(0.8),
                            HeirloomColors.familyGreen.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text(contributor.initials)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                )

            // Name
            Text(contributor.displayName)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("This contributor doesn't have an active Heirloom account")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            Spacer()
        }
    }

    // MARK: - Components

    @ViewBuilder
    private var profileAvatar: some View {
        if let avatarURL = contributor.avatarURL, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 2)
                        )
                case .failure, .empty:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.familyGreen.opacity(0.8),
                        HeirloomColors.familyGreen.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Text(contributor.initials)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }

    private var contextBadge: some View {
        VStack(spacing: HeirloomSpacing.xs) {
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: "arrow.branch")
                    .font(.system(size: 12))
                Text("Recipe Lineage Contributor")
            }
            .font(HeirloomFonts.caption1)
            .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
        .background(HeirloomColors.amber.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    LineageContributorSheet(
        contributor: ContributorInfo(
            userId: "preview-user",
            displayName: "Jane Smith",
            avatarURL: nil,
            isConnected: true
        )
    )
}
