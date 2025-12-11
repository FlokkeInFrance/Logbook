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
/*struct ActionContext { // old working version before text prompt
    var instances: Instances
    var modelContext: ModelContext
    var showBanner: (String) -> Void
    var openDangerSheet: (ActionVariant) -> Void
}*/

struct ActionContext {
    let instances: Instances
    let modelContext: ModelContext
    let showBanner: (String) -> Void
    let openDangerSheet: (ActionVariant) -> Void

    // NEW: hook into UI to show a one-line text prompt
    let presentTextPrompt: (ActionTextPromptRequest) -> Void

    init(
        instances: Instances,
        modelContext: ModelContext,
        showBanner: @escaping (String) -> Void,
        openDangerSheet: @escaping (ActionVariant) -> Void,
        presentTextPrompt: @escaping (ActionTextPromptRequest) -> Void = { _ in }
    ) {
        self.instances = instances
        self.modelContext = modelContext
        self.showBanner = showBanner
        self.openDangerSheet = openDangerSheet
        self.presentTextPrompt = presentTextPrompt
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
