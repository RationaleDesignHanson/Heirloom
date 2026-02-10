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
    @State private var audioLevel: CGFloat = 0
    @State private var audioLevelCancellable: AnyCancellable?

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

    // MARK: - View State

    private enum ViewState {
        case idle
        case recording
        case done
    }

    private var viewState: ViewState {
        if isRecording {
            return .recording
        } else if !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .done
        } else {
            return .idle
        }
    }

    private var micState: AudioReactiveMicButton.MicState {
        switch viewState {
        case .idle: return .idle
        case .recording: return .recording
        case .done: return .done
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                // Transcription area — hero section
                TranscriptionAreaView(
                    text: transcribedText,
                    isRecording: isRecording
                )
                .padding(.horizontal)

                // Compact permission/error bar
                if !dictationService.isAvailable {
                    permissionBar
                        .padding(.horizontal)
                        .padding(.top, 8)
                } else if let errorMessage = errorMessage {
                    errorBar(errorMessage)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // Bottom section: timer + mic button
                bottomSection
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 4)
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
                            .foregroundStyle(
                                viewState == .done
                                    ? HeirloomColors.tomato
                                    : Color.secondary
                            )
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
                setupAudioLevelPublisher()
                Log.info("🎙️ ReadRecipeView.onAppear — isAvailable=\(dictationService.isAvailable)", category: .general)
                Task {
                    Log.info("🎙️ Requesting authorization...", category: .general)
                    let result = await dictationService.requestAuthorization()
                    Log.info("🎙️ Authorization result: \(result)", category: .general)
                }
            }
            .onDisappear {
                audioLevelCancellable?.cancel()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text(headerTitle)
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            if viewState == .idle {
                Text("Read your recipe aloud")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.warmGray)
            }
        }
    }

    private var headerTitle: String {
        switch viewState {
        case .idle: return "Ready to Record"
        case .recording: return "Listening..."
        case .done: return "Recording Complete"
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 4) {
            // Duration timer (recording only)
            if viewState == .recording {
                Text(formatDuration(recordingDuration))
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.tomato)
                    .transition(.opacity)
            }

            AudioReactiveMicButton(
                state: micState,
                audioLevel: audioLevel,
                isAvailable: dictationService.isAvailable
            ) {
                if isRecording {
                    stopRecording()
                } else if viewState == .idle {
                    startRecording()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewState == .recording)
    }

    // MARK: - Compact Permission/Error Bars

    private var permissionBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(HeirloomColors.tomato)

            Text("Permissions required")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.tomato)

            Spacer()

            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Open Settings")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(HeirloomColors.tomato)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(HeirloomColors.tomato.opacity(0.08))
        )
    }

    private func errorBar(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(HeirloomColors.tomato)

            Text(message)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.tomato)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(HeirloomColors.tomato.opacity(0.08))
        )
    }

    // MARK: - Recording

    private func startRecording() {
        errorMessage = nil

        Task {
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

    // MARK: - Subscriptions

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

    private func setupAudioLevelPublisher() {
        audioLevelCancellable = dictationService.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] level in
                audioLevel = CGFloat(level)
            }
    }

    // MARK: - Processing

    private func startBackgroundProcessing() {
        let transcription = transcribedText

        dismiss()

        Task { @MainActor in
            do {
                try await generationService.generateFromVoice(
                    transcript: transcription,
                    context: modelContext
                )
            } catch {
                toastManager.error(title: "Failed to start voice generation")
                Log.error("Failed to create voice generation job", category: .general, error: error)
            }
        }
    }
}
