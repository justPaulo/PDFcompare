import SwiftUI

@MainActor
final class CompareModel: ObservableObject {
    @Published var urlA: URL?
    @Published var urlB: URL?
    @Published var pages: [PageDiff] = []
    @Published var selection: Int?
    @Published var isWorking = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?

    // View state lives here because @State is a macro that needs Xcode's plugin
    @Published var mode: ViewMode = .overlay
    @Published var zoom: Double = 1.0
    @Published var onlyDiffs = false

    var differingCount: Int { pages.filter(\.isDifferent).count }

    func setA(_ url: URL) { urlA = url; run() }
    func setB(_ url: URL) { urlB = url; run() }

    func swapFiles() {
        swap(&urlA, &urlB)
        run()
    }

    func run() {
        guard let a = urlA, let b = urlB, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        progress = 0
        pages = []
        selection = nil

	Task { [weak self] in
    	    do {
        	let result = try await Task.detached(priority: .userInitiated) { [weak self] in
            	    try DiffEngine.compare(urlA: a, urlB: b) { p in
                        Task { @MainActor in self?.progress = p }
                    }
        	}.value
        	self?.pages = result
        	self?.selection = result.first(where: \.isDifferent)?.id ?? result.first?.id
    	    } catch {
        	self?.errorMessage = error.localizedDescription
    	    }
    	    self?.isWorking = false
	}
    }

    /// Jump to the next (+1) or previous (-1) page that has differences.
    func step(_ direction: Int) {
        let ids = pages.filter(\.isDifferent).map(\.id)
        guard !ids.isEmpty else { return }
        let current = selection ?? -1
        if direction > 0 {
            selection = ids.first(where: { $0 > current }) ?? ids.first
        } else {
            selection = ids.last(where: { $0 < current }) ?? ids.last
        }
    }
}
