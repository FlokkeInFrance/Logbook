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
    var instances: Instances
    var modelContext: ModelContext
    var showBanner: (String) -> Void
    var openDangerSheet: (ActionVariant) -> Void
}

