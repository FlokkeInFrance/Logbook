//
//  LogbookActionView.swift
//  SailTrips
//
//  Created by jeroen kok on 25/11/2025.
//

//
//  LogActionView.swift
//  SailTrips
//
//  Created by ChatGPT on 25/11/2025.
//

//
//  LogActionView.swift
//  SailTrips
//
//  Rebuilt version with:
//  - Situation picker (S1, S2… via SituationDefinition)
//  - Fixed AF top bar (AF1..AF17)
//  - 4-per-line grid for situation-dependent actions
//


import SwiftUI
import SwiftData

struct LogActionView: View {
    // MARK: - Inputs
    
    @Bindable var instances: Instances
    
    let showBanner: (String) -> Void
    let openDangerSheet: (ActionVariant) -> Void
    let onClose: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query var settings: [LogbookSettings]
    
    private let registry = ActionRegistry.makeDefault()
    
    // situations come from registry (static map / helper in your extension)
    private var situations: [SituationDefinition] {
        ActionRegistry.allSituations
        // If you named it differently, e.g. `allSituationDefinitions`,
        // replace with that.
    }
    
    // MARK: - State
    
    /// Currently selected situation (for v1, chosen manually).
    @State private var currentSituationID: SituationID
    
    /// Optional toast/banner text (short feedback after actions).
    @State private var bannerText: String?
    @State private var showBannerView: Bool = false
    
    //addition states for sheets
    
    @State private var showSailPlanSheet = false
    @State private var sailPlanRuntime: ActionRuntime? = nil
    @State private var autopilotRuntime: ActionRuntime? = nil
    @State private var showAutopilotSheet = false

    @State private var showSailingSheet = false
    @State private var sailingRuntime: ActionRuntime? = nil
    @State private var showMooringPicker = false
    @State private var mooringRuntime: ActionRuntime? = nil


    
    // state for text prompt (one line of text)
    @State private var textPromptRequest: ActionTextPromptRequest?
    @State private var confirmRequest: ActionConfirmRequest?
    @State private var showTankInventorySheet = false
    @State private var tankInventoryFilterKinds: Set<TankTypes>? = nil

    @State private var tankSnapshot: [UUID: Int] = [:]          // tank.id -> percentFull
    @State private var tankSheetOriginTag: String? = nil        // "A9" or "AF18"
    // AF4
    @State private var showProblemReporterSheet = false
    @State private var problemText: String = ""
    @State private var problemImages: [UIImage] = []
    // AF5
    @State private var showManualLogSheet = false
    // AF6
    @State private var showInstancesEditorSheet = false

    @State private var showNMEATestSheet = false
    // LogActionView.swift
    @StateObject private var pos = PositionUpdater()
    
    // MARK: - Init
    
    init(
        instances: Instances,
        initialSituationID: SituationID? = nil,
        showBanner: @escaping (String) -> Void,
        openDangerSheet: @escaping (ActionVariant) -> Void,
        onClose: @escaping () -> Void
    ) {
        self._instances = Bindable(wrappedValue: instances)
        self.showBanner = showBanner
        self.openDangerSheet = openDangerSheet
        self.onClose = onClose
        
        // Derive from instances if caller doesn't force a situation
        let derived = instances.derivedSituationID()
        _currentSituationID = State(initialValue: initialSituationID ?? derived)
    }

    // Current situation definition (if any).
    private var currentDefinition: SituationDefinition? {
        situations.first { $0.id == currentSituationID }
    }
    
    /// AF tags for the permanent top bar (fixed list).
    private let topAFTags: [String] = [
        "AF1",  // Danger spotted
        "AF2",  // Start motor
        "AF2R", // Stop motor
        "AF21", // Motors (multi-motor sheet)
        "AF2S", // Sails for Motor
        "AF3N", // Night
        "AF3D", // Day
        "AF4",  // Failure report
        "AF5",  // Manual log
        "AF6",  // Modify instances
        "AF7",  // Crew incident
        "AF8",  // Run checklist
        "AF9",  // Weather report
        "AF10", // Encounter
        "AF11", // Insert WPT
        //"AF12", // Back to trip page
        "AF14", // Change destination
        "AF15", // Log position
        "AF15x", //test nmea stream
        "AF16", // Goto next WPT
        "AF17", // use extrarigging
        "AF18"  //get new tank levels
]
    
    // MARK: - Fixed AF groups (layout)
    
    /// First line: emergency actions (bigger, red buttons)
    private let emergencyTags: [String] = [
        "E1", "E2", "E3", "E4"
    ]
    
    /// Second line: checklists & incidents
    private let checklistIncidentTags: [String] = [
        "AF8", "AF7", "AF4"
    ]
    
    /// Third line: motor
    private let motorTags: [String] = [
        "AF2", "AF2R", "AF21", "AF2S"
    ]
    
    /// Fourth line: navigation
    private let navigationTags: [String] = [
        "AF12", "AF14", "AF11", "AF16"
    ]
    
    /// Fifth line: environment
    private let environmentTags: [String] = [
        "AF3", "AF9", "AF10", "AF1"
    ]
    
    /// Sixth line: other logs
    private let otherLogTags: [String] = [
        "AF18", "AF5", "AF6", "AF15", "AF15x"
    ]
    
    
    /// Grid layout: 4 items per row.
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }
    
    // define the actionContext

    private var actionContext: ActionContext {
        ActionContext(
            instances: instances,
            modelContext: modelContext,
            currentSettings: { settings.first ?? LogbookSettings() },
            showBanner: { msg in
                showBanner(msg)
                bannerText = msg
                withAnimation { showBannerView = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showBannerView = false }
                }
            },
            openDangerSheet: openDangerSheet,
            presentTextPrompt: { request in
                Task { @MainActor in textPromptRequest = request }
            },
            presentConfirm: { request in                      // ✅ NEW
                Task { @MainActor in confirmRequest = request }
            },
            openSailingGeometrySheet: { variant in            // ✅ NEW
                Task { @MainActor in
                    guard !showSailingSheet else { return }
                    let rt = ActionRuntime(context: actionContext, variant: variant)
                    sailingRuntime = rt
                    showSailingSheet = true
                }
            },
            positionUpdater: pos,
            nmeaSnapshot: {
                // later: return nmeaAdapter.latestSnapshot
                nil
            }
        )
    }

    // MARK: - Body
    //***************************
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                titleBar
                Divider()
                topFixedAFBar
                Divider()
                actionGrid
                Divider()
                bottomBar
            }
            .background(Color(.systemBackground))
            
            if showBannerView, let bannerText {
                banner(bannerText)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showBannerView)
        .sheet(isPresented: $showSailPlanSheet, onDismiss: {
            currentSituationID = instances.derivedSituationID()
        }) {
            if let rt = sailPlanRuntime {
                SailPlanSheet(runtime: rt)
            }
        }
        .sheet(isPresented: $showAutopilotSheet) {
            if let rt = autopilotRuntime {
                AutopilotModeSheet(runtime: rt)
            }
        }
        .sheet(isPresented: $showSailingSheet, onDismiss: {
            rederiveSituation()
        }) {
            if let rt = sailingRuntime {
                SailingGeometrySheet(runtime: rt)
            }
        }
        .sheet(item: $textPromptRequest) { request in
            SingleLineTextPromptSheet(request: request)
        }
        .sheet(isPresented: $showNMEATestSheet) {
            NMEATestSheet(boat: instances.selectedBoat)
        }
        .sheet(item: $confirmRequest) { request in
            ConfirmSheet(request: request)
        }
        .sheet(isPresented: $showMooringPicker, onDismiss: {
            rederiveSituation()
        }) {
            if let rt = mooringRuntime {
                MooringPickerSheet(runtime: rt)
            }
        }
        .sheet(isPresented: $showTankInventorySheet, onDismiss: {
            logTankChangesAfterDismiss()
            rederiveSituation()
        }) {
            TankInventorySheet(
                boat: instances.selectedBoat,
                filterKinds: tankInventoryFilterKinds
            )
        }
        // AF4 – Failure report → creates a ToService task
        .sheet(isPresented: $showProblemReporterSheet) {
            ProblemInputView(
                item: nil,
                observationText: $problemText,
                images: $problemImages
            ) { pictures, observation in
                let task = ToService(boat: instances.selectedBoat)
                task.observation = observation
                task.pictures = pictures.map { Picture(data: $0) }
                modelContext.insert(task)
                try? modelContext.save()
            }
        }
        //AF5 manual log
        .sheet(isPresented: $showManualLogSheet, onDismiss: {
            rederiveSituation()
        }) {
            NavigationStack {
                
                LogbookEntryView(instances: instances, settings: settings.first ?? LogbookSettings())
            }
        }
        //AF6 log from modifications on instance table
        .sheet(isPresented: $showInstancesEditorSheet, onDismiss: {
            rederiveSituation()
        }) {
            NavigationStack {
                InstancesView(
                    settings: settings.first ?? LogbookSettings(),
                    instances: instances
                )
            }
        }
    }
    
    //END OF BODY
    //**************************************T
    
    private func runAction(_ variant: ActionVariant) {


            // AF4 / AF5 / AF6 are UI-only: present sheets
        if variant.tag == "AF4" {
            problemText = ""
            problemImages = []
            showProblemReporterSheet = true
            return
        }

        if variant.tag == "AF5" {
            showManualLogSheet = true
            return
        }

        if variant.tag == "AF6" {
            showInstancesEditorSheet = true
            return
        }
        
        if variant.tag == "A8X" {
            let rt = ActionRuntime(context: actionContext, variant: variant)
            mooringRuntime = rt
            showMooringPicker = true
            return
        }

        if variant.tag == "AF15x" {
            showNMEATestSheet = true
            return
        }
        // Tank sheets (A9 / AF18)
        if variant.tag == "AF18" {
            tankSheetOriginTag = variant.tag
            tankInventoryFilterKinds = nil // all tanks

            // snapshot visible tanks
            tankSnapshot = Dictionary(uniqueKeysWithValues:
                instances.selectedBoat.tankItems.map { ($0.id, $0.percentFull) }
            )

            showTankInventorySheet = true
            return
        }

        if variant.tag == "A9" {
            tankSheetOriginTag = variant.tag
            tankInventoryFilterKinds = [.fuel] // fuel only

            // snapshot only fuel tanks
            let fuelTanks = instances.selectedBoat.tankItems(of: .fuel)
            tankSnapshot = Dictionary(uniqueKeysWithValues:
                fuelTanks.map { ($0.id, $0.percentFull) }
            )

            showTankInventorySheet = true
            return
        }

        
        let rt = ActionRuntime(context: actionContext, variant: variant)

        // 1. Sail plan sheet (A28 / AF2S)
        if (variant.tag == "A28") || (variant.tag == "AF2S") {
            sailPlanRuntime = rt
            showSailPlanSheet = true
            return
        }

        // 2. Autopilot sheet (A26)
        if variant.tag == "A26" {
            autopilotRuntime = rt
            showAutopilotSheet = true
            return
        }

        // 3. Does this action also need the sailing geometry sheet?
        let needsSailingSheetTags: Set<String> = [
            "A27", // sails set
            "A23", // change course
            "A21", // deviation
            "A20", // back on route
            "A39", // tack
            "A40", // gybe
            "A43", // fall off
            "A44"  // luff
        ]

        let needsSailingSheet = needsSailingSheetTags.contains(variant.tag)

        // Special exception: A39 + close-hauled => just flip tack, no sheet
        if variant.tag == "A39",
           rt.instances.pointOfSail == PointOfSail.closeHauled {
            variant.handler(rt)          // handler will flip tack + log
            rederiveSituation()
            return
        }

        // 4. Run the base handler (may be a no-op for some)
        variant.handler(rt)

        // 5. Show sailing sheet if needed
        if needsSailingSheet {
            sailingRuntime = rt
            showSailingSheet = true
        } else {
            rederiveSituation()
        }
    }
    
    // Write to the log when changes occur in tank levels (AF18 and A9)

    private func logTankChangesAfterDismiss() {
        let boat = instances.selectedBoat

        // Decide which tanks were shown
        let shownTanks: [InventoryItem] = {
            if let filter = tankInventoryFilterKinds {
                return boat.tankItems.filter { $0.tankKind.map(filter.contains) ?? false }
            } else {
                return boat.tankItems
            }
        }()

        // Compute diffs
        struct Diff {
            let tank: InventoryItem
            let oldP: Int
            let newP: Int
            var delta: Int { newP - oldP }
        }

        let diffs: [Diff] = shownTanks.compactMap { t in
            let oldP = tankSnapshot[t.id] ?? t.percentFull
            let newP = t.percentFull
            guard newP != oldP else { return nil }
            return Diff(tank: t, oldP: oldP, newP: newP)
        }

        // A9: always log "Fuel tanked" (+ append new level if any positive change)
        if tankSheetOriginTag == "A9" {
            let positive = diffs.filter { $0.delta > 0 }
            if positive.isEmpty {
                ActionRegistry.logSimple("Fuel tanked", using: actionContext)
            } else {
                // If one fuel tank: single %; otherwise list each tank’s final %
                let fuelTanks = boat.tankItems(of: .fuel)
                if fuelTanks.count == 1, let t = fuelTanks.first {
                    ActionRegistry.logSimple("Fuel tanked, new fuel level: \(t.percentFull)%", using: actionContext)
                } else {
                    let levels = fuelTanks.map { tank in
                        let name = tank.name.isEmpty ? "Unnamed" : tank.name
                        return "\(name) \(tank.percentFull)%"
                    }.joined(separator: ", ")
                    ActionRegistry.logSimple("Fuel tanked, new fuel levels: \(levels)", using: actionContext)
                }
            }

            // cleanup
            tankSheetOriginTag = nil
            tankSnapshot = [:]
            return
        }

        // AF18: log what changed (up or down), one sentence per tank changed
        if tankSheetOriginTag == "AF18" {
            for d in diffs {
                let t = d.tank
                let kindTitle = t.tankKind?.title ?? "Tank"
                let name = t.name.isEmpty ? "Unnamed" : t.name

                let direction = d.delta > 0 ? "increased" : "decreased"
                let absDelta = abs(d.delta)

                if t.capacity > 0, let amt = t.amountComputed {
                    let unit = t.tankKind?.unit(using: actionContext.currentSettings()) ?? ""
                    ActionRegistry.logSimple(
                        "\(kindTitle) in \(name) has \(direction) by \(absDelta)%, \(amt)\(unit) remaining",
                        using: actionContext
                    )
                }
                else {
                    ActionRegistry.logSimple(
                        "\(kindTitle) in \(name) has \(direction) by \(absDelta)%, now \(t.percentFull)%",
                        using: actionContext
                    )
                }
            }

            // cleanup
            tankSheetOriginTag = nil
            tankSnapshot = [:]
            return
        }

        // fallback cleanup
        tankSheetOriginTag = nil
        tankSnapshot = [:]
    }


    // MARK: - Title bar with situation picker
    
    private var titleBar: some View {
        HStack {
            Text("Action Log")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            if !situations.isEmpty {
                Menu {
                    Picker("Situation", selection: $currentSituationID) {
                        ForEach(situations, id: \.id) { situation in
                            Text(situation.title)
                                .tag(situation.id)
                        }
                    }
                } label: {
                    Label("Situation", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .padding([.horizontal, .top])
    }
    
    // MARK: - Fixed AF bar
    
    private var topFixedAFBar: some View {
        let ctx = actionContext
        
        func variants(for tags: [String]) -> [ActionVariant] {
            tags.compactMap { registry.variant(for: $0) }
                .filter { variant in
                    let runtime = ActionRuntime(context: ctx, variant: variant)
                    return variant.isVisible(runtime)
                }
        }
        
        let emergency    = variants(for: emergencyTags)
        let checklistInc = variants(for: checklistIncidentTags)
        let motor        = variants(for: motorTags)
        let navigation   = variants(for: navigationTags)
        let environment  = variants(for: environmentTags)
        let otherLogs    = variants(for: otherLogTags)
        
        return VStack(spacing: 6) {
            
            // 1. Emergencies row – red, bigger, spread across the line
            if !emergency.isEmpty {
                HStack(spacing: 8) {
                    ForEach(emergency) { variant in
                        Button {
                            runAction(variant)
                        } label: {
                            HStack(spacing: 4) {
                                if let systemImage = variant.systemImage {
                                    Image(systemName: systemImage)
                                        .font(.headline)
                                }
                                Text(shortLabel(for: variant))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.red)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            
            
            
            // 2–6. Remaining rows
            if !checklistInc.isEmpty { row(checklistInc) }
            if !motor.isEmpty        { row(motor) }
            if !navigation.isEmpty   { row(navigation) }
            if !environment.isEmpty  { row(environment) }
            if !otherLogs.isEmpty    { row(otherLogs) }
        }
        .padding(.bottom, 4)
    }
    
    // Helper to draw the “normal” rows (smaller buttons)
    func row(_ variants: [ActionVariant]) -> some View {
        HStack(spacing: 6) {
            ForEach(variants) { variant in
                Button {
                    runAction(variant)
                } label: {
                    HStack(spacing: 3) {
                        if let systemImage = variant.systemImage {
                            Image(systemName: systemImage)
                                .font(.caption)
                        }
                        Text(shortLabel(for: variant))
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }
    
    /// Compact label (max 3 letters) for AF buttons, when no `systemImage` is set.
    private func shortLabel(for variant: ActionVariant) -> LocalizedStringKey {
        variant.title
    }
    
    // MARK: - Situation-dependent action grid
    
    private var actionGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let def = currentDefinition {
                    Text(def.title)
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(visibleContextualVariants(for: def)) { variant in
                            actionButton(for: variant)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                } else {
                    Text("No situation selected.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
    
    // MARK: - Bottom bar
    
    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(instances.selectedBoat.name)
                    .font(.subheadline).bold()
                Text("COG \(instances.COG)°, SOG \(String(format: "%.1f", instances.SOG)) kn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                onClose()
            } label: {
                Label("Close", systemImage: "xmark.circle.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Single action button (grid cell)
    
    private func actionButton(for variant: ActionVariant) -> some View {
        Button {
            runAction(variant)
        } label: {
            VStack(spacing: 6) {
                if let systemImage = variant.systemImage {
                    Image(systemName: systemImage)
                        .font(.title2)
                }
                Text(variant.title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(variant.isEmphasised
                          ? Color.accentColor.opacity(0.15)
                          : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(variant.isEmphasised
                            ? Color.accentColor
                            : Color.secondary.opacity(0.4),
                            lineWidth: variant.isEmphasised ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Banner
    
    private func banner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 2)
    }
    
    // MARK: - Helpers: visible variants
    
    /// AF variants for the fixed bar, filtered by `isVisible`.
    private func visibleAFVariants() -> [ActionVariant] {
        let ctx = actionContext
        
        let candidates: [ActionVariant] = topAFTags.compactMap { tag in
            registry.variant(for: tag)
        }
        
        return candidates.filter { variant in
            let runtime = ActionRuntime(context: ctx, variant: variant)
            return variant.isVisible(runtime)
        }
    }
    
    /// Contextual (situation-based) variants for the grid, filtered by `isVisible`
    /// and excluding AF-tags (they are handled in the top bar).
    private func visibleContextualVariants(for def: SituationDefinition) -> [ActionVariant] {
        let ctx = actionContext
        let afTagSet = Set(topAFTags)
        
        let tags = def.actionTags.filter { !afTagSet.contains($0) }
        
        let variants = registry.variants(for: tags)
        
        return variants.filter { variant in
            let runtime = ActionRuntime(context: ctx, variant: variant)
            return variant.isVisible(runtime)
        }
    }
    
   

    private func rederiveSituation() {
        let newID = deriveSituationID(for: instances)
        currentSituationID = newID
    }
    
    private struct ConfirmSheet: View {
        @Environment(\.dismiss) private var dismiss
        let request: ActionConfirmRequest

        var body: some View {
            NavigationStack {
                Form {
                    Text(request.message)
                }
                .navigationTitle(request.title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(request.cancelTitle) {
                            request.completion(false)
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(request.confirmTitle) {
                            request.completion(true)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}



// MARK: - Situation derivation

func deriveSituationID(for instances: Instances) -> SituationID {

    guard let trip = instances.currentTrip else {
        return .s1PreparingTrip
    }

    // 1. Trip status as primary driver
    switch trip.tripStatus {
    case .preparing:   return .s1PreparingTrip
    case .started:     return .s2TripStarted
    case .underway:    break          // handled below
    case .interrupted: break       // treat like underway, but can refine later
    case .completed:   return .s1PreparingTrip // no active trip in practice
    }

    // 2. Emergency overrides everything
    if instances.emergencyState {
        switch instances.emergencyNature {
        case .mob:            return .e1MOB
        case .fire:           return .e2Fire
        case .health:         return .e3Medical
        case .none:           break
        default:            return .e4OtherEmergency
        }
    }

    // 3. Storm manoeuvre S8
    if instances.severeWeather != .none {
        return .s8Storm
    }

    // 4. Dangers spotted S9 / S9w (any non-[.none] array)
    let hasDanger = instances.environmentDangers.contains { $0 != .none }
    if hasDanger {
        if instances.windDescription > 4 {
            return .s9wDangerSpotStrongWind
        } else {
            return .s9DangerSpotLightWind
        }
    }

    // 5. In harbour / anchorage / buoy field => S3 (S7 is defined as “same as S3”)
    if instances.currentNavZone == .harbour ||
       instances.currentNavZone == .anchorage ||
       instances.currentNavZone == .buoyField {
        if instances.navStatus == .stopped {return .s7HarbourLikeS3}
        else {return .s3InHarbourArea}
    }

    // 6. Approach => S6 / S6s
    if instances.currentNavZone == .approach {
        if instances.propulsion == .motor || instances.propulsion == .none {
            return .s6ApproachMotor
        } else if instances.propulsion == .sail || instances.propulsion == .motorsail {
            return .s6sApproachSail
        }
    }

    // 7. Motor vs sail split for “underway” cruising situations
    let zone = instances.currentNavZone
    let propulsion = instances.propulsion

    // --- Motor / none propulsion: S41..S45 ---
    if propulsion == .motor || propulsion == .none {
        switch zone {
        case .coastal:
            return .s41CoastalMotor
        case .protectedWater:
            return .s42ProtectedMotor
        case .intracoastalWaterway:
            return .s43WaterwayMotor
        case .openSea:
            return .s44OpenSeaMotor
        case .traffic:
            return .s45TrafficLane
        default:
            // Fallback: treat unknown zones like coastal motor
            return .s41CoastalMotor
        }
    }

    // --- Sail / motorsail propulsion: S51..S55(w) ---
    if propulsion == .sail || propulsion == .motorsail {
        let strongWind = instances.windDescription > 4   // “w” variants

        switch zone {
        case .coastal:
            return strongWind ? .s51wCoastalSailStrong : .s51CoastalSail
        case .protectedWater:
            return strongWind ? .s52wProtectedSailStrong : .s52ProtectedSail
        case .intracoastalWaterway:
            return strongWind ? .s53wWaterwaySailStrong : .s53WaterwaySail
        case .openSea:
            return strongWind ? .s54wOpenSeaSailStrong : .s54OpenSeaSail
        case .traffic:
            return strongWind ? .s55wTrafficLane : .s55TrafficLane
        default:
            // Fallback: coastal sail
            return strongWind ? .s51wCoastalSailStrong : .s51CoastalSail
        }
    }

    // 8. Final fallback – still underway but nothing matched
    return .s41CoastalMotor
}

//End of Situation Derivator

// ActionRegistry+Situation.swift

extension ActionRegistry {
    static var allSituations: [SituationDefinition] {
        // Flatten the static map and sort by SituationID raw value
        situationMap
            .values
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }
}

