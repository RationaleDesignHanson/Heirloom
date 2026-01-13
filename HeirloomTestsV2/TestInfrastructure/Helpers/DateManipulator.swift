//
//  DateManipulator.swift
//  HeirloomTestsV2
//
//  Utility for manipulating dates in tests (time travel)
//  Created: 2026-01-13
//

import Foundation

/// Utility for date manipulation in tests
/// Provides "time travel" capabilities for testing date-based logic
enum DateManipulator {

    // MARK: - Relative Dates

    /// Get date N days ago from now
    static func daysAgo(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    /// Get date N days from now
    static func daysFromNow(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: Date())!
    }

    /// Get date N hours ago from now
    static func hoursAgo(_ hours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: -hours, to: Date())!
    }

    /// Get date N hours from now
    static func hoursFromNow(_ hours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: hours, to: Date())!
    }

    // MARK: - Trial-Specific Dates

    /// Get trial start date for a specific day in trial (0 = today, 7 = 7 days ago, etc.)
    static func trialStartDate(forDay day: Int) -> Date {
        return daysAgo(day)
    }

    /// Get trial expiry date for a specific day in trial (14-day trial)
    static func trialExpiryDate(forDay day: Int) -> Date {
        let daysRemaining = 14 - day
        return daysFromNow(daysRemaining)
    }

    // MARK: - Cooldown-Specific Dates

    /// Get date for cooldown period (48 hours)
    static func cooldown48HoursAgo() -> Date {
        return hoursAgo(48)
    }

    /// Get date for cooldown period (72 hours)
    static func cooldown72HoursAgo() -> Date {
        return hoursAgo(72)
    }

    /// Get date that's within cooldown (1 hour ago)
    static func withinCooldown() -> Date {
        return hoursAgo(1)
    }

    /// Get date that's outside cooldown (100 hours ago)
    static func outsideCooldown() -> Date {
        return hoursAgo(100)
    }

    // MARK: - Date Comparison Helpers

    /// Check if date is today
    static func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }

    /// Check if date is yesterday
    static func isYesterday(_ date: Date) -> Bool {
        return Calendar.current.isDateInYesterday(date)
    }

    /// Days between two dates
    static func daysBetween(_ start: Date, _ end: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Hours between two dates
    static func hoursBetween(_ start: Date, _ end: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: start, to: end).hour ?? 0
    }

    // MARK: - Boundary Dates

    /// Get date at start of today (00:00:00)
    static func startOfToday() -> Date {
        return Calendar.current.startOfDay(for: Date())
    }

    /// Get date at end of today (23:59:59)
    static func endOfToday() -> Date {
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday())!
        return Calendar.current.date(byAdding: .second, value: -1, to: startOfTomorrow)!
    }

    // MARK: - Subscription-Specific Dates

    /// Get date far in the past (expired subscription)
    static func expiredSubscription() -> Date {
        return daysAgo(30)
    }

    /// Get date far in the future (active subscription)
    static func activeSubscription() -> Date {
        return Date(timeIntervalSinceNow: 365 * 24 * 60 * 60) // 1 year from now
    }
}

// MARK: - XCTestCase Extension

#if canImport(XCTest)
import XCTest

extension XCTestCase {

    /// Assert that two dates are within N seconds of each other
    func assertDatesEqual(
        _ date1: Date?,
        _ date2: Date?,
        within seconds: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let date1 = date1, let date2 = date2 else {
            XCTFail("One or both dates are nil", file: file, line: line)
            return
        }

        let difference = abs(date1.timeIntervalSince(date2))
        XCTAssertLessThanOrEqual(
            difference,
            seconds,
            "Dates differ by \(difference) seconds (expected within \(seconds) seconds)",
            file: file,
            line: line
        )
    }

    /// Assert that date is approximately now (within 1 second)
    func assertDateIsNow(
        _ date: Date?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assertDatesEqual(date, Date(), within: 1.0, file: file, line: line)
    }
}
#endif
