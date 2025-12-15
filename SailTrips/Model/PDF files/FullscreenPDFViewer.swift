//
//  FullscreenPDFViewer.swift
//  SailTrips
//
//  Created by jeroen kok on 15/12/2025.
//


import SwiftUI

struct FullscreenPDFViewer: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let data: Data
    let rotationDegrees: Int

    @State private var shareURL: URL? = nil
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            PDFDataView(data: data, rotationDegrees: rotationDegrees)
                .ignoresSafeArea()
                .navigationTitle(title.isEmpty ? "PDF" : title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            do {
                                shareURL = try ShareTempFile.makePDFURL(data: data, fileName: title)
                                showShare = true
                            } catch {
                                print("Share error:", error)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
    }
}
