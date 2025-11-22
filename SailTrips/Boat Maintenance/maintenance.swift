//
//  maintenance.swift
//  SailTrips
//
//  Created by jeroen kok on 14/05/2025.
//

import SwiftUI
import SwiftData
import PDFKit
import UIKit
import AVFoundation

// MARK: - Share Sheet Helper
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems,
                                 applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Image Picker for Maintenance
struct TaskImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: TaskImagePicker
        init(_ parent: TaskImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

/// A simple UIViewControllerRepresentable that wraps UIImagePickerController
/// to take photos (or pick from library, if you switch sourceType).


// MARK: - Maintenance List View
struct MaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    var boat: Boat

    @State private var statusFilter: TaskStatusFilter = .all
    @State private var periodPreset: PeriodPreset = .all
    @State private var startDate: Date? = Calendar.current
        .date(byAdding: .month, value: -1, to: .now) ?? .distantPast
    @State private var endDate: Date? = .now

    @State private var isAddingNew = false
    @State private var newTask: ToService?
    @State private var shareURLs: [URL] = []
    @State private var showShareSheet = false
    
    @Query(sort: [
        SortDescriptor(\ToService.dateOfEntry, order: .reverse)
    ]) private var tasks: [ToService]

    private var filteredTasks: [ToService] {
        tasks
            .filter { $0.boat.id == boat.id }
            .filter {
                switch statusFilter {
                case .all:   return true
                case .done:  return $0.fixed
                case .pending: return !$0.fixed
                }
            }
            .filter { log in
                if let s = startDate, let e = endDate {
                    return log.dateOfEntry >= s && log.dateOfEntry <= e
                } else if let s = startDate {
                    return log.dateOfEntry >= s
                } else if let e = endDate {
                    return log.dateOfEntry <= e
                } else {
                    return true
                }
            }
    }

    private var totalCost: Double {
        filteredTasks.reduce(0) { $0 + $1.cost }
    }
    
    private var startBinding: Binding<Date> {
        Binding(get: { startDate ?? Date() }, set: { startDate = $0 })
    }
    private var endBinding: Binding<Date> {
        Binding(get: { endDate ?? Date() }, set: { endDate = $0 })
    }

    var body: some View {
        //NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status Filter
                   GroupBox(label: Text("Status")) {
                        HStack {
                            ForEach(TaskStatusFilter.allCases, id: \.self) { filter in
                                Button(filter.rawValue) { statusFilter = filter }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).stroke())

                    // Period Filter
                    GroupBox(label: Text("Period")) {
                        
                        HStack {
                            DatePicker("From", selection: startBinding, displayedComponents: .date)
                            DatePicker("To",   selection: endBinding,   displayedComponents: .date)
                        }
                        HStack {
                            ForEach(PeriodPreset.allCases, id: \.self) { preset in
                                Button(preset.rawValue) {
                                    switch preset {
                                    case .all:
                                        startDate = .distantPast
                                        endDate = .now
                                    case .lastMonth:
                                        endDate   = .now
                                        startDate = Calendar.current
                                            .date(byAdding: .month, value: -1, to: .now) ?? .distantPast
                                    case .lastYear:
                                        endDate   = .now
                                        startDate = Calendar.current
                                            .date(byAdding: .year, value: -1, to: .now) ?? .distantPast
                                    }
                                    periodPreset = preset
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding().background(RoundedRectangle(cornerRadius: 8).stroke())

                    // Total + PDF + Share
                    HStack {
                        Text("Total known costs:")
                        Spacer()
                        Text(totalCost,
                             format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    }
                    HStack {
                        Button("Generate PDF Report") { generateListPDF() }
                            .buttonStyle(.borderedProminent)
                        if !shareURLs.isEmpty {
                            Button("Share Report") { showShareSheet = true }
                                .buttonStyle(.bordered)
                        }
                    }

                    // Task Rows
                    VStack(alignment: .leading) {
                        if filteredTasks.isEmpty {
                            Text("No tasks logged in the selected period for the given status.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(filteredTasks) { task in
                                NavigationLink(value: task) {
                                    HStack {
                                        Text(task.dateOfEntry, style: .date)
                                        Divider()
                                        Text(task.observation).lineLimit(2)
                                        Spacer()
                                        Image(systemName: task.fixed
                                                ? "checkmark.circle.fill"
                                                : "exclamationmark.triangle.fill")
                                            .foregroundColor(task.fixed ? .green : .yellow)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Maintenance")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add New Issue") {
                        let task = ToService(boat: boat)
                        modelContext.insert(task)
                        newTask = task
                        isAddingNew = true
                    }
                }
            }
            .navigationDestination(for: ToService.self) { task in
                ToServiceDetailView(boat: boat, task: task)
            }
            .sheet(isPresented: $isAddingNew) {
                if let task = newTask {
                    
                        ToServiceDetailView(boat: boat, task: task)
                    
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: shareURLs)
            }
        //}
    }

    // MARK: PDFKit: List
    private func generateListPDF() {
        
        let pageSize = CGSize(width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let title = "\(boat.name) issues from \(startDate!.formatted(date: .numeric, time: .omitted)) to \(endDate!.formatted(date: .numeric, time: .omitted))"
            title.draw(at: CGPoint(x: 20, y: 20),
                       withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
            let headers = ["Date", "Issue", "Status", "Cost"]
            var y = 60.0
            for (i, h) in headers.enumerated() {
                h.draw(at: CGPoint(x: [20, 100, 300, 400][i], y: y),
                       withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14)])
            }
            y += 20
            for task in filteredTasks {
                if y > pageSize.height - 40 { ctx.beginPage(); y = 20 }
                let row = [
                    task.dateOfEntry.formatted(date: .numeric, time: .omitted),
                    task.observation,
                    task.fixed ? "Fixed" : "Pending",
                    task.cost > 0 ? String(format: "%.2f", task.cost) : ""
                ]
                for (i, text) in row.enumerated() {
                    let rect = CGRect(x: [20,100,300,400][i], y: y,
                                      width: i==1 ? 180 : 80, height: 20)
                    text.draw(in: rect,
                              withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
                }
                y += 30
            }
        }
        guard let docsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let url = docsURL.appendingPathComponent("MaintenanceList_\(boat.id).pdf")
        do {
            try data.write(to: url)
            shareURLs = [url]
        } catch {
            print("Error writing PDF: \(error)")
        }
    }
}

// MARK: - Task Detail View
struct ToServiceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var boat: Boat
    @State var task: ToService
    var onSave: ((ToService) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage? = nil
    @State private var showFull = false
    @State private var fullImage: UIImage? = nil

    @State private var shareURLs: [URL] = []
    @State private var showShareSheet = false

    var body: some View {
        Form {
            Section("Issues for \(boat.name)") {
                Text("Date of creation: \(task.dateOfEntry, style: .date)")
            }
            Section("Observation") {
                if task.fixed { Text(task.observation) }
                else             { TextEditor(text: $task.observation).frame(height: 100) }
            }
            Section("Action to undertake") {
                TextEditor(text: $task.actiontoTake).frame(height: 80)
            }
            Section("Parts") {
                TextEditor(text: $task.parts).frame(height: 80)
            }
            Section("Suppliers") {
                TextField("Suppliers", text: $task.suppliers)
            }
            Section("Cost") {
                TextField("Cost", value: $task.cost, format: .number)
                    .keyboardType(.decimalPad)
            }
            Section {
                Toggle("Fixed", isOn: $task.fixed)
                    .onChange(of: task.fixed) { old, new in
                        if new { task.dateFixed = Date.now }
                    }
                if task.fixed == true  {
                    let df = task.dateFixed
                    DatePicker("Date Fixed",
                               selection: Binding(get: { df }, set: { task.dateFixed = $0 }),
                               displayedComponents: .date)
                }
            }
            Section("Pictures") {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(task.pictures) { pic in
                            if let img = pic.uiImage() {
                                Button {
                                    fullImage = img
                                    showFull = true
                                } label: {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 200, height: 100)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                        }
                        Button { showActionSheet() } label: {
                            Image(systemName: "plus.rectangle.on.folder")
                                .font(.largeTitle)
                        }
                    }
                }
            }
        }
        .navigationTitle("Task Detail")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    try? modelContext.save()
                    dismiss()
                }
            }
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button("Generate PDF Report") { generateDetailPDF() }
                        .buttonStyle(.borderedProminent)
                    if !shareURLs.isEmpty {
                        Button("Share Report") { showShareSheet = true }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            TaskImagePicker(sourceType: pickerSource,
                            selectedImage: $selectedImage)
                .onDisappear {
                    if let ui = selectedImage {
                        let pic = Picture(uiImage: ui)
                        modelContext.insert(pic)
                        task.pictures.append(pic)
                        selectedImage = nil
                    }
                }
        }
        .fullScreenCover(isPresented: $showFull) {
            if let img = fullImage {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: img).resizable().scaledToFit()
                    Button { showFull = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle).padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareURLs)
        }
    }

    private func showActionSheet() {
        let sheet = UIAlertController(title: nil,
                                      message: nil,
                                      preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(.init(title: "Camera", style: .default) { _ in
                pickerSource = .camera; showImagePicker = true
            })
        }
        sheet.addAction(.init(title: "Photo Library", style: .default) { _ in
            pickerSource = .photoLibrary; showImagePicker = true
        })
        sheet.addAction(.init(title: "Cancel", style: .cancel))
        UIApplication.shared.windows.first?
            .rootViewController?
            .present(sheet, animated: true)
    }

    // MARK: PDFKit: Detail
    private func generateDetailPDF() {
        let pageSize = CGSize(width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y = 20.0
            boat.name.draw(at: CGPoint(x: 20, y: y),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
            y += 30
            let fields: [(String,String)] = [
                ("Date of first report", task.dateOfEntry.formatted(date: .numeric, time: .omitted)),
                ("Description",           task.observation),
                ("Proposed actions",      task.actiontoTake),
                ("Parts used",            task.parts),
                ("Suppliers",             task.suppliers),
                ("Total Costs incurred",  task.cost > 0 ? String(format: "%.2f", task.cost) : ""),
                ("Fixed on",              task.fixed
                 ? (task.dateFixed.formatted(date: .numeric, time: .omitted))
                                           : "Pending")
            ].filter { !$0.1.isEmpty }
            for (label, value) in fields {
                label.draw(at: CGPoint(x: 20, y: y),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14)])
                y += 18
                let rect = CGRect(x: 20, y: y,
                                  width: pageSize.width - 40,
                                  height: CGFloat(value.components(separatedBy: "\n").count * 14))
                value.draw(in: rect,
                           withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
                y += rect.height + 10
            }
            for pic in task.pictures {
                if y > pageSize.height - 120 { ctx.beginPage(); y = 20 }
                if let img = pic.uiImage() {
                    img.draw(in: CGRect(x: 20, y: y, width: 200, height: 100))
                }
                y += 110
            }
        }
        guard let docsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let url = docsURL.appendingPathComponent("TaskDetail_\(task.id).pdf")
        do {
            try data.write(to: url)
            shareURLs = [url]
        } catch {
            print("Error writing PDF: \(error)")
        }
    }
}

// MARK: - Filters
enum TaskStatusFilter: String, CaseIterable { case all="All", done="Done", pending="Pending" }
enum PeriodPreset: String, CaseIterable {
    case all="All"
    case lastMonth="Last Month"
    case lastYear="Last Year"
    var id: Self { self }
}

