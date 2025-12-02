//
//  HomePage.swift
//  SailTrips
//
//  Created by jeroen kok on 01/03/2025.
//


import SwiftUI
import SwiftData

enum HomePageNavigation: Hashable {
    case boatList
    case boatDetail
    case checklist
    case runChecklist
    case settings
    case beaufort
    case crew
    case maintenance
    case boatLog
    case inventory
    case locations
    case tripdetail
    case tripCompanion
    case triplist
    case cruise
    case logbookManEntry
    case parameters
    case logView
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
    
    init() {
        _fetchDescriptor = State(initialValue: FetchDescriptor<Boat>(sortBy: [SortDescriptor(\Boat.name)]))
    }
    
    var body: some View {
        /*Button("Memos"){
            showMementoSheet = true
        }
        .buttonStyle(.borderedProminent)*/
        
        NavigationStack(path: $navPath.path) {
            VStack(spacing: 20) {
                //Headers
                Text("Current Boat is \(selectedBoat? .name ?? "None")")
                    .font(.headline)
                Text("Select an Option")
                    .font(.subheadline)
                    .bold()
                    .padding()
                
                // Links
                NavigationLink("Crew Members", value: HomePageNavigation.crew)
                    .frame(maxWidth: .infinity)
                    .padding()
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
                
                NavigationLink("Run Checklists", value: HomePageNavigation.runChecklist)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                NavigationLink("Boat Logbook", value: HomePageNavigation.logView)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                
                if let instance = instances {
                    if instance.currentTrip != nil {
                        NavigationLink("Go back to current Trip",value: HomePageNavigation.tripCompanion)
                    }
                    else {
                        NavigationLink("Start new Trip", value: HomePageNavigation.tripCompanion)
                    }
                }
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
            .navigationDestination(for: HomePageNavigation.self) { homeNav in
                switch homeNav {
                case .beaufort: BeaufortEditor()
                case .crew: CrewMembersView()
                case .boatList: BoatListView(selectedBoat: $selectedBoat)
                case .boatDetail: BoatDetailsView(aBoat: selectedBoat!)
                case .checklist: ChecklistList(currentBoat: selectedBoat!)
                case .runChecklist: ChecklistPickerView(instances: instances!)
                case .boatLog: BoatLogListView(boat: selectedBoat!)
                case .maintenance: MaintenanceView(boat: selectedBoat!)
                case .locations: LocationListView()
                case .tripdetail: TripListView(instances: instances!)
                case .triplist: TripListView(instances: instances!)
                case .cruise: CruiseListView(instances: instances!)
                case .logbookManEntry: LogbookEntryView(instances: instances!, settings: settings[0])
                case .tripCompanion: TripCompanionView(instances: instances!)
                case .parameters: SettingsView()
                case .logView:
                    LogbookViewer()
                case .actionLog:
                    if let instances = instances {
                        LogActionView(
                            instances: instances,
                            showBanner: { _ in
                                // For now, no external banner – LogActionView already shows its own local banner.
                            },
                            openDangerSheet: { _ in
                                // Later: set some @State to present a danger sheet.
                            },
                            onClose: {
                                // Pop ActionLog from NavigationStack
                                navPath.path.removeLast()
                            }
                        )
                    } else {
                        Text("No active Instances / Boat selected.")
                    }

                    
                default : fatalError("Unhandled Navigation Destination")
                }
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
