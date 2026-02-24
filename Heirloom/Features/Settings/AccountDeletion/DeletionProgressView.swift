//
//  DeletionProgressView.swift
//  Heirloom
//
//  Apple Compliance: Progress feedback during account deletion
//

import SwiftUI

/// Shows progress feedback during account deletion
struct DeletionProgressView: View {
    let progress: DeletionProgress
    let onComplete: () -> Void

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            Spacer()

            // Icon
            progressIcon

            // Status text
            VStack(spacing: HeirloomSpacing.sm) {
                Text(progress.currentStep.displayText)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                if let error = progress.error {
                    Text(error)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if !progress.isComplete {
                    Text("Please don't close the app")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

            // Progress bar
            if !progress.isComplete {
                progressBar
            }

            Spacer()

            // Complete button (only shown when done)
            if progress.isComplete {
                Button {
                    onComplete()
                } label: {
                    Text("Done")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.xl)
            }
        }
        .background(HeirloomColors.appBackground)
        .onChange(of: progress.isComplete) { _, isComplete in
            if isComplete {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showCheckmark = true
                }
            }
        }
    }

    // MARK: - Progress Icon

    @ViewBuilder
    private var progressIcon: some View {
        ZStack {
            if progress.isComplete {
                // Checkmark animation
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0)
            } else if progress.error != nil {
                // Error icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.red)
            } else {
                // Progress spinner
                ZStack {
                    Circle()
                        .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: progress.percentComplete)
                        .stroke(HeirloomColors.tomato, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress.percentComplete)

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: HeirloomColors.tomato))
                        .scaleEffect(1.5)
                }
            }
        }
        .frame(width: 100, height: 100)
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            // Step indicators
            HStack(spacing: HeirloomSpacing.xs) {
                ForEach(DeletionProgress.DeletionStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(stepColor(for: step))
                        .frame(width: 8, height: 8)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HeirloomColors.warmGray.opacity(0.3))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(HeirloomColors.tomato)
                        .frame(width: geometry.size.width * progress.percentComplete, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progress.percentComplete)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, HeirloomSpacing.xl)
    }

    // MARK: - Helpers

    private func stepColor(for step: DeletionProgress.DeletionStep) -> Color {
        let currentIndex = progress.currentStep.stepIndex
        let stepIndex = step.stepIndex

        if stepIndex < currentIndex {
            return .green
        } else if stepIndex == currentIndex {
            return HeirloomColors.tomato
        } else {
            return HeirloomColors.warmGray.opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview("In Progress") {
    DeletionProgressView(
        progress: DeletionProgress(currentStep: .cloudRecipes),
        onComplete: {}
    )
}

#Preview("Complete") {
    DeletionProgressView(
        progress: DeletionProgress(currentStep: .complete, isComplete: true),
        onComplete: {}
    )
}

#Preview("Error") {
    DeletionProgressView(
        progress: DeletionProgress(currentStep: .cloudRecipes, error: "Network error occurred"),
        onComplete: {}
    )
}
