import Foundation
import PDFKit

enum PDFMergerError: LocalizedError {
    case unreadablePart
    case writeFailed

    var errorDescription: String? { L10n.errorMerge }
}

/// Joins PDFs into one file. Every part starts on a new page and gets a
/// bookmark (shown in Preview's sidebar) named after its source file.
enum PDFMerger {
    static func merge(_ parts: [(title: String, url: URL)], into destination: URL) throws {
        let merged = PDFDocument()
        let outline = PDFOutline()

        for part in parts {
            guard let document = PDFDocument(url: part.url) else { throw PDFMergerError.unreadablePart }
            let firstPageIndex = merged.pageCount
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
                merged.insert(page, at: merged.pageCount)
            }

            if let firstPage = merged.page(at: firstPageIndex) {
                let bookmark = PDFOutline()
                bookmark.label = part.title
                let top = firstPage.bounds(for: .mediaBox).maxY
                bookmark.destination = PDFDestination(page: firstPage, at: NSPoint(x: 0, y: top))
                outline.insertChild(bookmark, at: outline.numberOfChildren)
            }
        }

        merged.outlineRoot = outline
        guard merged.pageCount > 0, merged.write(to: destination) else { throw PDFMergerError.writeFailed }
    }
}
