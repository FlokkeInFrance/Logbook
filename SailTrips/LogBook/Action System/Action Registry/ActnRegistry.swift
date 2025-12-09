//
//  Action Registry.swift
//  SailTrips
//
//  Created by jeroen kok on 24/11/2025.
//

// ActionRegistry.swift
// Central registry for all logbook actions + situation layouts

//
//  ActionRegistry.swift
//  SailTrips
//
//  Created by ChatGPT on 25/11/2025.
//

import Foundation
import SwiftUI

/// Central registry of all Log actions + where they appear.
/// For v1 this is hard-coded but structured so you can easily extend it.
struct ActionRegistry {
    private var variants: [String: ActionVariant] = [:]

    init(variants: [String: ActionVariant] = [:]) {
        self.variants = variants
    }

    // MARK: - Registration

    //struct ActionRegistry {
      //  private var variants: [String: ActionVariant] = [:]

        @discardableResult
        mutating func add(
            _ tag: String,
            title: LocalizedStringKey,
            group: ActionGroup = .generic,
            systemImage: String? = nil,
            isEmphasised: Bool = false,
            isVisible: @escaping ActionVisibilityPredicate = { _ in true },
            handler: @escaping ActionHandler = { _ in }
        ) -> ActionRegistry {
            let variant = ActionVariant(
                tag: tag,
                title: title,
                systemImage: systemImage,
                group: group,
                isEmphasised: isEmphasised,
                isVisible: isVisible,
                handler: handler
            )
            variants[tag] = variant
            return self
        }

        func variant(for tag: String) -> ActionVariant? {
            variants[tag]
        }

        func variants(for tags: [String]) -> [ActionVariant] {
            tags.compactMap { variants[$0] }
        }
        
        /// Convenience: filter only visible ones for the current runtime.
        func visibleVariants(for tags: [String], in runtime: ActionRuntime) -> [ActionVariant] {
            variants(for: tags).filter { $0.isVisible(runtime) }
        }
    //}

}


extension ActionRegistry {

    static func logSimple(_ message: String, using ctx: ActionContext) {
        
        guard let trip = ctx.instances.currentTrip else {
            ctx.showBanner("No active Trip – action not logged.")
            return
        }
        let modelContext = ctx.modelContext
        let log = Logs(trip: trip)
        log.dateOfLog = Date()
        log.posLat = ctx.instances.gpsCoordinatesLat
        log.posLong = ctx.instances.gpsCoordinatesLong
        log.logEntry = message

        modelContext.insert(log)
        do {
            try modelContext.save()
            ctx.showBanner("Logged: \(message)")
        } catch {
            ctx.showBanner("Could not save log (\(error.localizedDescription))")
        }
    }
}



