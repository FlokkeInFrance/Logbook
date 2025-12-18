//
//  Location manager.swift
//  SailTrips
//
//  Created by jeroen kok on 18/05/2025.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - Location List View
struct LocationListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Location.Name) private var locations: [Location]
    @State private var regionFilter: String = ""
    @State private var nameFilter: String = ""
    @State private var typeFilterOn: Bool = false
    @State private var selectedType: TypeOfLocation = .pOI
    @State private var showingDetail = false
    @State private var newLocation = Location(name: "", latitude: 0, longitude: 0)

    // Combined filtering
    var filtered: [Location] {
        locations.filter { loc in
            let matchesRegion = regionFilter.isEmpty || loc.region.localizedCaseInsensitiveContains(regionFilter)
            let matchesName = nameFilter.isEmpty || loc.Name.localizedCaseInsensitiveContains(nameFilter)
            let matchesType = !typeFilterOn || loc.typeOfLocation == selectedType
            return matchesRegion && matchesName && matchesType
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section("Filters") {
                    TextField("Filter by region", text: $regionFilter)
                    TextField("Filter by name", text: $nameFilter)
                    Toggle("Filter by type", isOn: $typeFilterOn.animation())
                    if typeFilterOn {
                        Picker("Location Type", selection: $selectedType) {
                            ForEach(TypeOfLocation.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    ForEach(filtered) { loc in
                        NavigationLink(destination: LocationDetailView(location: loc)) {
                            VStack(alignment: .leading) {
                                Text(loc.Name).font(.headline)
                                Text(loc.typeOfLocation.rawValue).font(.subheadline)
                                if !loc.region.isEmpty {
                                    Text(loc.region).font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Locations to remember")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        newLocation = Location(name: "", latitude: 0, longitude: 0)
                        showingDetail = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                NavigationView {
                    LocationDetailView(location: newLocation, context: context)
                }
            }
        }
    }
}

// MARK: - Location Detail View
struct LocationDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var location: Location
    @State private var showImagePicker = false
    @State private var selectedUIImage: UIImage? = nil
    //@State private var showFullImage: UIImage? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var fullImage: UIImage? = nil
    @State private var showFull = false
    @State private var lastDate: Date = Date.distantPast
    @State private var selectedPhotoIDs: Set<UUID> = []

    init(location: Location, context: ModelContext? = nil) {
        _location = State(initialValue: location)
    }

    var body: some View {
        Form {
            GroupBox(label: Label("Title & Coordinates", systemImage: "mappin")) {
                TextField("Name", text: $location.Name)
                Picker("Type", selection: $location.typeOfLocation) {
                    ForEach(TypeOfLocation.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                CoordinatesView(latitude: $location.Latitude, longitude: $location.Longitude, isEditable: true)
                HStack {
                    DatePicker("Last visited", selection: $lastDate, displayedComponents: .date)
                        .onChange (of: lastDate) { _,newDate in
                            self.location.LastDateVisited = newDate
                        }
                    Button ("Today"){
                        self.location.LastDateVisited = Date.now
                        self.lastDate = Date.now
                    }
                }
            }

            GroupBox(label: Label("Address", systemImage: "house")) {
                TextField("Region", text: $location.region)
                TextField("Address", text: $location.address)
                TextField("Postal Code", text: $location.cP)
                TextField("Town", text: $location.town)
                TextField("Country", text: $location.country)
            }

            GroupBox(label: Label("Contact", systemImage: "person.crop.circle")) {
                TextField("Name", text: $location.contactName)
                TextField("Phone", text: $location.contactPhone)
                TextField("VHF Channel", text: $location.vhfContact)
                TextField("Email", text: $location.emailContact)
            }

            GroupBox(label: Label("Procedures", systemImage: "arrow.right.arrow.left")) {
                TextEditor(text: $location.arrivalProcedures).frame(height: 80)
                TextEditor(text: $location.departureProcedures).frame(height: 80)
            }

            GroupBox(label: Label("Observations", systemImage: "pencil")) {
                TextEditor(text: $location.observations).frame(height: 100)
            }
            // Photos for the location
            GroupBox(label: Label("Photos", systemImage: "photo")) {
                
                PhotoStripView(pictures: $location.picture, selectionEnabled: false, selectedIDs: $selectedPhotoIDs)

            }

        }
        .navigationTitle("Edit the location")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveAndClose() }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showImagePicker) {
               TaskImagePicker(sourceType: .photoLibrary, selectedImage: $selectedUIImage)
                .onDisappear {
                    if let ui = selectedUIImage, let data = ui.jpegData(compressionQuality: 0.8) {
                        location.picture.append(Picture(data: data))
                    }
                }
        }
        .fullScreenCover(isPresented: $showFull) {
            if let img = fullImage {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: img).resizable().scaledToFit()
                    Button { showFull = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle).padding()
                    }
                }
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") { /* noop */ }
        }
        .onAppear() {
            if let newDate = self.location.LastDateVisited as Date? {
                 lastDate=newDate
             }
        }
    }

    private func saveAndClose() {
        guard !location.Name.isEmpty,
              (-90...90).contains(location.Latitude),
              (-180...180).contains(location.Longitude) else {
            alertMessage = "Please enter a valid name and coordinates before saving."
            showAlert = true
            return
        }
            context.insert(location)
        try? context.save()
        dismiss()
    }
}

// MARK: - Quick Add (Planning)
struct QuickAddPlanningView: View {
    @Environment(\.modelContext) private var context
    @Binding var location: Location
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $location.Name)
                CoordinatesView(latitude: $location.Latitude, longitude: $location.Longitude, isEditable: true)
            }
            .navigationTitle("Quick Add")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func onDone() {
        if location.Name.isEmpty && (location.Latitude == 0 && location.Longitude == 0) {
            // invalid
        } else {
            context.insert(location)
            try? context.save()
            dismiss()
        }
    }
}

// MARK: - Quick Add (On the Fly)
struct QuickAddOnTheFlyView: View {
    @Environment(\.modelContext) private var context
    @Binding var location: Location
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $location.Name)
                CoordinatesView(latitude: $location.Latitude, longitude: $location.Longitude, isEditable: false)
                // Optionally add photos like in detail
            }
            .navigationTitle("Give a name to your current position")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // TODO: set location.Latitude & Longitude to current device position
            }
        }
    }

    private func onDone() {
        if location.Name.isEmpty {
            // show warning or abort
        } else {
            context.insert(location)
            try? context.save()
            dismiss()
        }
    }
}
