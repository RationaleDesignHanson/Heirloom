# ASMR Video Recipe Extraction: Detailed Prompt Engineering & Dedicated UI

## Part 1: Dedicated ASMR Video UI Flow

### Design Philosophy

The ASMR video extraction is a **premium feature** that costs 10-15x more than standard audio extraction. The UI should:
1. **Gate access** — require explicit opt-in, not automatic fallback
2. **Set expectations** — clearly communicate cost, time, and accuracy tradeoffs
3. **Feel premium** — distinct visual treatment that justifies the investment
4. **Minimize waste** — help users avoid processing videos that won't work well

---

### Entry Point: Separate from Standard Flow

Instead of automatic fallback, ASMR extraction should be a distinct option in the Add menu:

```swift
// AddRecipeMenuView.swift

struct AddRecipeMenuView: View {
    @State private var showStandardVideoImport = false
    @State private var showASMRVideoImport = false
    @State private var showManualEntry = false
    
    var body: some View {
        Menu {
            Button {
                showManualEntry = true
            } label: {
                Label("Manual Entry", systemImage: "square.and.pencil")
            }
            
            Button {
                showStandardVideoImport = true
            } label: {
                Label("From Video", systemImage: "video.badge.waveform")
            }
            
            Divider()
            
            // ASMR as distinct, clearly marked option
            Button {
                showASMRVideoImport = true
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("From Silent Video")
                        Text("For ASMR & videos without narration")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "eye.circle")
                }
            }
            
        } label: {
            Image(systemName: "plus")
        }
        .sheet(isPresented: $showStandardVideoImport) {
            StandardVideoImportView()
        }
        .sheet(isPresented: $showASMRVideoImport) {
            ASMRVideoImportView()
        }
    }
}
```

---

### ASMR Import Flow: Step-by-Step UI

#### Step 1: Feature Introduction (First-Time Only)

```swift
// ASMROnboardingView.swift

struct ASMROnboardingView: View {
    let onContinue: () -> Void
    let onCancel: () -> Void
    
    @AppStorage("hasSeenASMROnboarding") private var hasSeenOnboarding = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Hero illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)
            }
            
            VStack(spacing: 12) {
                Text("Visual Recipe Extraction")
                    .font(.title.bold())
                
                Text("Extract recipes from silent cooking videos using AI vision analysis")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // How it works
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "1.circle.fill",
                    color: .blue,
                    title: "Identifies the dish",
                    description: "AI recognizes what's being cooked from visual cues"
                )
                
                FeatureRow(
                    icon: "2.circle.fill",
                    color: .green,
                    title: "Detects ingredients",
                    description: "Scans frames to find visible ingredients"
                )
                
                FeatureRow(
                    icon: "3.circle.fill",
                    color: .orange,
                    title: "Infers seasonings",
                    description: "Uses culinary knowledge to fill gaps"
                )
                
                FeatureRow(
                    icon: "4.circle.fill",
                    color: .purple,
                    title: "Builds instructions",
                    description: "Analyzes techniques to create step-by-step guide"
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Important callouts
            VStack(spacing: 8) {
                CalloutRow(
                    icon: "clock",
                    text: "Takes 4-6 minutes to process"
                )
                CalloutRow(
                    icon: "target",
                    text: "70-85% typical accuracy — review recommended"
                )
                CalloutRow(
                    icon: "sparkles",
                    text: "Works best with clear, well-lit videos"
                )
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    hasSeenOnboarding = true
                    onContinue()
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Maybe Later", action: onCancel)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CalloutRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

#### Step 2: Video Selection with Suitability Check

```swift
// ASMRVideoSelectionView.swift

struct ASMRVideoSelectionView: View {
    @StateObject private var viewModel = ASMRVideoSelectionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Video preview area
                if let selectedVideo = viewModel.selectedVideo {
                    VideoPreviewCard(
                        video: selectedVideo,
                        suitabilityCheck: viewModel.suitabilityCheck
                    )
                } else {
                    VideoSelectionPlaceholder {
                        viewModel.showVideoPicker = true
                    }
                }
                
                // Suitability warnings (if video selected)
                if let check = viewModel.suitabilityCheck {
                    SuitabilityWarningsView(check: check)
                }
                
                // Tips for best results
                BestResultsTipsCard()
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    if viewModel.selectedVideo != nil {
                        Button {
                            viewModel.proceedToProcessing()
                        } label: {
                            HStack {
                                Text("Analyze Video")
                                if let duration = viewModel.estimatedDuration {
                                    Text("• \(duration)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canProceed)
                        
                        Button("Choose Different Video") {
                            viewModel.showVideoPicker = true
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .navigationTitle("Silent Video Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showVideoPicker) {
                VideoPickerView(selectedURL: $viewModel.selectedVideoURL)
            }
            .fullScreenCover(isPresented: $viewModel.showProcessing) {
                ASMRProcessingView(
                    videoURL: viewModel.selectedVideoURL!,
                    onComplete: { recipe in
                        viewModel.completedRecipe = recipe
                    }
                )
            }
        }
    }
}

struct VideoPreviewCard: View {
    let video: VideoMetadata
    let suitabilityCheck: VideoSuitabilityCheck?
    
    var body: some View {
        VStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: video.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fill)
                    .overlay {
                        ProgressView()
                    }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                // Duration badge
                Text(video.formattedDuration)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(8)
                , alignment: .bottomTrailing
            )
            
            // Video info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.filename)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label(video.formattedSize, systemImage: "doc")
                        Label(video.resolution, systemImage: "rectangle.arrowtriangle.2.outward")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Suitability indicator
                if let check = suitabilityCheck {
                    SuitabilityBadge(check: check)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SuitabilityBadge: View {
    let check: VideoSuitabilityCheck
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: check.overallSuitability.icon)
            Text(check.overallSuitability.label)
        }
        .font(.caption.bold())
        .foregroundStyle(check.overallSuitability.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(check.overallSuitability.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

struct SuitabilityWarningsView: View {
    let check: VideoSuitabilityCheck
    
    var body: some View {
        if !check.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(check.warnings, id: \.message) { warning in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: warning.severity.icon)
                            .foregroundStyle(warning.severity.color)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(warning.message)
                                .font(.caption)
                            if let suggestion = warning.suggestion {
                                Text(suggestion)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct BestResultsTipsCard: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.yellow)
                    Text("Tips for Best Results")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    TipRow(emoji: "✅", text: "Overhead or clear front-facing camera angle")
                    TipRow(emoji: "✅", text: "Good lighting with visible ingredients")
                    TipRow(emoji: "✅", text: "Shows the finished dish at the end")
                    TipRow(emoji: "✅", text: "Standard home cooking (not molecular gastronomy)")
                    
                    Divider()
                    
                    TipRow(emoji: "❌", text: "Fast-motion or heavily edited videos")
                    TipRow(emoji: "❌", text: "Dark or poorly lit kitchens")
                    TipRow(emoji: "❌", text: "Ingredients added off-screen")
                    TipRow(emoji: "❌", text: "Multiple recipes in one video")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TipRow: View {
    let emoji: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(emoji)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
```

#### Step 3: Video Suitability Analysis

```swift
// VideoSuitabilityChecker.swift

struct VideoSuitabilityCheck {
    let overallSuitability: Suitability
    let warnings: [SuitabilityWarning]
    let estimatedProcessingTime: TimeInterval
    let estimatedAccuracy: ClosedRange<Double>
    
    enum Suitability {
        case excellent
        case good
        case fair
        case poor
        
        var label: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor Fit"
            }
        }
        
        var icon: String {
            switch self {
            case .excellent: return "checkmark.circle.fill"
            case .good: return "checkmark.circle"
            case .fair: return "exclamationmark.circle"
            case .poor: return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
    }
}

struct SuitabilityWarning {
    let message: String
    let suggestion: String?
    let severity: Severity
    
    enum Severity {
        case info
        case warning
        case critical
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .critical: return "xmark.octagon"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
}

final class VideoSuitabilityChecker {
    
    func checkSuitability(for videoURL: URL) async throws -> VideoSuitabilityCheck {
        var warnings: [SuitabilityWarning] = []
        var suitabilityScore: Double = 100
        
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        // Check 1: Video duration
        if duration < 60 {
            warnings.append(SuitabilityWarning(
                message: "Very short video (\(Int(duration))s)",
                suggestion: "May not capture complete recipe",
                severity: .warning
            ))
            suitabilityScore -= 20
        } else if duration > 1800 { // 30 minutes
            warnings.append(SuitabilityWarning(
                message: "Long video (\(Int(duration/60)) min)",
                suggestion: "Processing will take longer. Consider trimming if possible.",
                severity: .info
            ))
            suitabilityScore -= 10
        }
        
        // Check 2: Resolution
        if let track = tracks.first {
            let size = try await track.load(.naturalSize)
            let resolution = min(size.width, size.height)
            
            if resolution < 480 {
                warnings.append(SuitabilityWarning(
                    message: "Low resolution video",
                    suggestion: "Ingredient detection may be less accurate",
                    severity: .warning
                ))
                suitabilityScore -= 25
            }
        }
        
        // Check 3: Frame rate (detect time-lapse)
        if let track = tracks.first {
            let frameRate = try await track.load(.nominalFrameRate)
            if frameRate < 15 {
                warnings.append(SuitabilityWarning(
                    message: "Low frame rate detected",
                    suggestion: "May be a time-lapse video which works less well",
                    severity: .warning
                ))
                suitabilityScore -= 15
            }
        }
        
        // Check 4: Sample frames for content analysis
        let sampleAnalysis = try await analyzeContentSamples(videoURL: videoURL, duration: duration)
        
        if !sampleAnalysis.appearsToBeFood {
            warnings.append(SuitabilityWarning(
                message: "Video may not contain cooking content",
                suggestion: "Visual analysis works best with cooking videos",
                severity: .critical
            ))
            suitabilityScore -= 40
        }
        
        if sampleAnalysis.hasTextOverlays {
            warnings.append(SuitabilityWarning(
                message: "Text overlays detected",
                suggestion: "Consider using standard video import which can extract text",
                severity: .info
            ))
        }
        
        if sampleAnalysis.hasPoorLighting {
            warnings.append(SuitabilityWarning(
                message: "Some frames appear dark",
                suggestion: "Lighting affects ingredient detection accuracy",
                severity: .warning
            ))
            suitabilityScore -= 15
        }
        
        // Determine overall suitability
        let overallSuitability: VideoSuitabilityCheck.Suitability
        switch suitabilityScore {
        case 80...100: overallSuitability = .excellent
        case 60..<80: overallSuitability = .good
        case 40..<60: overallSuitability = .fair
        default: overallSuitability = .poor
        }
        
        // Estimate processing time (base: 25 sec per minute of video)
        let baseTime = duration * 0.4 // ~25 sec per minute
        let estimatedTime = baseTime * (suitabilityScore < 60 ? 1.3 : 1.0) // Longer if quality issues
        
        // Estimate accuracy range
        let accuracyBase = suitabilityScore / 100 * 0.85
        let accuracyRange = max(0.5, accuracyBase - 0.1)...min(0.95, accuracyBase + 0.05)
        
        return VideoSuitabilityCheck(
            overallSuitability: overallSuitability,
            warnings: warnings,
            estimatedProcessingTime: estimatedTime,
            estimatedAccuracy: accuracyRange
        )
    }
    
    private func analyzeContentSamples(videoURL: URL, duration: TimeInterval) async throws -> ContentAnalysis {
        // Quick frame sampling for content pre-check
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 480) // Low res for speed
        
        // Sample 5 frames spread across video
        let sampleTimes = [0.1, 0.25, 0.5, 0.75, 0.9].map { 
            CMTime(seconds: duration * $0, preferredTimescale: 600) 
        }
        
        var frames: [CGImage] = []
        for time in sampleTimes {
            if let frame = try? generator.copyCGImage(at: time, actualTime: nil) {
                frames.append(frame)
            }
        }
        
        // Quick heuristic analysis (could use Claude Vision for deeper check)
        // For MVP, use simple brightness/color analysis
        var avgBrightness: Double = 0
        var hasKitchenColors = false
        
        for frame in frames {
            let brightness = calculateBrightness(frame)
            avgBrightness += brightness / Double(frames.count)
            
            // Check for typical kitchen/food colors (browns, greens, reds)
            if containsFoodColors(frame) {
                hasKitchenColors = true
            }
        }
        
        return ContentAnalysis(
            appearsToBeFood: hasKitchenColors,
            hasTextOverlays: false, // Would need OCR check
            hasPoorLighting: avgBrightness < 0.3
        )
    }
    
    private func calculateBrightness(_ image: CGImage) -> Double {
        // Simplified brightness calculation
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.5
        }
        
        var total: Double = 0
        let pixelCount = image.width * image.height
        let bytesPerPixel = image.bitsPerPixel / 8
        
        for i in stride(from: 0, to: min(pixelCount * bytesPerPixel, 10000), by: bytesPerPixel * 10) {
            let r = Double(bytes[i])
            let g = Double(bytes[i + 1])
            let b = Double(bytes[i + 2])
            total += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        }
        
        return total / Double(min(pixelCount / 10, 1000))
    }
    
    private func containsFoodColors(_ image: CGImage) -> Bool {
        // Simplified - would be more sophisticated in production
        return true
    }
}

struct ContentAnalysis {
    let appearsToBeFood: Bool
    let hasTextOverlays: Bool
    let hasPoorLighting: Bool
}
```

#### Step 4: Processing View (ASMR-Specific)

```swift
// ASMRProcessingView.swift

struct ASMRProcessingView: View {
    let videoURL: URL
    let onComplete: (ExtractedRecipe) -> Void
    
    @StateObject private var processor = ASMRVideoProcessor()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCancelConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress header
                ASMRProgressHeader(currentPass: processor.currentPass)
                    .padding(.bottom, 24)
                
                // Main content
                VStack(spacing: 32) {
                    // Animated visualization
                    ASMRProcessingAnimation(pass: processor.currentPass)
                        .frame(height: 200)
                    
                    // Pass information
                    VStack(spacing: 8) {
                        Text(processor.currentPass.title)
                            .font(.title2.bold())
                        
                        Text(processor.currentPass.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    
                    // Progress detail
                    if let progress = processor.passProgress {
                        VStack(spacing: 8) {
                            ProgressView(value: progress)
                                .tint(processor.currentPass.color)
                            
                            Text(processor.progressDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    // Live findings (shows what's been detected)
                    if !processor.liveFindings.isEmpty {
                        LiveFindingsCard(findings: processor.liveFindings)
                    }
                }
                
                Spacer()
                
                // Time estimate
                VStack(spacing: 4) {
                    if let remaining = processor.estimatedTimeRemaining {
                        Text("About \(remaining) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("You can close this screen — we'll notify you when done")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 8)
                
                // Cancel button
                Button("Cancel Processing") {
                    showCancelConfirmation = true
                }
                .foregroundStyle(.red)
                .padding(.bottom)
            }
            .padding()
            .navigationBarBackButtonHidden()
            .confirmationDialog(
                "Cancel Processing?",
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel Processing", role: .destructive) {
                    processor.cancel()
                    dismiss()
                }
                Button("Continue", role: .cancel) {}
            } message: {
                Text("Processing will stop and no recipe will be created. You can try again later.")
            }
            .task {
                await processor.process(videoURL: videoURL)
            }
            .onChange(of: processor.result) { result in
                if let recipe = result {
                    onComplete(recipe)
                }
            }
        }
    }
}

struct ASMRProgressHeader: View {
    let currentPass: ASMRProcessingPass
    
    var body: some View {
        VStack(spacing: 16) {
            // Pass indicators
            HStack(spacing: 4) {
                ForEach(ASMRProcessingPass.allCases, id: \.self) { pass in
                    PassIndicator(
                        pass: pass,
                        isActive: pass == currentPass,
                        isComplete: pass.rawValue < currentPass.rawValue
                    )
                }
            }
            
            // Overall progress
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * currentPass.overallProgress,
                            height: 4
                        )
                }
                .clipShape(Capsule())
            }
            .frame(height: 4)
        }
        .padding(.horizontal)
    }
}

struct PassIndicator: View {
    let pass: ASMRProcessingPass
    let isActive: Bool
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isComplete ? pass.color : (isActive ? pass.color.opacity(0.3) : Color(.systemGray5)))
                    .frame(width: 32, height: 32)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: pass.icon)
                        .font(.caption)
                        .foregroundStyle(isActive ? pass.color : .secondary)
                }
            }
            
            Text(pass.shortName)
                .font(.system(size: 9))
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LiveFindingsCard: View {
    let findings: [LiveFinding]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Found so far...")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(findings) { finding in
                    HStack(spacing: 4) {
                        Image(systemName: finding.icon)
                            .font(.caption2)
                        Text(finding.text)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(finding.color.opacity(0.15))
                    .foregroundStyle(finding.color)
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LiveFinding: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let color: Color
    let type: FindingType
    
    enum FindingType {
        case dish
        case ingredient
        case technique
    }
}

enum ASMRProcessingPass: Int, CaseIterable {
    case identifying = 0
    case detecting = 1
    case inferring = 2
    case analyzing = 3
    case validating = 4
    
    var title: String {
        switch self {
        case .identifying: return "Identifying Dish"
        case .detecting: return "Detecting Ingredients"
        case .inferring: return "Inferring Seasonings"
        case .analyzing: return "Analyzing Techniques"
        case .validating: return "Validating Recipe"
        }
    }
    
    var shortName: String {
        switch self {
        case .identifying: return "Dish"
        case .detecting: return "Ingredients"
        case .inferring: return "Seasonings"
        case .analyzing: return "Techniques"
        case .validating: return "Validate"
        }
    }
    
    var description: String {
        switch self {
        case .identifying: 
            return "Examining the video to understand what dish is being prepared"
        case .detecting: 
            return "Scanning frames to identify visible ingredients"
        case .inferring: 
            return "Using culinary knowledge to determine likely seasonings"
        case .analyzing: 
            return "Identifying cooking techniques and their sequence"
        case .validating: 
            return "Cross-checking findings and assembling the recipe"
        }
    }
    
    var icon: String {
        switch self {
        case .identifying: return "eye"
        case .detecting: return "carrot"
        case .inferring: return "sparkles"
        case .analyzing: return "flame"
        case .validating: return "checkmark.shield"
        }
    }
    
    var color: Color {
        switch self {
        case .identifying: return .blue
        case .detecting: return .green
        case .inferring: return .orange
        case .analyzing: return .red
        case .validating: return .purple
        }
    }
    
    var overallProgress: Double {
        Double(rawValue + 1) / Double(ASMRProcessingPass.allCases.count)
    }
}
```

#### Step 5: Enhanced Review (ASMR-Specific)

```swift
// ASMRRecipeReviewView.swift

struct ASMRRecipeReviewView: View {
    @Binding var recipe: ExtractedRecipe
    let metadata: VisionExtractionMetadata
    let frameProvider: FrameProvider
    
    let onSave: () -> Void
    let onDiscard: () -> Void
    
    @State private var activeSection: ReviewSection = .overview
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section tabs
                ReviewSectionPicker(selection: $activeSection)
                
                // Content
                TabView(selection: $activeSection) {
                    OverviewSection(recipe: recipe, metadata: metadata)
                        .tag(ReviewSection.overview)
                    
                    IngredientsSection(
                        ingredients: $recipe.ingredients,
                        frameProvider: frameProvider,
                        verificationNeeded: metadata.verificationNeeded
                    )
                    .tag(ReviewSection.ingredients)
                    
                    StepsSection(steps: $recipe.steps)
                        .tag(ReviewSection.steps)
                    
                    CompareSection(recipe: recipe)
                        .tag(ReviewSection.compare)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Bottom actions
                ReviewActionBar(
                    confidence: metadata.overallConfidence,
                    onSave: onSave,
                    onDiscard: onDiscard
                )
            }
            .navigationTitle("Review Recipe")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum ReviewSection: String, CaseIterable {
    case overview = "Overview"
    case ingredients = "Ingredients"
    case steps = "Steps"
    case compare = "Compare"
}

struct ReviewSectionPicker: View {
    @Binding var selection: ReviewSection
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(ReviewSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation { selection = section }
                    } label: {
                        Text(section.rawValue)
                            .font(.subheadline)
                            .fontWeight(selection == section ? .semibold : .regular)
                            .foregroundStyle(selection == section ? .primary : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .background(
                        selection == section ?
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                            .offset(y: 18)
                        : nil
                    )
                }
            }
        }
        .background(Color(.secondarySystemBackground))
    }
}

struct OverviewSection: View {
    let recipe: ExtractedRecipe
    let metadata: VisionExtractionMetadata
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Confidence card
                ConfidenceCard(confidence: metadata.overallConfidence)
                
                // Recipe summary
                VStack(alignment: .leading, spacing: 16) {
                    EditableField(
                        label: "Title",
                        value: .constant(recipe.title),
                        placeholder: "Recipe name"
                    )
                    
                    EditableField(
                        label: "Description",
                        value: .constant(recipe.description ?? ""),
                        placeholder: "Brief description",
                        axis: .vertical
                    )
                    
                    HStack {
                        InfoBadge(label: "Cuisine", value: recipe.cuisine ?? "Unknown")
                        InfoBadge(label: "Difficulty", value: recipe.difficulty ?? "Medium")
                    }
                    
                    HStack {
                        InfoBadge(label: "Prep", value: recipe.prepTime ?? "--")
                        InfoBadge(label: "Cook", value: recipe.cookTime ?? "--")
                        InfoBadge(label: "Servings", value: recipe.servings ?? "--")
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Warnings/notes
                if !metadata.validationNotes.isEmpty {
                    ValidationNotesCard(notes: metadata.validationNotes)
                }
                
                // Potential missing
                if !metadata.potentialMissing.isEmpty {
                    PotentialMissingCard(items: metadata.potentialMissing)
                }
            }
            .padding()
        }
    }
}

struct ConfidenceCard: View {
    let confidence: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Extraction Confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(confidence * 100))%")
                    .font(.title.bold())
                    .foregroundStyle(confidenceColor)
            }
            
            Spacer()
            
            CircularProgressView(progress: confidence, color: confidenceColor)
                .frame(width: 60, height: 60)
        }
        .padding()
        .background(confidenceColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.65..<0.8: return .orange
        default: return .red
        }
    }
}

struct IngredientsSection: View {
    @Binding var ingredients: [ExtractedIngredient]
    let frameProvider: FrameProvider
    let verificationNeeded: [String]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Needs verification section
                let needsVerification = ingredients.filter { 
                    verificationNeeded.contains($0.item) 
                }
                
                if !needsVerification.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Needs Verification")
                                .font(.headline)
                        }
                        
                        ForEach(needsVerification.indices, id: \.self) { index in
                            if let ingredientIndex = ingredients.firstIndex(where: { 
                                $0.id == needsVerification[index].id 
                            }) {
                                IngredientVerificationRow(
                                    ingredient: $ingredients[ingredientIndex],
                                    frameProvider: frameProvider
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // All ingredients list
                VStack(alignment: .leading, spacing: 12) {
                    Text("All Ingredients")
                        .font(.headline)
                    
                    ForEach($ingredients) { $ingredient in
                        IngredientEditRow(ingredient: $ingredient)
                    }
                    
                    Button {
                        ingredients.append(ExtractedIngredient.empty())
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}

struct IngredientVerificationRow: View {
    @Binding var ingredient: ExtractedIngredient
    let frameProvider: FrameProvider
    
    @State private var showFrames = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Ingredient info
            HStack {
                VStack(alignment: .leading) {
                    Text(ingredient.item)
                        .font(.subheadline.bold())
                    
                    HStack {
                        Text(ingredient.quantity ?? "?")
                        Text(ingredient.unit ?? "")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Source badge
                SourceBadge(source: ingredient.extractionSource ?? "visual")
            }
            
            // Frame references
            if let timestamps = ingredient.frameTimestamps, !timestamps.isEmpty {
                Button {
                    withAnimation { showFrames.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "photo.stack")
                        Text("View \(timestamps.count) reference frames")
                        Spacer()
                        Image(systemName: showFrames ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                if showFrames {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(timestamps, id: \.self) { timestamp in
                                FrameThumbnail(
                                    timestamp: timestamp,
                                    frameProvider: frameProvider
                                )
                            }
                        }
                    }
                }
            }
            
            // Actions
            HStack {
                Button {
                    ingredient.isVerified = true
                } label: {
                    Label("Confirm", systemImage: "checkmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                
                Button {
                    // Edit
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Button(role: .destructive) {
                    // Remove
                } label: {
                    Label("Remove", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SourceBadge: View {
    let source: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source == "visual" ? "eye" : "sparkles")
            Text(source == "visual" ? "Detected" : "Inferred")
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(source == "visual" ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
        .foregroundStyle(source == "visual" ? .blue : .purple)
        .clipShape(Capsule())
    }
}

struct CompareSection: View {
    let recipe: ExtractedRecipe
    
    @State private var similarRecipes: [SimilarRecipe] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Compare with Similar Recipes")
                    .font(.headline)
                
                Text("Check your extracted recipe against known versions to fill in gaps or verify accuracy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if isLoading {
                    ProgressView("Finding similar recipes...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if similarRecipes.isEmpty {
                    ContentUnavailableView(
                        "No Similar Recipes Found",
                        systemImage: "doc.questionmark",
                        description: Text("We couldn't find matching recipes to compare")
                    )
                } else {
                    ForEach(similarRecipes) { similar in
                        SimilarRecipeCard(
                            similar: similar,
                            extracted: recipe
                        )
                    }
                }
            }
            .padding()
        }
        .task {
            similarRecipes = await findSimilarRecipes(to: recipe)
            isLoading = false
        }
    }
    
    private func findSimilarRecipes(to recipe: ExtractedRecipe) async -> [SimilarRecipe] {
        // Search recipe database or use Claude to suggest similar recipes
        // For MVP, return empty
        return []
    }
}

struct SimilarRecipeCard: View {
    let similar: SimilarRecipe
    let extracted: ExtractedRecipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(similar.name)
                        .font(.subheadline.bold())
                    Text(similar.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(similar.matchScore * 100))% match")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            
            // Show differences
            if !similar.missingFromExtracted.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You might be missing:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(similar.missingFromExtracted, id: \.self) { item in
                            Text(item)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SimilarRecipe: Identifiable {
    let id = UUID()
    let name: String
    let source: String
    let matchScore: Double
    let missingFromExtracted: [String]
}
```

---

## Part 2: Detailed Prompt Engineering

### Core Principles

1. **Specificity over brevity** — detailed instructions produce more consistent results
2. **Examples are essential** — few-shot prompting dramatically improves accuracy
3. **Structured output** — JSON schema with validation rules
4. **Confidence scoring** — every claim should have an associated confidence level
5. **Negative examples** — explicitly state what NOT to do

---

### Pass 1: Dish Identification (Full Prompt)

```
<system>
You are a professional culinary expert with encyclopedic knowledge of world cuisines, dishes, and cooking techniques. Your task is to identify the dish being prepared in a cooking video by analyzing key frames.

## Your Expertise Includes:
- Recognition of dishes from 50+ world cuisines
- Understanding of regional variations (e.g., Tex-Mex vs Oaxacan Mexican)
- Knowledge of traditional vs modern interpretations
- Awareness of common home-cooking adaptations

## Analysis Approach:
1. Examine the FINAL frames first — the plated dish is the strongest signal
2. Note presentation style, colors, textures, and plating
3. Consider the cooking vessel and techniques visible
4. Look for cultural/regional cues (specific pans, garnishes, serving ware)
5. Cross-reference with initial frames showing raw ingredients

## Confidence Calibration:
- HIGH: Dish is clearly identifiable with distinctive characteristics
- MEDIUM: Dish is likely but could be a similar variant
- LOW: Best guess based on partial information

## Output Requirements:
- Respond ONLY with valid JSON
- No markdown, no explanations, no text outside the JSON
- All string values should be in English
- Use null for unknown values, never empty strings for optional fields
</system>

<user>
Analyze these video frames to identify the dish being prepared.

FRAME CONTEXT:
- Frames 1-3: Beginning of video (initial setup/ingredients)
- Frames 4-8: End of video (final plated dish)

The video has NO AUDIO — rely entirely on visual analysis.

## Required Analysis:

### 1. DISH IDENTIFICATION
Identify the specific dish. Be precise:
- ✓ "Chicken Tikka Masala" not "Indian Curry"
- ✓ "Beef Bulgogi" not "Korean BBQ"
- ✓ "Margherita Pizza" not "Pizza"

If the dish could be multiple things, provide alternatives ranked by likelihood.

### 2. CUISINE CLASSIFICATION
Determine the cuisine origin:
- Primary cuisine (e.g., "Mexican", "Japanese", "Italian")
- Regional variant if identifiable (e.g., "Sicilian", "Northern Thai", "Tex-Mex")

### 3. EXPECTED INGREDIENTS
Based on your culinary knowledge, list:
- Core ingredients: Essential, defining ingredients for this dish
- Typical seasonings: Spices, herbs, aromatics commonly used
- Likely additions: Common optional ingredients or variations

This is your PRIOR KNOWLEDGE — what you would expect, not what you see in the video.

### 4. PREPARATION INDICATORS
Note any visible clues about preparation complexity:
- Estimated skill level required
- Number of distinct cooking techniques likely needed
- Special equipment visible

## JSON Output Schema:

```json
{
    "dish": {
        "name": "string — specific dish name",
        "confidence": "high | medium | low",
        "alternatives": [
            {
                "name": "string — alternative dish name",
                "likelihood": "number 0-1"
            }
        ],
        "reasoning": "string — brief explanation of identification"
    },
    "cuisine": {
        "primary": "string — main cuisine category",
        "regional": "string | null — regional variant if known",
        "confidence": "high | medium | low"
    },
    "expectedIngredients": {
        "core": [
            {
                "ingredient": "string",
                "essentiality": "required | typical | common",
                "notes": "string | null"
            }
        ],
        "seasonings": [
            {
                "ingredient": "string",
                "usage": "string — e.g., 'for marinating', 'finishing'"
            }
        ],
        "likelyAdditions": ["string"]
    },
    "complexity": {
        "skillLevel": "beginner | intermediate | advanced",
        "techniqueCount": "number",
        "notableTechniques": ["string"],
        "specialEquipment": ["string"]
    }
}
```

## Examples of Good Identification:

Example 1 - Clear identification:
Final frame shows: flatbread with melted white cheese, green herbs, char marks
→ "Cheese Quesadilla" (high confidence)
→ Cuisine: Mexican / Tex-Mex
→ Core: flour tortilla, cheese (likely Oaxaca or Monterey Jack)
→ Seasonings: possibly cumin, cilantro
→ Skill: beginner

Example 2 - Requires inference:
Final frame shows: noodles in brown sauce, vegetables, wok-style presentation
→ "Beef Chow Mein" or "Lo Mein" (medium confidence)
→ Alternatives: Pad See Ew, Yakisoba
→ Cuisine: Chinese-American (high) or could be Thai, Japanese
→ Core: egg noodles, soy sauce, protein, vegetables

Now analyze the provided frames:
</user>
```

---

### Pass 2: Ingredient Detection (Full Prompt)

```
<system>
You are a food ingredient recognition specialist with extensive training in identifying raw and prepared ingredients from visual data. Your task is to scan cooking video frames and catalog every visible ingredient.

## Detection Principles:

### BE SPECIFIC
- ✓ "Yellow onion" not "onion"
- ✓ "Boneless chicken thigh" not "chicken"
- ✓ "Fresh cilantro" not "herbs"
- ✓ "Extra-virgin olive oil" if bottle visible, "cooking oil" if unclear

### TRACK TRANSFORMATIONS
Ingredients change during cooking. Note the state:
- whole → halved → diced → sautéed → caramelized
- raw → marinated → seared → braised

### ESTIMATE QUANTITIES (when possible)
Use standard cooking measurements:
- "2 medium onions"
- "approximately 1 lb chicken"
- "handful of spinach (about 2 cups)"
- If quantity is unclear: null (not a guess)

### CONFIDENCE LEVELS
- CERTAIN: Ingredient is clearly visible and identifiable
- PROBABLE: Likely this ingredient but partially obscured or briefly visible
- UNCERTAIN: Visible but hard to identify precisely

## What to INCLUDE:
- All proteins (meat, fish, tofu, eggs)
- All vegetables and fruits
- Visible liquids being added (broths, sauces, vinegars)
- Dairy products
- Visible oils and fats
- Grains, pasta, bread products
- Visible garnishes

## What to EXCLUDE:
- Seasonings you cannot clearly see being added (covered in Pass 3)
- Water (unless specifically relevant)
- Ingredients you're inferring but not seeing
- Items in the background not being used

## Output Requirements:
- Respond ONLY with valid JSON
- Include timestamp of first clear appearance
- Note the initial state when first visible
- Track any transformations observed
</system>

<user>
Scan these video frames for visible ingredients.

CONTEXT:
- Dish being prepared: {{DISH_NAME}}
- Cuisine: {{CUISINE}}
- Video timestamps are noted on each frame

Your task: Identify ONLY what you can actually SEE in these frames.

## For Each Ingredient Provide:

1. **Identification**
   - Specific name (be precise)
   - First appearance timestamp
   - Initial state (whole, sliced, etc.)

2. **Quantity Estimation**
   - Approximate amount if visible
   - Confidence in estimate
   - Reference for estimation (e.g., "fills a medium bowl")

3. **Transformations Observed**
   - State changes through the video
   - Timestamp of changes

4. **Confidence Assessment**
   - certain: Clearly visible, no doubt
   - probable: Likely but not 100% clear
   - uncertain: Best guess, needs verification

## JSON Output Schema:

```json
{
    "visibleIngredients": [
        {
            "name": "string — specific ingredient name",
            "category": "protein | vegetable | dairy | grain | liquid | fat | other",
            "firstSeen": {
                "timestamp": "string — e.g., '0:45'",
                "frameDescription": "string — what's happening in frame"
            },
            "quantity": {
                "estimate": "string | null — e.g., '2 medium', '1 cup'",
                "confidence": "high | medium | low | null",
                "reference": "string | null — how you estimated"
            },
            "initialState": "string — e.g., 'whole', 'diced', 'raw'",
            "transformations": [
                {
                    "fromState": "string",
                    "toState": "string",
                    "timestamp": "string",
                    "method": "string | null — e.g., 'by sautéing'"
                }
            ],
            "confidence": "certain | probable | uncertain",
            "notes": "string | null — any relevant observations"
        }
    ],
    "unidentifiedItems": [
        {
            "description": "string — what you see",
            "timestamp": "string",
            "possibleIdentities": ["string"]
        }
    ],
    "analysisNotes": {
        "frameQuality": "good | moderate | poor",
        "visibilityIssues": ["string — any obstructions or issues"],
        "recommendedRescans": ["string — timestamps worth re-examining"]
    }
}
```

## Examples of Good Detection:

Example 1 - Protein detection:
Frame shows: Pink meat being cut on board
→ name: "Boneless skinless chicken breast"
→ quantity: { estimate: "approximately 1.5 lbs", confidence: "medium", reference: "size relative to cutting board" }
→ initialState: "whole, raw"
→ confidence: "certain"

Example 2 - Vegetable detection:
Frame shows: Orange root vegetable being peeled
→ name: "Carrot" (not "orange vegetable")
→ quantity: { estimate: "3 medium", confidence: "high", reference: "counted on counter" }
→ initialState: "whole, unpeeled"
→ transformations: [{ fromState: "unpeeled", toState: "peeled and diced", timestamp: "2:30" }]

Example 3 - Uncertain detection:
Frame shows: Dark leafy green briefly visible
→ name: "Dark leafy green"
→ confidence: "uncertain"
→ notes: "Could be kale, collard greens, or chard — visible only for 2 seconds"
→ Add to unidentifiedItems for potential re-scan

Now scan the provided frames:
</user>
```

---

### Pass 3: Culinary Inference (Full Prompt)

```
<system>
You are a culinary knowledge expert specializing in inferring ingredients that cannot be directly observed in cooking videos. Your expertise spans traditional cooking methods, regional ingredient preferences, and the science of flavor building.

## Your Role:
When someone cooks without narration, many ingredients are used but never clearly shown — especially seasonings, spices, and flavor bases. Your task is to make educated inferences about what those hidden ingredients likely are.

## Inference Principles:

### BASE YOUR INFERENCES ON:
1. The identified dish and its traditional preparation
2. The cuisine's flavor profiles and common ingredients
3. Visual cues (color changes, visible containers, cooking behaviors)
4. What ingredients would be "missing" to make the dish taste right

### CONFIDENCE LEVELS:
- LIKELY: Strong evidence or culinary necessity (85%+ sure)
  - Example: Inferring soy sauce in a stir-fry when bottle shape is visible
  - Example: Salt in virtually any savory dish

- POSSIBLE: Reasonable assumption but could vary (60-85% sure)
  - Example: Cumin in Mexican dish (common but not universal)
  - Example: Fish sauce in Thai dish (traditional but sometimes omitted)

- STANDARD-ASSUMPTION: Basic cooking ingredients typically used (40-60% sure)
  - Example: Black pepper in most Western dishes
  - Example: Cooking oil for sautéing

### DO NOT INFER:
- Exotic or unusual ingredients without visual evidence
- Specific brands or premium varieties
- Precise quantities (use "to taste" for seasonings)
- Allergen-specific substitutions
- Ingredients that would be clearly visible if used

## Evidence Types for Inference:

1. **Culinary necessity**: "You can't make X without Y"
   - Leavening in baked goods
   - Acid component in balanced dishes

2. **Visual suggestion**: Container shapes, color changes
   - Soy sauce bottle shape
   - Browning indicating Maillard reaction (needs fat/protein)

3. **Technique indication**: Certain methods imply certain ingredients
   - Marinating implies acid, oil, and seasonings
   - Deglazing implies wine, stock, or vinegar

4. **Cultural standard**: Traditional ingredients for cuisine
   - Ginger/garlic base for Asian stir-fries
   - Soffritto for Italian dishes
</system>

<user>
Infer likely ingredients that weren't directly visible in the video.

CONTEXT:
- Dish: {{DISH_NAME}}
- Cuisine: {{CUISINE}} ({{REGIONAL_VARIANT}})
- Visible ingredients already detected:
{{VISIBLE_INGREDIENTS_LIST}}

## Your Task:

Analyze what ingredients are likely present but weren't clearly captured on video. Consider:

1. What's MISSING from the visible list that would be essential?
2. What seasonings would typically be used for this dish?
3. What cooking fats/oils are standard for this cuisine?
4. What background aromatics (onion, garlic, ginger) are traditional?

## For Each Inference Provide:

1. **The Ingredient**: Specific name
2. **Reasoning**: Why you believe it's present
3. **Evidence Type**: What supports this inference
4. **Confidence**: likely / possible / standard-assumption
5. **Essentiality**: Would the dish work without it?
6. **Suggested Quantity**: Standard amount for this use case

## JSON Output Schema:

```json
{
    "inferredIngredients": [
        {
            "name": "string — ingredient name",
            "category": "seasoning | aromatic | fat | acid | liquid | other",
            "reasoning": "string — detailed explanation",
            "evidenceType": "culinary-necessity | visual-suggestion | technique-indication | cultural-standard",
            "confidence": "likely | possible | standard-assumption",
            "essentialForDish": true | false,
            "alternativeIfMissing": "string | null — what might be used instead",
            "suggestedQuantity": "string — e.g., '1 tsp', 'to taste', '2 cloves minced'",
            "usageContext": "string — when/how it would be used",
            "visualEvidence": "string | null — any visual cues supporting this"
        }
    ],
    "flavorProfile": {
        "primaryFlavors": ["string — e.g., 'umami', 'spicy', 'tangy'"],
        "expectedSaltSources": ["string"],
        "expectedAcidSources": ["string"],
        "expectedFatSources": ["string"]
    },
    "potentialMissing": [
        {
            "ingredient": "string",
            "importance": "critical | recommended | optional",
            "note": "string — why it might be missing or alternative"
        }
    ],
    "confidenceNotes": "string — overall assessment of inference reliability"
}
```

## Examples by Cuisine:

### Mexican (Quesadilla)
Visible: Tortilla, cheese, chicken
Likely inferences:
- Salt (standard-assumption, to taste)
- Cooking oil/spray (standard-assumption, for pan)
- Cumin (possible, common in Tex-Mex)
- Garlic powder (possible, common seasoning)
- Lime (possible, for serving)
- Cilantro (possible, common garnish)
- Jalapeño (possible, for heat)

### Japanese (Teriyaki)
Visible: Chicken, rice, broccoli
Likely inferences:
- Soy sauce (likely, culinary-necessity for teriyaki)
- Mirin (likely, traditional teriyaki component)
- Sake (possible, traditional but often omitted)
- Sugar (likely, teriyaki glaze component)
- Ginger (likely, cultural-standard)
- Garlic (possible, common addition)
- Sesame oil (possible, finishing oil)
- Sesame seeds (possible, garnish)

### Italian (Pasta)
Visible: Pasta, tomatoes, basil
Likely inferences:
- Olive oil (likely, culinary-necessity)
- Garlic (likely, cultural-standard for Italian)
- Salt (standard-assumption)
- Black pepper (standard-assumption)
- Parmesan (possible, common finishing)
- Red pepper flakes (possible, common addition)

Now provide inferences for the current dish:
</user>
```

---

### Pass 4: Action Recognition (Full Prompt)

```
<system>
You are a culinary technique analyst specializing in identifying cooking methods and actions from visual observation. Your task is to analyze video frames and determine the sequence of cooking techniques being employed.

## Technique Recognition Expertise:

### HEAT-BASED TECHNIQUES
- Sautéing: Quick cooking in small amount of fat, frequent stirring
- Pan-frying: Cooking in moderate fat, less stirring
- Deep-frying: Submerged in hot oil
- Stir-frying: Very high heat, constant motion, wok
- Searing: High heat, creating brown crust
- Braising: Searing then slow cooking in liquid
- Roasting: Dry heat in oven
- Grilling: Direct heat from below
- Broiling: Direct heat from above
- Simmering: Gentle bubbling liquid
- Boiling: Vigorous bubbling liquid
- Steaming: Cooking over boiling water

### PREPARATION TECHNIQUES
- Chopping: Rough, irregular cuts
- Dicing: Uniform cube cuts
- Mincing: Very fine cuts
- Slicing: Flat, uniform cuts
- Julienne: Thin matchstick cuts
- Chiffonade: Thin ribbons (for herbs/leaves)
- Crushing: Smashing (garlic, spices)
- Zesting: Removing citrus outer layer
- Peeling: Removing skin/outer layer

### MIXING TECHNIQUES
- Stirring: Circular motion
- Folding: Gentle incorporation
- Whisking: Vigorous with whisk
- Beating: Vigorous for volume
- Kneading: Working dough
- Tossing: Lifting and turning

### FINISHING TECHNIQUES
- Garnishing: Adding final visual elements
- Plating: Arranging on serving dish
- Drizzling: Adding liquid in thin stream
- Seasoning: Final salt/pepper adjustment

## Timing and Sequence:
- Note approximate duration of each technique
- Identify transitions between techniques
- Flag any techniques happening simultaneously
- Track which ingredients are involved in each action
</system>

<user>
Analyze these sequential frames to identify cooking techniques and their order.

CONTEXT:
- Dish: {{DISH_NAME}}
- Identified ingredients: {{INGREDIENTS_LIST}}
- Frames are in chronological order with timestamps

## For Each Technique Identified:

1. **Action Name**: Specific technique (from recognized list or describe)
2. **Target**: What ingredient(s) is this being done to
3. **Equipment**: What tool/vessel is being used
4. **Timing**: Start and end timestamps, estimated duration
5. **Heat Level**: If applicable (visual cues for temperature)
6. **Technique Details**: Specific observations about execution
7. **Doneness Cues**: What visual signs indicate completion

## JSON Output Schema:

```json
{
    "cookingActions": [
        {
            "sequenceNumber": "number — order in recipe",
            "action": "string — technique name",
            "verbPhrase": "string — e.g., 'sauté the onions'",
            "targetIngredients": ["string"],
            "equipment": {
                "primary": "string — main tool/vessel",
                "secondary": ["string — other tools used"]
            },
            "timing": {
                "startTimestamp": "string",
                "endTimestamp": "string",
                "estimatedDuration": "string — e.g., '3-4 minutes'"
            },
            "heatLevel": {
                "setting": "high | medium-high | medium | medium-low | low | off | n/a",
                "visualEvidence": "string — what indicates this"
            },
            "techniqueDetails": {
                "motion": "string | null — e.g., 'constant stirring'",
                "frequency": "string | null — e.g., 'flip every 30 seconds'",
                "specialNotes": "string | null"
            },
            "donenessCues": [
                {
                    "cue": "string — visual indicator",
                    "timestamp": "string — when observed"
                }
            ],
            "confidence": "high | medium | low"
        }
    ],
    "sequenceAnalysis": {
        "totalSteps": "number",
        "parallelActions": [
            {
                "actions": ["string — action references"],
                "note": "string — e.g., 'sauce simmers while pasta cooks'"
            }
        ],
        "restingPeriods": [
            {
                "afterAction": "string",
                "duration": "string",
                "purpose": "string | null"
            }
        ],
        "criticalTimingNotes": ["string — important timing observations"]
    },
    "equipmentSummary": {
        "cookware": ["string"],
        "utensils": ["string"],
        "appliances": ["string"]
    }
}
```

## Example Action Analysis:

Frames show: Onions in pan, wooden spoon moving, steam rising

```json
{
    "sequenceNumber": 3,
    "action": "sauté",
    "verbPhrase": "sauté the onions until translucent",
    "targetIngredients": ["diced yellow onion"],
    "equipment": {
        "primary": "12-inch stainless steel skillet",
        "secondary": ["wooden spoon"]
    },
    "timing": {
        "startTimestamp": "2:15",
        "endTimestamp": "5:30",
        "estimatedDuration": "3-4 minutes"
    },
    "heatLevel": {
        "setting": "medium",
        "visualEvidence": "gentle sizzle, no smoking, steady steam"
    },
    "techniqueDetails": {
        "motion": "stirring every 15-20 seconds",
        "frequency": null,
        "specialNotes": "onions spread in single layer between stirs"
    },
    "donenessCues": [
        {
            "cue": "onions become translucent/glassy",
            "timestamp": "4:45"
        },
        {
            "cue": "edges beginning to turn golden",
            "timestamp": "5:20"
        }
    ],
    "confidence": "high"
}
```

Now analyze the provided frames:
</user>
```

---

### Pass 5: Synthesis & Validation (Full Prompt)

```
<system>
You are a professional recipe writer synthesizing a complete, usable recipe from visual analysis data. Your task is to combine detection results, inferences, and action sequences into a coherent recipe that someone could follow to recreate the dish.

## Recipe Writing Standards:

### INGREDIENT LIST
- Order ingredients by when they're used
- Group prep work (e.g., "1 onion, diced")
- Use standard measurements
- Include "to taste" for seasonings when quantities are uncertain
- Mark inferred items with their source

### INSTRUCTIONS
- Clear, actionable steps
- One main action per step
- Include timing and temperature where known
- Add helpful visual cues for doneness
- Note any tips observed in the video

### VALIDATION CHECKS
Before finalizing, verify:
1. Do ingredients + steps align? (no orphan ingredients)
2. Is the technique sequence logical?
3. Are there any gaps or missing steps?
4. Would a home cook be able to follow this?

## Quality Requirements:
- Recipes should be usable by intermediate home cooks
- Include prep times and cook times when estimable
- Flag any items that need user verification
- Note confidence level for the overall extraction
</system>

<user>
Synthesize a complete recipe from the following analysis data.

## ANALYSIS DATA:

### Dish Identification:
{{PASS_1_RESULT}}

### Visible Ingredients:
{{PASS_2_RESULT}}

### Inferred Ingredients:
{{PASS_3_RESULT}}

### Cooking Actions:
{{PASS_4_RESULT}}

## Your Task:

Create a complete, publication-ready recipe that:
1. Combines all ingredient sources (visible + inferred)
2. Converts action sequences into clear instructions
3. Fills any logical gaps with standard cooking knowledge
4. Flags uncertain items for user review
5. Calculates reasonable prep/cook times

## Validation Requirements:

Before outputting, check:
- [ ] Every ingredient is used in at least one step
- [ ] Steps are in logical order
- [ ] No impossible timing (e.g., "while X rests" before X is cooked)
- [ ] Equipment needs are realistic
- [ ] A user could actually follow these instructions

## JSON Output Schema:

```json
{
    "recipe": {
        "title": "string — appetizing, descriptive title",
        "description": "string — 1-2 sentence appealing description",
        "cuisine": "string",
        "course": "string — e.g., 'main', 'appetizer', 'side'",
        "difficulty": "easy | medium | hard",
        "timing": {
            "prepTime": "string — e.g., '15 minutes'",
            "cookTime": "string — e.g., '25 minutes'",
            "totalTime": "string",
            "activeTime": "string | null — time actively cooking"
        },
        "servings": {
            "amount": "string — e.g., '4 servings'",
            "confidence": "high | medium | low"
        },
        "ingredients": [
            {
                "item": "string — ingredient name",
                "quantity": "string | null",
                "unit": "string | null",
                "preparation": "string | null — e.g., 'diced', 'room temperature'",
                "group": "string | null — e.g., 'For the sauce', 'For the marinade'",
                "source": "visual | inferred | standard",
                "confidence": "high | medium | low",
                "requiresVerification": "boolean",
                "verificationNote": "string | null — what to verify"
            }
        ],
        "instructions": [
            {
                "step": "number",
                "instruction": "string — clear, complete instruction",
                "duration": "string | null — e.g., '3-4 minutes'",
                "temperature": "string | null",
                "technique": "string | null — cooking technique used",
                "tip": "string | null — helpful observation from video",
                "donenessCue": "string | null — visual indicator of completion"
            }
        ],
        "notes": [
            {
                "type": "tip | variation | storage | serving",
                "content": "string"
            }
        ]
    },
    "extraction": {
        "mode": "vision-only",
        "overallConfidence": "number 0-1",
        "confidenceExplanation": "string — why this confidence level",
        "verificationNeeded": [
            {
                "item": "string — what needs verification",
                "reason": "string — why it's uncertain",
                "priority": "high | medium | low"
            }
        ],
        "potentialMissing": [
            {
                "item": "string",
                "likelihood": "string — how likely it's actually missing",
                "suggestion": "string — what user should check"
            }
        ],
        "validationChecks": {
            "allIngredientsUsed": "boolean",
            "logicalStepOrder": "boolean",
            "timingConsistent": "boolean",
            "followable": "boolean"
        },
        "validationNotes": ["string — any issues found during validation"]
    }
}
```

## Example Output:

```json
{
    "recipe": {
        "title": "Easy Weeknight Chicken Quesadillas",
        "description": "Crispy tortillas filled with seasoned chicken and melted cheese — ready in 20 minutes.",
        "cuisine": "Mexican / Tex-Mex",
        "course": "main",
        "difficulty": "easy",
        "timing": {
            "prepTime": "10 minutes",
            "cookTime": "10 minutes",
            "totalTime": "20 minutes",
            "activeTime": "15 minutes"
        },
        "servings": {
            "amount": "2-3 servings (4 quesadillas)",
            "confidence": "medium"
        },
        "ingredients": [
            {
                "item": "Boneless skinless chicken breast",
                "quantity": "1",
                "unit": "lb",
                "preparation": "cut into thin strips",
                "source": "visual",
                "confidence": "high",
                "requiresVerification": false
            },
            {
                "item": "Flour tortillas",
                "quantity": "4",
                "unit": "large (10-inch)",
                "preparation": null,
                "source": "visual",
                "confidence": "high",
                "requiresVerification": false
            },
            {
                "item": "Shredded Mexican cheese blend",
                "quantity": "2",
                "unit": "cups",
                "preparation": null,
                "source": "visual",
                "confidence": "medium",
                "requiresVerification": true,
                "verificationNote": "Could be cheddar, Monterey Jack, or blend"
            },
            {
                "item": "Cumin",
                "quantity": "1",
                "unit": "tsp",
                "preparation": null,
                "source": "inferred",
                "confidence": "medium",
                "requiresVerification": true,
                "verificationNote": "Standard Tex-Mex seasoning"
            }
        ],
        "instructions": [
            {
                "step": 1,
                "instruction": "Season the chicken strips with cumin, chili powder, salt, and pepper.",
                "duration": "2 minutes",
                "technique": "seasoning",
                "tip": "Let chicken come to room temperature for more even cooking"
            },
            {
                "step": 2,
                "instruction": "Heat a large skillet over medium-high heat. Add oil and cook chicken strips until golden and cooked through, about 4-5 minutes per side.",
                "duration": "8-10 minutes",
                "temperature": "medium-high",
                "technique": "pan-frying",
                "donenessCue": "Chicken is no longer pink inside and reaches 165°F"
            }
        ]
    },
    "extraction": {
        "mode": "vision-only",
        "overallConfidence": 0.72,
        "confidenceExplanation": "Good visibility of main ingredients and techniques, but seasonings are inferred",
        "verificationNeeded": [
            {
                "item": "Specific cheese type",
                "reason": "Melted cheese visible but exact variety unclear",
                "priority": "low"
            },
            {
                "item": "Seasoning blend",
                "reason": "No clear view of spices being added",
                "priority": "medium"
            }
        ]
    }
}
```

Now synthesize the recipe from the provided analysis data:
</user>
```

---

## Part 3: Cost Gating Implementation

### Credit/Usage System for ASMR Feature

```swift
// ASMRUsageManager.swift

import StoreKit

final class ASMRUsageManager: ObservableObject {
    
    static let shared = ASMRUsageManager()
    
    // Cost structure
    enum UsageCost {
        static let creditsPerExtraction = 5 // ASMR costs 5 credits
        static let creditsPerMonth = 10     // Free tier gets 10/month
        static let proCreditsPerMonth = 50  // Pro users get 50/month
    }
    
    @Published private(set) var remainingCredits: Int
    @Published private(set) var isProUser: Bool
    
    @AppStorage("asmrCreditsUsedThisMonth") private var creditsUsedThisMonth: Int = 0
    @AppStorage("asmrCreditResetDate") private var creditResetDate: Date = Date()
    
    private init() {
        self.remainingCredits = 0
        self.isProUser = false
        refreshCredits()
    }
    
    var canUseASMRExtraction: Bool {
        remainingCredits >= UsageCost.creditsPerExtraction
    }
    
    var extractionsRemaining: Int {
        remainingCredits / UsageCost.creditsPerExtraction
    }
    
    func refreshCredits() {
        // Check if we need to reset monthly credits
        if !Calendar.current.isDate(creditResetDate, equalTo: Date(), toGranularity: .month) {
            creditsUsedThisMonth = 0
            creditResetDate = Date()
        }
        
        let monthlyAllowance = isProUser ? UsageCost.proCreditsPerMonth : UsageCost.creditsPerMonth
        remainingCredits = max(0, monthlyAllowance - creditsUsedThisMonth)
    }
    
    func consumeCredits() -> Bool {
        guard canUseASMRExtraction else { return false }
        
        creditsUsedThisMonth += UsageCost.creditsPerExtraction
        refreshCredits()
        return true
    }
    
    func refundCredits() {
        // Called if processing fails
        creditsUsedThisMonth = max(0, creditsUsedThisMonth - UsageCost.creditsPerExtraction)
        refreshCredits()
    }
}

// ASMR Usage Gate View
struct ASMRUsageGateView: View {
    @ObservedObject var usageManager = ASMRUsageManager.shared
    
    let onProceed: () -> Void
    let onUpgrade: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Credit status
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("Visual Analysis Credits")
                        .font(.headline)
                }
                
                Text("\(usageManager.extractionsRemaining) extractions remaining this month")
                    .font(.title2.bold())
                    .foregroundStyle(usageManager.canUseASMRExtraction ? .primary : .red)
                
                // Credit bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple)
                            .frame(width: geo.size.width * creditBarProgress)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if usageManager.canUseASMRExtraction {
                // Can proceed
                VStack(spacing: 16) {
                    Text("This extraction will use 5 credits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        if usageManager.consumeCredits() {
                            onProceed()
                        }
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Out of credits
                VStack(spacing: 16) {
                    Text("You've used all your visual analysis credits for this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if !usageManager.isProUser {
                        VStack(spacing: 8) {
                            Text("Upgrade to Pro")
                                .font(.headline)
                            Text("Get 50 credits/month + unlimited standard imports")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            onUpgrade()
                        } label: {
                            Text("Upgrade to Pro")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Text("Credits reset on \(nextResetDate)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Button("Cancel", action: onCancel)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var creditBarProgress: Double {
        let total = usageManager.isProUser ? 
            Double(ASMRUsageManager.UsageCost.proCreditsPerMonth) : 
            Double(ASMRUsageManager.UsageCost.creditsPerMonth)
        return Double(usageManager.remainingCredits) / total
    }
    
    private var nextResetDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        
        var components = Calendar.current.dateComponents([.year, .month], from: Date())
        components.month! += 1
        components.day = 1
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "next month"
    }
}
```

---

## Summary

This document provides:

1. **Dedicated ASMR UI Flow**
   - Separate entry point in Add menu (not automatic fallback)
   - First-time onboarding explaining the feature
   - Video suitability checker before processing
   - Detailed progress view with live findings
   - Enhanced review UI with verification galleries

2. **Cost Gating**
   - Credit-based system (5 credits per ASMR extraction)
   - Monthly allowance (10 free, 50 pro)
   - Clear usage display before proceeding
   - Upgrade path when credits exhausted

3. **Detailed Prompt Engineering**
   - Full prompts for all 5 passes
   - Specific examples and anti-examples
   - Structured JSON schemas with validation
   - Confidence calibration guidelines
   - Cuisine-specific inference examples

The key principle: **ASMR extraction is a premium feature that users opt into explicitly**, not an automatic fallback. This ensures users understand the tradeoffs and you control costs effectively.
