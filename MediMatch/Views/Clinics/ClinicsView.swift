import SwiftUI
import CoreLocation

struct ClinicsView: View {
    @StateObject private var viewModel: ClinicsViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ClinicsViewModel(
            location: container.location,
            finder:   container.clinicFinder
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(NSLocalizedString("tab.clinics", value: "Clinics", comment: ""))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel(Text(NSLocalizedString("clinics.refresh",
                            value: "Refresh", comment: "")))
                    }
                }
        }
        .onAppear {
            switch viewModel.state {
            case .idle: viewModel.refresh()
            default: break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .requestingPermission, .locating:
            VStack(spacing: Theme.spacingMD) {
                ProgressView()
                Text(NSLocalizedString("clinics.locating",
                    value: "Locating you…", comment: ""))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .searching:
            VStack(spacing: Theme.spacingMD) {
                ProgressView()
                Text(NSLocalizedString("clinics.searching",
                    value: "Searching nearby clinics…", comment: ""))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let clinics):
            if clinics.isEmpty {
                EmptyStateView(
                    icon: "mappin.slash",
                    title: NSLocalizedString("clinics.empty.title",
                        value: "No clinics found", comment: ""),
                    message: NSLocalizedString("clinics.empty.message",
                        value: "Try refreshing once you have a stronger location signal.", comment: "")
                )
            } else if let coord = viewModel.lastUsedCoordinate {
                ClinicMapView(clinics: clinics, center: coord)
            }
        case .error(let message):
            VStack(spacing: Theme.spacingMD) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button(NSLocalizedString("clinics.openSettings",
                    value: "Open Settings", comment: "")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                SecondaryButton(NSLocalizedString("clinics.tryAgain",
                    value: "Try again", comment: "")) {
                    viewModel.refresh()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
