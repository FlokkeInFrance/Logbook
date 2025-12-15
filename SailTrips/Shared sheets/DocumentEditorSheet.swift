//
//  DocumentEditorSheet.swift
//  SailTrips
//
//  Created by jeroen kok on 15/12/2025.
//


import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct DocumentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let suggestedTitles: [String]
    let original: Document?           // nil = create
    let onDone: (Document) -> Void    // returns either a new doc or “updated values”

    @State private var title: String = ""
    @State private var data: Data? = nil

    @State private var showImporter = false
    @State private var showFullscreen = false

    // snapshot for Cancel when editing
    @State private var snapshotTitle: String = ""
    @State private var snapshotData: Data? = nil
    
    // snapshot alignment parameters
    @State private var rotationDegrees: Int = 0
    @State private var snapshotRotation: Int = 0
    
    // States for share button and sheet
    @State private var shareItem: ShareItem? = nil
    
    private func rotateHint(by delta: Int) {
        rotationDegrees = (rotationDegrees + delta) % 360
        if rotationDegrees < 0 { rotationDegrees += 360 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Form {
                    Section("Title") {
                        // simple dropdown suggestions + free text
                        Picker("Suggested", selection: Binding(
                            get: { "" },
                            set: { picked in if !picked.isEmpty { title = picked } }
                        )) {
                            Text("—").tag("")
                            ForEach(suggestedTitles, id: \.self) { Text($0).tag($0) }
                        }

                        TextField("Document title", text: $title)
                            .autocorrectionDisabled()
                    }

                    Section("PDF") {
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import PDF", systemImage: "square.and.arrow.down")
                        }

                        if let data, let img = PDFThumb.image(from: data, maxSide: 260) {
                            VStack(spacing: 8) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .rotationEffect(.degrees(Double(rotationDegrees)))
                                    .onTapGesture { showFullscreen = true }

                                Text("Tap the thumbnail to view full screen")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        } else {
                            Text("No PDF selected")
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                        
                        if (data != nil) {
                            HStack {
                                Button {
                                    rotateHint(by: -90)
                                } label: {
                                    Label("Rotate Left", systemImage: "rotate.left")
                                }
                                .buttonStyle(.borderless)
                                .contentShape(Rectangle())

                                Spacer()

                                Button {
                                    rotateHint(by: 90)
                                } label: {
                                    Label("Rotate Right", systemImage: "rotate.right")
                                }
                                .buttonStyle(.borderless)
                                .contentShape(Rectangle())
                            }
                        }
                        
                        Button {
                            guard let data else { return }
                            do {
                                let url = try ShareTempFile.makePDFURL(data: data, fileName: title)
                                shareItem = ShareItem(url: url)
                            } catch {
                                print("Share error:", error)
                            }
                        } label: {
                            Label("Share / Export PDF", systemImage: "square.and.arrow.up")
                        }
                        .disabled(data == nil)


                    }
                }
            }
            .navigationTitle(original == nil ? "Add document" : "Edit document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // revert if editing
                        if original != nil {
                            title = snapshotTitle
                            data = snapshotData
                            rotationDegrees = snapshotRotation
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard let data else { dismiss(); return }
                        if let original {
                            let temp = Document(title: title, data: data)
                            temp.id = original.id
                            temp.rotationDegrees = rotationDegrees
                            onDone(temp)
                        } else {
                            let new = Document(title: title, data: data)
                            new.rotationDegrees = rotationDegrees
                            onDone(new)
                        }
                        dismiss()
                    }
                    .disabled(data == nil)
                }
            }
            .onAppear {
                title = original?.title ?? ""
                data = original?.data

                rotationDegrees = original?.rotationDegrees ?? 0

                snapshotTitle = title
                snapshotData = data
                snapshotRotation = rotationDegrees
            }

            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { print("Import: success but no URL"); return }

                    Task {
                        do {
                            let pdf = try loadPDFData(from: url)
                            await MainActor.run {
                                data = pdf
                            }
                            print("Import: OK (\(pdf.count) bytes) from \(url.lastPathComponent)")
                        } catch {
                            print("Import PDF error:", error)
                        }
                    }


                case .failure(let error):
                    print("Import: user picked file but importer failed:", error)
                }
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                if let data {
                    FullscreenPDFViewer(title: title, data: data, rotationDegrees: rotationDegrees)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(activityItems: [item.url])
            }


        }
    }

    func loadPDFData(from pickedURL: URL) throws -> Data {
        // 1) Security scope (required for Files/iCloud)
        let didStart = pickedURL.startAccessingSecurityScopedResource()
        defer { if didStart { pickedURL.stopAccessingSecurityScopedResource() } }

        guard didStart else {
            throw NSError(
                domain: "Import",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "startAccessingSecurityScopedResource() returned false"]
            )
        }

        // 2) If it’s an iCloud (ubiquitous) item, request download if needed
        let fm = FileManager.default
        if fm.isUbiquitousItem(at: pickedURL) {
            try? fm.startDownloadingUbiquitousItem(at: pickedURL)
        }

        // 3) Coordinated read (important for iCloud / providers)
        var coordinatorError: NSError?
        var producedData: Data?
        var innerReadError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: pickedURL, options: [], error: &coordinatorError) { url in
            do {
                producedData = try Data(contentsOf: url)
            } catch {
                innerReadError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let innerReadError { throw innerReadError }

        guard let producedData else {
            throw NSError(
                domain: "Import",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No data produced by coordinated read"]
            )
        }

        return producedData
    }

    struct ShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]
        var applicationActivities: [UIActivity]? = nil

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems,
                                     applicationActivities: applicationActivities)
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }

}
