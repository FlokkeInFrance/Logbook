//
//  extensions.swift
//  SailTrips
//
//  Created by jeroen kok on 30/05/2025.
//

import Foundation
import SwiftUI

extension Date {
    private var calendar: Calendar { .current }
    
    /// Returns true if `self` is on the same calendar day as `other`.
    func isSame(_ other: Date) -> Bool {
        return calendar.isDate(self, equalTo: other, toGranularity: .day)
    }

    /// Returns true if `self` is at least one calendar‐day before `other`.
    func isBefore(_ other: Date) -> Bool {
        return calendar.compare(self, to: other, toGranularity: .day) == .orderedAscending
    }
    
    func isBeforeOrSame(_ other: Date) -> Bool {
        return isBefore(other) || isSame(other)
    }
    
    func isAfterOrSame(_ other: Date) -> Bool {
        return isAfter(other) || isSame(other)
    }

    /// Returns true if `self` is at least one calendar‐day after `other`.
    func isAfter(_ other: Date) -> Bool {
        return calendar.compare(self, to: other, toGranularity: .day) == .orderedDescending
    }

    /// Returns a new Date by adding the given number of days.
    func addingDays(_ days: Int) -> Date {
        guard let d = calendar.date(byAdding: .day, value: days, to: self) else { return self }
        return d
    }

    /// Returns a new Date by adding the given number of months.
    func addingMonths(_ months: Int) -> Date {
        guard let d = calendar.date(byAdding: .month, value: months, to: self) else { return self }
        return d
    }

    /// Returns a new Date by adding the given number of years.
    func addingYears(_ years: Int) -> Date {
        guard let d = calendar.date(byAdding: .year, value: years, to: self) else { return self }
        return d
    }

    /// Convenience: how many whole days separate `self` and `other` (positive if `other` is later).
    func days(until other: Date) -> Int? {
        let start = calendar.startOfDay(for: self)
        let end   = calendar.startOfDay(for: other)
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}
