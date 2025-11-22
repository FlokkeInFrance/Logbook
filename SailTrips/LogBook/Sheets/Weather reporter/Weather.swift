//
//  Weather.swift
//  SailTrips
//
//  Created by jeroen kok on 08/06/2025.
//

import SwiftUI
import SwiftData

struct WeatherViewb: View {
    @Bindable var instances: Instances
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \BeaufortScale.beaufortScaleInt, order: .forward) private var scales: [BeaufortScale]
    
    var body: some View {
        Text("WeatherView")
            .font(.title)
            .padding()
    }
}

struct WeatherView: View {
    // Binding to the shared Instances record
    let myFormat: NumberFormatter = {
       let nf = NumberFormatter()
       nf.numberStyle = .decimal
       nf.minimumFractionDigits = 2
       nf.maximumFractionDigits = 2
       nf.locale = Locale.current
       return nf
   }()
    @Bindable var instances: Instances
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var pIncrement: Float = 1.0

    // Query for Beaufort definitions via SwiftData
    @Query(sort: \BeaufortScale.beaufortScaleInt, order: .forward) private var scales: [BeaufortScale]

    var body: some View {
        Form {
            pressureSection
            windSection
            seaStateCloudSection
            PrecipSection
            visibilityTempSection
            presetsSection
            doneSection
        }
        .onAppear(perform: loadValues)
        .navigationTitle("Describe Weather")
    }

    private var pressureSection: some View {
        Section(header: Text("Barometric Pressure")) {
            NumberField(label: "hPa:", inData: $instances.pressure)
                .tooltip("Barometric pressure in mbar or hPa, with 2 decimal precision.")
        }
    }

    private var windSection: some View {
        Section(header: Text("Wind")) {
            VStack(alignment: .leading) {
                Text("Speed (knots): \(instances.TWS)")
                    .tooltip("Wind speed in knots. Adjusting will update Beaufort force.")
                Slider(value: Binding(get: { Double(instances.TWS) }, set: { instances.TWS = Int($0) }), in: 0...70, step: 1)
                    .onChange(of: instances.TWS) { _, new in updateBeaufort(for: Int(new)) }
                    //.tooltip("Wind speed in knots. Adjusting will update Beaufort force.")

                Picker("Force", selection: $instances.windDescription) {
                    ForEach(scales, id: \.beaufortScaleInt) { scale in
                        Text("Bft \(scale.beaufortScaleInt) - \(scale.windName)")
                            .tag(scale.beaufortScaleInt)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .frame(height: 40)
                .onChange(of: instances.windDescription) { _, new in enforceWindSpeed(minFor: new) }
                .tooltip("Wind force from the Beaufort scale.")

                BearingView(label: "True Wind Direction (°)", inBearing: $instances.TWD)

                HStack {
                    Text("Turbulence: \(instances.turbulence)°")
                        .tooltip("Define turbulence in degrees deviation from main direction.")
                    Slider(value: Binding(get: { Double(instances.turbulence) }, set: { instances.turbulence = Int($0) }), in: 0...180, step: 1)
                }

                HStack {
                    Text("Gustiness: \(instances.gustiness) (kn)")
                        .tooltip("Maximum amplitude of windspeed variations in knots.")
                    Slider(value: Binding(get: { Double(instances.gustiness) }, set: { instances.gustiness = Int($0) }), in: 0...60, step: 1)
                }
                
                Picker("Sea State", selection: $instances.seaState) {
                    ForEach(scales, id: \.beaufortScaleInt) { scale in
                        Text(scale.seaState).tag(scale.seaState)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .frame(height: 40)
                .onChange(of: instances.windDescription) { _, new in
                    if let scale = scales.first(where: { $0.beaufortScaleInt == new }) {
                        instances.seaState = scale.seaState
                    }
                }
                .tooltip("Describe the current sea state.")
            }
        }
    }

    private var seaStateCloudSection: some View {
        Section(header: Text("Clouds & Visibility")) {
            Text ("cloud coverage is \(instances.cloudiness)/8, tap to change : ")
            CloudOktaSelector(selection: $instances.cloudiness)
            
            HStack {
                Picker("Type of Clouds", selection: $instances.stateOfSky) {
                    Text("None").tag("None")
                    Text("Cumulus").tag("Cumulus")
                    Text("Alto").tag("Alto")
                    Text("Cirrus").tag("Cirrus")
                }
                .pickerStyle(DefaultPickerStyle())
                TextField("Details", text: $instances.stateOfSky)
            }
            .tooltip("Describes the height of the lowest clouds.")

            Toggle("Cumulonimbus nearby?", isOn: $instances.presenceOfCn)
                .tooltip("Check if you see close cumulonimbus (<20 NM).")
            
            Picker("Visibility", selection: $instances.visibility) {
                ForEach(["50","100","200","500","1000","2000","Hazy","Clear"], id: \.self) { Text($0) }
            }
            .pickerStyle(MenuPickerStyle())
            .tooltip("Set current visibility in meters or describe the situation.")
        }
    }

    private var PrecipSection: some View {
        Section(header: Text("Severe Weather & Precipitations")) {
                Picker("Severe Weather", selection: $instances.severeWeather) {
                    ForEach(SevereWeather.allCases) { w in Text(w.rawValue).tag(w) }
                }
                .pickerStyle(DefaultPickerStyle())
                .onChange(of: instances.severeWeather) { _, new in applySevereOverride(new) }
                .tooltip("Actual severe weather type.")
            
            Picker("precipitations", selection: $instances.precipitations){
                ForEach(Precipitations.allCases) { p in Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(DefaultPickerStyle())
            .tooltip("Describe current precipitation.")


        }
    }

    private var visibilityTempSection: some View {
        Section(header: Text("Temperatures")) {
            
            HStack {
                IntField (label: "Air T°", inData: $instances.airTemperature)
                Slider(value: Binding(get: { Double(instances.airTemperature) }, set: { instances.airTemperature = Int($0) }), in: -10...60, step: 0.5)
            }
            
            HStack {
                
                IntField (label: "Water T°", inData: $instances.waterTemperature)
                Slider(value: Binding(get: { Double(instances.waterTemperature) }, set: { instances.waterTemperature = Int($0) }), in: -5...50, step: 0.5)
            }
        }
    }

    private var presetsSection: some View {
        Section {
            HStack {
                Button("Fair Weather") { presetFair() }
                Spacer()
                Button("Thunderstorm") { presetThunder() }
                Spacer()
                Button("Fog") { presetFog() }
                Spacer()
                Button("Rain") { presetRain() }
            }
        }
    }

    private var doneSection: some View {
        Section {
            HStack {
                Button("Done") { saveAndDismiss() }
                    .frame(maxWidth: .infinity)
                Button("Cancel"){ dismiss()}
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Load & Save
    private func loadValues() {
        instances.weatherTimestamp = Date()
        let _ = BeaufortScale.validatedScales(from: scales)
    }

    private func saveAndDismiss() {
        instances.weatherTimestamp = Date()
        if let trip = instances.currentTrip {
            switch trip.tripStatus {
            case .preparing, .started:
                trip.weatherAtStart = buildDescription()
                trip.baroAtStart = Float(instances.pressure)
            case .underway:
                break
            default: break
            }
            try? modelContext.save()
        }
        dismiss()
    }

    // MARK: - Builders & Helpers
    private func buildDescription() -> String {
        var parts: [String] = []
        if let scale = scales.first(where: { $0.beaufortScaleInt == instances.windDescription }) {
            var desc = "Wind: \(scale.windName) (Bft \(scale.beaufortScaleInt))"
            if instances.gustiness > 1 {
                let gtext: String
                switch instances.gustiness {
                case 0...3: gtext = "steady"
                case 2...4: gtext = "mild gusts"
                case 5...8: gtext = "gusts"
                default: gtext = "strong gusts"
                }
                desc += ", \(gtext)"
            }
            parts.append(desc)
        }
        if instances.turbulence >= 10 {
            let ttext: String
            switch instances.turbulence {
            case 10...20: ttext = "mild turbulence"
            case 21...40: ttext = "turbulent"
            case 41...90: ttext = "very turbulent"
            default: ttext = "erratic wind direction"
            }
            parts.append(ttext)
        }
        if instances.visibility.lowercased() != "clear" {
            parts.append("Visibility: \(instances.visibility)")
        }
        
            parts.append(", Precipitations: \(instances.precipitations)")
       
        switch instances.cloudiness {
        case 0: parts.append("Clear Sky")
        case 1...2: parts.append("Clouds FEW \(instances.cloudiness)/8, \(instances.stateOfSky)")
        case 3...4: parts.append("Clouds SCT \(instances.cloudiness)/8, \(instances.stateOfSky)")
        case 5...7: parts.append("Clouds BKN \(instances.cloudiness)/8, \(instances.stateOfSky)")
        case 8: parts.append("Overcast, \(instances.stateOfSky)")
        default: parts.append("")
        }
        if instances.severeWeather != .none {
            parts.append(instances.severeWeather.rawValue)
        }
        parts.append(String(format: "Air: %.0f°C, Water: %.0f°C", instances.airTemperature, instances.waterTemperature))
        return parts.joined(separator: ", ")
    }

    private func updateBeaufort(for speed: Int) {
        if let matched = scales.last(where: { speed >= $0.windVelocityLow }) {
            instances.windDescription = matched.beaufortScaleInt
        }
    }

    private func enforceWindSpeed(minFor beaufort: Int) {
        if let scale = scales.first(where: { $0.beaufortScaleInt == beaufort }) {
            if instances.TWS < scale.windVelocityLow {
                instances.TWS = scale.windVelocityLow + 2
            }
        }
        if beaufort < 12 {
            if let scale = scales.first(where: { $0.beaufortScaleInt == beaufort+1 }){
                if instances.TWS >= scale.windVelocityLow {
                    instances.TWS = scale.windVelocityLow-2
                }
             }
        }
    }

    private func applySevereOverride(_ weather: SevereWeather) {
        if [.thunderstorm, .microburst, .derecho, .mesoscale].contains(weather) {
            instances.presenceOfCn = true
            if instances.precipitations == Precipitations.none {
                instances.precipitations = Precipitations.rain
            }
        }
    }

    // MARK: - Presets
    private func presetFair() {
        instances.precipitations = Precipitations.none
        instances.visibility = "Clear"
        instances.cloudiness = 0
        instances.stateOfSky = "None"
        instances.presenceOfCn = false
        instances.severeWeather = .none
    }
    private func presetThunder() {
        instances.presenceOfCn = true
        instances.severeWeather = .thunderstorm
        instances.cloudiness = 8
        instances.precipitations = Precipitations.rain
        instances.visibility = "reduced"
       }
    private func presetFog()    {
        instances.presenceOfCn = false
        instances.visibility = "<1km"
        instances.precipitations = Precipitations.none
        instances.severeWeather = .none}
    
    private func presetRain()   { 
        instances.precipitations = Precipitations.rain
        instances.severeWeather = .none
        instances.cloudiness = 8
        instances.stateOfSky = "Cumulus clouds"
        instances.visibility = "reduced"
    }
} // end of Struct

// MARK: - Tooltip Modifier
struct TooltipModifier: ViewModifier {
    let text: String
    @State private var show = false
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 1) {
                withAnimation { show.toggle() }
            }
            .overlay(
                Group {
                    if show {
                        Text(text)
                            .font(.caption)
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .transition(.opacity.combined(with: .scale))
                            .onTapGesture { withAnimation { show = false } }
                    }
                }, alignment: .top
            )
    }
}

extension View {
    func tooltip(_ text: String) -> some View {
        modifier(TooltipModifier(text: text))
    }
}

// MARK: - Cloud Okta Selector & Icon
struct CloudOktaSelector: View {
    @Binding var selection: Int
    var body: some View {
        
        HStack(spacing: 8) {
            ForEach(0...8, id: \.self) { okt in
                CloudCoverageIcon(okt: okt)
                    .frame(width: 32, height: 32)
                    .onTapGesture { selection = okt }
                    //.opacity(okt == selection ? 1 : 0.6)
            }
        }
    }
}

struct CloudCoverageIcon: View {
    let okt: Int
    var body: some View {
        switch okt {
        case 0:
            Circle().stroke(lineWidth: 1)
        case 1:
            ZStack(alignment: .center) {
                Circle().stroke(lineWidth: 1)
                    .frame(width: 30, height: 30)
                Rectangle()
                    .frame(width: 1)
            }
        case 2:
            ZStack(alignment: .center) {
                Circle().stroke(lineWidth: 1)
                    .frame(width: 30, height: 30)
                arcQ(nbQuart: 1)
                    .frame(width: 30, height: 30)
            }
        case 3:
            ZStack(alignment: .center) {
                Circle().stroke(lineWidth: 1)
                    .frame(width: 30, height: 30)
                arcQ(nbQuart: 1)
                    .frame(width: 30, height: 30)
                Rectangle()
                    .frame(width: 1)
            }
        case 4:
            ZStack(alignment: .center) {
                Circle().stroke(lineWidth: 1)
                    .frame(width: 30, height: 30)
                arcQ(nbQuart: 2)
                    .frame(width: 30, height: 30)
            }
            
        case 5:
            ZStack(alignment: .center) {
                Circle().stroke(lineWidth: 1)
                    .frame(width: 30, height: 30)
                arcQ(nbQuart: 2)
                    .frame(width: 30, height: 30)
                Rectangle()
                    .frame(height: 1)
                }
        case 6:
            ZStack(alignment: .center) {
                Circle().stroke(lineWidth: 1)
                    .frame(width: 30, height: 30)
                arcQ(nbQuart: 3)
            }
        case 7:
            ZStack(alignment: .center) {
                Circle()
                    .fill(.black)
                    .frame(width: 30, height: 30)
                Rectangle()
                    .fill(.white)
                    .frame(width: 2,height: 28)
                
            }
        case 8:
            ZStack(alignment: .center) {
                Circle()
                    .fill(.black)
                    .frame(width: 30, height: 30)
            }
        default:
                fatalError()
        }
    }
}

struct arcQ: Shape{
    var nbQuart: Int
    func path(in rect: CGRect) -> Path {
        Path {
            path in
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: rect.height / 2,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: Double(nbQuart-1)*90),
                clockwise: false)
        }
    }
}
