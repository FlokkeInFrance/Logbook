//Created by J.Kok on 17/05/2025

import SwiftUI
import MapKit
import CoreLocation

/// View for entering or displaying long and lat coordinates in either decimal or DMS format.
/// Shows the coords but also controls to show the point on a map, 
struct CoordinatesView: View {
    @Binding var latitude: Double
    @Binding var longitude: Double
    let isEditable: Bool

    @State private var showDecimal: Bool = true
    @State private var showMapSheet: Bool = false
    @State private var showPickerSheet: Bool = false
    @StateObject private var locationManager = LocationManager()

    // Temporary fields for DMS editing
    @State private var latDeg = 0
    @State private var latMin = 0
    @State private var latSec: Double = 0
    @State private var latNorth = true

    @State private var lonDeg = 0
    @State private var lonMin = 0
    @State private var lonSec: Double = 0
    @State private var lonEast = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Toggle between decimal and DMS
            Button(action: {showDecimal = !showDecimal},
                   label: { Text(showDecimal ? "DMS" : "Decimal") })

            if showDecimal {
                // Decimal display or edit
                HStack {
                    Text("Latitude:")
                    if isEditable {
                        TextField("Latitude", value: $latitude, formatter: NumberFormatter.decimal)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(String(format: "%.6f", latitude))
                    }
                }
                HStack {
                    Text("Longitude:")
                    if isEditable {
                        TextField("Longitude", value: $longitude, formatter: NumberFormatter.decimal)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(String(format: "%.6f", longitude))
                    }
                }
            } else {
                // DMS display or edit
                DMSView(
                    deg: isEditable ? $latDeg : .constant(dms(from: latitude).deg),
                    min: isEditable ? $latMin : .constant(dms(from: latitude).min),
                    sec: isEditable ? $latSec : .constant(dms(from: latitude).sec),
                    positive: isEditable ? $latNorth : .constant(dms(from: latitude).positive),
                    positiveLabel: (true: "N", false: "S"),
                    isEditable: isEditable,
                    onCommit: { commitLatitude() }
                )
                DMSView(
                    deg: isEditable ? $lonDeg : .constant(dms(from: longitude).deg),
                    min: isEditable ? $lonMin : .constant(dms(from: longitude).min),
                    sec: isEditable ? $lonSec : .constant(dms(from: longitude).sec),
                    positive: isEditable ? $lonEast : .constant(dms(from: longitude).positive),
                    positiveLabel: (true: "E", false: "W"),
                    isEditable: isEditable,
                    onCommit: { commitLongitude() }
                )
            }

            HStack {
                if isEditable {
                    Button(action: {
                        if let loc = locationManager.lastLocation {
                            latitude = loc.latitude
                            longitude = loc.longitude
                            syncDMSFields()
                        } else {
                            locationManager.requestLocation()
                        }
                    },
                           label: { Image(systemName: "location.app.fill")}
                    )
                    Button(action: {
                        syncDMSFields()
                        showPickerSheet = true
                    },
                           label: {Image(systemName: "mappin.circle")}
                    )
                
                } else {
                    Button("Show on Map") {
                        showMapSheet = true
                    }
                }
            }
        }
        .onAppear { syncDMSFields() }
        .sheet(isPresented: $showMapSheet) {
            MapDisplayView(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        .sheet(isPresented: $showPickerSheet) {
            SelectOnMapView(latitude: $latitude, longitude: $longitude)
        }
        .onChange(of: latitude){ _,_ in
            syncDMSFields()
        }
        .onChange(of: longitude){ _,_ in
            syncDMSFields()
        }
    }

    private func syncDMSFields() {
        let lat = dms(from: latitude)
        latDeg = lat.deg; latMin = lat.min; latSec = lat.sec; latNorth = lat.positive
        let lon = dms(from: longitude)
        lonDeg = lon.deg; lonMin = lon.min; lonSec = lon.sec; lonEast = lon.positive
    }

    private func commitLatitude() {
        print("commitlatitude")
        latitude = decimalFromDMS(deg: latDeg, min: latMin, sec: latSec, positive: latNorth)
    }
    private func commitLongitude() {
        longitude = decimalFromDMS(deg: lonDeg, min: lonMin, sec: lonSec, positive: lonEast)
    }

    // Conversion helpers
    private func dms(from decimal: Double) -> (deg: Int, min: Int, sec: Double, positive: Bool) {
        let positive = decimal >= 0
        let absVal = abs(decimal)
        let deg = Int(absVal)
        let minutesFull = (absVal - Double(deg)) * 60
        let min = Int(minutesFull)
        let sec = (minutesFull - Double(min)) * 60
        return (deg, min, sec, positive)
    }
    private func decimalFromDMS(deg: Int, min: Int, sec: Double, positive: Bool) -> Double {
        let val = Double(deg) + Double(min)/60 + sec/3600
        return positive ? val : -val
    }
}

// MARK: - DMS Subview
struct DMSView: View {
    @Binding var deg: Int
    @Binding var min: Int
    @Binding var sec: Double
    @Binding var positive: Bool
    let positiveLabel: (true: String, false: String)
    let isEditable: Bool
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if isEditable {
                TextField("°", value: $deg, formatter: NumberFormatter.int)
                    .frame(width: 50)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onCommit)
                Text("°")
            } else {
                Text("\(deg)°")
            }
            if isEditable {
                TextField("'", value: $min, formatter: NumberFormatter.int)
                    .frame(width: 50)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onCommit)
                Text("'")
            } else {
                Text("\(min)′")
            }
            if isEditable {
                TextField("\"", value: $sec, formatter: NumberFormatter.sec)
                    .frame(width: 70)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onCommit)
                Text("\"")
            } else {
                Text(String(format: "%.2f\"", sec))
            }
            Button (
                action: {
                positive = !positive
            },
                label: {
                    Text(positive ? positiveLabel.true: positiveLabel.false)
                }
                )
            .onChange(of: positive) {_,_ in onCommit()}
        }
    }
}

// MARK: - Map Display using new iOS 17 API
struct MapDisplayView: View {
    var coordinate: CLLocationCoordinate2D

    var body: some View {
        let cameraPosition = MapCameraPosition.region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )

        Map(initialPosition: cameraPosition) {
            Marker("", coordinate: coordinate)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Map Picker using new iOS 17 API
struct MapPickerView: View {
    @State private var cameraPosition: MapCameraPosition
    var onPick: (CLLocationCoordinate2D) -> Void

    init(coordinate: CLLocationCoordinate2D, onPick: @escaping (CLLocationCoordinate2D) -> Void) {
        let initial = MapCameraPosition.region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.5)
            )
        )
        _cameraPosition = State(initialValue: initial)
        self.onPick = onPick
    }

    var body: some View {
        //Map(initialPosition: cameraPosition, interactionModes: .all, showsUserLocation: true) {
        Map(position: $cameraPosition, interactionModes: .all) {
            if let region = cameraPosition.region {
                Marker("", coordinate: region.center)
            }
        }
        .ignoresSafeArea()
    }
}

final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    @Published var lastLocation: CLLocationCoordinate2D?
    var manager = CLLocationManager()
    
    
    func requestLocation() {
        
        manager.delegate = self
        manager.startUpdatingLocation()
        
        switch manager.authorizationStatus {
        case .notDetermined://The user choose allow or denny your app to get the location yet
            manager.requestWhenInUseAuthorization()
            
        case .restricted://The user cannot change this app’s status, possibly due to active restrictions such as parental controls being in place.
            print("Location restricted")
            
        case .denied://The user dennied your app to get location or disabled the services location or the phone is in airplane mode
            print("Location denied")
            
        case .authorizedAlways://This authorization allows you to use all location services and receive location events whether or not your app is in use.
            print("Location authorizedAlways")
            
        case .authorizedWhenInUse://This authorization allows you to use all location services and receive location events only when your app is in use
            print("Location authorized when in use")
            lastLocation = manager.location?.coordinate
            
        @unknown default:
            print("Location service disabled")
            
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {//Trigged every time authorization status changes
        requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.first?.coordinate
    }
}

// MARK: - Formatters
extension NumberFormatter {
    static var decimal: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 7
        return f
    }
    static var int: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .none
        return f
    }
    static var sec: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }
}
