//
//  HomePage.swift
//  SailTrips
//
//  Created by jeroen kok on 01/03/2025.
//


import SwiftUI
import SwiftData

enum HomePageNavigation: Hashable {
    case parameters
    case settings
    case beaufort
    case boatList
    case boatDetail
    case boatLog
    case maintenance
    case checklist
    case runChecklist
    case crew
    case inventory
    case locations
    case cruise
    case tripdetail
    case tripCompanion
    case triplist
    case tripDetails
    case logbookManEntry
    case logFromInstances
    case logView(tripID: UUID?)  // nil = all logs, non-nil = logs for that trip
    case actionLog
}

struct HomePage: View {
    
    @Environment(\.modelContext) private var modelContext: ModelContext
    @State private var selectedBoat: Boat?
    // FetchDescriptor for fetching boats sorted by status
    @State private var fetchDescriptor: FetchDescriptor<CruiseDataSchemaV1.Boat>
    @State var checklisthelper: Bool = false
    @StateObject var navPath = PathManager()
    @StateObject var active = activations()
    @State private var instances: CruiseDataSchemaV1.Instances?
    @State private var showMementoSheet = false
    @Query var winds: [BeaufortScale]
    @Query private var settings: [LogbookSettings]
    @Query(sort: \Trip.dateOfStart, order: .reverse) private var trips: [Trip]
    @Query(sort: \Cruise.DateOfStart, order: .forward) private var cruises: [Cruise]
    
    @State private var showCruiseMatchAlert = false
    @State private var detectedCruiseID: UUID?
    @State private var detectedCruiseTitle: String = ""
    @State private var showChecklistPicker = false

    private var defaultTripID: UUID? {
        if let current = instances?.currentTrip?.id { return current }
        guard let boatID = instances?.selectedBoat.id else { return nil }
        return trips.first(where: { $0.boat?.id == boatID && $0.tripStatus == .completed })?.id
    }
    
    init() {
        _fetchDescriptor = State(initialValue: FetchDescriptor<Boat>(sortBy: [SortDescriptor(\Boat.name)]))
    }
    
    @ViewBuilder
    private func require<T, V: View>(
        _ value: T?,
        _ message: String,
        @ViewBuilder content: (T) -> V
    ) -> some View {
        if let value {
            content(value)
        } else {
            // Side effect, not part of the ViewBuilder result
            let _ = assertionFailure(message)
            Text(message).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func destination(_ homeNav: HomePageNavigation) -> some View {
        switch homeNav {
        case .beaufort: BeaufortEditor()
        case .crew: CrewMembersView()
        case .boatList: BoatListView(selectedBoat: $selectedBoat)

        case .boatDetail:
            require(selectedBoat, "No selected boat.") { boat in
                BoatDetailsView(aBoat: boat)
            }

        case .tripCompanion:
            require(instances, "No Instances row.") { inst in
                TripCompanionView(instances: inst)
            }

        case .checklist:
            require(selectedBoat, "No selected boat.") { boat in
                ChecklistList(currentBoat: boat)
            }

        case .runChecklist:
            require(instances, "No Instances row.") { inst in
                ChecklistPickerView(instances: inst)
            }

        case .boatLog:
            require(selectedBoat, "No selected boat.") { boat in
                BoatLogListView(boat: boat)
            }

        case .maintenance:
            require(selectedBoat, "No selected boat.") { boat in
                MaintenanceView(boat: boat)
            }

        case .locations: LocationListView()

        case .tripdetail, .triplist:
            require(instances, "No Instances row.") { inst in
                TripListView(instances: inst)
            }

        case .cruise:
            require(instances, "No Instances row.") { inst in
                CruiseListView(instances: inst)
            }

        case .logbookManEntry:
            require(instances, "No Instances row.") { inst in
                if let s = settings.first {
                    LogbookEntryView(instances: inst, settings: s)
                } else {
                    Text("Missing settings row.")
                }
            }
        case .logFromInstances:
            require(instances, "No Instances row.") { inst in
                if let s = settings.first {
                    LogbookEntryView(instances: inst, settings: s)
                } else {
                    Text("Missing settings row.")
                }
            }
        case .parameters: SettingsView()
        case .logView(let tripID):
            LogbookViewer(tripID: tripID)

        case .tripDetails: TripDetailHostView()

        case .actionLog:
            require(instances, "No Instances row.") { inst in
                LogActionView(
                    instances: inst,
                    showBanner: { _ in },
                    openDangerSheet: { _ in },
                    onClose: { navPath.path.removeLast() }
                )
            }
        default:
            Text("Unhandled destination: \(String(describing: homeNav))")
        }
    }
    
    private struct CruiseAlertItem: Identifiable {
        let id: UUID
        let cruise: Cruise

        init(_ cruise: Cruise) {
            self.id = cruise.id
            self.cruise = cruise
        }
    }
    
    var body: some View {
        
        NavigationStack(path: $navPath.path) {
            VStack(spacing: 20) {
                //Headers
                Text("Current Boat is \(selectedBoat?.name ?? "None")")
                    .font(.headline)
                Text("Select an Option")
                    .font(.subheadline)
                    .bold()
                    .padding()
                
                // Links
                
                if let inst = instances, inst.currentTrip != nil {
                    NavigationLink(value: HomePageNavigation.tripCompanion) {
                        Text("Return to ongoing trip")
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                }
                
                NavigationLink("Crew Members", value: HomePageNavigation.crew)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                
                NavigationLink("Boats", value: HomePageNavigation.boatList)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                NavigationLink("Cruise list", value: HomePageNavigation.cruise)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                Button {
                    showChecklistPicker = true
                } label: {
                    Text("Run Checklists")
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                NavigationLink("Boat Logbook", value: HomePageNavigation.boatLog)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                NavigationLink("Past Trips", value: HomePageNavigation.triplist)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                if let inst = instances, inst.currentTrip == nil {
                    Button {
                        do {
                            let starter = TripStarter(context: modelContext)
                            let res = try starter.startTrip(instances: inst, cruises: cruises)
                            if let match = res.detectedCruise, inst.currentCruise == nil {
                                detectedCruiseID = match.id
                                detectedCruiseTitle = match.Title
                                showCruiseMatchAlert = true
                            } else {
                                navPath.path.append(HomePageNavigation.tripCompanion)
                            }

                        } catch {
                            print(error)
                        }
                    } label: {
                        Text("Start a new trip")
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }

            }
            .alert("Is trip part of Cruise?", isPresented: $showCruiseMatchAlert) {
                Button("Yes") {
                    guard
                        let inst = instances,
                        let id = detectedCruiseID,
                        let cruise = cruises.first(where: { $0.id == id })
                    else { return }

                    try? TripStarter(context: modelContext).setCurrentCruise(cruise, instances: inst)
                    detectedCruiseID = nil
                    detectedCruiseTitle = ""
                    navPath.path.append(HomePageNavigation.tripCompanion)
                }

                Button("No", role: .cancel) {
                    detectedCruiseID = nil
                    detectedCruiseTitle = ""
                    navPath.path.append(HomePageNavigation.tripCompanion)
                }
            } message: {
                Text("Start trip as part of cruise '\(detectedCruiseTitle)'?")
            }
            
            .onAppear {//ensuring that all necessary tables are assigned a value
                let windC = BeaufortScale.validatedScales(from: winds)
                for wind in windC {
                    let idx = winds.firstIndex(of: wind)
                    if idx == nil {
                        modelContext.insert(wind)
                    }
                }
                handleSelectedBoat()

                if settings.count == 0 {
                    let newSettings = LogbookSettings(id: UUID())
                    modelContext.insert(newSettings)
                }
                if let instance = instances
                {
                    if instance.currentTrip != nil {
                        if instance.currentTrip!.tripStatus == .completed {
                            instance.currentTrip = nil
                        }
                    }
                }
            }
            .onChange(of: selectedBoat) { oldboat, newBoat in
                guard let boat = newBoat else { return }
                fetchOrCreateInstances(for: boat)
                    
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Memos") {
                        showMementoSheet = true
                    }
                }
                
                ToolbarItem(){
                    Menu{
                        Button("Settings"){
                            navPath.path.append(HomePageNavigation.parameters)
                        }
                    } label: {
                        Text("Settings")
                    }
                }
                
                ToolbarItem(){
            
                    Menu{
                        Button("Locations"){
                            navPath.path.append(HomePageNavigation.locations)
                        }
                        
                        Button("Edit Checklists"){
                            navPath.path.append(HomePageNavigation.checklist)
                        }
                        Button("Crew Members") {
                            navPath.path.append(HomePageNavigation.crew)
                        }
                        Button("Beaufort Scale") {
                            navPath.path.append(HomePageNavigation.beaufort)
                        }
                    } label: {
                        Text("Lists")
                    }
                }
                
                ToolbarItem() {
                    Menu{
                        Button("Boats"){
                            navPath.path.append(HomePageNavigation.boatList)
                        }
                        
                        Button("Boat's Log") {
                            navPath.path.append(HomePageNavigation.boatLog)
                        }
                        
                        Button("Maintenance") {
                            navPath.path.append(HomePageNavigation.maintenance)
                        }
                    } label: {
                        Text("Boats")
                    }
                }
            }
            .sheet(isPresented: $showMementoSheet) {
                MementoSheetView()
            }
            .sheet(isPresented: $showChecklistPicker) {
                if let inst = instances {
                    ChecklistPickerView(instances: inst)   // ✅ already contains its own NavigationStack
                } else {
                    Text("No Instances row.")
                }
            }
            .navigationDestination(for: HomePageNavigation.self) { homeNav in
                destination(homeNav)
            }
            
        }
        .environmentObject(navPath)
        .environmentObject(active)
    }
    
    private func handleSelectedBoat() {
        do {
            let boats = try modelContext.fetch(fetchDescriptor)
            
            if boats.isEmpty {
                let newBoat = Boat(name: "New", boatType: .sailboat) // Specify a default type
                modelContext.insert(newBoat)
                newBoat.status = .selected
                selectedBoat = newBoat
                try modelContext.save()
                fetchOrCreateInstances(for: newBoat)
                navigateToBoatDetailsView(newBoat)
            } else {
                selectedBoat = boats.first(where: { $0.status == .selected })
                
                if let firstSelectedBoat = boats.first(where: { $0.status == .selected }) {
                    selectedBoat = firstSelectedBoat
                    boats.forEach { boat in
                        if boat != firstSelectedBoat {
                            boat.status = .inactive
                        }
                    }
                    try? modelContext.save()
                    fetchOrCreateInstances(for: firstSelectedBoat)
                }
            }
        } catch {
            print("Failed to fetch boats: \(error)")
        }
    }
    
    private func fetchOrCreateInstances(for boat: Boat) {

        let boatID = boat.id

        let descriptor = FetchDescriptor<Instances>(
            predicate: #Predicate<Instances> { inst in
                inst.selectedBoat.id == boatID
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            if let existing = results.first {
                self.instances = existing
            } else {
                // 3. No row yet → create one and save
                let newInst = Instances(boat: boat)
                modelContext.insert(newInst)
                try modelContext.save()
                self.instances = newInst
            }
        } catch {
            print("Failed to fetch or create Instances: \(error)")
        }
    }
    
    private func navigateToBoatDetailsView(_ boat: Boat) {
        selectedBoat = boat
        navPath.path.append(HomePageNavigation.boatDetail)
    }
}

#Preview {
    HomePage()
}
