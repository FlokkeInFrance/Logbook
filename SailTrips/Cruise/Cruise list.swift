//
//  Cruise list.swift
//  SailTrips
//
//  Created by jeroen kok on 15/05/2025.
//
// … Your imports and existing code up here …

import SwiftUI
import SwiftData

// MARK: – CruiseListView (with new SwiftUI 4 alert API)
struct CruiseListView: View {
    @Bindable var instances: Instances
    @EnvironmentObject var pathManager: PathManager
    @Environment(\.modelContext) private var modelContext

    // 1️⃣ Fetch all cruises once, sorted by start date:
    @Query(sort: \Cruise.DateOfStart, order: .forward)
    private var allCruises: [Cruise]

    @State private var showAllBoats = false
    @State private var selectedCruise: Cruise?
    @State private var showingDetail = false
    @State private var showingCopyAlert = false
    @State private var showRestartOption = false
    @State private var showStartOption = false
    @State private var showEndOption = false
    @State private var showAllCruises: Bool = true

    // 3️⃣ Status‐filter toggle + selected status
    @State private var selectCruiseOnStatus = false
    @State private var selectedStatus: CruiseStatus = .planned

    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    // MARK: – “Inconsistency” Alert Enum + State
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    enum AlertType: Identifiable {
        case plannedVsPlanned(cruise: Cruise)
        case plannedVsUnderway(cruise: Cruise)
        case plannedVsCompleted(cruise: Cruise)

        case underwayVsPlanned(cruise: Cruise)
        case underwayVsUnderway(cruise: Cruise)
        case underwayVsCompleted(cruise: Cruise)

        case completedVsPlanned(cruise: Cruise)
        case completedVsUnderway(cruise: Cruise)
        case completedVsCompleted(cruise: Cruise)

        var id: String {
            switch self {
            case let .plannedVsPlanned(c):     return "pp-\(c.id)"
            case let .plannedVsUnderway(c):    return "pu-\(c.id)"
            case let .plannedVsCompleted(c):   return "pc-\(c.id)"
            case let .underwayVsPlanned(c):    return "up-\(c.id)"
            case let .underwayVsUnderway(c):   return "uu-\(c.id)"
            case let .underwayVsCompleted(c):  return "uc-\(c.id)"
            case let .completedVsPlanned(c):   return "cp-\(c.id)"
            case let .completedVsUnderway(c):  return "cu-\(c.id)"
            case let .completedVsCompleted(c): return "cc-\(c.id)"
            }
        }
    }

    @State private var activeAlert: AlertType?

    // 2️⃣ Compute the list to display based on boat & status filters:
    private var cruises: [Cruise] {
        let base = showAllBoats
            ? allCruises
            : allCruises.filter { $0.Boat?.id == instances.selectedBoat.id }

        if selectCruiseOnStatus {
            return base.filter { $0.status == selectedStatus }
        } else {
            return base.filter { [.planned, .underway].contains($0.status) }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            if !showAllCruises {
                // Single ongoing cruise view
                if let current = instances.currentCruise {
                    Text("Ongoing cruise: \(current.Title) on \(instances.selectedBoat.name)")
                        .font(.headline)
                    if instances.currentTrip != nil {
                        Button("Goto trip") {
                            pathManager.path.append(HomePageNavigation.tripCompanion)
                        }
                    } else {
                        Button("Goto cruise") {
                            selectedCruise = instances.currentCruise
                            pathManager.path.append(CruiseNav.detail)
                        }
                    }
                }
                Button("Cruise Completed") {
                    showingCopyAlert = true
                }
                .alert(isPresented: $showingCopyAlert) {
                    Alert(
                        title: Text("Mark cruise as completed?"),
                        primaryButton: .destructive(Text("Yes")) {
                            instances.currentCruise = nil
                        },
                        secondaryButton: .cancel()
                    )
                }
                Button("Show List Of Cruises") {
                    showAllCruises = true
                }

            } else {
                // 3️⃣ Status‐filter controls
                HStack {
                    Button(selectCruiseOnStatus ? "Custom Status" : "Default Status") {
                        selectCruiseOnStatus.toggle()
                    }
                    if selectCruiseOnStatus {
                        Picker("Status", selection: $selectedStatus) {
                            ForEach(CruiseStatus.allCases) { status in
                                Text(status.displayString).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal)
                
                List(selection: $selectedCruise) {
                    ForEach(cruises, id: \.id) { cruise in
                        HStack {
                            // Date + Title + Type
                            VStack {
                                HStack {
                                    if let boat = cruise.Boat {
                                        Text(boat.name)
                                    } else {
                                        Text("Boat")
                                    }
                                    Text(
                                        cruise.DateOfStart,
                                        format: Date.FormatStyle(date: .numeric, time: .omitted)
                                    )
                                    Text("(\(cruise.CruiseType.displayString))")
                                }
                                Text("\(cruise.Title)")
                            }

                            // 1️⃣ Status‐based icons
                            switch cruise.status {
                            case .completed:
                                if let arrival = cruise.DateOfArrival,
                                   arrival.isAfter(Date.now)
                                {
                                    Image(systemName: "exclamationmark.triangle")
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }

                            case .planned:
                                if cruise.DateOfStart.isAfter(Date.now) {
                                    Image(systemName: "eye")
                                } else {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                }

                            case .underway:
                                if let arrival = cruise.DateOfArrival {
                                    if arrival.isAfterOrSame(Date.now)
                                        && cruise.DateOfStart.isBeforeOrSame(Date.now)
                                    {
                                        Image(systemName: "moonphase.full.moon")
                                            .foregroundColor(.green)
                                            .symbolEffect(.pulse, isActive: true)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle")
                                    }
                                } else {
                                    Image(systemName: "questionmark.app")
                                        .foregroundColor(.green)
                                }
                            }

                            // Delete button for future, planned cruises
                            if cruise.DateOfStart.isAfter(Date.now)
                                && cruise.status == .planned
                            {
                                Button {
                                    modelContext.delete(cruise)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .foregroundColor(.red)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCruise = cruise

                            // 1️⃣ Compute “apparent” status from dates:
                            let cruiseEarly = cruise.DateOfStart.isAfter(Date.now)
                            let cruiseLate: Bool = {
                                if let arrival = cruise.DateOfArrival {
                                    return arrival.isBefore(Date.now)
                                } else {
                                    return false
                                }
                            }()
                            let apparentCruiseStatus: CruiseStatus = {
                                if cruiseEarly {
                                    return .planned
                                } else if cruiseLate {
                                    return .completed
                                } else {
                                    return .underway
                                }
                            }()

                            // 2️⃣ Choose which AlertType to fire:
                            switch cruise.status {
                            case .planned:
                                switch apparentCruiseStatus {
                                case .planned:
                                    activeAlert = .plannedVsPlanned(cruise: cruise)
                                case .underway:
                                    activeAlert = .plannedVsUnderway(cruise: cruise)
                                case .completed:
                                    activeAlert = .plannedVsCompleted(cruise: cruise)
                                }

                            case .underway:
                                switch apparentCruiseStatus {
                                case .planned:
                                    activeAlert = .underwayVsPlanned(cruise: cruise)
                                case .underway:
                                    activeAlert = .underwayVsUnderway(cruise: cruise)
                                case .completed:
                                    activeAlert = .underwayVsCompleted(cruise: cruise)
                                }

                            case .completed:
                                switch apparentCruiseStatus {
                                case .planned:
                                    activeAlert = .completedVsPlanned(cruise: cruise)
                                case .underway:
                                    activeAlert = .completedVsUnderway(cruise: cruise)
                                case .completed:
                                    activeAlert = .completedVsCompleted(cruise: cruise)
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingDetail) {
                    if let cruise = selectedCruise {
                        CruiseDetailView(cruise: cruise, instance: instances)
                    }
                }

                // Bottom buttons
                HStack {
                    Button(showAllBoats ? "Current Boat" : "All Boats") {
                        showAllBoats.toggle()
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    if selectedCruise != nil {
                        Button("Details") {
                            showingDetail = true
                        }
                        Button("Copy") {
                            copyCruise()
                        }
                    }
                }
            }
        }
        // ───────────────────────────────────────────────────────────────────────────────
        // ● Modified: use SwiftUI 4 `.alert(_:isPresented:presenting:actions:message:)`
        // ───────────────────────────────────────────────────────────────────────────────
        .alert(
            "",         // ← static/empty title
            isPresented: Binding<Bool>(
                get: { activeAlert != nil },        // show the alert whenever activeAlert != nil
                set: { if !$0 { activeAlert = nil } } // when SwiftUI sets isPresented = false, clear activeAlert
            ),
            presenting: activeAlert    // pass in the enum case
        ) { alertCase in      // ← actions closure
            switch alertCase {
            // 1) Planned vs Planned
            case let .plannedVsPlanned(cruise):
                Button("Go to Detail") {
                    selectedCruise = cruise
                    showingDetail = true
                }
                Button("Copy") {
                    copyCruise()
                }

            // 2) Planned vs Underway
            case let .plannedVsUnderway(cruise):
                Button("Set Underway & Detail") {
                    startCruise(thisCruise: cruise)
                }
                Button("Postpone by 7 Days") {
                    postponeCruise7Days(cruise)
                    selectedCruise = cruise
                    showingDetail = true
                }
                Button("Go to Detail") {
                    selectedCruise = cruise
                    showingDetail = true
                }

            // 3) Planned vs Completed
            case let .plannedVsCompleted(cruise):
                Button("Set Completed") {
                    cruise.status = .completed
                    if instances.currentCruise == cruise {
                        instances.currentCruise = nil
                    }
                    try? modelContext.save()
                }
                Button("Postpone by 7 Days") {
                    postponeCruise7Days(cruise)
                    selectedCruise = cruise
                    showingDetail = true
                }
                Button("Go to Detail") {
                    selectedCruise = cruise
                    showingDetail = true
                }

            // 4) Underway vs Planned
            case let .underwayVsPlanned(cruise):
                Button("Set to Planned") {
                    cruise.status = .planned
                    if instances.currentCruise == cruise {
                        instances.currentCruise = nil
                    }
                    try? modelContext.save()
                }
                Button("Postpone by 7 Days & Underway") {
                    postponeCruise7Days(cruise)
                    cruise.status = .underway
                    instances.currentCruise = cruise
                    try? modelContext.save()
                    selectedCruise = cruise
                    showingDetail = true
                }
                Button("Go to Detail") {
                    selectedCruise = cruise
                    showingDetail = true
                }

            // 5) Underway vs Underway
            case let .underwayVsUnderway(cruise):
                Button("Start,show Detail") {
                    selectedCruise = cruise
                    instances.currentCruise = cruise
                    pathManager.path.append(CruiseNav.detail)
                }
                Button("Copy") {
                    copyCruise()
                }

            // 6) Underway vs Completed
            case let .underwayVsCompleted(cruise):
                Button("Set Completed") {
                    cruise.status = .completed
                    if instances.currentCruise == cruise {
                        instances.currentCruise = nil
                    }
                    try? modelContext.save()
                }
                Button("Prepone by 7 Days") {
                    preponeCruise7Days(cruise)
                    // After prepone: if arrival ≥ today, set .underway; else .completed
                    if let arr = cruise.DateOfArrival {
                        if arr.isAfter(Date.now) {
                            cruise.status = .underway
                            instances.currentCruise = cruise
                        } else {
                            cruise.status = .completed
                            if instances.currentCruise == cruise {
                                instances.currentCruise = nil
                            }
                        }
                    }
                    try? modelContext.save()
                    selectedCruise = cruise
                    showingDetail = true
                }
                Button("Go to Detail") {
                    selectedCruise = cruise
                    showingDetail = true
                }

            // 7) Completed vs Planned
            case let .completedVsPlanned(cruise):
                Button("Set Planned") {
                    cruise.status = .planned
                    if instances.currentCruise == cruise {
                        instances.currentCruise = nil
                    }
                    try? modelContext.save()
                }
                Button("Prepone by 7 Days") {
                    preponeCruise7Days(cruise)
                    // After prepone, arrival < today → keep .completed
                    cruise.status = .completed
                    if instances.currentCruise == cruise {
                        instances.currentCruise = nil
                    }
                    try? modelContext.save()
                    selectedCruise = cruise
                    showingDetail = true
                }
                Button("Go to Detail") {
                    selectedCruise = cruise
                    showingDetail = true
                }

            // 8) Completed vs Underway
            case let .completedVsUnderway(cruise):
                Button("Set Underway") {
                    cruise.status = .underway
                    instances.currentCruise = cruise
                    try? modelContext.save()
                }
                Button("Prepone by 7 Days") {
                    preponeCruise7Days(cruise)
                    // After prepone, arrival < today → keep .completed
                    cruise.status = .completed
                    if instances.currentCruise == cruise {
                        instances.currentCruise = nil
                    }
                    try? modelContext.save()
                    selectedCruise = cruise
                    showingDetail = true
                }
                Button("Go to Detail") {
                    selectedCruise = cruise
                    showingDetail = true
                }

            // 9) Completed vs Completed
            case let .completedVsCompleted(cruise):
                Button("Go to Detail") {
                    selectedCruise = cruise
                    showingDetail = true
                }
                Button("Copy") {
                    copyCruise()
                }
            }
        } message: { alertCase in   // ← message closure
            switch alertCase {
            case .plannedVsPlanned:
                return Text(
                    "Cruise is in the future\n\n" +
                    "Everything looks consistent. What do you want to do?"
                )
            case .plannedVsUnderway:
                return Text(
                    "Cruise appears to be underway\n\n" +
                    "The dates overlap with today—how do you want to proceed?"
                )
            case .plannedVsCompleted:
                return Text(
                    "Cruise appears completed\n\n" +
                    "Arrival is already in the past. How do you want to proceed?"
                )

            case .underwayVsPlanned:
                return Text(
                    "Cruise seems still in preparation\n\n" +
                    "Dates are still entirely in the future. What do you want to do?"
                )
            case .underwayVsUnderway:
                return Text(
                    "Cruise is already underway\n\n" +
                    "Everything is consistent—what do you want to do?"
                )
            case .underwayVsCompleted:
                return Text(
                    "Cruise appears to be completed because\n\n" +
                    "arrival date is in the past. How do you want to handle it?"
                )

            case .completedVsPlanned:
                return Text(
                    "Cruise still in the future\n\n" +
                    "Dates do not match “completed” status. How do you want to fix it?"
                )
            case .completedVsUnderway:
                return Text(
                    "Cruise appears to be underway\n\n" +
                    "Dates overlap today but status is “completed.” How do you want to fix it?"
                )
            case .completedVsCompleted:
                return Text(
                    "Cruise is completed\n\n" +
                    "Everything is consistent—what do you want to do?"
                )
            }
        }
        // ───────────────────────────────────────────────────────────────────────────────

        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: addCruise) {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: CruiseNav.self) { nav in
            switch nav {
            case .detail:
                if let cruise = selectedCruise {
                    CruiseDetailView(cruise: cruise, instance: instances)
                }
            default:
                fatalError("Unhandled Navigation Destination")
            }
        }
        .navigationTitle(showAllCruises
            ? "All Cruises"
            : "Cruises – \(instances.selectedBoat.name)")
        .onAppear {
            if let current = instances.currentCruise {
                selectedCruise = current
                showAllCruises = false
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────────
    // MARK: – Existing Actions (unchanged)
    // ───────────────────────────────────────────────────────────────────────────────
    private func startCruise(thisCruise: Cruise) {
        thisCruise.status = .underway
        instances.currentCruise = thisCruise
        instances.odometerForCruise = 0
        instances.odometerForTrip = 0
        try? modelContext.save()
        pathManager.path.append(CruiseNav.detail)
    }

    private func endCruise(thisCruise: Cruise) {
        thisCruise.status = .completed
        if instances.currentCruise == thisCruise {
            instances.currentCruise = nil
        }
        try? modelContext.save()
    }

    private func postponeCruise(thisCruise: Cruise) {
        thisCruise.status = .planned
        if let arrival = thisCruise.DateOfArrival {
            let duration = arrival.timeIntervalSince(thisCruise.DateOfStart)
            thisCruise.DateOfArrival = Date.now.addingTimeInterval(duration + 3600 * 24)
        }
        thisCruise.DateOfStart = Date.now.addingTimeInterval(3600 * 24)
        if instances.currentCruise == thisCruise {
            instances.currentCruise = nil
        }
        try? modelContext.save()
    }

    private func addCruise() {
        let new = Cruise()
        new.Boat = instances.selectedBoat
        new.DateOfStart = Date.now
        new.DateOfArrival = Date.now.addingTimeInterval(3600 * 24)
        new.Departure = instances.currentLocation?.Name ?? ""
        new.CruiseType = TypeOfCruise.round
        new.status = CruiseStatus.planned
        modelContext.insert(new)
        selectedCruise = new
        showingDetail = true
    }

    private func copyCruise() {
        guard let original = selectedCruise else { return }
        let copy = Cruise()
        copy.Title = original.Title
        copy.Boat = instances.selectedBoat
        copy.DateOfStart = Date()
        if let arrival = original.DateOfArrival {
            let duration = arrival.timeIntervalSince(original.DateOfStart)
            copy.DateOfArrival = Date().addingTimeInterval(duration)
        }
        copy.Crew = original.Crew
        copy.legs = original.legs
        modelContext.insert(copy)
        showingDetail = true
    }

    // ───────────────────────────────────────────────────────────────────────────────
    // MARK: – New “7‐day shift” Helpers (unchanged)
    // ───────────────────────────────────────────────────────────────────────────────
    private func preponeCruise7Days(_ cruise: Cruise) {
        guard let originalArrival = cruise.DateOfArrival else {
            // If no arrival, set both 7 days before today, with a 1‐day fallback
            let newArrival = Date.now.addingDays(-7)
            cruise.DateOfArrival = newArrival
            cruise.DateOfStart = newArrival.addingDays(-1)
            return
        }
        let originalStart = cruise.DateOfStart
        let originalDurationDays = Calendar.current.dateComponents([.day],
            from: originalStart.startOfDay(),
            to: originalArrival.startOfDay()).day ?? 0

        let newArrival = Date.now.addingDays(-7)
        let newStart = Calendar.current.date(
            byAdding: .day,
            value: -originalDurationDays,
            to: newArrival) ?? newArrival

        cruise.DateOfStart = newStart
        cruise.DateOfArrival = newArrival

        if instances.currentCruise == cruise {
            instances.currentCruise = nil
        }
        try? modelContext.save()
    }

    private func postponeCruise7Days(_ cruise: Cruise) {
        guard let originalArrival = cruise.DateOfArrival else {
            // If no arrival, set both 7 days after today, with a 1‐day fallback
            let newStart = Date.now.addingDays(7)
            cruise.DateOfStart = newStart
            cruise.DateOfArrival = newStart.addingDays(1)
            cruise.status = .planned
            return
        }
        let originalStart = cruise.DateOfStart
        let originalDurationDays = Calendar.current.dateComponents([.day],
            from: originalStart.startOfDay(),
            to: originalArrival.startOfDay()).day ?? 0

        let newStart = Date.now.addingDays(7)
        let newArrival = Calendar.current.date(
            byAdding: .day,
            value: originalDurationDays,
            to: newStart) ?? newStart

        cruise.DateOfStart = newStart
        cruise.DateOfArrival = newArrival
        cruise.status = .planned

        if instances.currentCruise == cruise {
            instances.currentCruise = nil
        }
        try? modelContext.save()
    }
}

// — Helper extension to get startOfDay() for a Date —
private extension Date {
    func startOfDay() -> Date {
        Calendar.current.startOfDay(for: self)
    }
}


/*struct CruiseListView: View {
    @Bindable var instances: Instances
    @EnvironmentObject var pathManager: PathManager
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Cruise.DateOfStart, order: .forward)
    private var allCruises: [Cruise]
    
    @State private var showAllBoats = false
    @State private var selectedCruise: Cruise?
    @State private var showingDetail = false
    @State private var showingCopyAlert = false
    @State private var showRestartOption = false
    @State private var showStartOption = false
    @State private var showEndOption = false
    @State private var showAllCruises: Bool = true
    
    @State private var selectCruiseOnStatus = false
    @State private var selectedStatus: CruiseStatus = .planned
    
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    // MARK: – Active “Inconsistency” Alert
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    enum AlertType: Identifiable {
        case plannedVsPlanned(cruise: Cruise)
        case plannedVsUnderway(cruise: Cruise)
        case plannedVsCompleted(cruise: Cruise)
        
        case underwayVsPlanned(cruise: Cruise)
        case underwayVsUnderway(cruise: Cruise)
        case underwayVsCompleted(cruise: Cruise)
        
        case completedVsPlanned(cruise: Cruise)
        case completedVsUnderway(cruise: Cruise)
        case completedVsCompleted(cruise: Cruise)
        
        var id: String {
            switch self {
            case let .plannedVsPlanned(c): return "pp-\(c.id)"
            case let .plannedVsUnderway(c): return "pu-\(c.id)"
            case let .plannedVsCompleted(c): return "pc-\(c.id)"
            case let .underwayVsPlanned(c): return "up-\(c.id)"
            case let .underwayVsUnderway(c): return "uu-\(c.id)"
            case let .underwayVsCompleted(c): return "uc-\(c.id)"
            case let .completedVsPlanned(c): return "cp-\(c.id)"
            case let .completedVsUnderway(c): return "cu-\(c.id)"
            case let .completedVsCompleted(c): return "cc-\(c.id)"
            }
        }
    }
    
    @State private var activeAlert: AlertType?
    @State private var showAlert: Bool = false
    
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    // MARK: – Filtered Cruises
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    private var cruises: [Cruise] {
        let base = showAllBoats
            ? allCruises
            : allCruises.filter { $0.Boat?.id == instances.selectedBoat.id }
        
        if selectCruiseOnStatus {
            return base.filter { $0.status == selectedStatus }
        } else {
            return base.filter { [.planned, .underway].contains($0.status) }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if !showAllCruises {
                if let current = instances.currentCruise {
                    Text("Ongoing cruise: \(current.Title) on \(instances.selectedBoat.name)")
                        .font(.headline)
                    if instances.currentTrip != nil {
                        Button("Goto trip") {
                            pathManager.path.append(HomePageNavigation.tripCompanion)
                        }
                    } else {
                        Button("Goto cruise") {
                            selectedCruise = instances.currentCruise
                            pathManager.path.append(CruiseNav.detail)
                        }
                    }
                }
                Button("Cruise Completed") {
                    showingCopyAlert = true
                }
                .alert(isPresented: $showingCopyAlert) {
                    Alert(
                        title: Text("Mark cruise as completed?"),
                        primaryButton: .destructive(Text("Yes")) {
                            instances.currentCruise = nil
                        },
                        secondaryButton: .cancel()
                    )
                }
                Button("Show List Of Cruises") {
                    showAllCruises = true
                }
                
            } else { // showAllCruises == true
                // — Status‐filter controls —
                HStack {
                    Button(selectCruiseOnStatus ? "Custom Status" : "Default Status") {
                        selectCruiseOnStatus.toggle()
                    }
                    if selectCruiseOnStatus {
                        Picker("Status", selection: $selectedStatus) {
                            ForEach(CruiseStatus.allCases) { status in
                                Text(status.rawValue).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal)
                
                List(selection: $selectedCruise) {
                    ForEach(cruises, id: \.id) { cruise in
                        HStack {
                            VStack {
                                HStack {
                                    if let boat = cruise.Boat {
                                        Text(boat.name)
                                    } else {
                                        Text("Boat")
                                    }
                                    Text(cruise.DateOfStart, format: Date.FormatStyle(date: .numeric, time: .omitted))
                                    Text("(\(cruise.CruiseType.rawValue))")
                                }
                                Text("\(cruise.Title)")
                            }
                            
                            // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                            //   Status‐based icons:
                            // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                            switch cruise.status {
                            case .completed:
                                if let arrival = cruise.DateOfArrival, arrival.isAfter(Date.now) {
                                    Image(systemName: "exclamationmark.triangle")
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                
                            case .planned:
                                if cruise.DateOfStart.isAfter(Date.now) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                } else {
                                    Image(systemName: "eye")
                                }
                                
                            case .underway:
                                if let arrival = cruise.DateOfArrival {
                                    if arrival.isAfter(Date.now) && cruise.DateOfStart.isBefore(Date.now) {
                                        Image(systemName: "moonphase.full.moon")
                                            .foregroundColor(.green)
                                            .symbolEffect(.pulse, isActive: true)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle")
                                    }
                                } else {
                                    Image(systemName: "moonphase.full.moon")
                                        .foregroundColor(.green)
                                }
                            }
                            
                            // Delete button for future planned cruises
                            if cruise.DateOfStart.isAfter(Date.now) && cruise.status == .planned {
                                Button {
                                    modelContext.delete(cruise)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .foregroundColor(.red)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCruise = cruise
                            
                            // — Compute “apparent status” from dates —
                            let cruiseEarly = cruise.DateOfStart.isAfter(Date.now)
                            let cruiseLate: Bool = {
                                if let arrival = cruise.DateOfArrival {
                                    return arrival.isBefore(Date.now)
                                } else {
                                    return false
                                }
                            }()
                            
                            let apparentCruiseStatus: CruiseStatus = {
                                if cruiseEarly {
                                    return .planned
                                } else if cruiseLate {
                                    return .completed
                                } else {
                                    return .underway
                                }
                            }()
                            
                            // — Decide which Alert to fire —
                            switch cruise.status {
                            case .planned:
                                switch apparentCruiseStatus {
                                case .planned:
                                    activeAlert = .plannedVsPlanned(cruise: cruise)
                                case .underway:
                                    activeAlert = .plannedVsUnderway(cruise: cruise)
                                case .completed:
                                    activeAlert = .plannedVsCompleted(cruise: cruise)
                                }
                                
                            case .underway:
                                switch apparentCruiseStatus {
                                case .planned:
                                    activeAlert = .underwayVsPlanned(cruise: cruise)
                                case .underway:
                                    activeAlert = .underwayVsUnderway(cruise: cruise)
                                case .completed:
                                    activeAlert = .underwayVsCompleted(cruise: cruise)
                                }
                                
                            case .completed:
                                switch apparentCruiseStatus {
                                case .planned:
                                    activeAlert = .completedVsPlanned(cruise: cruise)
                                case .underway:
                                    activeAlert = .completedVsUnderway(cruise: cruise)
                                case .completed:
                                    activeAlert = .completedVsCompleted(cruise: cruise)
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingDetail) {
                    if let cruise = selectedCruise {
                        CruiseDetailView(cruise: cruise, instance: instances)
                    }
                }
                
                // Bottom buttons
                HStack {
                    Button(showAllBoats ? "Current Boat" : "All Boats") {
                        showAllBoats.toggle()
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    if selectedCruise != nil {
                        Button("Details") { showingDetail = true }
                        Button("Copy") { copyCruise() }
                    }
                }
            }
        }
        // — Single alert‐modifier tied to “activeAlert” —
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            // ──────────────────────────────────────────────────────────────────────────────
            //   1) Planned vs Planned
            // ──────────────────────────────────────────────────────────────────────────────
            case let .plannedVsPlanned(cruise):
                return Alert(
                    title: Text("Cruise is in the future"),
                    message: Text("Everything looks consistent. What do you want to do?"),
                    primaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    },
                    secondaryButton: .default(Text("Copy")) {
                        copyCruise()
                    }
                )
                
            // ──────────────────────────────────────────────────────────────────────────────
            //   2) Planned vs Underway
            // ──────────────────────────────────────────────────────────────────────────────
            case let .plannedVsUnderway(cruise):
                return Alert(
                    title: Text("Cruise appears to be underway"),
                    message: Text("The dates overlap with today—how do you want to proceed?"),
                    primaryButton: .default(Text("Set Underway & Detail")) {
                        startCruise(thisCruise: cruise)
                    },
                    secondaryButton: .default(Text("Postpone by 7 Days")) {
                        postponeCruise7Days(cruise)
                        selectedCruise = cruise
                        showingDetail = true
                    }//,
                    /*tertiaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    }*/
                )
                
            // ──────────────────────────────────────────────────────────────────────────────
            //   3) Planned vs Completed
            // ──────────────────────────────────────────────────────────────────────────────
            case let .plannedVsCompleted(cruise):
                return Alert(
                    title: Text("Cruise appears completed"),
                    message: Text("Arrival is already in the past. How do you want to proceed?"),
                    primaryButton: .default(Text("Set Completed")) {
                        cruise.status = .completed
                        if instances.currentCruise == cruise {
                            instances.currentCruise = nil
                        }
                        try? modelContext.save()
                    },
                    secondaryButton: .default(Text("Postpone by 7 Days")) {
                        postponeCruise7Days(cruise)
                        selectedCruise = cruise
                        showingDetail = true
                    },
                    tertiaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    }
                )
                
            // ──────────────────────────────────────────────────────────────────────────────
            //   4) Underway vs Planned
            // ──────────────────────────────────────────────────────────────────────────────
            case let .underwayVsPlanned(cruise):
                return Alert(
                    title: Text("Cruise seems still in preparation"),
                    message: Text("Dates are still entirely in the future. What do you want to do?"),
                    primaryButton: .default(Text("Set to Planned")) {
                        cruise.status = .planned
                        if instances.currentCruise == cruise {
                            instances.currentCruise = nil
                        }
                        try? modelContext.save()
                    },
                    secondaryButton: .default(Text("Postpone by 7 Days & Underway")) {
                        postponeCruise7Days(cruise)
                        cruise.status = .underway
                        instances.currentCruise = cruise
                        try? modelContext.save()
                        selectedCruise = cruise
                        showingDetail = true
                    },
                    tertiaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    }
                )
                
            // ──────────────────────────────────────────────────────────────────────────────
            //   5) Underway vs Underway
            // ──────────────────────────────────────────────────────────────────────────────
            case let .underwayVsUnderway(cruise):
                return Alert(
                    title: Text("Cruise is already underway"),
                    message: Text("Everything is consistent—what do you want to do?"),
                    primaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    },
                    secondaryButton: .default(Text("Copy")) {
                        copyCruise()
                    }
                )
                
            // ──────────────────────────────────────────────────────────────────────────────
            //   6) Underway vs Completed
            // ──────────────────────────────────────────────────────────────────────────────
            case let .underwayVsCompleted(cruise):
                return Alert(
                    title: Text("Cruise appears to be completed"),
                    message: Text("Arrival date is in the past. How do you want to handle it?"),
                    primaryButton: .default(Text("Set Completed")) {
                        cruise.status = .completed
                        if instances.currentCruise == cruise {
                            instances.currentCruise = nil
                        }
                        try? modelContext.save()
                    },
                    secondaryButton: .default(Text("Prepone by 7 Days")) {
                        preponeCruise7Days(cruise)
                        // After prepone, if arrival ≥ today, set .underway; otherwise .completed
                        if let arr = cruise.DateOfArrival {
                            if arr.isAfter(Date.now) {
                                cruise.status = .underway
                                instances.currentCruise = cruise
                            } else {
                                cruise.status = .completed
                                if instances.currentCruise == cruise {
                                    instances.currentCruise = nil
                                }
                            }
                        }
                        try? modelContext.save()
                        selectedCruise = cruise
                        showingDetail = true
                    },
                    tertiaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    }
                )
                
            // ──────────────────────────────────────────────────────────────────────────────
            //   7) Completed vs Planned
            // ──────────────────────────────────────────────────────────────────────────────
            case let .completedVsPlanned(cruise):
                return Alert(
                    title: Text("Cruise still in the future"),
                    message: Text("Dates do not match “completed” status. How do you want to fix it?"),
                    primaryButton: .default(Text("Set Planned")) {
                        cruise.status = .planned
                        if instances.currentCruise == cruise {
                            instances.currentCruise = nil
                        }
                        try? modelContext.save()
                    },
                    secondaryButton: .default(Text("Prepone by 7 Days")) {
                        preponeCruise7Days(cruise)
                        // After prepone, arrival < today, so we keep .completed
                        cruise.status = .completed
                        if instances.currentCruise == cruise {
                            instances.currentCruise = nil
                        }
                        try? modelContext.save()
                        selectedCruise = cruise
                        showingDetail = true
                    },
                    tertiaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    }
                )
                
            // ──────────────────────────────────────────────────────────────────────────────
            //   8) Completed vs Underway
            // ──────────────────────────────────────────────────────────────────────────────
            case let .completedVsUnderway(cruise):
                return Alert(
                    title: Text("Cruise appears to be underway"),
                    message: Text("Dates overlap today but status is “completed.” How do you want to fix it?"),
                    primaryButton: .default(Text("Set Underway")) {
                        cruise.status = .underway
                        instances.currentCruise = cruise
                        try? modelContext.save()
                    },
                    secondaryButton: .default(Text("Prepone by 7 Days")) {
                        preponeCruise7Days(cruise)
                        // After prepone, arrival < today, so keep status = .completed
                        cruise.status = .completed
                        if instances.currentCruise == cruise {
                            instances.currentCruise = nil
                        }
                        try? modelContext.save()
                        selectedCruise = cruise
                        showingDetail = true
                    },
                    tertiaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    }
                )
                
            // ──────────────────────────────────────────────────────────────────────────────
            //   9) Completed vs Completed
            // ──────────────────────────────────────────────────────────────────────────────
            case let .completedVsCompleted(cruise):
                return Alert(
                    title: Text("Cruise is completed"),
                    message: Text("Everything is consistent—what do you want to do?"),
                    primaryButton: .default(Text("Go to Detail")) {
                        selectedCruise = cruise
                        showingDetail = true
                    },
                    secondaryButton: .default(Text("Copy")) {
                        copyCruise()
                    }
                )
            }
        }
        // — Toolbar, navigation, onAppear, etc. —
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: addCruise) {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: CruiseNav.self) { nav in
            switch nav {
            case .detail:
                if let cruise = selectedCruise {
                    CruiseDetailView(cruise: cruise, instance: instances)
                }
            default:
                fatalError("Unhandled Navigation Destination")
            }
        }
        .navigationTitle(showAllCruises ? "All Cruises" : "Cruises – \(instances.selectedBoat.name)")
        .onAppear {
            if let current = instances.currentCruise {
                selectedCruise = current
                showAllCruises = false
            }
        }
    }
    
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    // MARK: – Existing Actions (unchanged)
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    private func startCruise(thisCruise: Cruise) {
        thisCruise.status = .underway
        instances.currentCruise = thisCruise
        try? modelContext.save()
        pathManager.path.append(CruiseNav.detail)
    }
    
    private func endCruise(thisCruise: Cruise) {
        thisCruise.status = .completed
        if instances.currentCruise == thisCruise {
            instances.currentCruise = nil
        }
        try? modelContext.save()
    }
    
    private func postponeCruise(thisCruise: Cruise) {
        thisCruise.status = .planned
        if let arrival = thisCruise.DateOfArrival {
            let duration = arrival.timeIntervalSince(thisCruise.DateOfStart)
            thisCruise.DateOfArrival = Date.now.addingTimeInterval(duration + 3600 * 24)
        }
        thisCruise.DateOfStart = Date.now.addingTimeInterval(3600 * 24)
        if instances.currentCruise == thisCruise {
            instances.currentCruise = nil
        }
        try? modelContext.save()
    }
    
    private func addCruise() {
        let new = Cruise()
        new.Boat = instances.selectedBoat
        new.DateOfStart = Date.now
        new.DateOfArrival = Date.now.addingTimeInterval(3600 * 24)
        new.Departure = instances.currentLocation?.Name ?? ""
        new.CruiseType = TypeOfCruise.round
        new.status = CruiseStatus.planned
        modelContext.insert(new)
        selectedCruise = new
        showingDetail = true
    }

    private func copyCruise() {
        guard let original = selectedCruise else { return }
        let copy = Cruise()
        copy.Title = original.Title
        copy.Boat = instances.selectedBoat
        copy.DateOfStart = Date()
        if let arrival = original.DateOfArrival {
            let duration = arrival.timeIntervalSince(original.DateOfStart)
            copy.DateOfArrival = Date().addingTimeInterval(duration)
        }
        copy.Crew = original.Crew
        copy.legs = original.legs
        modelContext.insert(copy)
        showingDetail = true
    }
    
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    // MARK: – New “7-day shift” Helpers
    // ●–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––●
    private func preponeCruise7Days(_ cruise: Cruise) {
        guard let originalArrival = cruise.DateOfArrival else {
            // If no arrival, set both 7 days before today, with a 1-day fallback
            let newArrival = Date.now.addingDays(-7)
            cruise.DateOfArrival = newArrival
            cruise.DateOfStart = newArrival.addingDays(-1)
            return
        }
        let originalStart = cruise.DateOfStart
        let originalDurationDays = Calendar.current.dateComponents([.day],
            from: originalStart.startOfDay(),
            to: originalArrival.startOfDay()).day ?? 0
        
        let newArrival = Date.now.addingDays(-7)
        let newStart = Calendar.current.date(
            byAdding: .day,
            value: -originalDurationDays,
            to: newArrival) ?? newArrival
        
        cruise.DateOfStart = newStart
        cruise.DateOfArrival = newArrival
        
        if instances.currentCruise == cruise {
            instances.currentCruise = nil
        }
        try? modelContext.save()
    }
    
    private func postponeCruise7Days(_ cruise: Cruise) {
        guard let originalArrival = cruise.DateOfArrival else {
            // If no arrival, set both 7 days after today, with a 1-day fallback
            let newStart = Date.now.addingDays(7)
            cruise.DateOfStart = newStart
            cruise.DateOfArrival = newStart.addingDays(1)
            cruise.status = .planned
            return
        }
        let originalStart = cruise.DateOfStart
        let originalDurationDays = Calendar.current.dateComponents([.day],
            from: originalStart.startOfDay(),
            to: originalArrival.startOfDay()).day ?? 0
        
        let newStart = Date.now.addingDays(7)
        let newArrival = Calendar.current.date(
            byAdding: .day,
            value: originalDurationDays,
            to: newStart) ?? newStart
        
        cruise.DateOfStart = newStart
        cruise.DateOfArrival = newArrival
        cruise.status = .planned
        
        if instances.currentCruise == cruise {
            instances.currentCruise = nil
        }
        try? modelContext.save()
    }
}

// — Helper extension to get startOfDay() for a Date —
private extension Date {
    func startOfDay() -> Date {
        Calendar.current.startOfDay(for: self)
    }
}
*/
