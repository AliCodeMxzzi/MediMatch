import Foundation
import CoreLocation
import Combine

/// Wraps Core Location with a SwiftUI-friendly `@Published` interface.
@MainActor
public final class LocationService: NSObject, ObservableObject {

    public enum AuthorizationState: Equatable {
        case notDetermined
        case denied
        case restricted
        case authorized
    }

    @Published public private(set) var authorization: AuthorizationState = .notDetermined
    @Published public private(set) var lastLocation: CLLocation?
    @Published public private(set) var lastError: String?

    private let manager = CLLocationManager()

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        syncAuthorization()
    }

    public func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func requestLocation() {
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }

    private func syncAuthorization() {
        authorization = Self.map(manager.authorizationStatus)
    }

    private static func map(_ status: CLAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .notDetermined:                       return .notDetermined
        case .denied:                              return .denied
        case .restricted:                          return .restricted
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        @unknown default:                          return .notDetermined
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorization = Self.map(manager.authorizationStatus)
            if self.authorization == .authorized {
                manager.requestLocation()
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = loc
            self.lastError = nil
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
        }
    }
}
