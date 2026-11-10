import SwiftUI
import UniformTypeIdentifiers

enum ViewMode: String, CaseIterable, Identifiable {
    case overlay = "Overlay"
    case sideBySide = "Side by Side"
    case text = "Text"
    var id: String { rawValue }
}

@MainActor
func pickPDF() -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.pdf]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    return panel.runModal() == .OK ? panel.url : nil
}

struct ContentView: View {
    @EnvironmentObject var model: CompareModel
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            FileSlot(title: "Original (A)", url: model.urlA) { model.setA($0) }
            Button {
                model.swapFiles()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .help("Swap A and B")
            .disabled(model.urlA == nil || model.urlB == nil)
            FileSlot(title: "Modified (B)", url: model.urlB) { model.setB($0) }

            Spacer()

            Button { model.step(-1) } label: { Image(systemName: "chevron.up") }
                .help("Previous difference (⌘[)")
                .disabled(model.differingCount == 0)
            Button { model.step(1) } label: { Image(systemName: "chevron.down") }
                .help("Next difference (⌘])")
                .disabled(model.differingCount == 0)

            Picker("View", selection: $model.mode) {
                ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 270)
        }
        .padding(12)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.isWorking {
            VStack(spacing: 12) {
                ProgressView(value: model.progress).frame(width: 260)
                Text("Comparing pages…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage {
            ContentUnavailableView("Comparison failed", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if model.pages.isEmpty {
            ContentUnavailableView("Choose two PDFs", systemImage: "doc.on.doc",
                                   description: Text("Drop files on the boxes above or use Choose…. The comparison starts automatically."))
        } else {
            HSplitView {
                sidebar
                detail
            }
        }
    }

    private var visiblePages: [PageDiff] {
        model.onlyDiffs ? model.pages.filter(\.isDifferent) : model.pages
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.differingCount == 0
                     ? "No differences found"
                     : "\(model.differingCount) of \(model.pages.count) pages differ")
                    .font(.headline)
                Toggle("Only changed pages", isOn: $model.onlyDiffs)
                    .toggleStyle(.checkbox)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            Divider()
            List(selection: $model.selection) {
                ForEach(visiblePages) { p in
                    HStack {
                        Image(systemName: p.isDifferent ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(p.isDifferent ? Color.orange : Color.green)
                        Text("Page \(p.id + 1)")
                        Spacer()
                        if !p.hasA || !p.hasB {
                            Text(p.hasA ? "removed" : "new").font(.caption).foregroundStyle(.secondary)
                        } else if p.isDifferent {
                            Text(String(format: "%.2f%%", p.changedRatio * 100))
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    .tag(p.id)
                }
            }
        }
        .frame(minWidth: 190, idealWidth: 220, maxWidth: 280)
    }

    @ViewBuilder
    private var detail: some View {
        if let id = model.selection, let page = model.pages.first(where: { $0.id == id }) {
            PageDetail(page: page, mode: model.mode, zoom: $model.zoom)
        } else {
            ContentUnavailableView("Select a page", systemImage: "sidebar.left")
        }
    }
}

// MARK: - File slot

final class DropState: ObservableObject {
    @Published var on = false
}

struct FileSlot: View {
    let title: String
    let url: URL?
    let onPick: (URL) -> Void
    @StateObject private var drop = DropState()
    private var targeted: Bool { drop.on }

    var body: some View {
        HStack {
            Image(systemName: "doc.richtext").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(url?.lastPathComponent ?? "Drop a PDF here")
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button("Choose…") { if let u = pickPDF() { onPick(u) } }
        }
        .padding(8)
        .frame(minWidth: 240, maxWidth: 320)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(targeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(targeted ? Color.accentColor : Color.secondary.opacity(0.3),
                          style: StrokeStyle(lineWidth: 1, dash: [4])))
        .dropDestination(for: URL.self) { urls, _ in
            guard let u = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else { return false }
            onPick(u)
            return true
        } isTargeted: { drop.on = $0 }
    }
}

// MARK: - Page detail

struct PageDetail: View {
    let page: PageDiff
    let mode: ViewMode
    @Binding var zoom: Double

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Page \(page.id + 1)").font(.headline)
                if !page.hasA { Text("(only in B)").foregroundStyle(.secondary) }
                if !page.hasB { Text("(only in A)").foregroundStyle(.secondary) }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()

            switch mode {
            case .overlay:
                ZoomableImage(image: page.overlay, zoom: zoom)
            case .sideBySide:
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 20) {
                        labelled("A – Original", page.imageA)
                        labelled("B – Modified", page.imageB)
                    }
                    .padding()
                }
            case .text:
                TextDiffView(lines: page.textLines)
            }

            Divider()
            HStack(spacing: 14) {
                if mode == .overlay {
                    legend(.red, "Only in A (removed)")
                    legend(.green, "Only in B (added)")
                    legend(.orange, "Colour changed")
                } else if mode == .text {
                    legend(.red, "Removed")
                    legend(.green, "Added")
                }
                Spacer()
                if mode != .text {
                    Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                    Slider(value: $zoom, in: 0.25...3).frame(width: 160)
                    Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private func labelled(_ title: String, _ image: NSImage) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Image(nsImage: image)
                .resizable().interpolation(.high)
                .frame(width: image.size.width * zoom, height: image.size.height * zoom)
                .shadow(radius: 2)
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(text)
        }
    }
}

struct ZoomableImage: View {
    let image: NSImage
    let zoom: Double

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Image(nsImage: image)
                .resizable().interpolation(.high)
                .frame(width: image.size.width * zoom, height: image.size.height * zoom)
                .shadow(radius: 2)
                .padding()
        }
    }
}

struct TextDiffView: View {
    let lines: [DiffLine]

    var body: some View {
        if lines.isEmpty {
            ContentUnavailableView("No text on this page", systemImage: "text.alignleft",
                                   description: Text("The page may be scanned or image-only. Use the Overlay view instead."))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(line.kind == .removed ? "−" : (line.kind == .added ? "+" : " "))
                                .frame(width: 14)
                            Text(line.text).textSelection(.enabled)
                            Spacer(minLength: 0)
                        }
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12).padding(.vertical, 2)
                        .background(background(for: line.kind))
                    }
                }
            }
        }
    }

    private func background(for kind: LineKind) -> Color {
        switch kind {
        case .same: return .clear
        case .removed: return Color.red.opacity(0.18)
        case .added: return Color.green.opacity(0.18)
        }
    }
}
