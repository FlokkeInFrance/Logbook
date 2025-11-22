//
//  BoatListView.swift
//  SailTrips
//
//  Created by jeroen kok on 08/03/2025.
//

import SwiftUI
import SwiftData

struct BoatListView: View {
    @Query var boats: [Boat] // Chargement depuis SwiftData
    @EnvironmentObject var navPath : PathManager
    @State private var searchText: String = ""
    @Binding var selectedBoat: Boat?
    @Environment(\.modelContext) private var modelContext
    
    var filteredBoats: [Boat] {
        boats
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List(filteredBoats){
            boat in
            HStack{
                
                NavigationLink {
                    BoatDetailsView(aBoat: boat)
                } label: {
                    BoatLabel(boatToShow: boat, selectedBoat: $selectedBoat)
                }.buttonStyle(.plain)
                
                Button(action: {
                    toggleSelection(boatToShow: boat)
                }) {
                    Image(systemName: selectedBoat == boat ? "checkmark.square.fill" : "square")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(selectedBoat == boat ? .blue : .gray)
                }.buttonStyle(.plain)
            }
        }
        .navigationTitle("My Boats")
        .searchable(text: $searchText, prompt: "Search for boat name :")
        .toolbar {
            // Bouton pour ajouter un nouveau bateau
            Button(action: addBoat) {
                Label("Add", systemImage: "plus")
            }
        }
    }
  
    // Ajout d'un nouveau bateau
    private func addBoat() {
        let newBoat = Boat(name: "New",boatType: .sailboat)
        if let sB: Boat = selectedBoat {
            sB.status = BoatStatus.inactive
           // modelContext.save()
        }
        
        selectedBoat = newBoat
        newBoat.status = BoatStatus.selected
        modelContext.insert(newBoat)
        
        navPath.path.append(newBoat)  // This will trigger navigation to the new boat's details.

    }
    
    private func toggleSelection(boatToShow: Boat) {
        if selectedBoat != boatToShow {
            // Select the boat and set the previous one to inactive
            if let oldSelectedBoat = selectedBoat {
                oldSelectedBoat.status = BoatStatus.inactive
            }
            selectedBoat = boatToShow
            boatToShow.status = BoatStatus.selected
        }
        try? modelContext.save()
    }
}

struct BoatLabel: View {
    var boatToShow: Boat
    @Binding var selectedBoat: Boat?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
         HStack {
             VStack(alignment: .leading) {
                 Text(boatToShow.name)
                     .font(.headline)
                 Text("\(boatToShow.brand) \(boatToShow.modelType)")
                     .font(.subheadline)
             }
         }
         .padding(2)
     }
    
 }
#Preview {
//    BoatListView()
}
