import SwiftUI

struct CreatorAttributionBadge: View {
    let platform: SocialPlatform
    let attribution: String  // e.g., "@username" or display name
    let size: BadgeSize

    enum BadgeSize {
        case small, medium, large
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: platform.iconSystemName)
                .font(iconFont)

            Text(attribution)
                .font(textFont)
                .lineLimit(1)
        }
        .foregroundColor(platformColor)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(platformColor.opacity(0.1))
        .cornerRadius(cornerRadius)
    }

    private var platformColor: Color {
        switch platform {
        case .tiktok: return .pink
        case .instagram: return .purple
        case .youtube: return .red
        case .facebook: return .blue
        case .unknown: return .gray
        }
    }

    private var iconFont: Font {
        switch size {
        case .small: return .caption2
        case .medium: return .caption
        case .large: return .body
        }
    }

    private var textFont: Font {
        switch size {
        case .small: return .caption2
        case .medium: return .caption
        case .large: return .subheadline.weight(.medium)
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 6
        case .medium: return 8
        case .large: return 12
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 3
        case .medium: return 4
        case .large: return 6
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }
}
