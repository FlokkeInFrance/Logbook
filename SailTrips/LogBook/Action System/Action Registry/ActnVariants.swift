//
//  ActionVariants.swift
//  SailTrips
//
//  Created by jeroen kok on 24/11/2025.
//
//
//  ActionVariants.swift
//  SailTrips
//
//  Created by jeroen kok on 24/11/2025.
//

import Foundation
import SwiftUI
import SwiftData

/// Coarse group for UI layout (sections / colors etc).
enum ActionGroup {
    case emergency
    case checklist
    case incident
    case motor
    case navigation
    case environment
    case otherLog
    case generic
    case sailPlan
}

enum LogActionCode: String, CaseIterable {
    case A1 = "A1"
    case A1R = "A1R"
    case A1A = "A1A"
    case A2 = "A2"
    case A3 = "A3"
    case A4 = "A4"
    case A5 = "A5"
    case A6 = "A6"
    case A7M = "A7M"
    case A7A = "A7A"
    case A8M = "A8M"
    case A8A = "A8A"
    case A9 = "A9"
    case A10 = "A10"
    case A11H = "A11H"
    case A11HR = "A11HR"
    case A11A = "A11A"
    case A11AR = "A11AR"
    case A11B = "A11B"
    case A11BR = "A11BR"
    case A12 = "A12"
    case A13 = "A13"
    case A14 = "A14"
    case A15 = "A15"
    case A16 = "A16"
    case A17 = "A17"
    case A18 = "A18"
    case A19 = "A19"
    case A20 = "A20"
    case A21 = "A21"
    case A22 = "A22"
    case A23 = "A23"
    case A24 = "A24"
    case A24R = "A24R"
    case A25 = "A25"
    case A25R = "A25R"
    case A26 = "A26"
    case A27 = "A27"
    case A27R = "A27R"
    case A28 = "A28"
    case A29 = "A29"
    case A29R = "A29R"
    case A30 = "A30"
    case A30R = "A30R"
    case A31 = "A31"
    case A31R = "A31R"
    case A32 = "A32"
    case A32R = "A32R"
    case A33R = "A33R"
    case A33F = "A33F"
    case A34 = "A34"
    case A35R = "A35R"
    case A35F = "A35F"
    case A36 = "A36"
    case A37 = "A37"
    case A38 = "A38"
    case A39 = "A39"
    case A40 = "A40"
    case A41 = "A41"
    case A42 = "A42"
    case A43 = "A43"
    case A44 = "A44"
    case A45 = "A45"
    case A46 = "A46"
    case A47 = "A47"
    case A48 = "A48"
    case A49 = "A49"
    case A50 = "A50"
    case A51 = "A51"

    case E1 = "E1"
    case E2 = "E2"
    case E4 = "E4"
    case E3 = "E3"

    case AF1 = "AF1"
    case AF2 = "AF2"
    case AF2R = "AF2R"
    case AF21 = "AF21"
    case AF2S = "AF2S"
    case AF3N = "AF3N"
    case AF3D = "AF3D"
    case AF4 = "AF4"
    case AF5 = "AF5"
    case AF6 = "AF6"
    case AF7 = "AF7"
    case AF8 = "AF8"
    case AF9 = "AF9"
    case AF10 = "AF10"
    case AF11 = "AF11"
    //case AF12 = "AF12"
    case AF14 = "AF14"
    case AF15 = "AF15"
    case AF16 = "AF16"
    case AF17 = "AF17"

    case EM1 = "EM1"
    case EM2 = "EM2"
    case EM3 = "EM3"
    case EM4 = "EM4"
    case EM5 = "EM5"
    case EM6 = "EM6"
    case EM7 = "EM7"
    case EM8 = "EM8"
    case EM9 = "EM9"
    case EM10 = "EM10"
    case EM11 = "EM11"
    case EM12 = "EM12"
    case EM13 = "EM13"
    case EM14 = "EM14"
}


/// Unique variant key: same base action (A11) but multiple context variants (“harbour”, “anchorage”…)
/*struct ActionVariantID: Hashable {
    let id: String       // e.g. "A11"
    let variantKey: String  // e.g. "harbour", "anchorage", "buoyField"
}*/


enum ActionIcon {
    case sfSymbol(String)
    case emoji(String)
}


/// Everything an action needs to know / mutate.
/*struct ActionRuntime {
    let modelContext: ModelContext
    let instances: Instances
    let boat: Boat?
    // add more as needed: trip, cruise, sensors, etc.
}*/

typealias ActionVisibilityPredicate = (ActionRuntime) -> Bool
typealias ActionHandler = (ActionRuntime) -> Void

struct ActionVariant: Identifiable {

    let tag: String
    let title: LocalizedStringKey /// User-facing label (short, for the button).
    let systemImage: String? /// Optional SF Symbol name.
    let group: ActionGroup    /// Visual grouping (Motor, Navigation, Emergency, etc.)
    let isEmphasised: Bool /// Emphasis for UI (e.g. emergencies, primary actions).
    let isVisible: ActionVisibilityPredicate/// Whether this action should be shown in the *current* runtime context.
    let handler: ActionHandler /// What actually happens: instance updates, logs, sheets, etc.
    
    var id: String { tag }
    
    init(
        tag: String,
        title: LocalizedStringKey,
        systemImage: String? = nil,
        group: ActionGroup = .generic,
        isEmphasised: Bool = false,
        isVisible: @escaping ActionVisibilityPredicate = { _ in true },
        handler: @escaping ActionHandler = { _ in }
    ) {
        self.tag = tag
        self.title = title
        self.systemImage = systemImage
        self.group = group
        self.isEmphasised = isEmphasised
        self.isVisible = isVisible
        self.handler = handler
    }
}

