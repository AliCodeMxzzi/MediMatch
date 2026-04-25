import Foundation
import CoreLocation

@MainActor
public final class ClinicsViewModel: ObservableObject {

    public enum State: Equatable {
        case idle
        case requestingPermission
        case locating
        case searching
        case ready([Clinic])
        case error(String)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var lastUsedCoordinate: CLLocationCoordinate2D?

    private let location: LocationService
    private let finder: ClinicFinder
    private var task: Task<Void, Never>?

    public init(location: LocationService, finder: ClinicFinder) {
        self.location = location
        self.finder = finder
    }

    public func refresh() {
        task?.cancel()
        task = Task { [weak self] in
            await self?.run()
        }
    }

    private func run() async {
        switch location.authorization {
        case .denied, .restricted:
            state = .error(NSLocalizedString("clinics.error.permission",
                value: "Location permission is denied. Enable Location for MediMatch in Settings to find nearby clinics.",
                comment: ""))
            return
        case .notDetermined:
            state = .requestingPermission
            location.requestAuthorization()
            // Delegate-driven; user must respond before we can retry.
            return
        case .authorized:
            break
        }

        state = .locating
        location.requestLocation()

        // Wait briefly for a fresh fix.
        let waitDeadline = Date().addingTimeInterval(8)
        while location.lastLocation == nil && Date() < waitDeadline {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        guard let coord = location.lastLocation?.coordinate else {
            state = .error(NSLocalizedString("clinics.error.location",
                value: "Couldn't get your location. Please try again.", comment: ""))
            return
        }
        lastUsedCoordinate = coord

        state = .searching
        do {
            let clinics = try await finder.findNearby(center: coord)
            state = .ready(clinics)
        } catch {
            state = .error(NSLocalizedString("clinics.error.search",
                value: "Map search failed. Try again later.", comment: ""))
        }
    }
}
