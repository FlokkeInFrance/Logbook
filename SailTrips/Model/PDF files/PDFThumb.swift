//
//  PDFThumb.swift
//  SailTrips
//
//  Created by jeroen kok on 15/12/2025.
//


import PDFKit
import UIKit

/*enum PDFThumb {
    static func image(from pdfData: Data, maxSide: CGFloat = 180) -> UIImage? {
        guard let doc = PDFDocument(data: pdfData),
              let page = doc.page(at: 0) else { return nil }

        let rect = page.bounds(for: .mediaBox)
        let scale = maxSide / max(rect.width, rect.height)
        let size = CGSize(width: rect.width * scale, height: rect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.saveGState()
            ctx.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
}*/

enum PDFThumb {
    static func image(from pdfData: Data, maxSide: CGFloat = 180) -> UIImage? {
        guard let doc = PDFDocument(data: pdfData),
              let page = doc.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: maxSide, height: maxSide), for: .mediaBox)
    }
}

