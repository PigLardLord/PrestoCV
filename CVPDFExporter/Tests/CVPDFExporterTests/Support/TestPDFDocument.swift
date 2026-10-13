import Foundation

/// Small but valid PDF documents for tests, so that page counts come from the document and not from its size
enum TestPDFDocument {

    /// A PDF with `pageCount` blank A4 pages
    static func data(pageCount: Int) -> Data {
        let firstPageObject = 3
        let kids = (0..<pageCount).map { "\(firstPageObject + $0) 0 R" }.joined(separator: " ")

        var objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [\(kids)] /Count \(pageCount) >>"
        ]
        for _ in 0..<pageCount {
            objects.append("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] >>")
        }

        var pdf = "%PDF-1.4\n"
        var offsets: [Int] = []
        for (index, body) in objects.enumerated() {
            offsets.append(pdf.utf8.count)
            pdf += "\(index + 1) 0 obj\n\(body)\nendobj\n"
        }

        let crossReferenceOffset = pdf.utf8.count
        pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        for offset in offsets {
            pdf += String(format: "%010d 00000 n \n", offset)
        }
        pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(crossReferenceOffset)\n%%EOF\n"

        return Data(pdf.utf8)
    }
}
