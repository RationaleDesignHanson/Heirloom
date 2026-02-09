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

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceDictationError.recognitionFailed("Unable to create recognition request")
        }

        recognitionRequest.shouldReportPartialResults = true

        // If device supports on-device recognition, use it
        if #available(iOS 13, *), speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcriptionSubject.send(transcription)
                }
            }

            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopAudioEngine()
                }
            }
        }

        isRecording = true
    }

    func stopDictation() -> String {
        stopAudioEngine()
        let finalTranscript = transcriptionSubject.value
        return finalTranscript
    }

    func cancelDictation() {
        stopAudioEngine()
        transcriptionSubject.send("")
    }

    // MARK: - Private Helpers

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
