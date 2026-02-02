//
//  ReadRecipeView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import SwiftUI
import SwiftData
import Combine

/// Voice recording view for dictating recipes
struct ReadRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isRecording: Bool = false
    @State private var transcribedText: String = ""
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isProcessing: Bool = false
    @State private var structuredRecipe: Recipe?
    @State private var errorMessage: String?
    @State private var showingPermissionAlert: Bool = false
    @State private var cancellables = Set<AnyCancellable>()

    private let dictationService: VoiceDictationServiceProtocol
    private let recipeExtractor: AIRecipeExtractorProtocol
    private let imageGenerator: RecipeImageGeneratorProtocol

    init(
        dictationService: VoiceDictationServiceProtocol,
        recipeExtractor: AIRecipeExtractorProtocol,
        imageGenerator: RecipeImageGeneratorProtocol
    ) {
        self.dictationService = dictationService
        self.recipeExtractor = recipeExtractor
        self.imageGenerator = imageGenerator
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Title and instructions
                VStack(spacing: 8) {
                    Text(isRecording ? "Listening..." : "Ready to Record")
                        .font(HeirloomFonts.title2)
                        .fontWeight(.semibold)

                    if !isRecording && transcribedText.isEmpty {
                        Text("Tap the microphone and dictate your recipe")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 32)

                Spacer()

                // Microphone button
                VStack(spacing: 16) {
                    Button {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color.accentColor)
                                .frame(width: 120, height: 120)

                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white)
                        }
                    }
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)

                    // Recording duration
                    if isRecording {
                        Text(formatDuration(recordingDuration))
                            .font(HeirloomFonts.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                // Transcription display
                if !transcribedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)

                        ScrollView {
                            Text(transcribedText)
                                .font(HeirloomFonts.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.horizontal)
                }

                // Error message
                if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(.red)
                    }
                    .padding()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Read Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isRecording {
                            dictationService.cancelDictation()
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await processTranscription()
                        }
                    } label: {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("Done")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRecording || isProcessing)
                }
            }
            .navigationDestination(item: $structuredRecipe) { recipe in
                ReadRecipePreviewView(
                    recipe: recipe,
                    onSave: {
                        dismiss()
                    },
                    onRerecord: {
                        structuredRecipe = nil
                        transcribedText = ""
                        recordingDuration = 0
                    }
                )
            }
            .alert("Permissions Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings", role: nil) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Heirloom needs microphone and speech recognition permissions to record recipes. Please enable them in Settings.")
            }
            .onAppear {
                setupTranscriptionPublisher()
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        errorMessage = nil

        Task {
            // Request authorization if needed
            if !dictationService.isAvailable {
                let authorized = await dictationService.requestAuthorization()
                if !authorized {
                    showingPermissionAlert = true
                    return
                }
            }

            do {
                try await dictationService.startDictation()
                isRecording = true
                startTimer()
            } catch let error as VoiceDictationError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        stopTimer()
        transcribedText = dictationService.stopDictation()
    }

    // MARK: - Timer

    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingDuration += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Transcription

    private func setupTranscriptionPublisher() {
        dictationService.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] text in
                if isRecording {
                    transcribedText = text
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Processing

    @MainActor
    private func processTranscription() async {
        errorMessage = nil
        isProcessing = true

        defer {
            isProcessing = false
        }

        do {
            // Extract recipe structure from transcription
            let recipe = try await recipeExtractor.extract(from: transcribedText)

            // Mark as voice dictated
            recipe.voiceDictated = true

            // Insert into context
            modelContext.insert(recipe)

            // Generate image (non-blocking if fails)
            do {
                try await imageGenerator.generateAndSaveImage(for: recipe)
            } catch {
                Log.error("Failed to generate image for voice-dictated recipe", category: .general, metadata: [
                    "error": error.localizedDescription
                ])
                // Continue without image - user can add one later
            }

            // Show preview
            structuredRecipe = recipe

        } catch AIError.notConfigured(let provider) {
            errorMessage = "API key not configured for \(provider). Please add your API key in Settings."
        } catch AIError.quotaExceeded(let provider, let limit, _) {
            errorMessage = "Daily limit of \(String(describing: limit)) requests exceeded for \(provider). Please try again tomorrow or add your own API key in Settings."
        } catch {
            errorMessage = "Failed to process recipe: \(error.localizedDescription)"
        }
    }
}
