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
    // (extend later when you wire more PGNs/sentences)
}

// ActnContext.swift

struct ActionContext {
    let instances: Instances
    let modelContext: ModelContext
    let showBanner: (String) -> Void
    let openDangerSheet: (ActionVariant) -> Void
    let presentTextPrompt: (ActionTextPromptRequest) -> Void

    let positionUpdater: PositionUpdater?

    /// NEW: last known NMEA snapshot
    let nmeaSnapshot: () -> NMEASnapshot?

    init(
        instances: Instances,
        modelContext: ModelContext,
        showBanner: @escaping (String) -> Void,
        openDangerSheet: @escaping (ActionVariant) -> Void,
        presentTextPrompt: @escaping (ActionTextPromptRequest) -> Void = { _ in },
        positionUpdater: PositionUpdater? = nil,
        nmeaSnapshot: @escaping () -> NMEASnapshot? = { nil }
    ) {
        self.instances = instances
        self.modelContext = modelContext
        self.showBanner = showBanner
        self.openDangerSheet = openDangerSheet
        self.presentTextPrompt = presentTextPrompt
        self.positionUpdater = positionUpdater
        self.nmeaSnapshot = nmeaSnapshot
    }
}


extension ActionContext {
    /// Shows a generic single-line text prompt and returns the result.
    /// - Returns: `nil` if user cancelled. Empty string if allowed and user left it blank.
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

            presentTextPrompt(request)
        }
    }
}
