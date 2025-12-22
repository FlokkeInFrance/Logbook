//
//  ChecklistRunner.swift
//  SailTrips
//
//  Created by jeroen kok on 18/04/2025.
//


import SwiftUI
import SwiftData

enum ChecklistNavigation: Hashable {
    case start(UUID)
    case show(UUID)
    case resume(UUID)
}

enum ChecklistFilterMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case emergency = "Emergency"
    var id: String { rawValue }
}

struct ChecklistPickerView: View {
    @Bindable var instances: Instances
    @Environment(\.dismiss) private var dismissPicker

    @State private var navPath = NavigationPath()

    @State private var filterMode: ChecklistFilterMode = .normal
    @State private var userOverrodeMode = false
    @State private var selectedHeader: ChecklistHeader?

    @Query private var rawHeaders: [ChecklistHeader]

    private var headers: [ChecklistHeader] {
        let today = Calendar.current.startOfDay(for: Date())

        return rawHeaders.filter { header in
            // mode filter
            switch filterMode {
            case .normal:    guard header.emergencyCL == false else { return false }
            case .emergency: guard header.emergencyCL == true  else { return false }
            }

            // visibility logic (your existing logic)
            if header.forAllBoats {
                // ok
            } else if header.boat.id == instances.selectedBoat.id {
                if header.alwaysShow {
                    // ok
                } else if header.conditionalShow == instances.navStatus {
                    // ok
                } else {
                    return false
                }
            } else {
                return false
            }

            // wait24Hours
            if header.wait24Hours {
                let lastRunDay = Calendar.current.startOfDay(for: header.latestRunDate)
                if lastRunDay >= today { return false }
            }

            return true
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack {
                HStack {
                    Button("Back") { dismissPicker() }
                    Spacer()
                }
                .padding()

                Picker("", selection: $filterMode) {
                    Text("Normal").tag(ChecklistFilterMode.normal)
                    Text("Emergency").tag(ChecklistFilterMode.emergency)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: filterMode) { _, _ in userOverrodeMode = true }
                .onAppear {
                    filterMode = instances.emergencyState ? .emergency : .normal
                }
                .onChange(of: instances.emergencyState) { _, newVal in
                    guard !userOverrodeMode else { return }
                    filterMode = newVal ? .emergency : .normal
                }

                HStack(spacing: 16) {
                    if let header = selectedHeader {
                        Button("Run") {
                            navPath.append(ChecklistNavigation.start(header.id))
                        }
                        .buttonStyle(FramedButtonStyle())

                        if header.completed {
                            Button("Show") {
                                navPath.append(ChecklistNavigation.show(header.id))
                            }
                            .buttonStyle(FramedButtonStyle(borderColor: .green))
                        }

                        if header.aborted {
                            Button("Resume") {
                                navPath.append(ChecklistNavigation.resume(header.id))
                            }
                            .buttonStyle(FramedButtonStyle(borderColor: .red))
                        }
                    }
                }
                .padding(.vertical)

                Text("Select a checklist:")
                    .font(.headline)

                List {
                    ForEach(headers, id: \.self) { header in
                        HStack {
                            Text(header.name)
                            Spacer()
                            if header.completed {
                                Image(systemName: "checkmark.circle")
                            } else if header.aborted {
                                Image(systemName: "exclamationmark.circle")
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(selectedHeader == header ? Color.accentColor.opacity(0.2) : .clear)
                        .cornerRadius(8)
                        .onTapGesture { selectedHeader = header }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Checklists")
            .navigationDestination(for: ChecklistNavigation.self) { route in
                switch route {
                case .start(let id):
                    ChecklistRunnerHostView(headerID: id, instances: instances, mode: .start, onFinished: { dismissPicker() })
                case .show(let id):
                    ChecklistRunnerHostView(headerID: id, instances: instances, mode: .show)
                case .resume(let id):
                    ChecklistRunnerHostView(headerID: id, instances: instances, mode: .resume)
                }
            }
        }
    }
}

private struct ChecklistRunnerHostView: View {
    let headerID: UUID
    @Bindable var instances: Instances
    let mode: ChecklistMode
    var onFinished: (() -> Void)? = nil

    @Query private var headers: [ChecklistHeader]

    init(headerID: UUID, instances: Instances, mode: ChecklistMode, onFinished: (() -> Void)? = nil) {
        self.headerID = headerID
        self._instances = .init(instances)
        self.mode = mode
        self.onFinished = onFinished
        self._headers = Query(filter: #Predicate<ChecklistHeader> { $0.id == headerID })
    }

    var body: some View {
        if let header = headers.first {
            ChecklistRunnerView(header: header, instances: instances, mode: mode, onFinished: onFinished)
        } else {
            Text("Checklist not found.")
                .foregroundStyle(.secondary)
        }
    }
}

