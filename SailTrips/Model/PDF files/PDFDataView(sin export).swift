//
//  PDFDataView.swift
//  SailTrips
//
//  Created by jeroen kok on 15/12/2025.
//


import SwiftUI
import PDFKit

struct PDFDataView: UIViewRepresentable {
    let data: Data
    let rotationDegrees: Int

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.document = makeDocument()
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = makeDocument()
    }

    private func makeDocument() -> PDFDocument? {
        guard let doc = PDFDocument(data: data) else { return nil }
        let r = normalized(rotationDegrees)
        for i in 0..<doc.pageCount {
            doc.page(at: i)?.rotation = r
        }
        return doc
    }

    private func normalized(_ r: Int) -> Int {
        var v = r % 360
        if v < 0 { v += 360 }
        return (v / 90) * 90
    }
}

