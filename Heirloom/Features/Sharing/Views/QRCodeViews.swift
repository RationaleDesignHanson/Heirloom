import SwiftUI
import AVFoundation

// MARK: - QR Code Display Sheet

/// Sheet displaying QR code for recipe sharing
struct QRCodeShareSheet: View {
    let shareURL: URL
    let recipeTitle: String
    @Environment(\.dismiss) private var dismiss

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    @State private var qrImage: UIImage?
    @State private var showingSaveConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Header
                    VStack(spacing: HeirloomSpacing.sm) {
                        Text("Share via QR Code")
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text(recipeTitle)
                            .font(HeirloomFonts.subheadline)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    // QR Code
                    if let image = qrImage {
                        qrCodeDisplay(image)
                    } else {
                        ProgressView()
                            .frame(width: 300, height: 300)
                    }

                    // Instructions
                    instructionsSection

                    // Actions
                    actionsSection
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await generateQRCode()
            }
            .alert("QR Code Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") {}
            } message: {
                Text("QR code has been saved to your Photos library")
            }
        }
    }

    // MARK: - QR Code Display

    @ViewBuilder
    private func qrCodeDisplay(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 300, height: 300)
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("How to Use")
                .font(HeirloomFonts.headline)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                instructionItem("Have the recipient open Heirloom")
                instructionItem("Tap the scan icon or share button")
                instructionItem("Point their camera at this QR code")
                instructionItem("They can now import the recipe!")
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func instructionItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Text("•")
                .foregroundStyle(HeirloomColors.tomato)
            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            // Save to Photos
            Button {
                Task {
                    await saveQRCode()
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save to Photos")
                }
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.buttonTextLight)
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.tomato)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Share as Image
            if let image = qrImage {
                ShareLink(item: Image(uiImage: image), preview: SharePreview("Recipe QR Code", image: Image(uiImage: image))) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share QR Code")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.tomato)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.cream)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func generateQRCode() async {
        let image = QRCodeService.shared.generateBrandedQRCode(from: shareURL)
        await MainActor.run {
            qrImage = image
        }

        // Track analytics
        analytics.track(event: .recipeShared, properties: [
            "method": "qr_code",
            "recipe_title": recipeTitle
        ])
    }

    private func saveQRCode() async {
        guard let image = qrImage else { return }

        do {
            try await QRCodeService.shared.saveQRCodeToPhotos(image)
            showingSaveConfirmation = true

            toastManager.success(
                title: "Saved",
                message: "QR code saved to Photos"
            )
        } catch {
            toastManager.error(
                title: "Failed to Save",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - QR Code Scanner View

/// Scanner view for importing recipes via QR code
struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = QRCodeScannerViewModel()

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    let onScanSuccess: (URL) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                QRCodeCameraPreview(scanner: scanner)
                    .ignoresSafeArea()

                // Scanning reticle overlay
                scannerOverlay

                // Instructions
                VStack {
                    Spacer()

                    instructionsCard
                        .padding(HeirloomSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Scan QR Code")
                        .font(HeirloomFonts.headline)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.black.opacity(0.5), for: .navigationBar)
            .onAppear {
                scanner.startScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
            .onChange(of: scanner.scannedURL) { _, newURL in
                if let url = newURL {
                    handleScannedURL(url)
                }
            }
        }
    }

    // MARK: - Scanner Overlay

    private var scannerOverlay: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white, lineWidth: 3)
            .frame(width: 250, height: 250)
            .overlay(
                // Corner brackets
                ZStack {
                    ForEach(0..<4) { i in
                        cornerBracket(index: i)
                    }
                }
            )
    }

    @ViewBuilder
    private func cornerBracket(index: Int) -> some View {
        let size: CGFloat = 30
        let offset: CGFloat = 125

        Path { path in
            switch index {
            case 0: // Top-left
                path.move(to: CGPoint(x: -offset, y: -offset + size))
                path.addLine(to: CGPoint(x: -offset, y: -offset))
                path.addLine(to: CGPoint(x: -offset + size, y: -offset))
            case 1: // Top-right
                path.move(to: CGPoint(x: offset - size, y: -offset))
                path.addLine(to: CGPoint(x: offset, y: -offset))
                path.addLine(to: CGPoint(x: offset, y: -offset + size))
            case 2: // Bottom-left
                path.move(to: CGPoint(x: -offset, y: offset - size))
                path.addLine(to: CGPoint(x: -offset, y: offset))
                path.addLine(to: CGPoint(x: -offset + size, y: offset))
            case 3: // Bottom-right
                path.move(to: CGPoint(x: offset - size, y: offset))
                path.addLine(to: CGPoint(x: offset, y: offset))
                path.addLine(to: CGPoint(x: offset, y: offset - size))
            default:
                break
            }
        }
        .stroke(HeirloomColors.tomato, lineWidth: 4)
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 24))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Position QR code within the frame")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.buttonTextLight)
        }
        .padding(HeirloomSpacing.md)
        .background(.black.opacity(0.7))
        .cornerRadius(12)
    }

    // MARK: - Handle Scanned URL

    private func handleScannedURL(_ url: URL) {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Dismiss and callback
        dismiss()
        onScanSuccess(url)

        // Track analytics
        analytics.track(event: .recipeShared, properties: [
            "method": "qr_scan_received",
            "url": url.absoluteString
        ])
    }
}

// MARK: - Camera Preview

struct QRCodeCameraPreview: UIViewRepresentable {
    @ObservedObject var scanner: QRCodeScannerViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: scanner.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Scanner View Model

@MainActor
class QRCodeScannerViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedURL: URL?

    let session = AVCaptureSession()
    private var isScanning = false

    func startScanning() {
        guard !isScanning else { return }

        Task {
            await setupCaptureSession()
            session.startRunning()
            isScanning = true
        }
    }

    func stopScanning() {
        session.stopRunning()
        isScanning = false
    }

    private func setupCaptureSession() async {
        guard let device = AVCaptureDevice.default(for: .video) else {
            Log.error("No camera available for QR scanning", category: .general)
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            session.addOutput(output)

            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]

        } catch {
            Log.error("Failed to setup camera for QR scanning", category: .general, metadata: ["error": error.localizedDescription])
        }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        // Validate and set URL
        Task { @MainActor in
            if let url = QRCodeService.shared.validateQRCodeData(stringValue) {
                scannedURL = url
                stopScanning()
            }
        }
    }
}

// MARK: - Previews

#Preview("QR Display") {
    QRCodeShareSheet(
        shareURL: URL(string: "heirloom://share/test123")!,
        recipeTitle: "Grandma's Chocolate Chip Cookies"
    )
}

#Preview("QR Scanner") {
    QRCodeScannerView { url in
        Log.debug("QR code scanned in preview", category: .general, metadata: ["url": url.absoluteString])
    }
}
