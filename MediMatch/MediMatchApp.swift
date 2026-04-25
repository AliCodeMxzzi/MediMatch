import SwiftUI

/// Root app entry. Boots the dependency container once and injects services
/// into the SwiftUI environment so any view can pull what it needs without
/// passing them down by hand.
@main
struct MediMatchApp: App {

    @StateObject private var container = AppContainer.boot()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(container.settings)
                .environmentObject(container.location)
                .environmentObject(container.speech)
                .preferredColorScheme(nil)
                .environment(\.locale, container.settings.preferredLocale)
                .dynamicTypeSize(container.settings.dynamicTypeBoost)
                .task {
                    // Kick off model warm-ups in the background so the user
                    // doesn't pay the cost on first triage.
                    container.warmUpModelsInBackground()
                }
        }
    }
}
