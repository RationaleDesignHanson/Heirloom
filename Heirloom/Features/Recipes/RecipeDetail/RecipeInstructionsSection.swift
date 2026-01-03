//
//  RecipeInstructionsSection.swift
//  Heirloom
//
//  Phase 3: View Layer Decomposition
//  Instructions component for RecipeDetailView
//

import SwiftUI

/// Recipe instructions displayed as numbered steps
struct RecipeInstructionsSection: View {
    // MARK: - Properties

    let instructions: [String]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionHeader(
                title: "Instructions",
                icon: "list.number",
                count: instructions.count
            )

            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    instructionRow(number: index + 1, text: instruction)
                }
            }
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
            )
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String, count: Int? = nil) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(HeirloomColors.tomato)

            Text(title)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.charcoal)

            if let count = count {
                Text("(\(count))")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
            }

            Spacer()
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            ZStack {
                Circle()
                    .fill(HeirloomColors.tomato)
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
            }

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    let instructions = [
        "Preheat oven to 350°F (175°C).",
        "Mix flour, baking soda, and salt in a bowl.",
        "In another bowl, cream together butter and sugars until fluffy.",
        "Beat in eggs one at a time, then stir in vanilla.",
        "Gradually blend in the flour mixture.",
        "Stir in chocolate chips.",
        "Drop rounded tablespoons of dough onto ungreased cookie sheets.",
        "Bake for 9-11 minutes or until golden brown.",
        "Cool on baking sheet for 2 minutes before removing to a wire rack."
    ]

    return RecipeInstructionsSection(instructions: instructions)
        .padding()
        .background(HeirloomColors.cream)
}
