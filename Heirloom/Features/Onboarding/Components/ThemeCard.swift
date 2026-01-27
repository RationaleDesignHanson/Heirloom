//
//  ThemeCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct ThemeCard: View {
    let theme: RecipeTheme
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 240

    var body: some View {
        ZStack(alignment: .topTrailing) {
                // Background image
                themeImage

                // Gradient overlay - stronger and starts earlier for better text legibility
                LinearGradient(
                    colors: [.clear, .black.opacity(0.3), .black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content overlay
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Category badge
                    Text(theme.category.displayName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 4)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                    // Theme name
                    Text(theme.name)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                    // Tagline
                    Text(theme.tagline)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(2)
                        .padding(.top, 4)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                    // Recipe count
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text("\(theme.totalRecipes) recipes")
                            .font(HeirloomFonts.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 8)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                .padding(HeirloomSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(HeirloomColors.familyGreen)
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 24, height: 24)
                        )
                        .padding(HeirloomSpacing.sm)
                }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? HeirloomColors.familyGreen : .clear,
                    lineWidth: 3
                )
        )
        .shadow(
            color: .black.opacity(isSelected ? 0.2 : 0.1),
            radius: isSelected ? 12 : 8,
            x: 0,
            y: isSelected ? 6 : 4
        )
        .opacity(isDisabled && !isSelected ? 0.5 : 1.0)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled {
                onTap()
            }
        }
        .onLongPressGesture(minimumDuration: 0.01, maximumDistance: .infinity) {
            // Tap completed
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }

    @ViewBuilder
    private var themeImage: some View {
        if let urlString = theme.coverImageURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                case .failure:
                    placeholderImage
                case .empty:
                    placeholderImage
                        .overlay(ProgressView())
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.warmGray.opacity(0.3),
                        HeirloomColors.warmGray.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: theme.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            )
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        ThemeCard(
            theme: .preview,
            isSelected: false,
            isDisabled: false,
            onTap: {}
        )

        ThemeCard(
            theme: .preview,
            isSelected: true,
            isDisabled: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

// MARK: - Preview Helper

extension RecipeTheme {
    static var preview: RecipeTheme {
        RecipeTheme(
            firebaseId: "preview",
            name: "Automat Classics",
            tagline: "Recipes from restaurants that no longer exist",
            themeDescription: "Horn & Hardart's legendary cafeteria...",
            iconName: "building.columns",
            category: .source,
            totalRecipes: 14,
            unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14]
        )
    }
}
