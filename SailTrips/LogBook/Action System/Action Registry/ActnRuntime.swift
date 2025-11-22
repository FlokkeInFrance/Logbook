//
//  ActionRuntime.swift
//  SailTrips
//
//  Created by jeroen kok on 29/11/2025.
//

import SwiftData

struct ActionRuntime {
    let context: ActionContext
    let variant: ActionVariant

    var instances: Instances { context.instances }
    var modelContext: ModelContext { context.modelContext }
    var showBanner: (String) -> Void { context.showBanner }
    var openDangerSheet: (ActionVariant) -> Void { context.openDangerSheet }
    let A11HR_InHarbourHandler: ActionHandler = { runtime in
        await handleInHarbourAction(runtime: runtime)
    }

    // Convenience if you add more to ActionContext later (e.g. locations, tripDestination)
}

