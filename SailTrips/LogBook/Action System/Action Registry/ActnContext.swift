//
//  ActionContext.swift
//  SailTrips
//
//  Created by jeroen kok on 28/11/2025.
//

// ActionContext.swift (or inside ActionVariants.swift)
// ActionContext.swift

// ActnContext.swift

import Foundation
import SwiftData
import SwiftUI

// MARK: - Requests

struct ActionConfirmRequest: Identifiable, Sendable {
    let id = UUID()

    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let completion: @Sendable (Bool) -> Void
}

struct PositionFix: Sendable {
    enum Source: Sendable { case phone, nmea, continuousStream, unknown }
    var lat: Double
    var lon: Double
    var timestamp: Date
    var source: Source
}

struct NavSensorsSnapshot: Sendable {
    var sog: Float?
    var cog: Int?
    var stw: Float?
    var awa: Int?
    var aws: Int?
    var twd: Int?
    var tws: Int?
    var magHeading: Int?
    // extend later
}

// MARK: - ActionContext

/// Important: must be a class (ObservableObject) because we publish sheet requests.
@MainActor
final class ActionContext: ObservableObject {

    // Core dependencies / environment
    let instances: Instances
    let currentSettings: () -> LogbookSettings
    let modelContext: ModelContext

    // UI / routing callbacks
    let showBanner: (String) -> Void
    let openDangerSheet: (ActionVariant) -> Void
    let presentTextPrompt: (ActionTextPromptRequest) -> Void
    let presentConfirm: (ActionConfirmRequest) -> Void
    let openSailingGeometrySheet: (ActionVariant) -> Void

    // Services
    let positionUpdater: PositionUpdater?

    /// last known NMEA snapshot provider
    let nmeaSnapshot: () -> NMEASnapshot?
    let presentSeaAnchorPrompt: (ActionChoicePromptRequest<SeaAnchorDeployment>) -> Void
    let presentSteeringPrompt: (ActionChoicePromptRequest<Steering>) -> Void

    init(
        instances: Instances,
        modelContext: ModelContext,
        currentSettings: @escaping () -> LogbookSettings = { LogbookSettings() },
        showBanner: @escaping (String) -> Void,
        openDangerSheet: @escaping (ActionVariant) -> Void,
        presentTextPrompt: @escaping (ActionTextPromptRequest) -> Void = { _ in },
        presentConfirm: @escaping (ActionConfirmRequest) -> Void = { _ in },
        openSailingGeometrySheet: @escaping (ActionVariant) -> Void,
        positionUpdater: PositionUpdater? = nil,
        nmeaSnapshot: @escaping () -> NMEASnapshot? = { nil },
        presentSeaAnchorPrompt: @escaping (ActionChoicePromptRequest<SeaAnchorDeployment>) -> Void = { _ in },
        presentSteeringPrompt: @escaping (ActionChoicePromptRequest<Steering>) -> Void = { _ in },
         
    ) {
        self.instances = instances
        self.modelContext = modelContext
        self.currentSettings = currentSettings

        self.showBanner = showBanner
        self.openDangerSheet = openDangerSheet
        self.presentTextPrompt = presentTextPrompt
        self.presentConfirm = presentConfirm
        self.openSailingGeometrySheet = openSailingGeometrySheet
        self.presentSeaAnchorPrompt = presentSeaAnchorPrompt
        self.presentSteeringPrompt = presentSteeringPrompt

        self.positionUpdater = positionUpdater
        self.nmeaSnapshot = nmeaSnapshot
    }

    // MARK: - Published sheet requests (Choice prompts)


    // MARK: - Async prompts

    func promptSeaAnchorDeployment(default def: SeaAnchorDeployment = .bow) async -> SeaAnchorDeployment? {
        await withCheckedContinuation { cont in
            let req = ActionChoicePromptRequest(
                title: "Sea anchor deployment",
                message: "Was the sea anchor deployed from the bow (default) or from the stern?",
                choices: SeaAnchorDeployment.allCases,
                choiceLabel: { $0.displayString },
                defaultChoice: def,
                completion: { choice in cont.resume(returning: choice) }
            )
            self.presentSeaAnchorPrompt(req)
        }
    }

    func promptSteering(default def: Steering = .byHand) async -> Steering? {
        await withCheckedContinuation { cont in
            let req = ActionChoicePromptRequest(
                title: "Steering",
                message: "Select the steering method to use in these conditions.",
                choices: Steering.allCases,
                choiceLabel: { $0.displayString },
                defaultChoice: def,
                completion: { choice in cont.resume(returning: choice) }
            )
            self.presentSteeringPrompt(req)
        }
    }

    // MARK: - Existing prompts

    /// Generic single-line prompt (already uses presenter closure, so no @Published needed).
    func promptSingleLine(
        title: String,
        message: String? = nil,
        placeholder: String = "",
        initialText: String = "",
        allowEmpty: Bool = true
    ) async -> String? {
        await withCheckedContinuation { continuation in
            let request = ActionTextPromptRequest(
                title: title,
                message: message,
                placeholder: placeholder,
                initialText: initialText,
                allowEmpty: allowEmpty
            ) { result in
                continuation.resume(returning: result)
            }

            self.presentTextPrompt(request)
        }
    }

    func confirm(
        title: String,
        message: String,
        confirmTitle: String = "Review",
        cancelTitle: String = "Keep"
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let req = ActionConfirmRequest(
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                cancelTitle: cancelTitle
            ) { result in
                continuation.resume(returning: result)
            }

            self.presentConfirm(req)
        }
    }
}
