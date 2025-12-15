//
//  DocumentStrip.swift
//  SailTrips
//
//  Created by jeroen kok on 15/12/2025.
//


import SwiftUI

struct DocumentStrip: View {
    @Binding var documents: [Document]
    let suggestedTitles: [String]

    @State private var editorMode: EditorMode? = nil
    @State private var pendingDelete: Document? = nil

    enum EditorMode: Identifiable {
        case create
        case edit(Document)
        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let d): return d.id.uuidString
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Documents")
                Spacer()
                Button {
                    editorMode = .create
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }

            if documents.isEmpty {
                Text("No documents yet")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 12) {
                        ForEach(documents, id: \.id) { doc in
                            DocumentTile(doc: doc)
                                .onTapGesture { editorMode = .edit(doc) }
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    pendingDelete = doc
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            switch mode {
            case .create:
                DocumentEditorSheet(
                    suggestedTitles: suggestedTitles,
                    original: nil
                ) { newDoc in
                    documents.append(newDoc)
                }
            case .edit(let doc):
                DocumentEditorSheet(
                    suggestedTitles: suggestedTitles,
                    original: doc
                ) { updatedDoc in
                    // We update in place (SwiftData model reference),
                    // but this keeps behavior explicit.
                    doc.title = updatedDoc.title
                    doc.data = updatedDoc.data
                }
            }
        }
        .confirmationDialog(
            "Delete this document?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let d = pendingDelete {
                    documents.removeAll { $0.id == d.id }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }
}

struct DocumentTile: View {
    let doc: Document

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 120, height: 160)

                if let img = PDFThumb.image(from: doc.data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                }
            }

            Text(doc.title.isEmpty ? "Untitled" : doc.title)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 120)
        }
    }
}
