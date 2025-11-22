//
//  BoatDetailsView.swift
//  SailTrips
//
//  Created by jeroen kok on 05/03/2025.
//
import SwiftUI
import SwiftData
import PDFKit

extension Boat {
    var hasCombustionEngine: Bool {
        // Default to true when no motors defined
        guard !motors.isEmpty else { return true }
        // If any motor energy is not purely electric, consider combustion
        return motors.contains { $0.energy != .electric }
    }
}

struct BoatDetailsView: View {
    @Bindable var aBoat: Boat

    @State private var isFileImporterPresented: Bool = false
    @State private var isIFileImporterPresented: Bool = false
    @State private var isSailSheetPresented: Bool = false
    @State private var isAddingCustomSail: Bool = false
    @State private var selectedSailIndex: Int? = nil
    @State private var isMotorSheetPresented: Bool = false
    @State private var isAddingMotor: Bool = false
    @State private var selectedMotorIndex: Int? = nil
    @State private var newMotor = Motor(id: UUID())
    @State private var isValidAxiomIP: Bool = true
    @State private var isValidNMEAIP: Bool = true

    @FocusState var focus: Bool

    static let myFormat: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf
    }()

    static let myIntFormat: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        return nf
    }()

    var body: some View {
        Form {
            Section(header: Text("The Boat")) {
                TextField("Name", text: $aBoat.name)
                    .autocorrectionDisabled()
                    .focused($focus)
                    .onChange(of: focus) { oldValue, newValue in
                        if newValue && aBoat.name == "New" {
                            DispatchQueue.main.async {
                                UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                            }
                        }
                    }
                TextField("Brand", text: $aBoat.brand).autocorrectionDisabled()
                TextField("Type", text: $aBoat.modelType).autocorrectionDisabled()
            }

            Section(header: Text("Description")) {
                Picker("Propulsion", selection: $aBoat.boatType) {
                    ForEach(PropulsionType.allCases) { value in
                        Text(value.label).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Color of the hull", text: $aBoat.hullColor)
                if aBoat.boatType == .sailboat || aBoat.boatType == .motorsailer {
                    TextField("Rig Type", text: $aBoat.otherType).autocorrectionDisabled()
                    // SAILS LIST & MODIFIER Hide this section if not a sailboat
                    HStack {
                        Text("Sails")
                        Spacer()
                        Button("Modify") {
                            selectedSailIndex = nil
                            isAddingCustomSail = false
                            isSailSheetPresented = true
                        }
                    }
                    VStack(alignment: .leading) {
                        ForEach(aBoat.sails.prefix(10), id: \ .id) { sail in
                            Text(sail.nameOfSail)
                        }
                        if aBoat.sails.count > 10 {
                            Text("...and \(aBoat.sails.count - 10) more").italic()
                        }
                    }
                }

                // MOTORS LIST & MODIFIER
                HStack {
                    Text("Motors")
                    Spacer()
                    Button("Modify") {
                        newMotor = Motor(id: UUID())
                        selectedMotorIndex = nil
                        isAddingMotor = false
                        isMotorSheetPresented = true
                    }
                }
                VStack(alignment: .leading) {
                    ForEach(aBoat.motors, id: \ .id) { motor in
                        HStack {
                            Text(motor.use.label)
                            Spacer()
                            Text("\(motor.motorBrand) (\(motor.motorType))")
                        }
                    }
                }
                
                //RIG LIST &MODIFIER
                //TODO : implement 
            }

            Section(header: Text("Dimensions")) {
                NumberField(label: "Hull Length", inData: $aBoat.length,
                            inString: BoatDetailsView.myFormat.string(for: aBoat.length) ?? "")
                NumberField(label: "Length over all", inData: $aBoat.lengthOverall,
                            inString: BoatDetailsView.myFormat.string(for: aBoat.lengthOverall) ?? "")
                NumberField(label: "Beam", inData: $aBoat.beam,
                            inString: BoatDetailsView.myFormat.string(for: aBoat.beam) ?? "")
                NumberField(label: "Draft", inData: $aBoat.draft,
                            inString: BoatDetailsView.myFormat.string(for: aBoat.draft) ?? "")
                NumberField(label: "AirDraft", inData: $aBoat.airDraft,
                            inString: BoatDetailsView.myFormat.string(for: aBoat.airDraft) ?? "")
                NumberField(label: "Displacement", inData: $aBoat.weight,
                            inString: BoatDetailsView.myFormat.string(for: aBoat.weight) ?? "")
            }

            Section(header: Text("Administrative Data")) {
                TextField("Reg Num", text: $aBoat.registrationNumber).autocorrectionDisabled()
                DatePicker("First Registration", selection: $aBoat.dateOfRegistration, in: ...Date(), displayedComponents: .date)
                TextField("Owner", text: $aBoat.owner).autocorrectionDisabled()
                TextField("Hull Number", text: $aBoat.hullNumber).autocorrectionDisabled()
                TextField("Home Harbor", text: $aBoat.usualPort).autocorrectionDisabled()
                TextField("Category of Navigation", text: $aBoat.navCategory).autocorrectionDisabled()
                PDFThumbnailView(pdfData: aBoat.RegistrationPDF, emptyString: "enter PDF of Registration Document")
                Button("Select PDF of Registration") {
                    isFileImporterPresented = true
                }
                .fileImporter(
                    isPresented: $isFileImporterPresented,
                    allowedContentTypes: [.pdf],
                    allowsMultipleSelection: false
                ) { result in
                    do {
                        let selectedFile = try result.get().first
                        if let fileURL = selectedFile {
                            aBoat.RegistrationPDF = try Data(contentsOf: fileURL)
                        }
                    } catch {
                        print("Error loading PDF: \(error)")
                    }
                }
            }

            Section(header: Text("Radio")) {
                TextField("MMSI", text: $aBoat.MMSI).autocorrectionDisabled()
                TextField("Call Sign", text: $aBoat.callsign).autocorrectionDisabled()
                Toggle(isOn: $aBoat.hasEpirb) { Text("has an EPIRB") }
            }

            Section(header: Text("Insurance")) {
                TextField("Insurance Company", text: $aBoat.insuranceCompany).autocorrectionDisabled()
                TextField("Insurance Number", text: $aBoat.insuranceNumber).autocorrectionDisabled()
                TextField("Insurance Phone", text: $aBoat.insurancePhoneNumber).autocorrectionDisabled()
                PDFThumbnailView(pdfData: aBoat.InsurancePDF, emptyString: "Select PDF of Insurance Document")
                Button("Select PDF of Insurance Document") {
                    isIFileImporterPresented = true
                }
                .fileImporter(
                    isPresented: $isIFileImporterPresented,
                    allowedContentTypes: [.pdf],
                    allowsMultipleSelection: false
                ) { result in
                    do {
                        let selectedInsFile = try result.get().first
                        if let fileURL = selectedInsFile {
                            aBoat.InsurancePDF = try Data(contentsOf: fileURL)
                        }
                    } catch {
                        print("Error loading PDF: \(error)")
                    }
                }
            }

            Section(header: Text("Network")) {
                VStack(alignment: .leading) {
                    TextField("NMEA WIFI IP", text: $aBoat.wifiNMEAIP)
                        .autocorrectionDisabled()
                        .onChange(of: aBoat.wifiNMEAIP) { _, val in
                            isValidNMEAIP = isValidIP(val)
                        }
                    if !isValidNMEAIP {
                        Text("Invalid IP address").font(.caption).foregroundColor(.red)
                    }
                }
                VStack(alignment: .leading) {
                    TextField("NMEA WIFI Port", text: $aBoat.wifiNMEAPort).autocorrectionDisabled()
                }
                VStack(alignment: .leading) {
                    TextField("MFD WIFI IP", text: $aBoat.wifiAxiomIP)
                        .autocorrectionDisabled()
                        .onChange(of: aBoat.wifiAxiomIP) { _, val in
                            isValidAxiomIP = isValidIP(val)
                        }
                    if !isValidAxiomIP {
                        Text("Invalid IP address").font(.caption).foregroundColor(.red)
                    }
                }
                TextField("MFD WIFI Port", text: $aBoat.wifiAxiomPort).autocorrectionDisabled()
            }
        }
        // SAil MODIFIER SHEET
        .sheet(isPresented: $isSailSheetPresented) {
            SailModifyView(
                sails: $aBoat.sails,
                isPresented: $isSailSheetPresented
            )
        }
        .sheet(isPresented: $isMotorSheetPresented) {
            MotorModifyView(
                motors: $aBoat.motors,
                isPresented: $isMotorSheetPresented
            )
        }
    }
    private func isValidIP(_ ip: String) -> Bool {
        let pattern = "^((25[0-5]|2[0-4]\\d|[01]?\\d?\\d)\\.){3}(25[0-5]|2[0-4]\\d|[01]?\\d?\\d)$"
        let pred = NSPredicate(format: "SELF MATCHES %@", pattern)
        return pred.evaluate(with: ip)
    }
}

// MARK: - SailModifyView
struct SailModifyView: View {
    @Binding var sails: [Sail]
    @Binding var isPresented: Bool

    @State private var selectedIndex: Int? = nil
    @State private var isAddingCustom = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            HStack {
                Button(action: addNewDefaultSail) {
                    Image(systemName: "plus.circle")
                }
                Spacer()
                if selectedIndex != nil {
                    Button(action: deleteSelected) {
                        Image(systemName: "minus.circle")
                    }
                }
                Button("Done") {
                    isPresented = false
                }
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(Array(sails.enumerated()), id: \.element.id) { idx, sail in
                        Text(sail.nameOfSail)
                            .padding(4)
                            .background(selectedIndex == idx ? Color.gray.opacity(0.3) : Color.clear)
                            .cornerRadius(4)
                            .onTapGesture {
                                selectedIndex = idx
                                isAddingCustom = false
                            }
                    }
                }
            }
            .frame(maxHeight: CGFloat(min(sails.count, 10)) * 44)

            if isAddingCustom {
                Form {
                    let idx = selectedIndex!
                    TextField("Name", text: $sails[idx].nameOfSail)
                    Toggle("Optional", isOn: $sails[idx].optional)
                    Toggle("Reefs", isOn: $sails[idx].reducedWithReefs)
                    Toggle("Furling", isOn: $sails[idx].reducedWithFurling)
                    Toggle("Outpoled", isOn: $sails[idx].canBeOutpoled)
                    NumberField(label: "Area", inData: $sails[idx].sailArea,
                                inString: BoatDetailsView.myFormat.string(for: sails[idx].sailArea) ?? "")
                    Picker("State", selection: $sails[idx].currentState) {
                        ForEach(SailState.allCases, id: \.self) { state in
                            Text(state.label).tag(state)
                        }
                    }
                    HStack {
                        Button("Add") { isAddingCustom = false }
                        Spacer()
                        Button("Cancel") {
                            isAddingCustom = false
                            selectedIndex = nil
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    if !sails.contains(where: { $0.nameOfSail == "Mainsail" }) {
                        Button("Mainsail") { addDefaultMainsail() }
                    }
                    if !sails.contains(where: { $0.nameOfSail == "Genoa" }) {
                        Button("Genoa") { addGenoa() }
                    }
                    if !sails.contains(where: { $0.nameOfSail == "Gennaker" }) {
                        Button("Gennaker") { addGennaker() }
                    }
                    if !sails.contains(where: { $0.nameOfSail == "Spinnaker" }) {
                        Button("Spinnaker") { addDefaultSpinnaker() }
                    }
                    Button("Custom") {
                        let new = Sail(id: UUID(), nameOfSail: "", reducedWithReefs: false,
                                       reducedwithFurling: false, currentState: .down)
                        sails.append(new)
                        selectedIndex = sails.count - 1
                        isAddingCustom = true
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Actions
    private func addNewDefaultSail() {
        selectedIndex = nil
        isAddingCustom = false
    }
    private func deleteSelected() {
        if let idx = selectedIndex { sails.remove(at: idx); selectedIndex = nil }
    }
    private func addDefaultMainsail() {
        sails.append(Sail(id: UUID(), nameOfSail: "Mainsail", reducedWithReefs: true, reducedwithFurling: false, currentState: .down))
    }
    private func addGenoa() {
        sails.append(Sail(id: UUID(), nameOfSail: "Genoa", reducedWithReefs: false, reducedwithFurling: true, currentState: .lowered))
    }
    private func addGennaker() {
        let s = Sail(id: UUID(), nameOfSail: "Gennaker", reducedWithReefs: false, reducedwithFurling: false, currentState: .down)
        s.optional = true; sails.append(s)
    }
    private func addDefaultSpinnaker() {
        let s = Sail(id: UUID(), nameOfSail: "Spinnaker", reducedWithReefs: false, reducedwithFurling: false, currentState: .down)
        s.optional = true; sails.append(s)
    }
}

// MARK: - MotorModifyView
struct MotorModifyView: View {
    @Binding var motors: [Motor]
    @Binding var isPresented: Bool

    @State private var selectedIndex: Int? = nil
    @State private var isAdding = false
    @State private var newMotor = Motor(id: UUID())

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            HStack {
                Button(action: { isAdding = true }) {
                    Image(systemName: "plus.circle")
                }
                Spacer()
                if selectedIndex != nil {
                    Button(action: deleteSelected) {
                        Image(systemName: "minus.circle")
                    }
                }
                Button("Done") { isPresented = false }
            }
            .padding()

            if isAdding {
                Form {
                    TextField("Name", text: $newMotor.name)
                    Picker("Use", selection: $newMotor.use) {
                        ForEach(MotorUse.allCases) { m in Text(m.label).tag(m) }
                    }
                    Picker("Energy", selection: $newMotor.energy) {
                        ForEach(MotorEnergy.allCases) { e in Text(e.label).tag(e) }
                    }
                    Toggle("Inboard", isOn: $newMotor.inboard)
                    TextField("Brand", text: $newMotor.motorBrand)
                    TextField("Type", text: $newMotor.motorType)
                    TextField("Power", text: $newMotor.motorPower)
                    HStack {
                        Button("Add") {
                            motors.append(newMotor)
                            newMotor = Motor(id: UUID())
                            isAdding = false
                        }
                        Spacer()
                        Button("Cancel") {
                            newMotor = Motor(id: UUID())
                            isAdding = false
                        }
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(Array(motors.enumerated()), id: \.element.id) { idx, motor in
                            HStack {
                                Text(motor.use.label)
                                Spacer()
                                Text("\(motor.motorBrand) (\(motor.motorType))")
                            }
                            .padding(4)
                            .background(selectedIndex == idx ? Color.gray.opacity(0.3) : Color.clear)
                            .cornerRadius(4)
                            .onTapGesture { selectedIndex = idx }
                        }
                    }
                }
                .frame(maxHeight: CGFloat(min(motors.count, 10)) * 44)
            }
        }
    }

    private func deleteSelected() {
        if let idx = selectedIndex { motors.remove(at: idx); selectedIndex = nil }
    }
}
