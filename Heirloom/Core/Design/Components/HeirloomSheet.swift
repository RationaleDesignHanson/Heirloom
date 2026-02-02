import SwiftUI

// MARK: - Unified Sheet Components (Task #5)

/// Standardized sheet header with title, optional subtitle, and dismiss button
struct HeirloomSheetHeader: View {
    let title: String
    let subtitle: String?

    @Environment(\.dismiss) private var dismiss

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: HeirloomSpacing.xs) {
            HStack {
                Text(title)
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.top, HeirloomSpacing.md)
        .padding(.bottom, HeirloomSpacing.sm)
    }
}

/// Standardized primary action button with loading state
struct HeirloomPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    init(title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: HeirloomSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }

                Text(isLoading ? "Processing..." : title)
                    .font(HeirloomFonts.bodyBold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HeirloomSpacing.md)
            .background(HeirloomColors.tomato)
            .foregroundStyle(.white)
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
        }
        .disabled(isLoading)
    }
}

/// Standardized secondary button style
struct HeirloomSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HeirloomFonts.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HeirloomSpacing.md)
                .background(HeirloomColors.warmGray.opacity(0.15))
                .foregroundStyle(HeirloomColors.primaryText)
                .cornerRadius(HeirloomSpacing.cardCornerRadius)
        }
    }
}

/// Unified sheet container with standard layout
struct HeirloomSheetContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeirloomSheetHeader(title: title, subtitle: subtitle)

                Divider()

                ScrollView {
                    VStack(spacing: HeirloomSpacing.lg) {
                        content
                    }
                    .padding(HeirloomSpacing.md)
                }
            }
            .background(HeirloomColors.appBackground)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Button("Show Sheet") { }
    }
    .sheet(isPresented: .constant(true)) {
        HeirloomSheetContainer(
            title: "Import Recipe",
            subtitle: "Scan or upload a recipe photo"
        ) {
            VStack(spacing: HeirloomSpacing.md) {
                Text("Sheet content goes here")
                    .foregroundStyle(HeirloomColors.secondaryText)

                HeirloomPrimaryButton(
                    title: "Continue",
                    isLoading: false,
                    action: { }
                )

                HeirloomSecondaryButton(
                    title: "Cancel",
                    action: { }
                )
            }
        }
    }
}
