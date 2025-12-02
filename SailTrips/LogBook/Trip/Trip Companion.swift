//
//  Trip Companion.swift
//  SailTrips
//
//  Created by jeroen kok on 22/05/2025.
// The trip companion is the interface used to prepare, then track the progress of a trip
// it shows links to the logbook, the instances table

import SwiftUI
import SwiftData

struct TripCompanionView: View {
    let myFormat: NumberFormatter = {
       let nf = NumberFormatter()
       nf.numberStyle = .decimal
       nf.minimumFractionDigits = 2
       nf.maximumFractionDigits = 2
       nf.locale = Locale.current
       return nf
   }()
    
    @EnvironmentObject var navPath: PathManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var instances: Instances
    @State private var thisTrip: Trip? //Trip is found in Instances
    var initialDestination: Location?
    @Query private var allCruises: [Cruise]
    // Fetch cruises for the selected boat once
    
    //private var boatCruises: [Cruise]

    @State private var detectedCruise: Cruise?
    @State private var showCruiseAlert = false
    @State private var showCrewSelector = false
    @State private var showLocationSelector = false
    @State private var showStartSelector = false
    @State private var showDestinationSelector = false
    @State private var showWeatherDesciption: Bool = false
    

    // Calendar and clamped dates
    private let calendar = Calendar.current
    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }
    private var tomorrowStart: Date? {
        calendar.date(byAdding: .day, value: 1, to: todayStart)
    }
    
    var body: some View {
        
        Button("Run a Checklist") {
            navPath.path.append(HomePageNavigation.runChecklist)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 10).stroke())
        
        
        Button("View Current Logbook") {
            navPath.path.append(HomePageNavigation.logView)
        }
        /*if (thisTrip != nil){
            if (thisTrip!.tripStatus != TripStatus.preparing && thisTrip!.tripStatus != TripStatus.completed){
                Button("View Current Logbook"){
                    if let trip = instances.currentTrip {
                        navPath.path.append(HomePageNavigation.logView(trip))
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 10).stroke())
                
            }
        }*/
        
        Button {
            navPath.path.append(HomePageNavigation.actionLog)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "dot.viewfinder")
                .font(.system(size: 32))
                Text("Action Log")
                .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        
        ScrollView{
            VStack {
                
                // Boat & Cruise
                GroupBox(label: Text("Trip Setup").font(.headline)) {
                    Text("Boat: \(instances.selectedBoat.name)")
                    if let cruise = thisTrip?.cruise ?? instances.currentCruise {
                        Text("Cruise: \(cruise.Title)")
                    }
                }
                
                // Date & Status with +/- clamp logic
                GroupBox(label: Text("Date & Status").font(.headline)) {
                    HStack {
                        Text(thisTrip?.dateOfStart ?? Date.now, style: .date)
                        Spacer()
                        if calendar.isDate(thisTrip?.dateOfStart ?? Date.now, inSameDayAs: todayStart) {
                            Button("+") {
                                guard let tom = tomorrowStart else { return }
                                instances.dateOfStart = tom
                                thisTrip?.dateOfStart = tom
                            }
                        } else if let tom = tomorrowStart,
                                  calendar.isDate(instances.dateOfStart, inSameDayAs: tom) {
                            Button("-") {
                                instances.dateOfStart = todayStart
                                instances.currentTrip?.dateOfStart = todayStart
                            }
                        }
                    }
                    HStack {
                        Text("Status: \(instances.currentTrip?.tripStatus.rawValue ?? "-")")
                        Spacer()
                        if Date.now.isSame(thisTrip?.dateOfStart ?? Date.now){
                            Button("Go"){
                                thisTrip!.tripStatus = .underway
                                instances.odometerForTrip = 0
                            }
                        }
                        if Date.now.isAfterOrSame(thisTrip?.dateOfStart ?? Date.now) {
                            Button("End Trip") {
                                thisTrip!.tripStatus = .completed
                                instances.currentTrip = nil
                            }
                        }
                    }
                }
                
                // Crew & Skipper
                GroupBox(label: Text("Crew").font(.headline)) {
                    HStack {
                        Text("Members:")
                        Spacer()
                        Button("Edit") { showCrewSelector = true }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(instances.currentTrip?.crew ?? [], id: \.id) { member in
                                Text("\(member.FirstName) \(member.LastName)")
                                    .padding(4)
                                    .background(RoundedRectangle(cornerRadius: 8).stroke())
                            }
                        }
                    }
                    HStack {
                        Text("Skipper :")
                        Picker("Skipper", selection: Binding(
                            get: { instances.currentTrip?.skipper?.id },
                            set: { newID in
                                if let m = instances.currentTrip?.crew.first(where: { $0.id == newID }) {
                                    instances.currentTrip?.skipper = m
                                }
                            }
                        ))  {
                            Text("None").tag(UUID?.none)
                            ForEach(instances.currentTrip?.crew ?? [], id: \.id) { member in
                                Text("\(member.FirstName) \(member.LastName)").tag(Optional(member.id))
                            }
                        }
                    }
                }
                .sheet(isPresented: $showCrewSelector) {
                    CrewSelectorView(selectedMembers: Binding(
                        get: { instances.currentTrip?.crew ?? [] },
                        set: { instances.currentTrip?.crew = $0 }
                    ))
                }
                
                // Route
                GroupBox(label: Text("Route").font(.headline)) {
                    HStack {
                        Text("Start place:")
                        Spacer()
                        Button(action: { showStartSelector = true }) {
                            Text(instances.currentTrip?.startPlace?.Name ?? "Select…")
                        }
                        .sheet(isPresented: $showStartSelector) {
                            @State var locat: Location?
                               OneLocationSelect(
                                 selectedLocation: Binding(
                                   get:  { instances.currentTrip?.startPlace },
                                   set:  { instances.currentTrip?.startPlace = $0 }
                                 )
                               )
                           }
                    }
                    HStack {
                        Text("Destination:")
                        Spacer()
                        Button(action: { showDestinationSelector = true }) {
                            Text(instances.currentTrip?.destination?.Name ?? "Select…")
                        }
                        .sheet(isPresented: $showDestinationSelector) {
                                OneLocationSelect(
                                  selectedLocation: Binding(
                                    get:  { instances.currentTrip?.destination },
                                    set:  { instances.currentTrip?.destination = $0 }
                                  )
                                )
                            }
                    }
                    if let stops = instances.currentTrip?.plannedStops, !stops.isEmpty {
                        Text("Planned Stops:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(stops, id: \.id) { loc in
                                    Text(loc.Name)
                                        .padding(4)
                                        .background(RoundedRectangle(cornerRadius: 8).stroke())
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showLocationSelector) {
                    LocationSelectorView(selectedLocations: Binding(
                        get: { instances.currentTrip?.plannedStops ?? [] },
                        set: { instances.currentTrip?.plannedStops = $0 }
                    ))
                }
                // Comments
                GroupBox(label: Text("Comments").font(.headline)) {
                    TextEditor(text: Binding(
                        get: { instances.currentTrip?.comments ?? "" },
                        set: { instances.currentTrip?.comments = $0 }
                    ))
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                }
                
                // Contact at Destination
                GroupBox(label: Text("At Destination").font(.headline)) {
                    TextField("Contact Person", text: Binding(
                        get: { instances.currentTrip?.personAtDestination ?? "" },
                        set: { instances.currentTrip?.personAtDestination = $0 }
                    ))
                    TextField("Phone", text: Binding(
                        get: { instances.currentTrip?.phoneToContact ?? "" },
                        set: { instances.currentTrip?.phoneToContact = $0 }
                    ))
                    TextField("VHF Channel", text: Binding(
                        get: { instances.currentTrip?.vhfChannelDestination ?? "" },
                        set: { instances.currentTrip?.vhfChannelDestination = $0 }
                    ))
                }
                
                // Conditions
                GroupBox(label: Text("Conditions").font(.headline)) {
                    HStack {
                        NumberField(label: "Pressure in hPa:", inData: $instances.pressure)
                        .frame(width: 300)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    // TODO: Weather description view
                    Button("Define Weather") {
                        showWeatherDesciption = true
                    }
                    .sheet(isPresented: $showWeatherDesciption){
                        WeatherView(instances: instances)
                    }
                    Text("Current Weather conditions :")
                    TextEditor(text: Binding(
                        get: { instances.currentTrip?.weatherAtStart ?? "" },
                        set: { instances.currentTrip?.weatherAtStart = $0 }
                    ))
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                    Text("Weather forecast:")
                    TextEditor(text: Binding(
                        get: { instances.currentTrip?.weatherForecast ?? "" },
                        set: { instances.currentTrip?.weatherForecast = $0 }
                    ))
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                    Text("notices to Mariners in effect:")
                    TextEditor(text: Binding(
                        get: { instances.currentTrip?.noticesToMariner ?? "" },
                        set: { instances.currentTrip?.noticesToMariner = $0 }
                    ))
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                    // TODO: Tidal info component
                }
                
                // Inventory & NMEA
                GroupBox(label: Text("Inventory").font(.headline)) {
                    NumberField(label: "Motor Hours", inData: $instances.motorHours, inString: myFormat.string(for: instances.motorHours) ?? "" )
                    Text("%Water level:")
                    Slider(value: Binding(
                        get: { Double(instances.waterLevel) },
                        set: { instances.waterLevel = Int($0) }
                    ), in: 0...100) { Text("Water %") }
                    Text("%Fuel level:")
                    Slider(value: Binding(
                        get: { Double(instances.fuelLevel) },
                        set: { instances.fuelLevel = Int($0) }
                    ), in: 0...100) { Text("Fuel %") }
                    Text("%Battery level:")
                    Slider(value: Binding(
                        get: { Double(instances.batteryLevel) },
                        set: { instances.batteryLevel = Int($0) }
                    ), in: 0...100) { Text("Battery %") }
                    Button("Test NMEA") {
                        // TODO: trigger NMEA test
                    }
                }
                
                Spacer()
                
                // Go To Log
                Button(action: {
                    navPath.path.append(HomePageNavigation.actionLog)
                }) {
                    Text("Go To Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke())
                }
            }
            .padding()
            .onAppear {
                if (instances.currentTrip == nil) {
                    let newTrip = Trip()
                    newTrip.dateOfStart = Date.now
                    modelContext.insert(newTrip)
                    instances.currentTrip = newTrip
                    instances.dateOfStart = newTrip.dateOfStart
                    if instances.currentLocation != nil {
                        newTrip.startPlace = instances.currentLocation
                    }
                    thisTrip = newTrip
                }
                else {thisTrip = instances.currentTrip!}
                
                // Clamp date
                let start = instances.dateOfStart
                if start < todayStart {
                    instances.dateOfStart = todayStart
                    instances.currentTrip?.dateOfStart = todayStart
                } else if let tom = tomorrowStart, start > tom {
                    instances.dateOfStart = tom
                    instances.currentTrip?.dateOfStart = tom
                }
                // Cruise auto-detect once
                if instances.currentCruise == nil,
                   let match = allCruises.first(where: {
                       $0.Boat?.id == instances.selectedBoat.id &&
                       $0.DateOfStart <= start &&
                       ($0.DateOfArrival ?? Date.distantFuture) >= start
                   })  {
                    detectedCruise = match
                    showCruiseAlert = true
                }
            }
            .alert("Is trip part of Cruise ?", isPresented: $showCruiseAlert) {
                Button("Yes") {
                    instances.currentCruise = detectedCruise
                    thisTrip!.cruise = detectedCruise
                }
                Button("No", role: .cancel) {}
            } message: {
                Text("Start trip as part of cruise '\(detectedCruise?.Title ?? "")'?" )
            }
        }
        
    }
}
