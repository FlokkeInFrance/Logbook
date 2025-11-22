//
//  BeaufortEditor.swift
//  SailTrips
//
//  Created by jeroen kok on 15/03/2025.
//

import SwiftUI
import SwiftData

enum BeaufortScaleNav{
    case detail
}
struct BeaufortEditor: View {
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var path: PathManager
    @State var selectedBf : BeaufortScale? = nil
    @Query private var scales: [BeaufortScale]
    
    var body: some View {
        List(scales, selection: $selectedBf) { scale in
                NavigationLink("Force \(scale.beaufortScaleInt): \(scale.windName)", value: BeaufortScaleNav.detail )
                .tag(scale)
            }
            .navigationTitle("Beaufort Scale")
            .toolbar {
                Button(action: addNewScale) {
                Label("Add Scale", systemImage: "plus")
            }
                .navigationDestination(for: BeaufortScaleNav.self) {bf in
                    BeaufortScaleDetailView(scale: selectedBf!)  }
        }

    }
    
    private func addNewScale() {
        let newScale = BeaufortScale(id: UUID(), beaufortScaleInt: scales.count)
        modelContext.insert(newScale)
        do
        {try modelContext.save()}
            catch {
                print("Error saving new scale: \(error)")
                
        }
        selectedBf = newScale
        path.path.append(BeaufortScaleNav.detail)
        
    }
}

struct BeaufortScaleListView: View {
    let scales: [BeaufortScale]
    @Binding var selectedScale: BeaufortScale?

    var body: some View {
        List(scales, selection: $selectedScale) { scale in
            Text("Force \(scale.beaufortScaleInt): \(scale.windName)")
                .tag(scale)
        }
    }
}

struct BeaufortScaleDetailView: View {
    @Bindable var scale: BeaufortScale

    var body: some View {
        Form {
            Section(header: Text("General Info")) {
                Stepper("Beaufort Level: \(scale.beaufortScaleInt)", value: $scale.beaufortScaleInt, in: 0...12)
                TextField("Wind Name", text: $scale.windName)
                TextField("Sea State", text: $scale.seaState)
            }

            Section(header: Text("Wind Velocity")) {
                IntField(label: "Lower Limit (knots)", inData: $scale.windVelocityLow)
                    .keyboardType(.numberPad)
            }
        }
        .navigationTitle("Edit Scale Level")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    BeaufortEditor()
}
