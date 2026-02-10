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
    @State private var errorMessage: String?
    @State private var showingPermissionAlert: Bool = false
    @State private var cancellables = Set<AnyCancellable>()

    private let dictationService: VoiceDictationServiceProtocol
    private var generationService: RecipeGenerationService {
        ServiceContainer.shared.resolve(RecipeGenerationService.self)
    }
    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    init(dictationService: VoiceDictationServiceProtocol) {
        self.dictationService = dictationService
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
                        if dictationService.isAvailable {
                            Text("Tap the microphone and dictate your recipe")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Please enable permissions below to record")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
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
                                .fill(isRecording ? Color.red : (dictationService.isAvailable ? Color.accentColor : Color.gray.opacity(0.5)))
                                .frame(width: 120, height: 120)

                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white)
                        }
                    }
                    .disabled(!dictationService.isAvailable && !isRecording)
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

                // Error message or permissions prompt
                if !dictationService.isAvailable {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("Microphone or speech recognition permission not granted.")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.red)
                        }

                        Button {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        } label: {
                            Label("Open Settings", systemImage: "gear")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(HeirloomColors.tomato)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                } else if let errorMessage = errorMessage {
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
                        startBackgroundProcessing()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                    .disabled(transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRecording)
                }
            }
            .alert("Permissions Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Heirloom needs microphone and speech recognition permissions to record recipes.\n\nPlease enable:\n• Microphone\n• Speech Recognition\n\nTap 'Open Settings' to go to Heirloom's settings page.")
            }
            .onAppear {
                setupTranscriptionPublisher()
                // Request permissions on appear so OS prompts fire immediately
                Log.info("🎙️ ReadRecipeView.onAppear — isAvailable=\(dictationService.isAvailable)", category: .general)
                Task {
                    Log.info("🎙️ Requesting authorization...", category: .general)
                    let result = await dictationService.requestAuthorization()
                    Log.info("🎙️ Authorization result: \(result)", category: .general)
                }
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

    private func startBackgroundProcessing() {
        let transcription = transcribedText

        // Dismiss immediately (cookbook scan pattern)
        dismiss()

        Task { @MainActor in
            do {
                // Start voice generation (shows banner automatically)
                try await generationService.generateFromVoice(
                    transcript: transcription,
                    context: modelContext
                )

                // Progress UI shows automatically via bottom banner

            } catch {
                toastManager.error(title: "Failed to start voice generation")
                Log.error("Failed to create voice generation job", category: .general, error: error)
            }
        }
    }
}
