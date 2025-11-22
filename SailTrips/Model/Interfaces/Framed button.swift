//
//  Framed button.swift
//  SailTrips
//
//  Created by jeroen kok on 03/05/2025.
//

import SwiftUI

struct FramedButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8
    var lineWidth: CGFloat = 1
    var borderColor: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: lineWidth)
            )
            // Optional: a pressed‐state effect
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
