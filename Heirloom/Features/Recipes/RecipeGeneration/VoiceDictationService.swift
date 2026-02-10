//
//  VoiceDictationService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import Foundation
import Speech
import Combine

/// Errors that can occur during voice dictation
enum VoiceDictationError: LocalizedError {
    case notAuthorized
    case notAvailable
    case recognitionFailed(String)
    case alreadyRecording

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone or speech recognition permission not granted. Please enable in Settings."
        case .notAvailable:
            return "Speech recognition is not available on this device."
        case .recognitionFailed(let message):
            return "Speech recognition failed: \(message)"
        case .alreadyRecording:
            return "Recording is already in progress."
        }
    }
}

/// Protocol for voice dictation service
@MainActor
protocol VoiceDictationServiceProtocol {
    /// Publisher for real-time transcription updates
    var transcriptionPublisher: AnyPublisher<String, Never> { get }

    /// Check if speech recognition is available
    var isAvailable: Bool { get }

    /// Request authorization for speech recognition and microphone
    func requestAuthorization() async -> Bool

    /// Start recording and transcribing
    func startDictation() async throws

    /// Stop recording and return final transcript
    func stopDictation() -> String

    /// Cancel ongoing dictation
    func cancelDictation()
}

/// Service for voice dictation using SFSpeechRecognizer
@MainActor
class VoiceDictationService: VoiceDictationServiceProtocol {

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private let transcriptionSubject = CurrentValueSubject<String, Never>("")
    var transcriptionPublisher: AnyPublisher<String, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    private var isRecording = false
    /// Accumulated transcript from completed recognition segments
    private var accumulatedTranscript = ""
    /// Current partial transcript from the active recognition task
    private var currentSegmentTranscript = ""

    // MARK: - Initialization

    init() {
        // Use device locale, fallback to English
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        Log.info("🎙️ requestAuthorization() called", category: .general)
        Log.info("🎙️ Current speech status: \(SFSpeechRecognizer.authorizationStatus().rawValue)", category: .general)

        // Request speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        Log.info("🎙️ Speech auth result: \(speechStatus.rawValue) (0=notDetermined, 1=denied, 2=restricted, 3=authorized)", category: .general)

        guard speechStatus == .authorized else {
            return false
        }

        // Request microphone authorization
        let micStatus = await AVAudioApplication.requestRecordPermission()
        Log.info("🎙️ Mic auth result: \(micStatus)", category: .general)
        return micStatus
    }

    // MARK: - Dictation

    func startDictation() async throws {
        // Check if already recording
        guard !isRecording else {
            throw VoiceDictationError.alreadyRecording
        }

        // Check availability
        guard isAvailable else {
            throw VoiceDictationError.notAvailable
        }

        // Check authorization
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw VoiceDictationError.notAuthorized
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Reset transcript state
        accumulatedTranscript = ""
        currentSegmentTranscript = ""
        transcriptionSubject.send("")

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Configure audio engine — install tap once, it feeds whatever recognitionRequest is current
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true

        // Start first recognition task
        startRecognitionTask()
    }

    func stopDictation() -> String {
        stopAudioEngine()
        // Combine accumulated segments with any current partial
        let finalTranscript = buildFullTranscript()
        accumulatedTranscript = ""
        currentSegmentTranscript = ""
        return finalTranscript
    }

    func cancelDictation() {
        stopAudioEngine()
        accumulatedTranscript = ""
        currentSegmentTranscript = ""
        transcriptionSubject.send("")
    }

    // MARK: - Private Helpers

    /// Start (or restart) a recognition task on the running audio engine.
    /// Called initially and again each time the recognizer finalizes a segment (e.g. after silence).
    private func startRecognitionTask() {
        // End previous request/task without stopping the audio engine
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Create a fresh recognition request — the existing tap feeds recognitionRequest via weak self
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13, *), speechRecognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        self.recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let segmentText = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.currentSegmentTranscript = segmentText
                    self.transcriptionSubject.send(self.buildFullTranscript())
                }

                // When the recognizer finalizes (silence/time limit), save and chain a new task
                if result.isFinal {
                    Task { @MainActor in
                        // Accumulate the finalized segment
                        if !segmentText.isEmpty {
                            if self.accumulatedTranscript.isEmpty {
                                self.accumulatedTranscript = segmentText
                            } else {
                                self.accumulatedTranscript += " " + segmentText
                            }
                        }
                        self.currentSegmentTranscript = ""

                        // Chain a new recognition task if still recording
                        if self.isRecording {
                            Log.info("🎙️ Recognition segment finalized, chaining new task", category: .general)
                            self.startRecognitionTask()
                        }
                    }
                }
            }

            // Only stop on actual errors (not on isFinal)
            if let error = error {
                let nsError = error as NSError
                // Error code 216 = "request was canceled" (happens during normal chaining) — ignore it
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                    return
                }
                Log.warning("🎙️ Recognition error: \(error.localizedDescription)", category: .general)
                Task { @MainActor in
                    // Don't stop for transient errors if we still have a good transcript
                    if self.isRecording && !self.buildFullTranscript().isEmpty {
                        Log.info("🎙️ Attempting to recover from recognition error", category: .general)
                        self.startRecognitionTask()
                    }
                }
            }
        }
    }

    /// Build the full transcript from accumulated segments + current partial
    private func buildFullTranscript() -> String {
        if currentSegmentTranscript.isEmpty {
            return accumulatedTranscript
        }
        if accumulatedTranscript.isEmpty {
            return currentSegmentTranscript
        }
        return accumulatedTranscript + " " + currentSegmentTranscript
    }

    private func stopAudioEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
}
