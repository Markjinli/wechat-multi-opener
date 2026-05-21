import SwiftUI

@main
struct WeChatMultiOpenerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 440)
    }
}
