//
//  ActionContext.swift
//  SailTrips
//
//  Created by jeroen kok on 28/11/2025.
//

// ActionContext.swift (or inside ActionVariants.swift)
import SwiftData
import Foundation

/// Runtime context passed to every action when it is executed.
struct ActionContext {
    /// Shared runtime state (your central Instances object).
    var instances: Instances

    /// SwiftData context to insert / update models.
    var modelContext: ModelContext

    /// UI feedback: show a short banner/toast message.
    var showBanner: (String) -> Void

    /// UI feedback: open the Environment Danger sheet.
    /// Only AF1 (and maybe future actions) will use this.
    var openDangerSheet: (ActionVariant) -> Void
}

