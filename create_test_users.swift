#!/usr/bin/env swift

import Foundation

// Quick script to generate test user data for Firestore
// Copy this JSON and paste into Firebase Console

let testUsers = [
    [
        "userId": "test-user-1",
        "displayName": "Matt Chef",
        "bio": "Love Italian cooking and fresh pasta",
        "photoURL": nil as String?
    ],
    [
        "userId": "test-user-2",
        "displayName": "Sarah Baker",
        "bio": "Specializing in artisan breads and pastries",
        "photoURL": nil as String?
    ],
    [
        "userId": "test-user-3",
        "displayName": "Maria Garcia",
        "bio": "Mexican cuisine enthusiast",
        "photoURL": nil as String?
    ],
    [
        "userId": "test-user-4",
        "displayName": "John Smith",
        "bio": "BBQ and grilling expert",
        "photoURL": nil as String?
    ],
    [
        "userId": "test-user-5",
        "displayName": "Emily Chen",
        "bio": "Asian fusion and vegetarian dishes",
        "photoURL": nil as String?
    ]
]

print("Test Users JSON:")
print("================")
for user in testUsers {
    print("\nFor user: \(user["displayName"] ?? "Unknown")")
    print("Path: users/\(user["userId"] ?? "")/profile/data")
    print("""
    {
      "userId": "\(user["userId"] ?? "")",
      "displayName": "\(user["displayName"] ?? "")",
      "bio": "\(user["bio"] ?? "")",
      "photoURL": null,
      "handle": null,
      "location": null,
      "specialties": [],
      "connectionCount": 0,
      "followerCount": 0,
      "followingCount": 0,
      "sharedRecipeCount": 0,
      "heritageGenerationCount": 0,
      "recipeAcceptanceCount": 0,
      "hasPublicProfile": false,
      "publicProfileSlug": null,
      "joinedAt": {"_seconds": \(Int(Date().timeIntervalSince1970)), "_nanoseconds": 0},
      "updatedAt": {"_seconds": \(Int(Date().timeIntervalSince1970)), "_nanoseconds": 0},
      "lastActiveAt": null,
      "locale": "en_US",
      "isVerified": false,
      "verificationType": null,
      "privacySettings": {
        "profileVisibility": "private",
        "allowMentions": true,
        "allowSearchIndexing": true
      }
    }
    """)
}
