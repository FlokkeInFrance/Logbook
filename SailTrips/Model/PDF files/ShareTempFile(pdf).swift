//
//  ShareTempFile.swift
//  SailTrips
//
//  Created by jeroen kok on 15/12/2025.
//


import Foundation

enum ShareTempFile {
    static func makePDFURL(data: Data, fileName: String) throws -> URL {
        let safe = fileName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        let name = safe.isEmpty ? "Document" : safe

        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("\(name).pdf")

        // overwrite if exists
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: [.atomic])

        return url
    }
}
