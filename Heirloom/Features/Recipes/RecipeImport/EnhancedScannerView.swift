import SwiftUI
import AVFoundation

/// Enhanced camera scanner for recipe cards with real-time quality feedback
struct EnhancedScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var showReviewSheet = false
    @State private var ocrResult: EnhancedOCRService.OCRResult?
    @State private var parsedRecipe: RecipeStructureParser.ParsedRecipe?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera Preview
                if capturedImage == nil {
                    cameraPreview
                } else {
                    capturedImageView
                }

                // Quality Overlay (only when camera is active)
                if capturedImage == nil && !isProcessing {
                    qualityOverlay
                }

                // Processing Overlay
                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("Scan Recipe Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showReviewSheet) {
                if let ocrResult = ocrResult, let parsedRecipe = parsedRecipe {
                    OCRReviewView(
                        ocrResult: ocrResult,
                        parsedRecipe: parsedRecipe,
                        originalImage: capturedImage
                    )
                }
            }
            .alert("Scan Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                cameraManager.checkPermissions()
            }
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Capture Guidance
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("Position recipe card in frame")
                        .font(HeirloomFonts.subheadline)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4)

                    Text("Hold steady for best results")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
                .padding(.bottom, HeirloomSpacing.xl)

                // Capture Button
                Button {
                    captureImage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 70, height: 70)

                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 85, height: 85)
                    }
                }
                .disabled(isProcessing)
                .padding(.bottom, HeirloomSpacing.xxl)
            }
        }
    }

    // MARK: - Quality Overlay

    private var qualityOverlay: some View {
        VStack {
            // Quality Indicator at Top
            if let assessment = cameraManager.currentQualityAssessment {
                HStack(spacing: HeirloomSpacing.sm) {
                    Image(systemName: assessment.icon)
                        .foregroundStyle(colorForQuality(assessment))

                    Text(assessment.qualityDescription)
                        .font(HeirloomFonts.subheadline)
                        .foregroundStyle(.white)

                    Text(assessment.scorePercentage)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.vertical, HeirloomSpacing.sm)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.6))
                )
                .shadow(color: .black.opacity(0.3), radius: 8)
                .padding(.top, HeirloomSpacing.lg)
            }

            Spacer()

            // Recommendations at Bottom
            if let assessment = cameraManager.currentQualityAssessment,
               !assessment.recommendations.isEmpty,
               !assessment.isGoodQuality {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    ForEach(assessment.recommendations, id: \.self) { recommendation in
                        HStack(spacing: HeirloomSpacing.xs) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)

                            Text(recommendation)
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(HeirloomSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.7))
                )
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.bottom, 140)  // Above capture button
            }
        }
    }

    // MARK: - Captured Image View

    private var capturedImageView: some View {
        VStack(spacing: 0) {
            // Image Preview
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }

            // Action Buttons
            HStack(spacing: HeirloomSpacing.lg) {
                Button {
                    retakePhoto()
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HeirloomSpacing.md)
                        .background(HeirloomColors.warmGray.opacity(0.2))
                        .cornerRadius(12)
                }

                Button {
                    processImage()
                } label: {
                    Label("Process", systemImage: "wand.and.stars")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HeirloomSpacing.md)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .disabled(isProcessing)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.appBackground)
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: HeirloomSpacing.lg) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)

                Text("Processing recipe card...")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(.white)

                Text("Enhancing image and recognizing text")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(HeirloomSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.8))
            )
        }
    }

    // MARK: - Actions

    private func captureImage() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        cameraManager.capturePhoto { image in
            capturedImage = image
        }
    }

    private func retakePhoto() {
        capturedImage = nil
        ocrResult = nil
        parsedRecipe = nil
        cameraManager.startSession()
    }

    private func processImage() {
        guard let image = capturedImage else { return }

        isProcessing = true

        Task {
            do {
                // Step 1: Preprocess image
                print("🎨 Step 1: Preprocessing image...")
                let preprocessed = try await ImagePreprocessor.shared.preprocess(image)

                // Step 2: Perform OCR
                print("🔍 Step 2: Performing OCR...")
                let ocr = try await EnhancedOCRService.shared.recognizeText(from: preprocessed)

                // Step 3: Parse recipe structure
                print("📋 Step 3: Parsing recipe structure...")
                let parsed = await RecipeStructureParser.shared.parse(ocr.recognizedText)

                await MainActor.run {
                    ocrResult = ocr
                    parsedRecipe = parsed
                    isProcessing = false

                    // Show review sheet
                    showReviewSheet = true

                    // Success feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    print("✅ Processing complete!")
                    print("   OCR Confidence: \(ocr.confidencePercentage)")
                    print("   Parse Confidence: \(parsed.confidencePercentage)")
                    print("   Detected: \(parsed.summary)")
                }

            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription

                    // Error feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    print("❌ Processing failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func colorForQuality(_ assessment: ImagePreprocessor.ImageQualityAssessment) -> Color {
        if assessment.overallScore >= 0.9 {
            return .green
        } else if assessment.overallScore >= 0.7 {
            return .blue
        } else if assessment.overallScore >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var currentQualityAssessment: ImagePreprocessor.ImageQualityAssessment?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoCaptureCompletion: ((UIImage) -> Void)?

    // Quality assessment timer
    private var qualityTimer: Timer?
    private var lastFrame: UIImage?

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }

    func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        photoOutput = output
        captureSession = session

        startSession()
        startQualityMonitoring()
    }

    func startSession() {
        Task {
            captureSession?.startRunning()
        }
    }

    func stopSession() {
        captureSession?.stopRunning()
        stopQualityMonitoring()
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        photoCaptureCompletion = completion

        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }

        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
        }

        return previewLayer
    }

    // MARK: - Quality Monitoring

    private func startQualityMonitoring() {
        // For now, simplified - in production you'd grab frames from video output
        // and analyze them in real-time
        qualityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Placeholder: Would analyze current camera frame
            // For demo, create a mock assessment
            Task { @MainActor in
                self?.updateQualityAssessment()
            }
        }
    }

    private func stopQualityMonitoring() {
        qualityTimer?.invalidate()
        qualityTimer = nil
    }

    private func updateQualityAssessment() {
        // Simplified for now - would analyze actual camera frame
        // Mock a "good" quality for demonstration
        currentQualityAssessment = ImagePreprocessor.ImageQualityAssessment(
            overallScore: 0.85,
            brightness: .good,
            sharpness: .good,
            contrast: .good,
            recommendations: []
        )
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }

        Task { @MainActor in
            photoCaptureCompletion?(image)
            stopSession()
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let previewLayer = cameraManager.getPreviewLayer() {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.getPreviewLayer() {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedScannerView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
