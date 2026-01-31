import SwiftUI

/// Badge shown on recipe cards when published to public discovery
struct PublicRecipeBadge: View {
    let viewCount: Int
    let compact: Bool

    init(viewCount: Int, compact: Bool = false) {
        self.viewCount = viewCount
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Image(systemName: "globe")
                .font(.system(size: compact ? 10 : 12, weight: .semibold))

            if !compact {
                Text("\(viewCount)")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(
            Capsule()
                .fill(HeirloomColors.familyBlue)
        )
    }
}

// MARK: - Preview

#Preview("Standard") {
    VStack(spacing: 16) {
        PublicRecipeBadge(viewCount: 42)
        PublicRecipeBadge(viewCount: 1234)
        PublicRecipeBadge(viewCount: 0)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

#Preview("Compact") {
    VStack(spacing: 16) {
        PublicRecipeBadge(viewCount: 42, compact: true)
        PublicRecipeBadge(viewCount: 1234, compact: true)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
