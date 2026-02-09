//
//  PhotoProgressInterpolator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-12.
//

import Foundation

/// Smoothly interpolates progress for photo processing based on estimated duration
/// Uses time-based estimation to provide continuous progress updates
@MainActor
class PhotoProgressInterpolator: ObservableObject {
    @Published var interpolatedProgress: Double = 0.0

    private var timer: Timer?
    private var startProgress: Double = 0.0
    private var targetProgress: Double = 0.0
    private var startTime: Date?
    private var estimatedDuration: TimeInterval = 0.0

    /// Estimated durations for photo processing phases
    enum PhaseDuration {
        static let optimizing: TimeInterval = 2.0    // 1-3s image preprocessing
        static let detecting: TimeInterval = 3.0     // 2-4s recipe detection
        static let extracting: TimeInterval = 4.0    // 3-5s recipe extraction
    }

    /// Start interpolating from current to target over estimated duration
    func start(from: Double, to: Double, duration: TimeInterval) {
        stop()

        // Never go backwards — clamp start to at least current progress
        let safeFrom = max(from, interpolatedProgress)
        let safeTo = max(to, safeFrom)

        startProgress = safeFrom
        targetProgress = safeTo
        startTime = Date()
        estimatedDuration = duration
        interpolatedProgress = safeFrom

        // Update every 0.5 seconds for smooth progress
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    /// Update to exact progress (for checkpoints)
    func snap(to progress: Double) {
        stop()
        interpolatedProgress = progress
    }

    /// Stop interpolation
    nonisolated func stop() {
        MainActor.assumeIsolated {
            timer?.invalidate()
            timer = nil
        }
    }

    private func updateProgress() {
        guard let startTime = startTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let ratio = min(elapsed / estimatedDuration, 1.0)

        // Use ease-out curve for natural feel
        let easedRatio = 1 - pow(1 - ratio, 2)

        interpolatedProgress = startProgress + (targetProgress - startProgress) * easedRatio

        // Cap at 95% of target to avoid reaching 100% before actual completion
        interpolatedProgress = min(interpolatedProgress, targetProgress * 0.95)
    }

    deinit {
        stop()
    }
}
