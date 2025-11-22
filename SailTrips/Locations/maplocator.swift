//Built by J.Kok
// On 20 may 2025

import SwiftUI
import MapKit

struct SelectOnMapView: View {
    @Binding var latitude: Double
    @Binding var longitude: Double

    @State private var searchQuery = ""
    @State private var completions: [MKLocalSearchCompletion] = []
    @State private var completer = MKLocalSearchCompleter()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.2948251, longitude: 5.3742983),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    )

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var active: activations

    init(latitude: Binding<Double>, longitude: Binding<Double>) {
        self._latitude = latitude
        self._longitude = longitude
        completer.resultTypes = .address
        completer.pointOfInterestFilter = .includingAll
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchQuery) { query in
                completer.queryFragment = query
            }
            .padding(.horizontal)

            Button("Done") { dismiss() }
                .padding(.vertical, 4)

            if !completions.isEmpty {
                List(completions, id: \.self) { completion in
                    Button(action: { searchLocation(completion) }) {
                        Text(completion.title)
                            .font(.subheadline)
                    }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: 150)
            }

            // Wrap Map inside MapReader for coordinate conversion
            MapReader { proxy in
                Map(
                    position: $position,
                    interactionModes: .all
                ) {
                    Marker(
                        "",
                        monogram: Text("📍"),
                        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    )
                }
                .mapControls { MapUserLocationButton() }
                .onTapGesture(coordinateSpace: .local) { tapPoint in
                    if let coord = proxy.convert(tapPoint, from: .local) {
                        latitude = coord.latitude
                        longitude = coord.longitude
                        active.lastLatitude = coord.latitude
                        active.lastLongitude = coord.longitude
                        // Recenter
                        position = .region(
                            MKCoordinateRegion(
                                center: coord,
                                span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5)
                            )
                        )
                    }
                }
                .onAppear {
                    if latitude != 0 || longitude != 0 {
                        position = .region(
                            MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5)
                            )
                        )
                    } else if let lastLat = active.lastLatitude,
                              let lastLon = active.lastLongitude,
                              (lastLat != 0 || lastLon != 0) {
                        position = .region(
                            MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: lastLat, longitude: lastLon),
                                span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5)
                            )
                        )
                    } else {
                        position = .region(
                            MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 43.2948251, longitude: 5.3742983),
                                span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5)
                            )
                        )
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
        // Handle search autoupdate
        .onChange(of: completer.results) { _, results in
            completions = results
            if let first = results.first {
                searchLocation(first)
            }
        }
    }

    private func searchLocation(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let coord = response?.mapItems.first?.placemark.coordinate,
                  error == nil else { return }

            latitude = coord.latitude
            longitude = coord.longitude

            position = .region(
                MKCoordinateRegion(
                    center: coord,
                    span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            )

            completions = []
            searchQuery = completion.title
        }
    }
}

// UIKit-based search bar unchanged
struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var onTextChange: (String) -> Void

    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        var onTextChange: (String) -> Void

        init(text: Binding<String>, onTextChange: @escaping (String) -> Void) {
            self._text = text
            self.onTextChange = onTextChange
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
            onTextChange(searchText)
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(true, animated: true)
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            searchBar.text = ""
            text = ""
            onTextChange("")
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTextChange: onTextChange)
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search for a town"
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
}

