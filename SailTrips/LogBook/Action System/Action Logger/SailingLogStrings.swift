//
//  Untitled.swift
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

    // MARK: - Basic words

    static func tackWord(_ tack: Tack) -> String {
        switch tack {
        case .port:
            return NSLocalizedString("log.tack.port",
                                     comment: "Short word for port tack")
        case .starboard:
            return NSLocalizedString("log.tack.starboard",
                                     comment: "Short word for starboard tack")
        case .none:
            return NSLocalizedString("log.tack.none",
                                     comment: "No tack / unknown tack")
        }
    }

    static func pointOfSailWord(_ pos: PointOfSail) -> String {
        switch pos {
        case .closeHauled:
            return NSLocalizedString("log.pos.closeHauled",
                                     comment: "Point of sail: close hauled")
        case .closeReach:
            return NSLocalizedString("log.pos.closeReach",
                                     comment: "Point of sail: close reach")
        case .beamReach:
            return NSLocalizedString("log.pos.beamReach",
                                     comment: "Point of sail: beam reach")
        case .broadReach:
            return NSLocalizedString("log.pos.broadReach",
                                     comment: "Point of sail: broad reach")
        case .running:
            return NSLocalizedString("log.pos.running",
                                     comment: "Point of sail: running")
        case .deadRun:
            return NSLocalizedString("log.pos.deadRun",
                                     comment: "Point of sail: dead run")
        case .stopped:
            return NSLocalizedString("log.pos.stopped",
                                     comment: "Point of sail: stopped")
        }
    }

    // MARK: - Phrases for segments

    /// e.g. " heading changed from 90° to 210°"
    static func headingPhrase(old: Int, new: Int) -> String {
        guard new != 0 else { return "" }

        if old != 0, old != new {
            let fmt = NSLocalizedString(
                "log.heading.changed",
                comment: "Heading changed from old° to new°"
            )
            return " " + String(format: fmt, old, new)
        } else {
            let fmt = NSLocalizedString(
                "log.heading.current",
                comment: "Current heading value"
            )
            return " " + String(format: fmt, new)
        }
    }

    /// e.g. " now close hauled" or " close hauled"
    static func pointOfSailPhrase(old: PointOfSail,
                                  new: PointOfSail,
                                  underMotorOnly: Bool) -> String {
        guard !underMotorOnly else { return "" }

        let word = pointOfSailWord(new)

        if old != new {
            let fmt = NSLocalizedString(
                "log.pos.now",
                comment: "Phrase 'now <point of sail>'"
            )
            return " " + String(format: fmt, word)
        } else {
            let fmt = NSLocalizedString(
                "log.pos.same",
                comment: "Phrase '<point of sail>' when unchanged"
            )
            return " " + String(format: fmt, word)
        }
    }

    /// e.g. " on port tack" or " from starboard to port"
    static func tackPhrase(old: Tack,
                           new: Tack,
                           underMotorOnly: Bool) -> String {
        guard !underMotorOnly else { return "" }
        guard new != .none else { return "" }

        let newWord = tackWord(new)

        if old != .none, old != new {
            let oldWord = tackWord(old)
            let fmt = NSLocalizedString(
                "log.tack.change",
                comment: "Phrase 'from <old> to <new>' for tack change"
            )
            return " " + String(format: fmt, oldWord, newWord)
        } else {
            let fmt = NSLocalizedString(
                "log.tack.on",
                comment: "Phrase 'on <tack> tack'"
            )
            return " " + String(format: fmt, newWord)
        }
    }

    // MARK: - Prefix per action

    static func prefix(for tag: String, underMotorOnly: Bool) -> String {
        switch (tag, underMotorOnly) {

        // Sails set
        case ("A27", false):
            return NSLocalizedString("log.prefix.A27.sail",
                                     comment: "Prefix for 'sails set' under sail")
        case ("A27", true):
            return NSLocalizedString("log.prefix.A27.motor",
                                     comment: "Prefix for 'sails set' under motor")

        // Change course
        case ("A23", false):
            return NSLocalizedString("log.prefix.A23.sail",
                                     comment: "Prefix for 'course changed' under sail")
        case ("A23", true):
            return NSLocalizedString("log.prefix.A23.motor",
                                     comment: "Prefix for 'course changed' under motor")

        // Deviation / back on route
        case ("A21", false):
            return NSLocalizedString("log.prefix.A21.sail",
                                     comment: "Prefix for 'deviation from route' under sail")
        case ("A21", true):
            return NSLocalizedString("log.prefix.A21.motor",
                                     comment: "Prefix for 'deviation from route' under motor")

        case ("A20", false):
            return NSLocalizedString("log.prefix.A20.sail",
                                     comment: "Prefix for 'back on route' under sail")
        case ("A20", true):
            return NSLocalizedString("log.prefix.A20.motor",
                                     comment: "Prefix for 'back on route' under motor")

        // Tack / gybe / fall off / luff
        case ("A39", false):
            return NSLocalizedString("log.prefix.A39.sail",
                                     comment: "Prefix for 'tack' under sail")
        case ("A39", true):
            return NSLocalizedString("log.prefix.A39.motor",
                                     comment: "Prefix for 'tack' under motor")

        case ("A40", false):
            return NSLocalizedString("log.prefix.A40.sail",
                                     comment: "Prefix for 'gybe' under sail")
        case ("A40", true):
            return NSLocalizedString("log.prefix.A40.motor",
                                     comment: "Prefix for 'gybe' under motor")

        case ("A43", false):
            return NSLocalizedString("log.prefix.A43.sail",
                                     comment: "Prefix for 'fall off' under sail")
        case ("A43", true):
            return NSLocalizedString("log.prefix.A43.motor",
                                     comment: "Prefix for 'fall off' under motor")

        case ("A44", false):
            return NSLocalizedString("log.prefix.A44.sail",
                                     comment: "Prefix for 'luff' under sail")
        case ("A44", true):
            return NSLocalizedString("log.prefix.A44.motor",
                                     comment: "Prefix for 'luff' under motor")

        // Default / fallback
        default:
            if underMotorOnly {
                return NSLocalizedString("log.prefix.default.motor",
                                         comment: "Generic prefix for heading change under motor")
            } else {
                return NSLocalizedString("log.prefix.default.sail",
                                         comment: "Generic prefix for sailing data update")
            }
        }
    }

    // MARK: - Default full messages

    static func defaultHeadingUpdatedUnderPower() -> String {
        NSLocalizedString(
            "log.default.headingUpdatedMotor",
            comment: "Full message: heading updated under power"
        )
    }

    static func defaultSailingDataUpdated() -> String {
        NSLocalizedString(
            "log.default.sailingDataUpdated",
            comment: "Full message: sailing data updated"
        )
    }
}
