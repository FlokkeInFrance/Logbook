//
//  SelectInstanceFields.swift
//  SailTrips
//
//  Created by jeroen kok on 20/07/2025.
//

import SwiftUI
import SwiftData

struct SelectInstanceFields: View {
    
    @Query private var settings: [LogbookSettings]
    @Environment(\.modelContext) private var modelContext: ModelContext
    
    var body: some View {
        Text("Select the data you want to track during a trip :")
            .font(.headline)
        Form{
            ForEach(InstanceField.allCases, id: \.self) { field in
              Toggle(field.rawValue, isOn: Binding(
                get: { settings[0].isInstanceFieldVisible(field) },
                set: { settings[0].setInstanceField(field, visible: $0) }
              ))
            }
        }//End of Form
        .onAppear {
            if settings.count == 0 {
                let newSettings = LogbookSettings(id: UUID())
                modelContext.insert(newSettings)
            }
        }
    }//End of View
}


#Preview {
    SelectInstanceFields()
}
