import Foundation
import MapKit
import CoreLocation

/// Finds nearby clinics, urgent care, hospitals, and pharmacies via MapKit's
/// local search. The query is performed on Apple's servers (this is not an
/// AI feature) but no MediMatch-specific data is sent.
public actor ClinicFinder {

    public init() {}

    public func findNearby(
        center: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance = 10_000
    ) async throws -> [Clinic] {
        async let hospitals  = search(query: "hospital",     category: .hospital,    center: center, radius: radiusMeters)
        async let urgent     = search(query: "urgent care",  category: .urgentCare,  center: center, radius: radiusMeters)
        async let clinics    = search(query: "clinic",       category: .clinic,      center: center, radius: radiusMeters)
        async let pharmacies = search(query: "pharmacy",     category: .pharmacy,    center: center, radius: radiusMeters)

        let combined = try await (hospitals + urgent + clinics + pharmacies)
        // Deduplicate by name + coordinate (rounded).
        var seen = Set<String>()
        var deduped: [Clinic] = []
        for clinic in combined {
            let key = "\(clinic.name)|\(Int(clinic.coordinate.latitude * 1000))|\(Int(clinic.coordinate.longitude * 1000))"
            if seen.insert(key).inserted {
                deduped.append(clinic)
            }
        }
        return deduped.sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
    }

    private func search(
        query: String,
        category: Clinic.Category,
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance
    ) async throws -> [Clinic] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: center,
                                            latitudinalMeters: radius * 2,
                                            longitudinalMeters: radius * 2)
        request.resultTypes = [.pointOfInterest]

        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            return []
        }

        let referenceLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return response.mapItems.compactMap { item -> Clinic? in
            guard let location = item.placemark.location else { return nil }
            let address = Self.formatAddress(item.placemark)
            let distance = location.distance(from: referenceLocation)
            return Clinic(
                name: item.name ?? query.capitalized,
                category: category,
                address: address,
                phone: item.phoneNumber,
                coordinate: location.coordinate,
                distanceMeters: distance
            )
        }
    }

    private static func formatAddress(_ placemark: CLPlacemark) -> String? {
        var parts: [String] = []
        if let s = placemark.subThoroughfare { parts.append(s) }
        if let s = placemark.thoroughfare    { parts.append(s) }
        var line = parts.joined(separator: " ")
        var localityParts: [String] = []
        if let s = placemark.locality        { localityParts.append(s) }
        if let s = placemark.administrativeArea { localityParts.append(s) }
        if !localityParts.isEmpty {
            if !line.isEmpty { line += ", " }
            line += localityParts.joined(separator: ", ")
        }
        return line.isEmpty ? nil : line
    }
}
