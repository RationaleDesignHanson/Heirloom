//
//  VideoConfirmationSheet.swift
//  Heirloom
//
//  Confirmation sheet for video jobs that completed analysis and need user approval
//

import SwiftUI
import SwiftData

struct VideoConfirmationSheet: View {
    let job: VideoProcessingJob
    let onConfirm: (String?) async throws -> Void  // dishNameHint
    let onCancel: () -> Void

    @State private var dishNameHint: String = ""
    @State private var isConfirming = false
    @State private var errorMessage: String?

    private var isASMR: Bool {
        job.analyzedModeName == "ASMR" || job.videoType == .asmr
    }

    private var creditCost: Int {
        job.analyzedCreditCost ?? (isASMR ? 5 : 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Mode icon
                    Image(systemName: isASMR ? "eye.circle.fill" : "waveform.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 24)

                    Text("\(job.analyzedModeName ?? "Video") Mode")
                        .font(.title2.bold())

                    // Credit cost display
                    GroupBox {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "creditcard")
                                    .foregroundColor(.green)
                                Text("Cost: \(creditCost) credit\(creditCost == 1 ? "" : "s")")
                                    .font(.headline)
                                Spacer()
                            }

                            if let reasoning = job.analysisReasoning {
                                Divider()
                                Text(reasoning)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal)

                    // ASMR mode: Show thumbnail and dish name hint field
                    if isASMR {
                        // Show video thumbnail so user can identify the dish
                        if let thumbnailData = job.thumbnailData,
                           let uiImage = UIImage(data: thumbnailData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        }

                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("What dish is this? (optional)", systemImage: "lightbulb")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)

                                TextField("e.g., Chocolate chip cookies, Beef stir fry", text: $dishNameHint, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...3)
                                    .submitLabel(.done)

                                Text("Providing the dish name helps our AI better understand and extract the recipe from visual content.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        // Foreground warning for ASMR processing
                        HStack(spacing: 8) {
                            Image(systemName: "iphone.circle")
                                .foregroundColor(.orange)
                            Text("Keep the app open during processing. Switching apps may interrupt the AI analysis.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // Confirm button
                    Button {
                        confirmImport()
                    } label: {
                        HStack {
                            if isConfirming {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text("Import for \(creditCost) Credit\(creditCost == 1 ? "" : "s")")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .disabled(isConfirming)

                    // Cancel button
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .disabled(isConfirming)
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Confirm Import")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func confirmImport() {
        isConfirming = true
        errorMessage = nil

        Task {
            do {
                try await onConfirm(isASMR && !dishNameHint.isEmpty ? dishNameHint : nil)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isConfirming = false
                }
            }
        }
    }
}
