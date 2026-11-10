import SwiftUI

@main
struct PDFCompareApp: App {
    @StateObject private var model = CompareModel()

    var body: some Scene {
        WindowGroup("PDF Compare") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Next Difference") { model.step(1) }
                    .keyboardShortcut("]", modifiers: .command)
                Button("Previous Difference") { model.step(-1) }
                    .keyboardShortcut("[", modifiers: .command)
            }
        }
    }
}
