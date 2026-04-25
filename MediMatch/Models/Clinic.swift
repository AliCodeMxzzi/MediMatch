import Foundation
import CoreLocation

/// A nearby healthcare facility surfaced by MapKit local search.
public struct Clinic: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let category: Category
    public let address: String?
    public let phone: String?
    public let coordinate: CLLocationCoordinate2D
    public let distanceMeters: CLLocationDistance?

    public init(
        id: UUID = UUID(),
        name: String,
        category: Category,
        address: String?,
        phone: String?,
        coordinate: CLLocationCoordinate2D,
        distanceMeters: CLLocationDistance?
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.address = address
        self.phone = phone
        self.coordinate = coordinate
        self.distanceMeters = distanceMeters
    }

    public enum Category: String, Sendable, Hashable {
        case hospital
        case urgentCare
        case clinic
        case pharmacy
    }

    public static func == (lhs: Clinic, rhs: Clinic) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
