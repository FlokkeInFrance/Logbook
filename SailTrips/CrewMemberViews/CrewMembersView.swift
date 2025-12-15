//
//  SwiftUIView.swift
//  SailTrips
//
//  Created by jeroen kok on 08/02/2025.
//

import SwiftUI
import SwiftData

struct CrewMembersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var crewMembers: [CrewMember] // Récupère les membres du modèle SwiftData
     
     @State private var selectedCrewMember: CrewMember?
     @State private var searchText = ""
     @State private var showDetail = false

     var filteredCrewMembers: [CrewMember] {
         if searchText.isEmpty {
             return crewMembers
         } else {
             return crewMembers.filter { $0.LastName.localizedCaseInsensitiveContains(searchText) }
         }
     }

    var body: some View {
        List(filteredCrewMembers, selection: $selectedCrewMember) { member in
            
            CrewMemberLine(crewMember: member)
                .tag(member)
        }
        .navigationTitle("Crew Members")
        .onChange(of: selectedCrewMember){ _,_ in
            if (selectedCrewMember != nil) {showDetail = true}
        }
        .searchable(text: $searchText, prompt: "Search")
        .toolbar {
            Button(action: addCrewMember) {
                Label("Add", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showDetail,
               onDismiss: didDismiss) {
            if let crewM = selectedCrewMember {
                ACrewMember(crewMember: crewM)
            }
        }
    }
    
    private func didDismiss() {
        selectedCrewMember = nil
    }
               
     private func addCrewMember() {
         withAnimation {
             let newMember = CrewMember(lastName: "", firstName: "")
             selectedCrewMember = newMember
             modelContext.insert(newMember)
             showDetail = true
         }

     }
 }

 #Preview {
     CrewMembersView()
         .modelContainer(for: CrewMember.self, inMemory: true)
 }

struct CrewMemberLine: View {
    
    var crewMember: CrewMember
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(crewMember.LastName)
                    .font(.headline)
                Text(", ").font(.headline)
                Text(crewMember.FirstName)
                    .font(.headline)
            }
            HStack {
                Text(crewMember.Town)
                    .font(.caption2)
                Text(", ")
                Text(crewMember.Country)
                    .font(.caption2)
            }
        }
    }
}


