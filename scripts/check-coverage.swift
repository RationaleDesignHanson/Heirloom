#!/usr/bin/env swift
//
//  check-coverage.swift
//  Heirloom
//
//  Parse test coverage and validate thresholds
//  Usage: swift check-coverage.swift [coverage.json]
//

import Foundation

// MARK: - Configuration

struct CoverageThresholds {
    let overall: Double = 0.60 // 60% overall coverage
    let criticalPaths: [String: Double] = [
        "SubscriptionManager": 1.0,   // 100% - Revenue critical
        "PaywallManager": 1.0,         // 100% - Revenue critical
        "HeritageUnlockTracker": 1.0,  // 100% - Revenue critical
        "StoreManager": 0.80,          // 80% - Payment logic
        "FirebaseShareService": 0.80,  // 80% - Data integrity
        "VideoRecipeProcessor": 0.80   // 80% - Complex flow
    ]
}

// MARK: - Models

struct CoverageReport: Codable {
    let targets: [Target]

    struct Target: Codable {
        let name: String
        let lineCoverage: Double
        let files: [File]

        struct File: Codable {
            let path: String
            let lineCoverage: Double
        }
    }
}

// MARK: - Main

func main() {
    let thresholds = CoverageThresholds()

    // Get coverage file path from arguments or use default
    let coverageFilePath: String
    if CommandLine.arguments.count > 1 {
        coverageFilePath = CommandLine.arguments[1]
    } else {
        coverageFilePath = ".build/coverage.json"
    }

    // Read and parse coverage file
    guard let coverageData = FileManager.default.contents(atPath: coverageFilePath) else {
        printError("❌ Coverage file not found: \(coverageFilePath)")
        printError("Run tests with coverage enabled first:")
        printError("  xcodebuild test -scheme Heirloom -enableCodeCoverage YES")
        exit(1)
    }

    guard let report = try? JSONDecoder().decode(CoverageReport.self, from: coverageData) else {
        printError("❌ Failed to parse coverage JSON")
        exit(1)
    }

    // Validate coverage
    var hasFailures = false

    // 1. Check overall coverage
    printSection("Overall Coverage")
    let overallCoverage = calculateOverallCoverage(report: report)
    printCoverage(name: "Overall", coverage: overallCoverage, threshold: thresholds.overall)

    if overallCoverage < thresholds.overall {
        hasFailures = true
        printError("  ❌ Below threshold: \(Int(thresholds.overall * 100))%")
    } else {
        printSuccess("  ✅ Above threshold")
    }

    // 2. Check critical paths
    printSection("Critical Paths")
    for (className, threshold) in thresholds.criticalPaths.sorted(by: { $0.key < $1.key }) {
        if let coverage = findClassCoverage(className: className, report: report) {
            printCoverage(name: className, coverage: coverage, threshold: threshold)

            if coverage < threshold {
                hasFailures = true
                printError("  ❌ Below threshold: \(Int(threshold * 100))%")
            } else {
                printSuccess("  ✅ Above threshold")
            }
        } else {
            printWarning("⚠️  \(className): Not found in coverage report")
        }
    }

    // 3. Summary
    printSection("Summary")
    if hasFailures {
        printError("❌ Coverage check FAILED")
        printError("Some files are below required thresholds")
        exit(1)
    } else {
        printSuccess("✅ Coverage check PASSED")
        printSuccess("All thresholds met!")
        exit(0)
    }
}

// MARK: - Helpers

func calculateOverallCoverage(report: CoverageReport) -> Double {
    guard let mainTarget = report.targets.first(where: { $0.name == "Heirloom" }) else {
        return 0.0
    }
    return mainTarget.lineCoverage
}

func findClassCoverage(className: String, report: CoverageReport) -> Double? {
    guard let mainTarget = report.targets.first(where: { $0.name == "Heirloom" }) else {
        return nil
    }

    for file in mainTarget.files {
        if file.path.contains("\(className).swift") {
            return file.lineCoverage
        }
    }

    return nil
}

func printSection(_ title: String) {
    print("\n" + "=".repeating(count: 60))
    print(title)
    print("=".repeating(count: 60))
}

func printCoverage(name: String, coverage: Double, threshold: Double) {
    let percentage = Int(coverage * 100)
    let thresholdPercentage = Int(threshold * 100)
    print("\(name): \(percentage)% (threshold: \(thresholdPercentage)%)")
}

func printSuccess(_ message: String) {
    print("\u{001B}[0;32m\(message)\u{001B}[0;0m") // Green
}

func printError(_ message: String) {
    print("\u{001B}[0;31m\(message)\u{001B}[0;0m") // Red
}

func printWarning(_ message: String) {
    print("\u{001B}[0;33m\(message)\u{001B}[0;0m") // Yellow
}

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// Run main
main()
