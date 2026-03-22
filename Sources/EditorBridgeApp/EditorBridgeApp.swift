import SwiftUI

@main
struct EditorBridgeApp: App {
    @StateObject private var model = EditorBridgeModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 860, minHeight: 720)
        }
        .windowResizability(.contentSize)
    }
}
