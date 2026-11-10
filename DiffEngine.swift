import Foundation
import PDFKit
import AppKit

enum LineKind: Sendable { case same, removed, added }

struct DiffLine: Identifiable, Sendable {
    let id = UUID()
    let kind: LineKind
    let text: String
}

struct PageDiff: Identifiable, @unchecked Sendable {
    let id: Int                // zero-based page index
    let hasA: Bool
    let hasB: Bool
    let imageA: NSImage
    let imageB: NSImage
    let overlay: NSImage
    let changedPixels: Int
    let changedRatio: Double   // fraction of page area that changed
    let textLines: [DiffLine]

    var textChanged: Bool { textLines.contains { $0.kind != .same } }
    var isDifferent: Bool { changedPixels > 30 || textChanged || !hasA || !hasB }
}

enum DiffError: LocalizedError {
    case cannotOpen(String)
    case locked(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpen(let n): return "Could not open “\(n)” as a PDF."
        case .locked(let n): return "“\(n)” is password protected. Unlock it first."
        }
    }
}

enum DiffEngine {
    static let baseScale: CGFloat = 1.5
    static let maxDimension: CGFloat = 3000
    static let threshold = 48          // per-channel difference (0-255) that counts as a change
    static let cell = 16               // size of the yellow "marker" cells

    // MARK: Public

    static func compare(urlA: URL, urlB: URL, progress: (Double) -> Void) throws -> [PageDiff] {
        guard let docA = PDFDocument(url: urlA) else { throw DiffError.cannotOpen(urlA.lastPathComponent) }
        guard let docB = PDFDocument(url: urlB) else { throw DiffError.cannotOpen(urlB.lastPathComponent) }
        if docA.isLocked { throw DiffError.locked(urlA.lastPathComponent) }
        if docB.isLocked { throw DiffError.locked(urlB.lastPathComponent) }

        let count = max(docA.pageCount, docB.pageCount)
        var result: [PageDiff] = []
        for i in 0..<count {
            let pa = i < docA.pageCount ? docA.page(at: i) : nil
            let pb = i < docB.pageCount ? docB.page(at: i) : nil
            let diff = autoreleasepool { comparePage(index: i, a: pa, b: pb) }
            result.append(diff)
            progress(Double(i + 1) / Double(count))
        }
        return result
    }

    // MARK: Page comparison

    private static func pointSize(_ page: PDFPage?) -> CGSize {
        guard let page else { return .zero }
        let b = page.bounds(for: .cropBox)
        return abs(page.rotation) % 180 == 90 ? CGSize(width: b.height, height: b.width) : b.size
    }

    private static func comparePage(index: Int, a: PDFPage?, b: PDFPage?) -> PageDiff {
        let sa = pointSize(a), sb = pointSize(b)
        let wPt = max(sa.width, sb.width, 1)
        let hPt = max(sa.height, sb.height, 1)
        let s = min(baseScale, maxDimension / max(wPt, hPt))
        let W = max(1, Int((wPt * s).rounded(.up)))
        let H = max(1, Int((hPt * s).rounded(.up)))

        let bufA = render(a, scale: s, width: W, height: H)
        let bufB = render(b, scale: s, width: W, height: H)

        // Classify every pixel: 0 same, 1 only in A (removed), 2 only in B (added), 3 colour change
        let total = W * H
        var kind = [UInt8](repeating: 0, count: total)
        var changed = 0
        for p in 0..<total {
            let i = p * 4
            let ra = Int(bufA[i]), ga = Int(bufA[i + 1]), ba = Int(bufA[i + 2])
            let rb = Int(bufB[i]), gb = Int(bufB[i + 1]), bb = Int(bufB[i + 2])
            let maxDiff = max(abs(ra - rb), abs(ga - gb), abs(ba - bb))
            if maxDiff > threshold {
                let la = (77 * ra + 150 * ga + 29 * ba) >> 8
                let lb = (77 * rb + 150 * gb + 29 * bb) >> 8
                let d = lb - la
                kind[p] = d > threshold / 2 ? 1 : (d < -threshold / 2 ? 2 : 3)
                changed += 1
            }
        }

        // Coarse grid so that tiny changes get a visible yellow marker around them
        let cw = (W + cell - 1) / cell, ch = (H + cell - 1) / cell
        var counts = [Int](repeating: 0, count: cw * ch)
        for p in 0..<total where kind[p] != 0 {
            counts[(p / W / cell) * cw + (p % W) / cell] += 1
        }

        var overlay = [UInt8](repeating: 255, count: total * 4)
        for p in 0..<total {
            let i = p * 4
            var r = 0, g = 0, bl = 0
            switch kind[p] {
            case 1: (r, g, bl) = (225, 30, 30)
            case 2: (r, g, bl) = (20, 160, 60)
            case 3: (r, g, bl) = (240, 140, 0)
            default:
                let lb = (77 * Int(bufB[i]) + 150 * Int(bufB[i + 1]) + 29 * Int(bufB[i + 2])) >> 8
                let v = 255 - (255 - lb) * 40 / 100          // faded copy of B for context
                if counts[(p / W / cell) * cw + (p % W) / cell] >= 3 {
                    (r, g, bl) = (v, v * 235 / 255, v * 130 / 255)   // yellow marker
                } else {
                    (r, g, bl) = (v, v, v)
                }
            }
            overlay[i] = UInt8(r); overlay[i + 1] = UInt8(g); overlay[i + 2] = UInt8(bl); overlay[i + 3] = 255
        }

        let size = NSSize(width: CGFloat(W) / s, height: CGFloat(H) / s)
        let lines = textDiff(a: a?.string ?? "", b: b?.string ?? "")

        return PageDiff(
            id: index,
            hasA: a != nil, hasB: b != nil,
            imageA: makeImage(bufA, W, H, size),
            imageB: makeImage(bufB, W, H, size),
            overlay: makeImage(overlay, W, H, size),
            changedPixels: changed,
            changedRatio: Double(changed) / Double(total),
            textLines: lines
        )
    }

    // MARK: Rendering helpers

    private static func render(_ page: PDFPage?, scale s: CGFloat, width W: Int, height H: Int) -> [UInt8] {
        var buf = [UInt8](repeating: 255, count: W * H * 4)
        guard let page else { return buf }
        let size = pointSize(page)
        let w = max(1, Int((size.width * s).rounded()))
        let h = max(1, Int((size.height * s).rounded()))
        let thumb = page.thumbnail(of: NSSize(width: w, height: h), for: .cropBox)
        var rect = CGRect(x: 0, y: 0, width: w, height: h)
        guard let cg = thumb.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return buf }

        buf.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
            ctx.interpolationQuality = .high
            // Align to the top-left corner (CoreGraphics origin is bottom-left)
            ctx.draw(cg, in: CGRect(x: 0, y: H - h, width: w, height: h))
        }
        return buf
    }

    private static func makeImage(_ buf: [UInt8], _ W: Int, _ H: Int, _ size: NSSize) -> NSImage {
        let data = Data(buf) as CFData
        guard let provider = CGDataProvider(data: data),
              let cg = CGImage(
                width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return NSImage(size: size) }
        return NSImage(cgImage: cg, size: size)
    }

    // MARK: Text diff

    private static func lines(_ s: String) -> [String] {
        s.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func textDiff(a: String, b: String) -> [DiffLine] {
        let la = lines(a), lb = lines(b)
        let diff = lb.difference(from: la)
        var removed = Set<Int>(), inserted = Set<Int>()
        for change in diff {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        var out: [DiffLine] = []
        var i = 0, j = 0
        while i < la.count || j < lb.count {
            if i < la.count, removed.contains(i) {
                out.append(DiffLine(kind: .removed, text: la[i])); i += 1
            } else if j < lb.count, inserted.contains(j) {
                out.append(DiffLine(kind: .added, text: lb[j])); j += 1
            } else if i < la.count, j < lb.count {
                out.append(DiffLine(kind: .same, text: lb[j])); i += 1; j += 1
            } else if i < la.count {
                out.append(DiffLine(kind: .removed, text: la[i])); i += 1
            } else {
                out.append(DiffLine(kind: .added, text: lb[j])); j += 1
            }
        }
        return out
    }
}
