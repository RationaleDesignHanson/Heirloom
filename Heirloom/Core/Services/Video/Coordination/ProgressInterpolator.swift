//
//  ProgressInterpolator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-12.
//

import Foundation

/// Smoothly interpolates progress based on estimated duration
/// Uses time-based estimation to provide continuous progress updates
/// instead of discrete phase-based jumps
@MainActor
class ProgressInterpolator: ObservableObject {
    @Published var interpolatedProgress: Double = 0.0

    private var timer: Timer?
    private var startProgress: Double = 0.0
    private var targetProgress: Double = 0.0
    private var startTime: Date?
    private var estimatedDuration: TimeInterval = 0.0

    /// Start interpolating from current to target over estimated duration
    func start(from: Double, to: Double, duration: TimeInterval) {
        stop()

        startProgress = from
        targetProgress = to
        startTime = Date()
        estimatedDuration = duration
        interpolatedProgress = from

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
    func stop() {
        timer?.invalidate()
        timer = nil
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

    nonisolated deinit {
        // Timer invalidation must happen on main thread, but deinit can be called from any thread
        // Use detached task to safely invalidate on MainActor if needed
        let timerToInvalidate = timer
        if let timer = timerToInvalidate {
            Task { @MainActor in
                timer.invalidate()
            }
        }
    }
}
