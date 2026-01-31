//
//  CameraOriginDetector.swift
//  Heirloom
//
//  Camera origin detection for public sharing policy
//  Detects screenshots, downloads, and camera photos
//

import Foundation
import Photos

/// Simple detector for camera photo origin (Path A+ implementation)
/// Detects screenshots and camera indicators using PHAsset metadata
struct CameraOriginDetector {

    /// Analyze a PHAsset to determine if it came from device camera
    /// - Parameter asset: The PHAsset to analyze
    /// - Returns: Confidence level (definitelyCamera, likelyCamera, or definitelyNotCamera)
    static func analyze(asset: PHAsset) -> CameraOriginConfidence {
        // DISQUALIFYING FACTORS (definitelyNotCamera)

        // Check 1: Screenshot detection (iOS automatically flags these)
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            Log.debug("Camera origin: Screenshot detected - NOT eligible", category: .import)
            return .definitelyNotCamera
        }

        // Check 2: Cloud shared albums (received from others)
        if asset.sourceType == .typeCloudShared {
            Log.debug("Camera origin: Cloud shared - NOT eligible", category: .import)
            return .definitelyNotCamera
        }

        // Check 3: iTunes synced (transferred from computer)
        if asset.sourceType == .typeiTunesSynced {
            Log.debug("Camera origin: iTunes synced - NOT eligible", category: .import)
            return .definitelyNotCamera
        }

        // STRONG CAMERA INDICATORS (definitelyCamera)

        // Check 4: Live Photo (only created by camera)
        if asset.mediaSubtypes.contains(.photoLive) {
            Log.debug("Camera origin: Live Photo - DEFINITELY camera", category: .import)
            return .definitelyCamera
        }

        // Check 5: HDR photo (camera feature)
        if asset.mediaSubtypes.contains(.photoHDR) {
            Log.debug("Camera origin: HDR - DEFINITELY camera", category: .import)
            return .definitelyCamera
        }

        // Check 6: Portrait mode / Depth effect (camera feature)
        if asset.mediaSubtypes.contains(.photoDepthEffect) {
            Log.debug("Camera origin: Portrait mode - DEFINITELY camera", category: .import)
            return .definitelyCamera
        }

        // DEFAULT: Regular photo from user library
        // No red flags detected, no strong camera indicators
        // Most likely a camera photo (screenshots would be flagged above)
        if asset.sourceType == .typeUserLibrary {
            Log.debug("Camera origin: User library photo - likely camera", category: .import)
            return .likelyCamera
        }

        // UNKNOWN: Shouldn't hit this, but be conservative
        Log.warning("Camera origin: Unknown source type - NOT eligible", category: .import)
        return .definitelyNotCamera
    }

    /// Analyze in-app camera capture (always eligible)
    /// - Returns: definitelyCamera (in-app camera is trusted)
    static func analyzeInAppCamera() -> CameraOriginConfidence {
        Log.debug("Camera origin: In-app camera - DEFINITELY camera", category: .import)
        return .definitelyCamera
    }
}
