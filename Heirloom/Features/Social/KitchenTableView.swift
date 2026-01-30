//
//  KitchenTableView.swift
//  Heirloom
//
//  Social Layer Phase 4: Kitchen Table View (Placeholder)
//  Full implementation in Phase 6
//

import SwiftUI

struct KitchenTableView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 80))
                    .foregroundStyle(HeirloomColors.tomato)

                // Title
                Text("Kitchen Table")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Description
                Text("Coming in Phase 6")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)

                // Feature list
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    FeatureRow(icon: "person.2.fill", text: "See your connections")
                    FeatureRow(icon: "person.badge.plus", text: "Send connection requests")
                    FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Share recipes")
                    FeatureRow(icon: "heart.fill", text: "Favorite connections")
                    FeatureRow(icon: "bell.badge.fill", text: "Connection notifications")
                }
                .padding(.horizontal, HeirloomSpacing.xxl)

                Spacer()
            }
            .navigationTitle("Kitchen Table")
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
    KitchenTableView()
}
