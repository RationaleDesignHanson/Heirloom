//
//  CreditsBalanceIndicator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import SwiftUI

/// Small indicator showing remaining credit balance
/// - Can be displayed in navigation bar
/// - Tappable to show more details or purchase credits
struct CreditsBalanceIndicator: View {

    // MARK: - Properties

    let balance: Int
    let dailyQuota: Int
    let onTap: (() -> Void)?

    // MARK: - Computed

    private var isLow: Bool {
        balance < 5  // Less than 1 scanned PDF worth
    }

    private var displayText: String {
        return "\(balance)"
    }

    // MARK: - Body

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "giftcard.fill")
                    .font(.caption)
                    .foregroundColor(isLow ? .orange : HeirloomColors.familyGreen)

                Text(displayText)
                    .font(.subheadline.bold())
                    .foregroundColor(isLow ? .orange : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isLow ? Color.orange.opacity(0.15) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .disabled(onTap == nil)
    }
}

// MARK: - Compact Variant (for nav bar)

extension CreditsBalanceIndicator {

    /// Ultra-compact variant for toolbar
    static func compact(balance: Int, onTap: (() -> Void)? = nil) -> some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "giftcard.fill")
                    .font(.caption2)
                Text("\(balance)")
                    .font(.caption.bold())
            }
            .foregroundColor(balance < 5 ? .orange : HeirloomColors.familyGreen)
        }
        .disabled(onTap == nil)
    }
}

// MARK: - Preview

#Preview("Normal") {
    VStack(spacing: 20) {
        CreditsBalanceIndicator(balance: 15, dailyQuota: 25, onTap: {
            print("Tapped")
        })

        CreditsBalanceIndicator(balance: 3, dailyQuota: 25, onTap: {
            print("Tapped")
        })

        CreditsBalanceIndicator(balance: 0, dailyQuota: 25, onTap: nil)
    }
    .padding()
}

#Preview("Compact") {
    VStack(spacing: 20) {
        CreditsBalanceIndicator.compact(balance: 15) {
            print("Tapped")
        }

        CreditsBalanceIndicator.compact(balance: 3) {
            print("Tapped")
        }

        CreditsBalanceIndicator.compact(balance: 0)
    }
    .padding()
}
