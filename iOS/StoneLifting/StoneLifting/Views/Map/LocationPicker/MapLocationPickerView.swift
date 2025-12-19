//
//  MapLocationPickerView.swift
//  StoneLifting
//
//  Created by Max Rogers on 12/16/25.
//

import MapKit
import SwiftUI

// MARK: - Map Tap Handler (UIViewRepresentable)

/// Custom map view that properly handles tap gestures for coordinate selection
struct TappableMapView: UIViewRepresentable {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if changed
        if mapView.region.center.latitude != region.center.latitude ||
            mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }

        // Update annotation
        mapView.removeAnnotations(mapView.annotations)
        if let coordinate = selectedCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TappableMapView

        init(_ parent: TappableMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)

            parent.selectedCoordinate = coordinate
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

// MARK: - Map Location Picker

/// Map location picker using UIViewRepresentable for proper tap handling
struct MapLocationPickerView: View {
    @Binding var latitude: String
    @Binding var longitude: String

    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
    )

    @Bindable private var locationService = LocationService.shared
    @Environment(\.dismiss) private var dismiss
    private let logger = AppLogger()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                TappableMapView(selectedCoordinate: $selectedCoordinate, region: $region)
                    .edgesIgnoringSafeArea(.all)

                // Instructions overlay
                if selectedCoordinate == nil {
                    VStack {
                        Spacer()
                        Text("Tap anywhere on the map to select a location")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .padding(.bottom, 80)
                    }
                    .allowsHitTesting(false)
                }

                // Coordinate info card
                if let coordinate = selectedCoordinate {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Selected Location")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("\(coordinate.latitude, specifier: "%.6f"), \(coordinate.longitude, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(.ultraThickMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveLocation()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
            .onAppear {
                setupInitialPosition()
            }
        }
    }

    private func setupInitialPosition() {
        // If we have existing coordinates, show them
        if let lat = Double(latitude),
           let lon = Double(longitude),
           lat >= -90, lat <= 90,
           lon >= -180, lon <= 180 {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            selectedCoordinate = coordinate
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else if let currentLocation = locationService.currentLocation {
            // Use current location if available
            region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            // Fall back to region-based default using device locale
            let defaultCenter = defaultCoordinateForRegion()
            region = MKCoordinateRegion(
                center: defaultCenter,
                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
            )
        }
    }

    /// Returns a reasonable default coordinate based on the user's device region settings
    private func defaultCoordinateForRegion() -> CLLocationCoordinate2D {
        guard let regionCode = Locale.current.region?.identifier else {
            // If we can't determine region, default to US
            return CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)
        }

        switch regionCode {
        case "US":
            return CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795) // US center
        case "GB":
            return CLLocationCoordinate2D(latitude: 54.5, longitude: -2.0) // UK center
        case "IE":
            return CLLocationCoordinate2D(latitude: 53.4, longitude: -8.0) // Ireland center
        case "CA":
            return CLLocationCoordinate2D(latitude: 56.1, longitude: -106.3) // Canada center
        case "AU":
            return CLLocationCoordinate2D(latitude: -25.3, longitude: 133.8) // Australia center
        case "NZ":
            return CLLocationCoordinate2D(latitude: -40.9, longitude: 174.9) // New Zealand center
        case "IS":
            return CLLocationCoordinate2D(latitude: 64.9, longitude: -19.0) // Iceland center (stone lifting origin!)
        case "NO", "SE", "DK", "FI":
            return CLLocationCoordinate2D(latitude: 62.0, longitude: 10.0) // Scandinavia
        case "DE", "FR", "ES", "IT", "NL", "BE", "CH", "AT":
            return CLLocationCoordinate2D(latitude: 50.0, longitude: 10.0) // Central Europe
        default:
            // For other regions, default to US
            return CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)
        }
    }

    private func saveLocation() {
        guard let coordinate = selectedCoordinate else { return }

        latitude = String(format: "%.6f", coordinate.latitude)
        longitude = String(format: "%.6f", coordinate.longitude)

        logger.info("Location selected: \(latitude), \(longitude)")
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    MapLocationPickerView(
        latitude: .constant("40.7128"),
        longitude: .constant("-74.0060")
    )
}
