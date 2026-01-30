//
//  ProfileView.swift
//  Heirloom
//
//  Social Layer Phase 4: Profile View (Placeholder)
//  Full implementation in Phase 5
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(HeirloomColors.tomato)

                // Title
                Text("My Profile")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Description
                Text("Coming in Phase 5")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)

                // Feature list
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    FeatureRow(icon: "person.fill", text: "Edit profile & bio")
                    FeatureRow(icon: "photo.fill", text: "Update profile photo")
                    FeatureRow(icon: "at", text: "Set @handle for mentions")
                    FeatureRow(icon: "link", text: "Public profile URL")
                    FeatureRow(icon: "lock.fill", text: "Privacy settings")
                }
                .padding(.horizontal, HeirloomSpacing.xxl)

                Spacer()
            }
            .navigationTitle("My Profile")
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
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
                .frame(width: 20)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            Spacer()
        }
    }
}

#Preview {
    ProfileView()
}
