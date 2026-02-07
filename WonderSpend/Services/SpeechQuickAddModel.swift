//
//  SpeechQuickAddModel.swift
//  WonderSpend
//

import AVFoundation
import Combine
import Speech

@MainActor
final class SpeechQuickAddModel: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private var localeIdentifier: String
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
    }

    func updateLocale(identifier: String) {
        localeIdentifier = identifier
    }

    func start() async {
        guard !isRecording else { return }
        transcript = ""
        errorMessage = nil

        do {
            try await ensurePermissions()
            try startTranscription()
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
            isRecording = false
        }
    }

    func stop() async {
        guard isRecording else { return }
        isRecording = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func ensurePermissions() async throws {
        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            throw SpeechQuickAddError.permissionDenied
        }

        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            throw SpeechQuickAddError.microphoneDenied
        }
    }

    private func startTranscription() throws {
        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechQuickAddError.unsupportedLocale
        }
        speechRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
            }
            if error != nil || result?.isFinal == true {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest?.endAudio()
            }
        }

        try AVAudioSession.sharedInstance().setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker]
        )
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

enum SpeechQuickAddError: LocalizedError {
    case permissionDenied
    case microphoneDenied
    case unsupportedLocale

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission is required."
        case .microphoneDenied:
            return "Microphone permission is required."
        case .unsupportedLocale:
            return "This language isn’t supported for speech recognition."
        }
    }
}
