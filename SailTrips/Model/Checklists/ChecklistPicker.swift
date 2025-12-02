//
//  ChecklistRunner.swift
//  SailTrips
//
//  Created by jeroen kok on 18/04/2025.
//

import SwiftUI
import SwiftData
enum ChecklistNavigation {
    case show, resume, start
}
/// View to select and launch a checklist based on context
struct ChecklistPickerView: View {
    @Bindable var instances: Instances
    @EnvironmentObject var pathManager: PathManager
    @Environment(\.modelContext) private var context

    // Fetch all checklist headers matching criteria
    @Query private var rawHeaders: [ChecklistHeader] // fetch all, then filter dynamically

    /// Filter out those run today if wait24Hours
    private var headers: [ChecklistHeader] {
        let today = Calendar.current.startOfDay(for: Date())
        return rawHeaders.filter { header in
            // Base selection: for all boats
            if header.forAllBoats {
                // pass
            } else if header.boat.id == instances.selectedBoat.id {
                // alwaysShow or conditionalShow
                if header.alwaysShow {
                }//else if instances.currentTrip != nil && header.conditionalShow ==
                else if header.conditionalShow == instances.navStatus {
                } else {
                    return false
                }
            } else {
                return false
            }
            // Exclude if wait24Hours and run today
            if header.wait24Hours {
                let lastRunDay = Calendar.current.startOfDay(for: header.latestRunDate)
                if lastRunDay >= today {
                    return false
                }
            }
            return true
        }
    }


    @State private var selectedHeader: ChecklistHeader?

    var body: some View {
        VStack {
            // Toolbar
            HStack {
                Button("Back") {
                    pathManager.path.removeLast()
                }
                Spacer()
            }
            .padding()
            .navigationDestination(for: ChecklistNavigation.self){ choice in
                switch choice {
                case .show: ChecklistRunnerView(header: selectedHeader!, instances: instances, mode: .show)
                case .start: ChecklistRunnerView(header: selectedHeader!, instances: instances, mode: .start)
                case .resume: ChecklistRunnerView(header: selectedHeader!, instances: instances, mode: .resume)
                    
                }
                
            }
            HStack(spacing: 16) {
                if let header = selectedHeader{
                Button("Run") {
                    pathManager.path.append(ChecklistNavigation.start)
                }
                .buttonStyle(FramedButtonStyle())

                if header.completed {
                    Button("Show") {
                        pathManager.path.append(ChecklistNavigation.show)
                    }
                    .buttonStyle(FramedButtonStyle(borderColor: .green))
                }

                if header.aborted {
                    Button("Resume") {
                        pathManager.path.append(ChecklistNavigation.resume)
                    }
                    .buttonStyle(FramedButtonStyle(borderColor: .red))
                }}
            }

            .padding(.vertical)

            Text("Select a checklist:")
                .font(.headline)

            List {
                ForEach(headers, id: \.self) { header in
                    HStack {
                        Text(header.name)
                        //.fontWeight(selectedHeader == header ? .semibold : .regular)
                        Spacer()
                        if header.completed {
                            Image(systemName: "checkmark.circle")
                                } else if header.aborted {
                                    Image(systemName: "exclamationmark.circle")
                                }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(selectedHeader == header ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                        .contentShape(Rectangle())          // make entire row tappable
                        .onTapGesture {
                            withAnimation {                     // optional animation
                                selectedHeader = header
                                   }
                        }
                    }
                }
                .listStyle(PlainListStyle())    // remove extra insets for a cleaner look
        }
        .navigationTitle("Checklists")
    }
}
