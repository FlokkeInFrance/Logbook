
//  SailTrips
//
//  Created by jeroen kok on 11/12/2025.
//

//  SailingLogStrings.swift
//  SailTrips
//
//  Centralized, localizable strings for sailing geometry logs.
//

import Foundation

enum SailingLogStrings {
    static func tackWord(_ tack: Tack) -> String { tack.displayString }
    static func pointOfSailWord(_ pos: PointOfSail) -> String { pos.displayString }

    static func headingPhrase(old: Int, new: Int) -> String {
        guard new != 0 else { return "" }
        if old != 0, old != new {
            return " heading changed from \(old)° to \(new)°"
        } else {
            return " heading \(new)°"
        }
    }

    static func pointOfSailPhrase(old: PointOfSail, new: PointOfSail, underMotorOnly: Bool) -> String {
        guard !underMotorOnly else { return "" }
        guard old != new else { return "" }
        return " point of sail \(pointOfSailWord(new))"
    }

    static func tackPhrase(old: Tack, new: Tack, underMotorOnly: Bool) -> String {
        guard !underMotorOnly else { return "" }
        guard new != .none else { return "" }
        guard old != new else { return "" }
        return " on \(tackWord(new)) tack"
    }

    static func prefix(for tag: String, underMotorOnly: Bool) -> String {
        switch (tag, underMotorOnly) {
        case ("A27", false): return "Sail configuration:"
        case ("A27", true):  return "Course change:"
        case ("A39", false): return "Tack:"
        case ("A39", true):  return "Turned to"
        case ("A40", false): return "Gybe:"
        case ("A40", true):  return "Turned to"
        case ("A43", false): return "Fell off:"
        case ("A43", true):  return "Course changed"
        case ("A44", false): return "Luffed up:"
        case ("A44", true):  return "New course:"
        default:
            return underMotorOnly ? "Under power:" : "Sailing:"
        }
    }
}
