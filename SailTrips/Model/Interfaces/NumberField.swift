//
//  NumberField.swift
//  SailTrips
//
//  Created by jeroen kok on 10/03/2025.
//

import SwiftUI

struct NumberField: View {
    
     let myFormat: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        nf.locale = Locale.current
        return nf
    }()
    
    let label: String
    @Binding var inData: Float
    @State var inString: String = ""
    @State var inhibited: Bool = false
    let localSeparator = Locale.current.decimalSeparator ?? "."
    
    var body: some View {
        LabeledContent {TextField(label, text: $inString)
                .keyboardType(.decimalPad) // Clavier numérique avec point décimal
                
                .onChange(of: inString) {_, newValue in
                    readToStoredVariable(newValue)
                    inhibited = true
                    //inputValue = formatToTwoDecimals(newValue)
                }
                .onChange(of: inData){_, newValue in
                    if !inhibited {
                        inString = floatToString(newValue)
                    }
                    inhibited = false
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(2)
                .onAppear(){
                    inString = floatToString(inData)
                }
        } label: {Text(label)}

    }
    
    func readToStoredVariable(_ value: String) {
        let filtered = value.isEmpty ? "0" : value.filter { "-+0123456789\(localSeparator))".contains($0) }
        
        inData = stringToFloat(filtered) ?? inData
        
        if value.isEmpty {return}
        
        if filtered != value {
            inString = formatToTwoDecimals(filtered)
        }
        let fraction = value.split(separator: localSeparator).count
        if fraction > 2{
            inString = formatToTwoDecimals(filtered)
        }
        
    }
    
      func formatToTwoDecimals(_ value: String) -> String {
        // Supprime les caractères non numériques ou non valides
      //  let filtered = value.filter { "0123456789.,".contains($0) }
        
        // Limite à deux chiffres après le point
          print("formatting to two decimals")
        if let floatValue = Float(value) {
            return myFormat.string(for: floatValue) ?? ""
        }
        
        return value
    }
    
    func stringToFloat(_ value: String) -> Float? {
        return myFormat.number(from: value)?.floatValue
    }
    
    func floatToString(_ value: Float) -> String {
        return myFormat.string(for: value) ?? ""
    }
}

struct IntField: View {
    
    let myIntFormat: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        nf.locale = Locale.current
        nf.groupingSize = 0
        return nf
    }()
    
    let label: String
    @Binding var inData: Int
    
    var body: some View {
        LabeledContent {TextField(label, value: $inData, formatter: myIntFormat)
                .keyboardType(.numberPad) // Clavier numérique avec point décimal
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(2)
        } label: {Text(label)}
        
    }
    
}

struct BearingView: View {
    let label:String
    @Binding var inBearing: Int
    
    var bearingToInt: Binding<Double>{
            Binding<Double>(get: {
                return Double(inBearing)
            }, set: {
                //rounds the double to an Int
                print($0.description)
                inBearing = Int($0)
            })
        }
    
    var body: some View {
        VStack (alignment: .leading, spacing: 1)
        {
            Text(label)
                .frame(alignment: .leading)
            HStack {
                IntField(label: "", inData: $inBearing)
                    .frame(maxWidth: 58)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                VStack{
                    Slider(value: bearingToInt, in: 0...359, step: 1)
                    HStack{
                        Text("N")
                            .frame(maxWidth: .infinity)
                            .onTapGesture {inBearing = 0}
                        Text("E")
                            .frame(maxWidth: .infinity)
                            .onTapGesture {inBearing = 90}
                        Text("S")
                            .frame(maxWidth: .infinity)
                            .onTapGesture {inBearing = 180}
                        Text("W")
                            .frame(maxWidth: .infinity)
                            .onTapGesture {inBearing = 270}
                        Text("N")
                            .frame(maxWidth: .infinity)
                            .onTapGesture {inBearing = 359}
                    }
                }
            }
        }
    }
}
