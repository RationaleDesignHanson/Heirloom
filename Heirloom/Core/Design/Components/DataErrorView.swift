import SwiftUI

/// Error view displayed when SwiftData initialization fails
/// Provides clear messaging and recovery options
struct DataErrorView: View {
    var body: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Spacer()

            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(HeirloomColors.tomato)

            // Title
            Text("Unable to Load Data")
                .font(HeirloomFonts.title1)
                .foregroundStyle(HeirloomColors.charcoal)

            // Message
            Text("Heirloom encountered an error while loading your recipe data. Please try restarting the app.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            // Recovery actions
            VStack(spacing: HeirloomSpacing.md) {
                Button {
                    // Restart app - user will need to force quit and reopen
                    exit(0)
                } label: {
                    Text("Restart App")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.tomato)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, HeirloomSpacing.xl)

                // Technical details (expandable)
                DisclosureGroup("Technical Details") {
                    Text("SwiftData ModelContainer initialization failed. This may be due to data corruption or insufficient storage space. If the problem persists, you may need to reinstall the app.")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                        .padding(.top, HeirloomSpacing.sm)
                }
                .padding(.horizontal, HeirloomSpacing.xl)
                .tint(HeirloomColors.tomato)
            }

            Spacer()
            Spacer()
        }
        .background(HeirloomColors.cream)
    }
}

#Preview {
    DataErrorView()
}
