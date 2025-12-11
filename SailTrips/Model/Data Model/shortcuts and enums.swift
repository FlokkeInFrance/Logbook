//
//  shortcuts.swift
//  SailTrips
//
//  Created by jeroen kok on 16/02/2025.
//

import SwiftUI
import SwiftData
import PDFKit
import UIKit // FIX: Needed for UIImage, UIColor, UIGraphicsImageRenderer

typealias Boat = CruiseDataSchemaV1.Boat
typealias CrewMember = CruiseDataSchemaV1.CrewMember
typealias Cruise = CruiseDataSchemaV1.Cruise
typealias Location = CruiseDataSchemaV1.Location
typealias Trip = CruiseDataSchemaV1.Trip
typealias Logs = CruiseDataSchemaV1.Logs
typealias ToService = CruiseDataSchemaV1.ToService
typealias ChecklistHeader = CruiseDataSchemaV1.ChecklistHeader
typealias ChecklistSection = CruiseDataSchemaV1.ChecklistSection
typealias ChecklistItem = CruiseDataSchemaV1.ChecklistItem
typealias BoatsLog = CruiseDataSchemaV1.BoatsLog
typealias BeaufortScale = CruiseDataSchemaV1.BeaufortScale
typealias Instances = CruiseDataSchemaV1.Instances
typealias MagVar = CruiseDataSchemaV1.MagVar
typealias Picture = CruiseDataSchemaV1.Picture
typealias Motor = CruiseDataSchemaV1.Motor
typealias Sail = CruiseDataSchemaV1.Sail
typealias Memento = CruiseDataSchemaV1.Memento
typealias LogbookSettings = CruiseDataSchemaV1.LogbookSettings
typealias InventoryItem = CruiseDataSchemaV1.InventoryItem

// MARK: - Pattern helpers

protocol DisplayableEnum {
    var label: LocalizedStringKey { get }
}

// MARK: - Boat / propulsion

enum PropulsionType: String, Codable, CaseIterable, Identifiable {
    case sailboat = "Sailboat"
    case motorboat = "Motorboat"
    case motorsailer = "Motorsailer" // FIX: spelling unified
    case unknown = "unknown"
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .sailboat: "Sailboat"
        case .motorboat: "Motorboat"
        case .motorsailer: "Motorsailer"
        case .unknown: "Unknown"
        }
    }
}

// MARK: - Boat type (UI + helper)

enum BoatType: String, Codable, CaseIterable, Identifiable {
    case sailboat = "Sailboat"
    case motorboat = "Motorboat"
    case fifty = "Motorsailer"  // FIX: unified spelling
    case sloop = "Sloop"
    case ketch = "Ketch"
    case cutter = "Cutter"
    case yawl = "Yawl"
    case schooner = "Schooner"
    case cat = "Catboat"
    var id: String { rawValue }
    
    func generateThumbnail(from data: Data) -> UIImage? {
        guard let pdfDocument = PDFDocument(data: data),
              let pdfPage = pdfDocument.page(at: 0) else { return nil }
        let pageRect = pdfPage.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            pdfPage.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}

enum BoatStatus: Int, Codable, CaseIterable, Identifiable {
    case selected = 0
    case inactive = 1
    case deleted = 2
    var id: Int { rawValue } // FIX: stable numeric id for lists
}

enum MotorUse: String, CaseIterable, Identifiable, Codable {
    case inboard = "inboard"
    case outboard = "outboard"
    case sailDrive = "sail_drive"
    case generator = "generator"
    case auxiliary = "auxiliary"
    case spare = "spare"
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .inboard: "Inboard"
        case .outboard: "Outboard"
        case .sailDrive: "Sail Drive"
        case .generator: "Generator"
        case .auxiliary: "Auxiliary"
        case .spare: "Spare"
        }
    }
}

enum MotorEnergy: String, CaseIterable, Identifiable, Codable {
    case diesel = "diesel"
    case gasoline = "gasoline"
    case electric = "electric"
    case hybrid = "hybrid"
    case avGas = "av_gas"
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .diesel: "Diesel"
        case .gasoline: "Gasoline"
        case .electric: "Electric"
        case .hybrid: "Hybrid"
        case .avGas: "AvGas"
        }
    }
}

//Extra Equipment


enum ExtraRigging: String, Codable, CaseIterable, Identifiable {
    case outrigger
    case spinnakerPole
    case whiskerPole
    case preventer
    case walder
    case customPreventer
    case lifelines
    case bowsprit
    case removableForestay
    case boom
    case other

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .outrigger:          "Outrigger"
        case .spinnakerPole:      "Spinnaker pole"
        case .whiskerPole:        "Whisker pole"
        case .preventer:          "Preventer"
        case .walder:             "Walder"
        case .customPreventer:    "Custom preventer"
        case .lifelines:          "Lifelines"
        case .bowsprit:           "Bowsprit"
        case .removableForestay:  "Removable forestay"
        case .boom:               "Boom"
        case .other:              "Other"
        }
    }
}


// MARK: - Checklists / UI aids

enum SectionColors: String, CaseIterable, Identifiable, Codable {
    case red, green, blue, black
    var id: String { rawValue }
    var swiftUIColor: Color {
        switch self {
        case .red: .red
        case .green: .green
        case .blue: .blue
        case .black: .black
        }
    }
}

// MARK: - Emergency / urgency / distress

enum EmergencyLevel: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case securite = "securite"
    case urgency = "urgency"
    case distress = "distress"
    var id: String { rawValue } // FIX: id from rawValue
    var label: LocalizedStringKey {
        switch self {
        case .none: "None"
        case .securite: "Sécurité"
        case .urgency: "Urgency / PAN PAN" // FIX: punctuation moved to label
        case .distress: "Mayday"
        }
    }
}

enum Emergencies: String, Codable, CaseIterable, Identifiable {
    case fire = "fire"
    case flooding = "flooding"
    case mob = "man_overboard"
    case mobOtherBoat = "mob_other_boat"
    case collision = "collision"
    case mechanical = "mechanical_failure"
    case weather = "weather"
    case assistance = "assistance_to_others"
    case health = "health_issue"
    case authorityRequest = "authority_request"
    case piracy = "piracy"
    case relay = "mayday relay"
    case none = "none"
    case other = "other emergency"
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .fire: "Fire"
        case .flooding: "Flooding"
        case .mob: "Man overboard"
        case .mobOtherBoat: "MOB on another boat"
        case .collision: "Collision"
        case .mechanical: "Mechanical failure"
        case .weather: "Weather"
        case .assistance: "Assistance to others"
        case .health: "Health issue"
        case .authorityRequest: "Authority request"
        case .relay: "Mayday Relay"
        case .piracy: "Piracy"
        case .other: "Other emergency"
        case .none: "None"
        }
    }
}

enum Urgencies: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case fire = "small_contained_fire"
    case drifting = "drifting"
    case motorFailure = "motor_failure"
    case propulsionFailure = "propulsion_failure"
    case weather = "weather"
    case assistance = "assistance_to_others"
    case health = "health_issue"
    case authorityRequest = "authority_request"
    case mechanicalFailure = "mechanical_failure"
    case dismasted = "dismasted"
    case rudder = "rudder_failure"
    case water = "water_ingress"
    var id: String { rawValue }
}

enum Distress: String, Codable, CaseIterable, Identifiable {
    case MOB = "mob"
    case Fire = "fire_on_board"
    case Flooding = "hull_flooding"
    case listing = "listing"
    case sinking = "boat_sinking"
    case medical = "serious_injury_disease"
    case aground = "run_aground"
    case Piracy = "piracy"
    case abandon = "abandon_ship"
    case relay = "mayday_relay"
    var id: String { rawValue }
}

// MARK: - Environment hazards

enum EnvironmentDangers: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case strongCurrents = "strong_currents" // FIX: keep one variant
    case traffic = "heavy_traffic"
    case floatingDebris = "floating_debris"
    case icebergs = "icebergs"
    case growlers = "growlers"
    case weeds = "dense_weeds"
    case nets = "fishing_nets"
    case collisionCourse = "collision_course"
    case uncharted = "uncharted_highs"
    case magAnomalies = "magnetic_anomalies"
    case animals = "hazardous_animals"
    case orcas = "Orca attack"
    case aggressiveWild = "aggressive_wildlife"
    case military = "military_presence"
    case submarine = "submarines"
    case observationStation = "observation_station"
    case floatingStructures = "floating_structures"
    case windMills = "windmills"
    case fixedStructures = "fixed_structures"
    case unPredictable = "unpredictable_vessels"
    case other = "other"
    var id: String { rawValue }
}

//Autopilot mode enum

enum Autopilot: String, Codable, CaseIterable, Identifiable {
    case off = "off"
    case onTWA = "on_twa"
    case onAWA = "on_awa"
    case onHdg = "on_hdg"
    case onCOG = "on_cog"
    case onTrack = "on_track"
    case unknown = "on_unknown"
    
    var id: String { rawValue }
    
    var label: LocalizedStringKey {
        switch self {
        case .off: "Off"
        case .onTWA: "On, Wind mode (True)"
        case .onAWA: "On, Wind mode (Apparent)"
        case .onHdg: "On, Heading mode"
        case .onCOG: "On, Course Over Ground"
        case .onTrack: "On, Track mode"
        case .unknown: "On, mode Unknown"
        }
    }
}

enum Steering: String, Codable, CaseIterable, Identifiable {
    case byHand = "hand_steering"
    case autopilot = "autopilot"
    case fixed = "fixed_rudder"
    case none = "free rudder"
    
    var id: String { rawValue }
    
    var label: LocalizedStringKey {
        switch self {
        case .byHand: "By hand"
        case .autopilot: "Autopilot"
        case .fixed: "Fixed rudder"
        case .none: "Free rudder"
        }
    }
}

enum MooringType: String, Codable, CaseIterable, Identifiable {
    case mooringBall = "mooring_ball"
    case chainMooring = "chain_mooring"
    case mooredOnBuoy = "moored_on_buoy"
    case mooredOnShore = "moored_to_shore" // FIX: clearer wording
    case atAnchor = "at_anchor"
    case double = "double_moored"
    case other = "other"
    case none = "none"
    var id: String { rawValue }
}

// MARK: - Sail states

enum SailState: String, Codable, CaseIterable, Identifiable {
    case rigged = "rigged"
    case reefed = "reefed"
    case lowered = "lowered/all_furled" //means on the boom or furled, not a propulsion tool anymore
    case full = "full" //means raised or hoisted
    case down = "down" //not rigged anymore
    case reef1 = "reef_1"
    case reef2 = "reef_2"
    case reef3 = "reef_3"
    case vlightFurled = "vlight_furled"
    case lightFurled = "light_furled"
    case halfFurled = "half_furled"
    case tightFurled = "tight_furled"
    case outOfOrder = "out_of_order" //not a propulsion Tool anymore
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .rigged: "rigged"
        case .reefed: "reefed"
        case .lowered: "lowered/all furled"
        case .full: "full"
        case .down: "down"
        case .reef1: "reef 1"
        case .reef2: "reef2"
        case .reef3: "reef_3"
        case .vlightFurled: "very lightly furled"
        case .lightFurled: "light_furled"
        case .halfFurled: "half_furled"
        case .tightFurled: "tight_furled"
        case .outOfOrder: "out_of_order"
        }
    }
}

enum ReductionMode: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case reef = "by reefing"
    case furl = "by lowering"
        var id: String { rawValue }
}

enum MotorState: String, Codable, CaseIterable, Identifiable {
    case idle = "idle"    // FIX: raw key stays lowercase
    case cruise = "cruise"
    case slow = "slow"
    case full = "full"
    case stopped = "stopped"
    case neutral = "neutral" // unclutched
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .idle: "Idle"
        case .cruise: "Cruising"
        case .slow: "Slow"
        case .full: "Full"
        case .stopped: "Stopped"
        case .neutral: "Neutral"
        }
    }
}

// MARK: - Cruise / Trips

enum TypeOfCruise: String, Codable, CaseIterable, Identifiable {
    case round = "round_trip"
    case fromTo = "to_destination"
    case convoyage = "convoyage"
    case test = "test"
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .round: "Round Trip"
        case .fromTo: "To Destination"
        case .convoyage: "Convoyage"
        case .test: "Test"
        }
    }
}

enum CruiseStatus: String, Codable, CaseIterable, Identifiable {
    case planned = "planned"
    case underway = "ongoing" // label can still show “Underway/Ongoing”
    case completed = "completed"
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .planned: "Planned"
        case .underway: "Ongoing"
        case .completed: "Completed"
            
        }
    }
}

enum TypeOfTrip: String, Codable, CaseIterable, Identifiable {
    case training = "training session"
    case testing = "testing session"
    case race = "race leg"
    case roundTrip = "round trip"
    case legOfCruise = "cruise leg"
    case toDestination = "trip to destination"
    case regatta = "regatta"
    var id: String { rawValue }
}


// MARK: - Propulsion / TripStatus/NavStatus/NavZone
//Used for Instances and describes how the boat runs

enum PropulsionTool: String, Codable, CaseIterable, Identifiable {
    case motor = "motor"
    case sail = "sails"
    case inTow = "in_tow"
    case motorsail = "motor_and_sail"
    case none = "none"
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .motor: "Motor"
        case .sail: "Sails"
        case .inTow: "In tow"
        case .motorsail: "Motor and Sail"
        case .none: "None"
        }
    }
}
enum TripStatus: String, Codable, CaseIterable, Identifiable {
    case preparing = "preparing"
    case started = "started"
    case underway = "underway"
    case interrupted = "interrupted"
    case completed = "completed"
    var id: String { rawValue }
}

enum NavStatus: String, Codable, CaseIterable, Identifiable {
    case barepoles = "bare poles"
    case heaveto = "heave to"
    case stopped = "moored or anchored"
    case underway = "en route"
    case stormTactics = "storm tactics"
    case none = "none"
    var id: String { rawValue }
}

enum NavZone: String, Codable, CaseIterable, Identifiable {
    case coastal = "coastal"
    case intracoastalWaterway = "intracoastal waterway"
    case approach = "approach"
    case protectedWater = "protected water"
    case openSea = "open sea"
    case harbour = "harbour"
    case anchorage = "anchorage"
    case buoyField = "buoy field"
    case traffic = "traffic lane"
    case none = "none"
    var id: String { rawValue }
}

// MARK: - Sailing geometry

enum Tack: String, Codable, CaseIterable, Identifiable {
    case starboard = "starboard"
    case port = "port"
    case none = "none"
    var id: String { rawValue }
}

enum PointOfSail: String, Codable, CaseIterable, Identifiable {
    case closeHauled = "close hauled"
    case closeReach = "close reach"
    case beamReach = "beam reach"
    case broadReach = "broad reach"
    case running = "running" // FIX: was "trainingRun"
    case deadRun = "dead run"
    case stopped = "stopped"
    var id: String { rawValue }
}

// MARK: - Weather

enum Precipitations: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case lightRain = "light_rain"
    case rain = "rain"
    case heavyRain = "heavy_rain"
    case drizzle = "drizzle"
    case lightSnow = "light_snow"
    case snow = "snow"
    case heavySnow = "heavy_snow"
    case hail = "hail"
    case damagingHail = "damaging_hail"
    case sleet = "sleet"
    case freezingRain = "freezing_rain"
    case graupel = "graupel"
    case crystals = "crystals"
    var id: String { rawValue }
}

enum SevereWeather: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case storm = "storm"
    case squall = "squall"
    case gale = "gale"
    case hurricane = "hurricane"
    case waterspout = "waterspout"
    case thunderstorm = "thunderstorm"
    case microburst = "microburst"
    case derecho = "derecho"
    case mesoscale = "mesoscale_convective_system"
    var id: String { rawValue }
}

// MARK: - Locations

enum TypeOfLocation: String, Codable, CaseIterable, Identifiable {
    case mooring = "mooring"
    case marina = "marina"
    case anchorage = "anchorage"
    case waypoint = "waypoint"
    case harbor = "harbor"
    case shelter = "shelter"
    case stormShelter = "storm_shelter"
    case pOI = "poi"
    var id: String { rawValue }
}


// MARK: - Misc

enum CruiseNav {
    case detail, list
}

enum LandmarkCategory: String, Codable, CaseIterable, Identifiable {
    case cliff = "cliff"
    case rock = "rock"
    case island = "island"
    case cliffside = "cliffside"
    case rockface = "rockface"
    case seaStack = "sea_stack"
    case seaCave = "sea_cave"
    case seaCrest = "sea_crest"
    case church = "church"
    case lighthouse = "lighthouse"
    case remarkableBuilding = "remarkable_building"
    case riverMound = "river_mound"
    case buoy = "buoy"
    case cape = "cape"
    case estuary = "estuary"
    case namedStructure = "named_structure"
    case cove = "cove"
    case transit = "transit" //alignement
    var id: String { rawValue }
}

enum LandmarkTransition: String, CaseIterable {
    case approach = "approaching"
    case round = "round"
    case leavingBehind = "leaving behind"
    case cross = "cross"
    case keepTransit = "keep transit"
    case keepFixedBearing = "keep fixed bearing on"
}

enum CrewIncident: String, CaseIterable {
    case seasick = " reported to be seasick"
    case sunburn = " has a sunburn"
    case toeInjury =  " got an injured toe"
    case ankleSprain = " got a sprained ankle"
    case wristSprain = " got a sprained wrist"
    case fingerBurned = " burned finger(s) during rope management"
    case cut = " got small cut, no special treatment required"
    case head = " suffered a minor head trauma"
    case fall = " was bruised from a fall"
    case headache = " has a headache"
    case backPain = " has back pain"
    case tired = " feels very tired"
    case sick = " is sick but doesn't require further medical care"
    case other = " other (precise)"
    case none = " "
}

enum Encounters: String, CaseIterable {
    case dolphin = "Dolphins"
    case whale = "Whales"
    case shark = "Sharks"
    case tortoises = "Tortoises"
    case penguins = "Penguins"
    case seals = "Seals"
    case birds = "Bird on Board"
    case swarm_insects = "Swarm of Insects"
    case boat = "Remarkable vessel"
    case friend = "Friend sailor"
    case auroras = "Auroras"
    case flying_fish = "Flying Fish"
    case other = "Other"
}

enum InventoryType: String, Codable, CaseIterable, Identifiable {
    case extraRigging
    case safety
    case tools
    case electronics
    case spares
    case provisioning
    case other

    var id: String { rawValue }
}

enum InventoryCategory: String, Codable, CaseIterable, Identifiable {
    case navigation
    case rigging
    case safety
    case comfort
    case maintenance
    case food
    case galley
    case other
    case spares
    

    var id: String { rawValue }
}

// MARK: - Autopilot helpers

extension Autopilot {

    /// Human-readable name for display in the UI.
    var displayName: String {
        if self == .off {
            return "Off"
        }

        // Try rawValue first if it exists, fall back to type name
        let base: String
        if let raw = (self as? any RawRepresentable)?.rawValue as? String {
            base = raw
        } else {
            base = String(describing: self)
        }

        return base
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    /// Whether this mode normally has a numeric target (heading, COG, etc.).
    /// We assume every non-off mode can take a direction/target angle.
    var needsDirection: Bool {
        self != .off
    }

    /// Default active mode when engaging AP from "off".
    /// We try to pick something that looks like "heading" first,
    /// otherwise just use the first non-off case.
    static var defaultEngagedMode: Autopilot {
        if let headingLike = Autopilot.allCases.first(where: {
            let name = String(describing: $0).lowercased()
            return $0 != .off && (name.contains("hdg") || name.contains("heading"))
        }) {
            return headingLike
        }

        return Autopilot.allCases.first(where: { $0 != .off }) ?? .off
    }
}
