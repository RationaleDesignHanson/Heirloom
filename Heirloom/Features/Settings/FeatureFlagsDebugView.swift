//
//  FeatureFlagsDebugView.swift
//  Heirloom
//
//  Debug menu for viewing and toggling feature flags
//  Created: 2026-01-13
//

import SwiftUI

struct FeatureFlagsDebugView: View {

    @Environment(ServiceContainer.self) private var container
    @State private var flagManager: FeatureFlagManager?
    @State private var enabledStates: [Feature: Bool] = [:]

    var body: some View {
        List {
            // Info section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Feature Flag Management")
                        .font(.headline)

                    Text("Toggle features on/off for testing. Local overrides take precedence over remote flags.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Clear all button
            Section {
                Button(action: clearAllOverrides) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Clear All Overrides")
                    }
                    .foregroundStyle(.red)
                }
            }

            // Features grouped by category
            ForEach(FeatureCategory.allCases, id: \.self) { category in
                Section(header: Text(category.rawValue)) {
                    ForEach(featuresInCategory(category), id: \.self) { feature in
                        FeatureFlagRow(
                            feature: feature,
                            isEnabled: enabledStates[feature] ?? true,
                            hasOverride: flagManager?.localOverride(for: feature) != nil,
                            toggle: {
                                toggleFeature(feature)
                            }
                        )
                    }
                }
            }

            // Export section
            Section {
                Button(action: exportConfiguration) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Configuration")
                    }
                }
            }
        }
        .navigationTitle("Feature Flags")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            flagManager = container.resolve(FeatureFlagManager.self)
            refreshStates()
        }
    }

    // MARK: - Helpers

    private func featuresInCategory(_ category: FeatureCategory) -> [Feature] {
        Feature.allCases.filter { $0.category == category }
    }

    private func toggleFeature(_ feature: Feature) {
        guard let manager = flagManager else { return }

        let currentValue = enabledStates[feature] ?? true
        let newValue = !currentValue

        manager.setLocalOverride(feature, enabled: newValue)
        refreshStates()
    }

    private func clearAllOverrides() {
        flagManager?.clearAllLocalOverrides()
        refreshStates()
    }

    private func refreshStates() {
        guard let manager = flagManager else { return }

        var newStates: [Feature: Bool] = [:]
        for feature in Feature.allCases {
            newStates[feature] = manager.isEnabled(feature)
        }
        enabledStates = newStates
    }

    private func exportConfiguration() {
        guard let manager = flagManager else { return }

        var config: [String: Bool] = [:]
        for feature in Feature.allCases {
            config[feature.rawValue] = manager.isEnabled(feature)
        }

        if let jsonData = try? JSONEncoder().encode(config),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UIPasteboard.general.string = jsonString
            print("✅ Configuration exported to clipboard:")
            print(jsonString)
        }
    }
}

// MARK: - Feature Flag Row

struct FeatureFlagRow: View {
    let feature: Feature
    let isEnabled: Bool
    let hasOverride: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(feature.displayName)
                            .font(.body)

                        if hasOverride {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if feature.requiresPremium {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text(feature.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: .constant(isEnabled))
                    .labelsHidden()
                    .disabled(true) // Visual only, button handles toggle
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FeatureFlagsDebugView()
            .environment(ServiceContainer.shared)
    }
}
