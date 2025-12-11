//
//  ActionTextPrompt.swift
//  SailTrips
//
//  Created by jeroen kok on 10/12/2025.
//

import SwiftUI

/// Request object that bridges from the action system to the UI sheet.
struct ActionTextPromptRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let placeholder: String
    let initialText: String
    let allowEmpty: Bool
    let completion: (String?) -> Void
}

/// Simple one-line text input sheet.
struct SingleLineTextPromptSheet: View {
    @Environment(\.dismiss) private var dismiss

    let request: ActionTextPromptRequest
    @State private var text: String

    init(request: ActionTextPromptRequest) {
        self.request = request
        _text = State(initialValue: request.initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message = request.message {
                    Text(message)
                }
                TextField(request.placeholder, text: $text)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
            }
            .navigationTitle(request.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        request.completion(nil)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        let trimmed = text.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                        // If empty is forbidden, only allow non-empty.
                        if !request.allowEmpty && trimmed.isEmpty {
                            return
                        }

                        let result: String? = trimmed.isEmpty
                            ? (request.allowEmpty ? "" : nil)
                            : trimmed

                        request.completion(result)
                        dismiss()
                    }
                    .disabled(
                        !request.allowEmpty &&
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}
