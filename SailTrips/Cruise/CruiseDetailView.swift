//
//  CruiseDetailView.swift
//  SailTrips
//
//  Created by jeroen kok on 20/05/2025.
//


import SwiftUI
import SwiftData

struct CruiseDetailView: View {
    @Bindable var cruise: Cruise
    @Bindable var instance: Instances
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\ .modelContext) private var modelContext
    @EnvironmentObject var pathManager: PathManager
    
    @State private var showingCrewSelector = false
    @State private var showingLocationSelector = false

    /// true when arrival date exists and is before now
    var isPastArrival: Bool {
        if let arr = cruise.DateOfArrival {
            return arr.isBefore(Date.now)
        }
        return false
    }

    var body: some View {
        Form {
            // MARK: – Completed‐only view
            HStack
            {
                Button("Done") {
                    dismiss()
                }
                .underline(color: .init(UIColor.systemBlue))
                if (cruise.status == .underway && instance.currentTrip == nil) {
                    Button("Start Trip"){
                        let newTrip = Trip()
                        initTrip(inTrip: newTrip)
                        modelContext.insert(newTrip)
                        pathManager.path.append(HomePageNavigation.tripCompanion)
                    }
                }
            }
            if cruise.status == .completed {
                Section {
                    Text(cruise.Boat?.name ?? "")
                        .font(.headline)

                    Text("Title: \(cruise.Title)")
                    Text("Start: \(cruise.DateOfStart, style: .date)")
                    Text("Arrival: \(cruise.DateOfArrival.map { Text("\($0, style: .date)") } ?? Text("—"))")
                    Text("Basin: \(cruise.basin)")
                    Text("Departure: \(cruise.Departure)")
                    Text("Cruise Type: \(cruise.CruiseType.rawValue)")
                    Text("Status: \(cruise.status.rawValue)")
                }

            // MARK: – Editable view
            } else {
                Section(header: Text("Cruise plan")) {
                    Text(cruise.Boat?.name ?? "")
                        .font(.headline)

                    // 1️⃣ CruiseType picker when editable
                    Picker("Cruise Type", selection: $cruise.CruiseType) {
                        ForEach(TypeOfCruise.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Title", text: $cruise.Title)
                    DatePicker("Date of Departure", selection: $cruise.DateOfStart, displayedComponents: .date)
                    DatePicker(
                        "Date of Arrival",
                        selection: Binding(
                            get: { cruise.DateOfArrival ?? Date() },
                            set: { cruise.DateOfArrival = $0 }
                        ),
                        displayedComponents: .date
                    )
                    TextField("Basin", text: $cruise.basin)
                    TextField("Departure", text: $cruise.Departure)

                    // Always show status as text
                    Text("Status: \(cruise.status.rawValue)")
                }

                // 2️⃣ If arrival has passed but cruise not marked completed
                if isPastArrival {
                    Section {
                        Text("Is the cruise completed or should the date be modified?")
                        Toggle("Completed", isOn:
                            Binding<Bool>(
                                get: { cruise.status == .completed },
                                set: { newValue in
                                    if newValue {
                                        cruise.status = .completed
                                    }
                                }
                            )
                        )
                    }
                }
                // Crew and Locations remain editable until completed
                Section(header: Text("Crew")) {
                    VStack(alignment: .leading) {
                        ForEach(cruise.Crew, id: \.id) { member in
                            NavigationLink(destination: ACrewMember(crewMember: member)) {
                                Text("\(member.FirstName) \(member.LastName)")
                            }
                        }
                        Button("Change Crew") {
                            showingCrewSelector = true
                        }
                    }
                }
                
                Section(header: Text("Locations")) {
                    if ((cruise.status == .underway) && (cruise.legs != [])) {
                        Text("Long press a location to start a trip to this destination")
                    }
                    VStack(alignment: .leading) {
                        ForEach(cruise.legs, id: \.id) { loc in
                            Text(loc.Name)
                                .onLongPressGesture (minimumDuration: 0.2){
                                    if (cruise.status == .underway) {
                                        if let trip=instance.currentTrip {
                                            trip.destination = loc
                                            pathManager.path.append(HomePageNavigation.tripCompanion)
                                        } else {
                                            let newTrip = Trip()
                                            initTrip(inTrip: newTrip)
                                            newTrip.destination = loc
                                            modelContext.insert(newTrip)
                                            pathManager.path.append(HomePageNavigation.tripCompanion)
                                        }
                                    }
                                }
                        }
                        Button("Select Locations") {
                            showingLocationSelector = true
                        }
                    }
                }
            }
        }
        .navigationBarItems(trailing:
            Button("Done") {
                dismiss()
            }
        )
        .sheet(isPresented: $showingCrewSelector) {
            CrewSelectorView(selectedMembers: $cruise.Crew)
        }
        .sheet(isPresented: $showingLocationSelector) {
            LocationSelectorView(selectedLocations: $cruise.legs)
        }
    }
    private func initTrip(inTrip: Trip){
        inTrip.tripType = .legOfCruise
        inTrip.boat = instance.selectedBoat
        inTrip.dateOfStart = Date.now
        inTrip.cruise = cruise
        inTrip.crew = cruise.Crew
        instance.currentTrip = inTrip
        instance.dateOfStart = Date.now
    }
}
