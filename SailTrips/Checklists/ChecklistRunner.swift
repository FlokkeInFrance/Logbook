//
//  ChecklistRunner.swift
//  SailTrips
//
//  Created by jeroen kok on 03/05/2025.
//

import SwiftUI
import SwiftData
import AVFoundation

/*Add the following to Info.plist*/

/// Modes in which the checklist can run
enum ChecklistMode {
    case show, resume, start
}

struct ChecklistRunnerView: View {
    @Bindable var header: ChecklistHeader
    @Bindable var instances: Instances

    @State private var mode: ChecklistMode
    @State private var currentSectionIndex: Int = 0
    @State private var currentItemIndex: Int = 0
    @State private var showProblemSheet = false
    @State private var selectedProblemItem: ChecklistItem?
    @State private var observationText: String = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showQuitDialog = false
    
    @EnvironmentObject var active: activations
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    init(header: ChecklistHeader, instances: Instances, mode: ChecklistMode) {
        self._header = .init(header)
        self._instances = .init(instances)
        self._mode = State(initialValue: mode)
    }

    var body: some View {
        Group {
            switch mode {
            case .show:
                showView
            case .resume, .start:
                runView
            }
        }
        .onAppear(perform: setupMode)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if mode != .show {
                    Button("Abort") { abortChecklist() }
                }
            }
        }
        .sheet(isPresented: $showProblemSheet) {
            ProblemInputView(
                item: selectedProblemItem,
                observationText: $observationText,
                images: $selectedImages,
                onComplete: handleProblem)
        }
        .alert("Checklist Completed", isPresented: $showQuitDialog) {
            Button("Quit") { finishChecklist() }
            Button("Continue", role: .cancel) { mode = .show }
        } message: {
            Text("Would you like to quit the checklist?")
        }
    }

    /// MARK: - Subviews
    private var showView: some View {
        List {
            ForEach(header.sections.sorted(by: { $0.orderNum < $1.orderNum })) { section in
                Section(header: Text(section.nameOfSection)) {
                    ForEach(section.items.sorted(by: { $0.itemNumber < $1.itemNumber })) { item in
                        ChecklistRowView(
                            item: item,
                            showControls: false
                        )
                    }
                }
            }
        }
        .navigationTitle(header.name)
    }

    private var runView: some View {
        TabView(selection: $currentSectionIndex) {
                ForEach(Array(header.sections.sorted(by: { $0.orderNum < $1.orderNum }).enumerated()), id: \.offset) { idx, section in
                // Compute a Binding to the current item for scrolling
                let currentItemBinding = Binding<ChecklistItem?>(
                    get: {
                        let sortedSections = header.sections.sorted(by: { $0.orderNum < $1.orderNum })
                        guard sortedSections.indices.contains(idx) else { return nil }
                        let items = sortedSections[idx].items.sorted(by: { $0.itemNumber < $1.itemNumber })
                        return items.indices.contains(currentItemIndex) ? items[currentItemIndex] : nil
                    },
                    set: { _ in }
                )

                SectionView(
                    section: section,
                    currentItem: currentItemBinding,
                    onCheck: handleCheck,
                    onProblem: presentProblem
                )
                .tag(idx)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded(handleSwipe)
                )
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .navigationTitle(header.name)
        .overlay(
            Button(action: jumpToFirstIncomplete) {
                Image(systemName: "arrow.up.to.line")
                    .padding()
            }
            .accessibilityLabel("Jump to first incomplete item")
            , alignment: .bottomTrailing
        )
    }

    // MARK: - Setup
    private func setupMode() {
        switch mode {
        case .start:
            clearChecklist()
            currentSectionIndex = 0; currentItemIndex = 0;active.lastNumberChecked = nil
        case .resume:
            locateFirstIncomplete()
        case .show:
            break
        }
    }

    private func clearChecklist() {
        header.completed = false
        header.aborted = false
        header.sections.forEach { section in
            section.items.forEach { item in
                item.checked = false; item.problem = false
            }
        }
    }

    private func locateFirstIncomplete() {
        for (sIdx, section) in header.sections.sorted(by: { $0.orderNum < $1.orderNum }).enumerated() {
            for (iIdx, item) in section.items.sorted(by: { $0.itemNumber < $1.itemNumber }).enumerated() {
                if !item.checked {
                    currentSectionIndex = sIdx
                    currentItemIndex = iIdx
                    return
                }
            }
        }
    }

    /// MARK: - Actions
    private func handleCheck(item: ChecklistItem, withProblem: Bool) {
        if let lastNumberChecked = active.lastNumberChecked {
            if (item.itemNumber == 1 || item.itemNumber == lastNumberChecked+1) {
                item.checked = true
                active.lastNumberChecked = item.itemNumber
                if withProblem { item.problem = true }
                logEntry(for: item)
                advanceAfterChecking(item)
            }
        }
        else
        {
            if item.itemNumber == 1
            {
                item.checked = true
                if withProblem { item.problem = true }
                active.lastNumberChecked = item.itemNumber
                logEntry(for: item)
                advanceAfterChecking(item)
            }
        }
    }

    private func presentProblem(item: ChecklistItem) {
        selectedProblemItem = item
        showProblemSheet = true
    }

    private func handleProblem(pictureData: [Data], text: String) {
           guard let item = selectedProblemItem else { return }
           let hasInfo = !text.trimmingCharacters(in: .whitespaces).isEmpty || !pictureData.isEmpty
           if hasInfo {
               item.checked = true; item.problem = true
               let svc = ToService(boat: instances.selectedBoat)
               svc.observation = text
               if !pictureData.isEmpty {
                   for pictData in pictureData {
                       let pict: Picture = Picture(data: pictData)
                       svc.pictures.append(pict)
                   }
               }
               context.insert(svc)
               let logEntry = BoatsLog()
               logEntry.boat = instances.selectedBoat
               logEntry.entryText = "Executing checklist \(header.name), following problem was detected: \(text)"
               if let imgData = pictureData.first {
                   let pict: Picture = Picture(data: imgData)
                   logEntry.picture.append(pict)
               }
               context.insert(logEntry)
           } else {
               item.checked = true
               item.problem = false
           }
           saveContext()
           advanceAfterChecking(item)
           showProblemSheet = false
       }

    private func advanceAfterChecking(_ item: ChecklistItem) {
        let sortedSections = header.sections.sorted(by: { $0.orderNum < $1.orderNum })
        let section = sortedSections[currentSectionIndex]
        let items = section.items.sorted(by: { $0.itemNumber < $1.itemNumber })
        if currentItemIndex + 1 < items.count {
            currentItemIndex += 1
        } else if currentSectionIndex + 1 < sortedSections.count {
            currentSectionIndex += 1
            currentItemIndex = 0
        } else {
            showQuitDialog = true
        }
    }

    private func jumpToFirstIncomplete() {
        locateFirstIncomplete()
    }

    private func abortChecklist() {
        header.aborted = true
        header.latestRunDate = Date()
        saveContext()
        dismiss()
    }

    private func finishChecklist() {
        header.completed = true
        header.latestRunDate = Date()
        if header.canBeLogged {
            if let trip = instances.currentTrip {
                let entry = Logs(trip: trip)
                entry.logEntry = "Checklist \(header.name) completed"
                context.insert(entry)
            } else {
                let entry = BoatsLog()
                entry.boat = instances.selectedBoat
                entry.entryText = "Checklist \(header.name) completed"
                context.insert(entry)
            }
        }
        saveContext()
        dismiss()
    }

    private func logEntry(for item: ChecklistItem) {
        guard header.canBeLogged else { return }
        let message = item.problem ? "with problem at item \(item.itemNumber)" : "item \(item.itemNumber) checked"
        if let trip = instances.currentTrip {
            let entry = Logs(trip: trip)
            entry.logEntry = "Checklist \(header.name): \(message)"
            context.insert(entry)
        } else {
            let entry = BoatsLog()
            entry.boat = instances.selectedBoat
            entry.entryText = "Checklist \(header.name): \(message)"
            context.insert(entry)
        }
        saveContext()
    }

    private func saveContext() {
        do { try context.save() } catch {
            print("Failed to save context: \(error)")
        }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = abs(value.translation.width) > abs(value.translation.height)
        if horizontal {
            if value.translation.width > 0 {
                currentSectionIndex = max(currentSectionIndex - 1, 0)
            } else {
                let maxIndex = mode == .show ? header.sections.count - 1 : currentSectionIndex
                currentSectionIndex = min(currentSectionIndex + 1, maxIndex)
            }
        }
    }
}

// MARK: - Checklist Row View
struct ChecklistRowView: View {
    @Bindable var item: ChecklistItem
    var showControls: Bool
    var onCheck: ((ChecklistItem, Bool) -> Void)?
    var onProblem: ((ChecklistItem) -> Void)?
    @State private var showingLongText = false

    var body: some View {
        HStack {
            Text(item.itemShortText)
                .font(.title3)
                .onLongPressGesture (minimumDuration: 0.5) { showingLongText = true}
                .popover(isPresented: $showingLongText) {
                    Text(item.itemLongText)
                        .font(.headline)
                        .padding()
                }
            Spacer()
            if showControls {
                if item.itemNormalCheck {
                    Button(action: { onCheck?(item, false) }) {
                        Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                    }
                    Button(action: { onProblem?(item) }) {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } else {
                    Picker("Choice", selection: Binding(
                        get: { item.choiceAlt1 },
                        set: {
                            item.choiceAlt1 = $0
                            onCheck?(item, false)
                        }
                    )) {
                        Text(item.textAlt1).tag(true)
                        Text(item.textAlt2).tag(false)
                    }
                    .pickerStyle(.segmented)
                    Button(action: { onProblem?(item) }) {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
            }
        }
        .padding()
        .background(item.checked ? (item.problem ? Color.orange.opacity(0.5) : Color.green.opacity(0.3)) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Section View
struct SectionView: View {
    var section: ChecklistSection
    @Binding var currentItem: ChecklistItem?
    var onCheck: (ChecklistItem, Bool) -> Void
    var onProblem: (ChecklistItem) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(section.nameOfSection)
                .font(.headline)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 16) {
                        ForEach(section.items.sorted(by: { $0.itemNumber < $1.itemNumber })) { item in
                            ChecklistRowView(
                                item: item,
                                showControls: true,
                                onCheck: onCheck,
                                onProblem: onProblem
                            )
                            .id(item.id)
                        }
                    }
                    .onChange(of: currentItem?.id) { _, id in
                        if let id = id { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .padding()
    }
}





/// A simple UIViewControllerRepresentable that wraps UIImagePickerController
/// to take photos (or pick from library, if you switch sourceType).
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}


