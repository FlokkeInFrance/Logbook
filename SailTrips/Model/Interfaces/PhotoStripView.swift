//
//  PhotoStripView.swift
//  SailTrips
//
//  Created by jeroen kok on 16/12/2025.
//


import SwiftUI
import PhotosUI

struct PhotoStripView: View {
    @Binding var pictures: [CruiseDataSchemaV1.Picture]

    // Local mode toggle (small button-toggle)
    @State private var selectionMode = false

    // Optional selection support
    var selectionEnabled: Bool = false
    @Binding var selectedIDs: Set<UUID>

    var thumbSize: CGSize = .init(width: 110, height: 70)
    var addLabel: String = "Add"

    @State private var showImagePicker = false
    @State private var selectedUIImage: UIImage? = nil

    // Fullscreen driven by index (enables next/prev)
    private struct FullscreenIndex: Identifiable {
        let id = UUID()
        let value: Int
    }
    @State private var fullscreen: FullscreenIndex? = nil

    // Reorder
    @State private var draggingID: UUID? = nil
    @State private var showReorder = false  // keep your sheet as a fallback

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(pictures.indices, id: \.self) { idx in
                        let pic = pictures[idx]
                        if let ui = UIImage(data: pic.data) {
                            let isSelected = selectedIDs.contains(pic.id)

                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: thumbSize.width, height: thumbSize.height)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(lineWidth: isSelected ? 3 : 0)
                                    )

                                if selectionEnabled && isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .padding(6)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectionMode {
                                    toggleSelection(for: pic.id)
                                } else {
                                    fullscreen = FullscreenIndex(value: idx)
                                }
                            }
                            .onTapGesture(count: 2) {
                                guard !selectionMode else { return }
                                fullscreen = FullscreenIndex(value: idx)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(picID: pic.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            // Drag reorder directly in strip (disable while selecting)
                            .draggable(selectionMode ? "" : pic.id.uuidString) {
                                draggingID = pic.id
                                return Image(systemName: "photo")
                            }
                            .dropDestination(for: String.self) { _, _ in
                                guard !selectionMode else { return false }
                                guard let fromID = draggingID,
                                      let from = pictures.firstIndex(where: { $0.id == fromID }),
                                      from != idx
                                else { return false }

                                withAnimation {
                                    let moved = pictures.remove(at: from)
                                    pictures.insert(moved, at: idx)
                                }
                                return true
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            TaskImagePicker(sourceType: .photoLibrary, selectedImage: $selectedUIImage)
                .onDisappear {
                    guard let ui = selectedUIImage,
                          let data = ui.jpegData(compressionQuality: 0.8)
                    else { return }
                    pictures.append(CruiseDataSchemaV1.Picture(data: data))
                    selectedUIImage = nil
                }
        }
        .sheet(isPresented: $showReorder) {
            PhotoReorderSheet(pictures: $pictures)
        }
        .fullScreenCover(item: $fullscreen) { item in
            PhotoFullscreenPager(
                pictures: pictures,
                startIndex: min(item.value, pictures.count - 1),
                onClose: { fullscreen = nil }
            )
        }
    }

    private var header: some View {
        HStack {
            Spacer()

            // Small selection toggle (only shown if selectionEnabled)
            if selectionEnabled {
                Toggle(isOn: $selectionMode) {
                    Image(systemName: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .toggleStyle(.button)

                Button {
                    if selectedIDs.count == pictures.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(pictures.map(\.id))
                    }
                } label: {
                    Label(
                        "All",
                        systemImage: selectedIDs.count == pictures.count ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                .buttonStyle(.bordered)
            }

            // Keep your edit-sheet as fallback (useful if user struggles with drag)
            Button { showReorder = true } label: {
                Label("Edit", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(pictures.count < 2)

            Button { showImagePicker = true } label: {
                Label(addLabel, systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }

    private func toggleSelection(for id: UUID) {
        guard selectionEnabled else { return }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func delete(picID: UUID) {
        if let idx = pictures.firstIndex(where: { $0.id == picID }) {
            pictures.remove(at: idx)
            selectedIDs.remove(picID)
        }
    }

    private func clamp(_ value: Int, _ lo: Int, _ hi: Int) -> Int {
        min(max(value, lo), hi)
    }
}

// MARK: - Fullscreen viewer with Prev/Next

private struct PhotoFullscreenPager: View {
    let pictures: [CruiseDataSchemaV1.Picture]
    let startIndex: Int
    let onClose: () -> Void

    @State private var index: Int

    init(pictures: [CruiseDataSchemaV1.Picture], startIndex: Int, onClose: @escaping () -> Void) {
        self.pictures = pictures
        self.startIndex = startIndex
        self.onClose = onClose
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(pictures.indices, id: \.self) { i in
                    if let ui = UIImage(data: pictures[i].data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .ignoresSafeArea()
                            .tag(i)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .padding()
                    }
                }
                Spacer()
            }

            // Prev / Next buttons (optional but nice)
           /* HStack {
                Button {
                    index = max(0, index - 1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.largeTitle)
                        .padding()
                }
                .disabled(index == 0)

                Spacer()

                Button {
                    index = min(pictures.count - 1, index + 1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.largeTitle)
                        .padding()
                }
                .disabled(index >= pictures.count - 1)
            }*/
        }
    }
}


/*private struct PhotoFullscreenViewer: View {
    let pictures: [CruiseDataSchemaV1.Picture]
    let startIndex: Int
    let onClose: () -> Void

    @State private var index: Int

    init(pictures: [CruiseDataSchemaV1.Picture], startIndex: Int, onClose: @escaping () -> Void) {
        self.pictures = pictures
        self.startIndex = startIndex
        self.onClose = onClose
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !pictures.isEmpty, let ui = UIImage(data: pictures[index].data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .padding()
                    }
                }
                Spacer()
            }

            HStack {
                Button {
                    index = max(0, index - 1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.largeTitle)
                        .padding()
                }
                .disabled(index == 0 || pictures.isEmpty)

                Spacer()

                Button {
                    index = min(pictures.count - 1, index + 1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.largeTitle)
                        .padding()
                }
                .disabled(index >= pictures.count - 1 || pictures.isEmpty)
            }
        }
    }
}*/

// MARK: - Reorder sheet (fallback)

private struct PhotoReorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pictures: [CruiseDataSchemaV1.Picture]
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(pictures, id: \.id) { pic in
                    HStack(spacing: 12) {
                        if let ui = UIImage(data: pic.data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 50)
                                .clipped()
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .frame(width: 80, height: 50)
                        }

                        Text("Photo")
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
                .onMove { from, to in
                    pictures.move(fromOffsets: from, toOffset: to)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder Photos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
