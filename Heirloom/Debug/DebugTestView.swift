import SwiftUI
import SwiftData

#if DEBUG
/// Debug view for running in-app tests
/// Access via Debug menu or add to your app for easy testing
struct DebugTestView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var testResults: TestResults?
    @State private var isRunning = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let results = testResults {
                    // Results Display
                    ScrollView {
                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            // Summary Card
                            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                                Text("Test Results")
                                    .font(HeirloomFonts.bodyBold)

                                HStack(spacing: 20) {
                                    StatView(title: "Total", value: "\(results.total)", color: .blue)
                                    StatView(title: "Passed", value: "\(results.passed)", color: .green)
                                    StatView(title: "Failed", value: "\(results.failed)", color: results.failed > 0 ? .red : .gray)
                                }

                                if results.total > 0 {
                                    let passRate = Double(results.passed) / Double(results.total) * 100
                                    ProgressView(value: passRate, total: 100) {
                                        Text("\(String(format: "%.1f", passRate))% Pass Rate")
                                            .font(HeirloomFonts.caption1)
                                    }
                                    .tint(passRate == 100 ? .green : passRate >= 70 ? .orange : .red)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            if results.allPassed {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("All tests passed!")
                                        .fontWeight(.semibold)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            } else if results.failed > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Some tests failed - check console for details")
                                        .fontWeight(.semibold)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }

                            // Instructions
                            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                                Text("Console Output")
                                    .font(HeirloomFonts.bodyBold)
                                Text("Check Xcode console for detailed test output including pass/fail messages for each test.")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding()
                    }

                    Button("Run Tests Again") {
                        runTests()
                    }
                    .buttonStyle(.borderedProminent)

                } else {
                    // Initial State
                    VStack(spacing: HeirloomSpacing.md) {
                        Image(systemName: "flask.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Test Harness")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Run automated tests to validate:\n• Recipe Migration\n• Computed Properties\n• Multi-Recipe Import\n• Data Relationships")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Button(action: runTests) {
                            Label("Run All Tests", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isRunning)
                    }
                    .padding(40)
                }

                if isRunning {
                    ProgressView("Running tests...")
                        .padding()
                }
            }
            .navigationTitle("Debug Tests")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func runTests() {
        isRunning = true
        testResults = nil

        // Run tests after a brief delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let harness = TestHarness(modelContext: modelContext)
            let results = harness.runAllTests()
            testResults = results
            isRunning = false
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            Text(title)
                .font(HeirloomFonts.caption1)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    DebugTestView()
        .modelContainer(for: [Recipe.self, RecipeVersion.self, Ingredient.self])
}
#endif
