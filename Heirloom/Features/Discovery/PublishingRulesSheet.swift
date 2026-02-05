//
//  PublishingRulesSheet.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-04.
//  Task 14: Publishing Rules UI Copy
//

import SwiftUI

/// Sheet explaining what recipes can be published to Discover
struct PublishingRulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero section
                    VStack(spacing: 12) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [HeirloomColors.tomato, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Sharing to Discover")
                            .font(HeirloomFonts.title2)
                            .foregroundColor(HeirloomColors.primaryText)

                        Text("Help keep our community authentic")
                            .font(HeirloomFonts.body)
                            .foregroundColor(HeirloomColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // What you CAN publish
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(HeirloomColors.familyGreen)
                            Text("What you can share")
                                .font(HeirloomFonts.title3)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            PublishingRuleRow(
                                icon: "camera.fill",
                                title: "Photographed recipes",
                                description: "Handwritten cards, cookbooks, or family documents you've captured"
                            )

                            PublishingRuleRow(
                                icon: "pencil.line",
                                title: "Your own creations",
                                description: "Recipes you've developed and written yourself"
                            )

                            PublishingRuleRow(
                                icon: "heart.fill",
                                title: "Family heirlooms",
                                description: "Recipes passed down through your family that you have rights to share"
                            )
                        }
                    }
                    .padding(16)
                    .background(HeirloomColors.familyGreen.opacity(0.08))
                    .cornerRadius(12)

                    // What you CANNOT publish
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(HeirloomColors.tomato)
                            Text("What can't be shared")
                                .font(HeirloomFonts.title3)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            PublishingRuleRow(
                                icon: "globe",
                                title: "Website imports",
                                description: "Recipes saved from websites, blogs, or other online sources",
                                isRestricted: true
                            )

                            PublishingRuleRow(
                                icon: "video.fill",
                                title: "Video conversions",
                                description: "Recipes extracted from TikTok, YouTube, or Instagram videos",
                                isRestricted: true
                            )

                            PublishingRuleRow(
                                icon: "sparkles",
                                title: "AI-generated recipes",
                                description: "Recipes created by Heirloom's AI generator",
                                isRestricted: true
                            )
                        }
                    }
                    .padding(16)
                    .background(HeirloomColors.tomato.opacity(0.08))
                    .cornerRadius(12)

                    // Why we do this
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Why these rules?")
                                .font(HeirloomFonts.title3)
                        }

                        Text("Discover is a place for authentic, personal recipes. We want to celebrate family traditions and original creations while respecting the work of recipe creators everywhere.")
                            .font(HeirloomFonts.body)
                            .foregroundColor(HeirloomColors.secondaryText)

                        Text("Recipes from websites and videos belong to their original creators. By keeping these private, we ensure Discover stays filled with genuine, share-worthy recipes.")
                            .font(HeirloomFonts.body)
                            .foregroundColor(HeirloomColors.secondaryText)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Publishing Guidelines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(HeirloomColors.tomato)
                }
            }
        }
    }
}

// MARK: - Publishing Rule Row

private struct PublishingRuleRow: View {
    let icon: String
    let title: String
    let description: String
    var isRestricted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isRestricted ? HeirloomColors.tomato.opacity(0.7) : HeirloomColors.familyGreen)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundColor(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PublishingRulesSheet()
}
