//
//  Location picker.swift
//  SailTrips
//
//  Created by jeroen kok on 16/05/2025.
//

import SwiftUI
import SwiftData

// MARK: - Location Selector View
struct LocationSelectorView: View {
    @Environment(\.presentationMode) var presentation
    @Environment(\.modelContext) private var context

    /// Binding to the caller’s selected locations
    @Binding var selectedLocations: [Location]
    
    /// Fetch all locations once, live‐updating from SwiftData
    @Query(sort: \Location.Name, order: .forward)
    private var allLocations: [Location]

    /// Internal set of selected IDs for fast lookup/toggling
    @State private var selectedIDs: Set<UUID>
    @State private var searchText: String = ""
    @State private var filterType: TypeOfLocation? = nil
    @State private var showQuickAdd: Bool = false
    @State private var newLocation = Location(name: "", latitude: 0, longitude: 0)
    

    /// Initialize from the caller’s array
    init(selectedLocations: Binding<[Location]>) {
        self._selectedLocations = selectedLocations
        self._selectedIDs = State(initialValue: Set(selectedLocations.wrappedValue.map { $0.id }))
    }

    /// Apply search text and type filter
    private var filtered: [Location] {
        allLocations.filter {
            (searchText.isEmpty ||
                $0.Name.localizedCaseInsensitiveContains(searchText)) &&
            (filterType == nil || $0.typeOfLocation == filterType)
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Selected pill‐style list
                Text("Tap to unselect")
                    .font(.subheadline)
                    .padding(.top)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(allLocations.filter { selectedIDs.contains($0.id) }, id: \.id) { loc in
                            Text(loc.Name)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 8).stroke())
                                .onTapGesture { selectedIDs.remove(loc.id) }
                        }
                    }
                    .padding(.horizontal)
                }

                Divider()

                // Search field, type picker, and Add stub
                HStack {
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Picker("Type", selection: $filterType) {
                        Text("All").tag(nil as TypeOfLocation?)
                        ForEach(TypeOfLocation.allCases) { t in
                            Text(t.rawValue).tag(t as TypeOfLocation?)
                        }
                    }
                    Button("Add") {
                        newLocation = Location(name: "", latitude: 0, longitude: 0)
                        showQuickAdd = true
                    }
                }
                .padding(.horizontal)

                // List of filtered locations
                List(filtered, id: \.id) { loc in
                    HStack {
                        Text(loc.Name)
                        Spacer()
                        if selectedIDs.contains(loc.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedIDs.contains(loc.id) {
                            selectedIDs.remove(loc.id)
                        } else {
                            selectedIDs.insert(loc.id)
                        }
                    }
                    .onLongPressGesture {
                        // TODO: show lat/long & address
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentation.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    // Write back to caller
                    selectedLocations = allLocations.filter { selectedIDs.contains($0.id) }
                    presentation.wrappedValue.dismiss()
                }
            )
            .navigationTitle("Select Locations")
            .sheet(isPresented: $showQuickAdd, onDismiss: addnewloc){
                QuickAddLocationView(location: $newLocation)
            }
        }
    }
    
    private func addnewloc(){
        if newLocation.Name != "" && (newLocation.Longitude != 0.0 || newLocation.Latitude != 0.0) {
            context.insert(newLocation)
        }
    }
}


struct OneLocationSelect: View {
    @Environment(\.presentationMode) var presentation
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Binding to the caller’s selected location
    @Binding var selectedLocation: Location?
    
    /// Fetch all locations once, live‐updating from SwiftData
    @Query(sort: \Location.Name, order: .forward)
    private var allLocations: [Location]

    /// Internal set of selected IDs for fast lookup/toggling
    @State private var searchText: String = ""
    @State private var filterType: TypeOfLocation? = nil
    @State private var showQuickAdd: Bool = false
    @State private var newLocation = Location(name: "", latitude: 0, longitude: 0)
    
    private var filtered: [Location] {
        allLocations.filter {
            (searchText.isEmpty ||
                $0.Name.localizedCaseInsensitiveContains(searchText)) &&
            (filterType == nil || $0.typeOfLocation == filterType)
        }
    }
    
    var body: some View {
        Button ("Dismiss") {
           dismiss()
        }
        //Text("Selected Location \($selectedLocation??.Name)")
        HStack {
            TextField("Search…", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Picker("Type", selection: $filterType) {
                Text("All").tag(nil as TypeOfLocation?)
                ForEach(TypeOfLocation.allCases) { t in
                    Text(t.rawValue).tag(t as TypeOfLocation?)
                }
            }
            Button("Add") {
                newLocation = Location(name: "", latitude: 0, longitude: 0)
                showQuickAdd = true
            }
        }
        .padding(.horizontal)
        List(filtered, id: \.id) { loc in
            HStack {
                Text(loc.Name)
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                selectedLocation = loc
                dismiss()
            }
            .onLongPressGesture {
                // TODO: show lat/long & address
            }
        }
        .sheet(isPresented: $showQuickAdd, onDismiss: addnewloc){
            QuickAddLocationView(location: $newLocation)
        }
    }
    
    private func addnewloc(){
        if newLocation.Name != "" && (newLocation.Longitude != 0.0 || newLocation.Latitude != 0.0) {
            context.insert(newLocation)
        }
    }
    
}


