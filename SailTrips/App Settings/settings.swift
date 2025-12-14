//
//  Parameters.swift
//  SailTrips
//
//  Created by jeroen kok on 13/07/2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
  @Query private var settings: [LogbookSettings]
    @Environment(\.modelContext) private var modelContext: ModelContext

    // TODO: *** Add a toggle to select STW or SOG to make TWD and TWS calculations.
  var body: some View {
    Form {
      Section("Units") {
          //@State var setting: LogbookSettings = settings[0]
          let bDistanceUnit = Binding(
            get: { settings[0].distanceUnit },
            set: { settings[0].distanceUnit = $0 }
          )
          Picker("Distance", selection: bDistanceUnit) {
            ForEach(DistanceUnit.allCases, id: \.self) {
            Text($0.rawValue.capitalized)
            }
          }
       
          let bSpeedUnit = Binding(
            get: { settings[0].speedUnit },
            set: { settings[0].speedUnit = $0 }
          )
          Picker("Speed", selection: bSpeedUnit) {
            ForEach(SpeedUnit.allCases, id: \.self) {
              Text($0.rawValue.capitalized)
            }
          }
          let bSize = Binding(
            get: { settings[0].sizeUnit },
            set: { settings[0].sizeUnit = $0 }
          )
          Picker("Size", selection: bSize) {
            ForEach(SizeUnit.allCases, id: \.self) {
              Text($0.rawValue.capitalized)
            }
          }
          
          let bWeightUnit = Binding(
            get: { settings[0].weightUnit },
            set: { settings[0].weightUnit = $0 }
          )
          Picker("Weight", selection:bWeightUnit) {
            ForEach(WeightUnit.allCases, id: \.self) {
              Text($0.rawValue.capitalized)
            }
          }
          
          let bVolumeUnit = Binding(
            get: { settings[0].volumeUnit },
            set: { settings[0].volumeUnit = $0 }
          )
          Picker("Volume", selection: bVolumeUnit) {
            ForEach(VolumeUnit.allCases, id: \.self) {
              Text($0.rawValue.capitalized)
            }
          }
          let bPressureUnit = Binding(
            get: { settings[0].pressureUnit },
            set: { settings[0].pressureUnit = $0 }
          )
          Picker("Pressure", selection: bPressureUnit) {
            ForEach(PressureUnit.allCases, id: \.self) {
              Text($0.rawValue.capitalized)
            }
          }
      }
        
      Section ("Options"){
        
          let bautoReadposition = Binding(
          get: { settings[0].autoReadposition },
          set: { settings[0].autoReadposition = $0 }
         )
         Toggle("Read position automatically in log", isOn: bautoReadposition)
         /*  var autoUpdatePostion: Bool = false
          var autoUpdatePeriodicity: Int = 60*/
          let bAutoPos = Binding (
            get: { settings[0].autoUpdatePosition },
            set: { settings[0].autoUpdatePosition = $0 }
          )
          
          Toggle("Keep track of position", isOn: bAutoPos)

      }

      Section("Log Entry Fields") {
        ForEach(LogField.allCases, id: \.self) { field in
          Toggle(field.rawValue, isOn: Binding(
            get: { settings[0].isLogFieldVisible(field) },
            set: { settings[0].setLogField(field, visible: $0) }
          ))
        }
      }

      Section("Instance Fields") {
          ForEach(InstanceField.allCases, id: \.self) { field in
            Toggle(field.rawValue, isOn: Binding(
              get: { settings[0].isInstanceFieldVisible(field) },
              set: { settings[0].setInstanceField(field, visible: $0) }
            ))
          }
      }
    }
    .onAppear {
        if settings.count == 0 {
            let newSettings = LogbookSettings(id: UUID())
            modelContext.insert(newSettings)
        }
    }
  }
}
