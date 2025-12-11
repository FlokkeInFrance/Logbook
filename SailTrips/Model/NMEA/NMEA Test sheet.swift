//
//  NMEA Test sheet.swift
//  SailTrips
//
//  Created by jeroen kok on 11/12/2025.
//

import SwiftUI
import SwiftData

struct NMEATestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let boat: Boat

    @State private var mode: NMEAMode = .nmea2000
    @State private var isRunning = false
    @State private var result = NMEATestResult()
    @State private var duration: TimeInterval?
    @State private var showDoneAlert = false
    @State private var showErrorAlert = false

    private let service = NMEANetworkService()

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                resultsSection
                timingSection
            }
            .navigationTitle("NMEA test")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await runTest() }
                    } label: {
                        if isRunning {
                            ProgressView()
                        } else {
                            Text("Retrieve data")
                        }
                    }
                    .disabled(isRunning)
                }
            }
            .alert("NMEA test complete", isPresented: $showDoneAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                if let d = duration {
                    Text("All requested values were retrieved in \(String(format: "%.1f", d)) seconds.")
                } else {
                    Text("All requested values were retrieved.")
                }
            })
            .alert("NMEA error", isPresented: $showErrorAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(result.error ?? "Unknown error")
            })
        }
    }

    // MARK: Sections

    private var connectionSection: some View {
        Section("Connection") {
            HStack {
                Text("Boat")
                Spacer()
                Text(boat.name)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("IP")
                Spacer()
                Text(boat.wifiNMEAIP.isEmpty ? "Not set" : boat.wifiNMEAIP)
                    .foregroundStyle(boat.wifiNMEAIP.isEmpty ? .red : .secondary)
            }
            HStack {
                Text("Port")
                Spacer()
                Text(boat.wifiNMEAPort.isEmpty ? "Not set" : boat.wifiNMEAPort)
                    .foregroundStyle(boat.wifiNMEAPort.isEmpty ? .red : .secondary)
            }
            HStack {
                Text("Password")
                Spacer()
                Text(boat.wifiNMEAPW.isEmpty ? "Not set" : "••••••")
                    .foregroundStyle(boat.wifiNMEAPW.isEmpty ? .red : .secondary)
            }

            Picker("Protocol", selection: $mode) {
                ForEach(NMEAMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var resultsSection: some View {
        Section("Latest values") {
            Group {
                valueRow("Latitude", value: formattedLatLong(result.gpsLat))
                valueRow("Longitude", value: formattedLatLong(result.gpsLong))
                valueRow("STW", value: formatFloatKnots(result.STW))
                valueRow("SOG", value: formatFloatKnots(result.SOG))
            }

            Group {
                valueRow("AWA", value: formatAngle(result.AWA))
                valueRow("AWS", value: formatSpeed(result.AWS))
                valueRow("TWA", value: formatAngle(result.TWA))
                valueRow("TWS", value: formatSpeed(result.TWS))
                valueRow("TWD", value: formatDirection(result.TWD))
            }

            Group {
                valueRow("Pressure", value: formatPressure(result.pressure))
                valueRow("Air temp", value: formatTemp(result.airTemp))
                valueRow("Water temp", value: formatTemp(result.waterTemp))
            }

            Group {
                valueRow("Mag heading", value: formatDirection(result.magHeading))
                valueRow("Heel", value: formatHeel(result.heel))
            }

            if result.isComplete {
                HStack {
                    Label("All values received", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Spacer()
                }
            }
        }
    }

    private var timingSection: some View {
        Section("Timing") {
            if let d = duration {
                HStack {
                    Text("Last run")
                    Spacer()
                    Text("\(String(format: "%.1f", d)) s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Run the test to measure how long it takes to retrieve a full set of data.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Logic

    private func runTest() async {
        guard !isRunning else { return }
        isRunning = true
        duration = nil
        result = NMEATestResult()
        service.cancel()

        let start = Date()
        let newResult = await service.runOneShotTest(for: boat, mode: mode)
        let elapsed = Date().timeIntervalSince(start)

        await MainActor.run {
            self.isRunning = false
            self.result = newResult
            self.duration = elapsed

            if let error = newResult.error, !error.isEmpty {
                self.showErrorAlert = true
            } else if newResult.isComplete {
                self.showDoneAlert = true
            }
        }
    }

    // MARK: - Display helpers

    private func valueRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(value == "—" ? .secondary : .primary)
                .monospacedDigit()
        }
    }

    private func formattedLatLong(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.5f°", v)
    }

    private func formatFloatKnots(_ v: Float?) -> String {
        guard let v else { return "—" }
        return String(format: "%.2f kn", v)
    }

    private func formatSpeed(_ v: Int?) -> String {
        guard let v else { return "—" }
        return "\(v) kn"
    }

    private func formatAngle(_ v: Int?) -> String {
        guard let v else { return "—" }
        return "\(v)°"
    }

    private func formatDirection(_ v: Int?) -> String {
        guard let v else { return "—" }
        return "\(v)°"
    }

    private func formatPressure(_ v: Float?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f hPa", v)
    }

    private func formatTemp(_ v: Int?) -> String {
        guard let v else { return "—" }
        return "\(v)°C"
    }

    private func formatHeel(_ v: Float?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f°", v)
    }
}
