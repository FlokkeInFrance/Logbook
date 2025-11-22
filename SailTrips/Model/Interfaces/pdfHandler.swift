//
//  pdfHandler.swift
//  SailTrips
//
//  Created by jeroen kok on 09/03/2025.
//

import SwiftUI
import PDFKit

struct PDFThumbnailView: View {
    
    let pdfData: Data?
    let emptyString: String
    
    @State private var showPDFPreview = false
    
    var body: some View {
        if let pdfData, let document = PDFDocument(data: pdfData), let page = document.page(at: 0) {
            let image = page.thumbnail(of: CGSize(width: 100, height: 150), for: .mediaBox)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .onTapGesture {
                    showPDFPreview = true
                }
                .sheet(isPresented: $showPDFPreview) {
                    PDFPreviewView(pdfData: pdfData)
                }
        } else {
            Text(emptyString)
        }
    }
}

struct PDFPreviewView: View {
    let pdfData: Data
    @Environment(\.presentationMode) var presentationMode // Dismiss action

    var body: some View {
        NavigationView {
            PDFKitView(pdfData: pdfData)
                .navigationBarTitle("PDF Preview", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    },
                    trailing: ShareLink(
                        item: savePDFToTemp(),
                        preview: SharePreview("PDF Document")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                )
        }
    }

    private func savePDFToTemp() -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("document.pdf")
        try? pdfData.write(to: tempURL)
        return tempURL
    }
}

struct PDFKitView: UIViewRepresentable {
    let pdfData: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
