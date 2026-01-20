//
//  MigrationTestView.swift
//  Heirloom
//
//  Firebase Connection Testing
//

import SwiftUI
import SwiftData

struct MigrationTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var authService
    @Environment(\.firebaseSync) private var firebaseSync
    @Query private var recipes: [Recipe]

    @State private var showingSignIn = false
    @State private var testResult: String = ""
    @State private var isTesting = false

    var body: some View {
        List {
            // Backend Status Section
            Section("Backend Configuration") {
                HStack {
                    Text("Current Backend")
                    Spacer()
                    Text("Firebase")
                        .foregroundColor(.secondary)
                }
            }

            // Authentication Section
            Section("Firebase Authentication") {
                HStack {
                    Text("Status")
                    Spacer()
                    if authService.isAuthenticated {
                        Label("Signed In", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not Signed In", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }

                if let userId = authService.currentUser?.uid {
                    Text("User ID: \(userId)")
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(.secondary)
                }

                if !authService.isAuthenticated {
                    Button(action: { showingSignIn = true }) {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Sign in with Apple")
                        }
                    }
                }
            }

            // Firebase Connection Test
            if authService.isAuthenticated {
                Section("Firebase Connection Test") {
                    Button(action: testFirebaseConnection) {
                        HStack {
                            if isTesting {
                                ProgressView()
                            } else {
                                Image(systemName: "network")
                            }
                            Text("Test Firebase Sync")
                        }
                    }
                    .disabled(isTesting)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(HeirloomFonts.caption1)
                            .foregroundColor(testResult.contains("✅") ? .green : .red)
                    }
                }

                Section("Local Data") {
                    HStack {
                        Text("Recipes in SwiftData")
                        Spacer()
                        Text("\(recipes.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Firebase Testing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSignIn) {
            FirebaseSignInView()
        }
    }

    // MARK: - Actions

    private func testFirebaseConnection() {
        Task {
            isTesting = true
            testResult = "Testing..."

            do {
                // Test by syncing first recipe if available
                if let firstRecipe = recipes.first {
                    try await firebaseSync.uploadRecipe(firstRecipe)
                    testResult = "✅ Successfully synced recipe to Firebase"
                } else {
                    testResult = "⚠️ No recipes to test sync"
                }
            } catch {
                testResult = "❌ Error: \(error.localizedDescription)"
            }

            isTesting = false
        }
    }
}

#Preview {
    NavigationStack {
        MigrationTestView()
            .modelContainer(for: Recipe.self, inMemory: true)
    }
}
