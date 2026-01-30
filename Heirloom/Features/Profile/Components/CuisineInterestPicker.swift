//
//  CuisineInterestPicker.swift
//  Heirloom
//
//  Social Layer Phase 5: Cuisine interest tag picker
//  Allows user to select multiple cuisine specialties/interests
//

import SwiftUI

struct CuisineInterestPicker: View {
    @Binding var selectedCuisines: [String]
    let maxSelections: Int = 5

    private let availableCuisines = [
        "Italian", "Mexican", "Chinese", "Japanese", "French",
        "Indian", "Thai", "Mediterranean", "American", "Korean",
        "Vietnamese", "Greek", "Spanish", "Middle Eastern", "Caribbean",
        "Brazilian", "German", "British", "Moroccan", "Ethiopian",
        "Baking", "Desserts", "Grilling", "Vegetarian", "Vegan"
    ].sorted()

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Text("Cuisine Interests")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text("\(selectedCuisines.count)/\(maxSelections)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Text("Select up to \(maxSelections) cuisines you enjoy cooking")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            // Tag cloud
            FlowLayout(spacing: HeirloomSpacing.xs) {
                ForEach(availableCuisines, id: \.self) { cuisine in
                    cuisineTag(cuisine)
                }
            }
        }
    }

    // MARK: - Cuisine Tag

    @ViewBuilder
    private func cuisineTag(_ cuisine: String) -> some View {
        let isSelected = selectedCuisines.contains(cuisine)
        let isDisabled = !isSelected && selectedCuisines.count >= maxSelections

        Button {
            toggleCuisine(cuisine)
        } label: {
            Text(cuisine)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(
                    isSelected ? .white :
                    isDisabled ? HeirloomColors.secondaryText.opacity(0.5) :
                    HeirloomColors.primaryText
                )
                .padding(.horizontal, HeirloomSpacing.sm)
                .padding(.vertical, HeirloomSpacing.xs)
                .background(
                    isSelected ? HeirloomColors.tomato :
                    HeirloomColors.warmGray.opacity(0.1)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? HeirloomColors.tomato :
                            HeirloomColors.warmGray.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .disabled(isDisabled)
    }

    // MARK: - Actions

    private func toggleCuisine(_ cuisine: String) {
        if selectedCuisines.contains(cuisine) {
            selectedCuisines.removeAll { $0 == cuisine }
        } else if selectedCuisines.count < maxSelections {
            selectedCuisines.append(cuisine)
        }
    }
}

// MARK: - Flow Layout

/// Simple flow layout for tags
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // New line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
            self.positions = positions
        }
    }
}

#Preview {
    @Previewable @State var selectedCuisines: [String] = ["Italian", "Japanese", "Mexican"]

    ScrollView {
        VStack(spacing: HeirloomSpacing.lg) {
            CuisineInterestPicker(selectedCuisines: $selectedCuisines)

            Text("Selected: \(selectedCuisines.joined(separator: ", "))")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding()
    }
    .background(HeirloomColors.appBackground)
}
