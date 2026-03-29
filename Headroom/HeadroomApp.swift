import SwiftUI

@main
struct HeadroomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default window. The app is driven entirely by the
        // NSStatusItem created in AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
