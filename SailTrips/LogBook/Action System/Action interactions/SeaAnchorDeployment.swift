//
//  SeaAnchorDeployment.swift
//  SailTrips
//
//  Created by jeroen kok on 20/12/2025.
//


import SwiftUI

enum SeaAnchorDeployment: String, CaseIterable, Identifiable {
    case bow
    case stern
    var id: String { rawValue }

    var displayString: String {
        switch self {
        case .bow:   return "Bow (recommended)"
        case .stern: return "Stern (not advised)"
        }
    }
}

struct ActionChoicePromptRequest<Choice: Identifiable & Hashable>: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let choices: [Choice]
    let choiceLabel: (Choice) -> String
    let defaultChoice: Choice?
    let completion: (Choice?) -> Void
}

struct ChoicePromptSheet<Choice: Identifiable & Hashable>: View {
    @Environment(\.dismiss) private var dismiss

    let request: ActionChoicePromptRequest<Choice>
    @State private var selection: Choice?

    init(request: ActionChoicePromptRequest<Choice>) {
        self.request = request
        _selection = State(initialValue: request.defaultChoice)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message = request.message {
                    Text(message)
                }

                Picker("Selection", selection: $selection) {
                    ForEach(request.choices) { c in
                        Text(request.choiceLabel(c)).tag(Optional(c))
                    }
                }
                .pickerStyle(.inline)
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
                        request.completion(selection)
                        dismiss()
                    }
                    .disabled(selection == nil)
                }
            }
        }
    }
}
