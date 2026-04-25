import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            TriageView(container: container)
                .tabItem {
                    Label(NSLocalizedString("tab.triage", value: "Triage", comment: ""),
                          systemImage: "stethoscope")
                }

            ClinicsView(container: container)
                .tabItem {
                    Label(NSLocalizedString("tab.clinics", value: "Clinics", comment: ""),
                          systemImage: "cross.case")
                }

            MedicationsView(container: container)
                .tabItem {
                    Label(NSLocalizedString("tab.meds", value: "Medications", comment: ""),
                          systemImage: "pills")
                }

            HistoryView(container: container)
                .tabItem {
                    Label(NSLocalizedString("tab.history", value: "History", comment: ""),
                          systemImage: "clock.arrow.circlepath")
                }

            SettingsView(container: container)
                .tabItem {
                    Label(NSLocalizedString("tab.settings", value: "Settings", comment: ""),
                          systemImage: "gearshape")
                }
        }
        .tint(Color.accentColor)
    }
}
