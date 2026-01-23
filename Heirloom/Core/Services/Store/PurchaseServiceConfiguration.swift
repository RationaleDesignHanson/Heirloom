//
//  PurchaseServiceConfiguration.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//  Single source of truth for purchase service provider selection
//

import Foundation

/// Purchase service configuration
/// **TO SWAP FROM STOREKIT TO REVENUECAT: Change this ONE line**
enum PurchaseServiceConfiguration {

    // MARK: - Provider Selection

    /// Current purchase service provider
    /// Change this to switch between StoreKit and RevenueCat
    ///
    /// **How to swap to RevenueCat:**
    /// 1. Change `.storeKit` to `.revenueCat` below
    /// 2. Uncomment RevenueCat SDK import in RevenueCatPurchaseService.swift
    /// 3. Add RevenueCat configuration in HeirloomApp.swift
    /// 4. That's it! The app will now use RevenueCat for all purchases
    static let currentProvider: PurchaseServiceProvider = .storeKit

    // MARK: - Debug Settings

    /// Enable fake payments for testing (bypasses real transactions)
    /// Defaults to true in DEBUG builds for easy testing
    static var isFakePaymentsEnabled: Bool {
        #if DEBUG
        // Check UserDefaults, default to true for convenience
        if UserDefaults.standard.object(forKey: "debug_fake_payments_enabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "debug_fake_payments_enabled")
        #else
        return false // Never enable fake payments in production
        #endif
    }
}

// MARK: - Documentation

/*
 ## Quick Start: Swapping to RevenueCat

 ### Step 1: Change Provider (1 line)
 ```swift
 static let currentProvider: PurchaseServiceProvider = .revenueCat
 ```

 ### Step 2: Configure RevenueCat SDK
 In HeirloomApp.swift, add to init():
 ```swift
 import RevenueCat

 init() {
     Purchases.configure(withAPIKey: "YOUR_REVENUECAT_PUBLIC_API_KEY")
     Purchases.logLevel = .debug  // For development
     // ... rest of init
 }
 ```

 ### Step 3: Complete RevenueCatPurchaseService Implementation
 - Uncomment TODO sections in RevenueCatPurchaseService.swift
 - Implement each protocol method
 - See detailed guide in RevenueCatPurchaseService.swift

 That's it! The entire app will now use RevenueCat.

 ---

 ## How This Works

 StoreManager uses this configuration to determine which service to use:
 ```swift
 let purchaseService: PurchaseServiceProtocol = {
     switch PurchaseServiceConfiguration.currentProvider {
     case .storeKit:
         return StoreKitPurchaseService(logger: logger, analytics: analytics)
     case .revenueCat:
         return RevenueCatPurchaseService(logger: logger, analytics: analytics)
     }
 }()
 ```

 Both services implement the same protocol, so swapping is seamless.
 */
