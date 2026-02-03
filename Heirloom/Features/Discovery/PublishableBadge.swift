import SwiftUI

/// Badge shown on recipe cards when recipe can be published but isn't yet
/// Blue badge with upload icon - tappable to open publish sheet
struct PublishableBadge: View {
    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: compact ? 10 : 12, weight: .semibold))

            if !compact {
                Text("Share")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(
            Capsule()
                .fill(Color.blue)
        )
    }
}

// MARK: - Preview

#Preview("Publishable Badge") {
    VStack(spacing: 20) {
        PublishableBadge()
        PublishableBadge(compact: true)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
