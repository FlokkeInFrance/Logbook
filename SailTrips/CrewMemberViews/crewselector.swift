//
//  crewselector.swift
//  SailTrips
//
//  Created by jeroen kok on 16/05/2025.
//
import SwiftUI
import SwiftData

struct CrewSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedMembers: [CrewMember]
    @Query(sort: \CrewMember.LastName) private var available: [CrewMember]
    @State private var selectedIDs: Set<UUID>
    @State private var searchText: String = ""
    @State private var showAddDialog: Bool = false

    init(selectedMembers: Binding<[CrewMember]>) {
        self._selectedMembers = selectedMembers
        self._selectedIDs = State(initialValue: Set(selectedMembers.wrappedValue.map { $0.id }))
    }

    private var filtered: [CrewMember] {
        available.filter {
            searchText.isEmpty || $0.LastName.localizedCaseInsensitiveContains(searchText)
            || $0.FirstName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
            VStack {
                HStack {
                    Button("Cancel") {dismiss() }
                    Button("Done") {
                        selectedMembers = available.filter { selectedIDs.contains($0.id) }
                        dismiss()
                    }
                }
                .padding()
                .underline()
                Text("Build a crew")
                    .font(.headline)
                Text("Click a name to unselect")
                    .font(.subheadline)
                    .padding(.top)
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(available.filter { selectedIDs.contains($0.id) }, id: \ .id) { mem in
                            Text("\(mem.FirstName) \(mem.LastName)")
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 8).stroke())
                                .onTapGesture { selectedIDs.remove(mem.id) }
                        }
                    }
                    .padding(.horizontal)
                }
                Divider()
                HStack {
                    TextField("Search for:", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") { showAddDialog = true }
                }
                .padding(.horizontal)

                List {
                    Section(header: Text("Tap to select a crew member")) {
                        ForEach(filtered, id: \.id) { mem in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(mem.FirstName) \(mem.LastName)")
                                    Text("from \(mem.Town)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedIDs.contains(mem.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedIDs.insert(mem.id) }
                        }
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") {
                    selectedMembers = available.filter { selectedIDs.contains($0.id) }
                    dismiss()
                }
            )
            .navigationTitle("Select Crew")
            .sheet(isPresented: $showAddDialog) {
                AddCrewDialogView { newMember in
                    if let created = newMember {
                        // SwiftData insert
                        modelContext.insert(created)
                        selectedIDs.insert(created.id)
                    }
                    showAddDialog = false
                }
            }
    }
}

// MARK: - Add Crew Dialog
struct AddCrewDialogView: View {
    @Environment(\.presentationMode) var presentation
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    let onComplete: (CrewMember?) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") { onComplete(nil); presentation.wrappedValue.dismiss() },
                trailing: Button("Done") {
                    guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty || !lastName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let newMember = CrewMember(lastName: lastName, firstName: firstName)
                    onComplete(newMember)
                    presentation.wrappedValue.dismiss()
                }
                .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty && lastName.trimmingCharacters(in: .whitespaces).isEmpty)
            )
            .navigationTitle("Add Crew Member")
        }
    }
}
