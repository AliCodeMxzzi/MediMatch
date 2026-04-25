import SwiftUI
import MapKit
import CoreLocation

struct ClinicMapView: View {
    let clinics: [Clinic]
    let center: CLLocationCoordinate2D

    @State private var cameraPosition: MapCameraPosition

    init(clinics: [Clinic], center: CLLocationCoordinate2D) {
        self.clinics = clinics
        self.center = center
        let region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: 8_000,
                                        longitudinalMeters: 8_000)
        _cameraPosition = State(initialValue: .region(region))
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                Annotation(
                    NSLocalizedString("clinics.you", value: "You", comment: ""),
                    coordinate: center
                ) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
                ForEach(clinics) { clinic in
                    Marker(clinic.name, systemImage: icon(for: clinic.category), coordinate: clinic.coordinate)
                        .tint(tint(for: clinic.category))
                }
            }
            .frame(maxHeight: 300)

            List(clinics) { clinic in
                ClinicRow(clinic: clinic)
                    .listRowSeparator(.visible)
            }
            .listStyle(.plain)
        }
    }

    private func icon(for category: Clinic.Category) -> String {
        switch category {
        case .hospital:    return "cross.case.fill"
        case .urgentCare:  return "stethoscope"
        case .clinic:      return "stethoscope.circle"
        case .pharmacy:    return "pills"
        }
    }

    private func tint(for category: Clinic.Category) -> Color {
        switch category {
        case .hospital:   return .red
        case .urgentCare: return .orange
        case .clinic:     return .accentColor
        case .pharmacy:   return .green
        }
    }
}

private struct ClinicRow: View {
    let clinic: Clinic

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingMD) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(clinic.name)
                    .font(.system(.headline, design: .rounded))
                if let address = clinic.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let distance = clinic.distanceMeters {
                    Text(distanceLabel(distance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            VStack(spacing: 6) {
                if let phone = clinic.phone, !phone.isEmpty {
                    Button {
                        callNumber(phone)
                    } label: {
                        Image(systemName: "phone.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(Text(String(format: NSLocalizedString(
                        "clinics.call.a11y", value: "Call %@", comment: ""), clinic.name)))
                }
                Button {
                    openInMaps()
                } label: {
                    Image(systemName: "map")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text(String(format: NSLocalizedString(
                    "clinics.directions.a11y", value: "Directions to %@", comment: ""), clinic.name)))
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch clinic.category {
        case .hospital:   return "cross.case.fill"
        case .urgentCare: return "stethoscope"
        case .clinic:     return "stethoscope.circle"
        case .pharmacy:   return "pills"
        }
    }

    private var tint: Color {
        switch clinic.category {
        case .hospital:   return .red
        case .urgentCare: return .orange
        case .clinic:     return .accentColor
        case .pharmacy:   return .green
        }
    }

    private func distanceLabel(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: NSLocalizedString("clinics.distance.m",
                value: "%d m away", comment: ""), Int(meters))
        }
        return String(format: NSLocalizedString("clinics.distance.km",
            value: "%.1f km away", comment: ""), meters / 1000)
    }

    private func callNumber(_ raw: String) {
        let digits = raw.filter { "+0123456789".contains($0) }
        if let url = URL(string: "tel://\(digits)") {
            UIApplication.shared.open(url)
        }
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: clinic.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = clinic.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
