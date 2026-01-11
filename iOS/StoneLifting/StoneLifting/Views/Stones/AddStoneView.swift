//
//  AddStoneView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/25/25.
//

import PhotosUI
import SwiftUI

// MARK: - Add Stone View

/// Stone creation view with camera, weight input, and location capture
/// Allows users to log new stone lifting records
// swiftlint:disable type_body_length
struct AddStoneView: View {
    // MARK: - Properties

    @State private var viewModel = StoneFormViewModel()

    @Bindable private var locationService = LocationService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let offlineSyncService = OfflineSyncService.shared
    private let logger = AppLogger()

    @State private var stoneName: String = ""
    @State private var weight: String = ""
    @State private var estimatedWeight: String = ""
    @State private var stoneType: StoneType = .granite
    @State private var description: String = ""
    @State private var locationName: String = ""
    @State private var isPublic = true
    @State private var liftingLevel: LiftingLevel = .notLifted
    @State private var includeLocation = true
    @State private var manualLatitude: String = ""
    @State private var manualLongitude: String = ""
    @State private var showingMapPicker = false
    @State private var showingManualEntry = false

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingPhotoOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingCropView = false
    @State private var imageToCrop: UIImage?

    @FocusState private var focusedField: StoneFormField?

    /// Dismissal action
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        StonePhotoFormView(
                            photoData: $photoData,
                            showingPhotoOptions: $showingPhotoOptions
                        )

                        sectionDivider

                        StoneDetailsFormView(
                            stoneName: $stoneName,
                            description: $description,
                            liftingLevel: $liftingLevel,
                            focusedField: $focusedField
                        )

                        sectionDivider

                        StoneWeightFormView(
                            weight: $weight,
                            estimatedWeight: $estimatedWeight,
                            stoneType: $stoneType,
                            photoData: $photoData,
                            focusedField: $focusedField
                        )

                        sectionDivider

                        locationSection

                        sectionDivider

                        visibilitySection

                        if !networkMonitor.isConnected {
                            offlineStatusBanner
                        }

                        if !isFormValid {
                            formValidationMessage
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .navigationTitle("Add Stone")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            logger.info("User cancelled stone creation")
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveStone()
                        }
                        .disabled(!isFormValid || viewModel.isLoading)
                        .fontWeight(isFormValid ? .semibold : .regular)
                    }
                }
                .onAppear {
                    setupView()
                }
                if viewModel.isLoading {
                    LoadingView(message: networkMonitor.isConnected ? "Adding stone..." : "Saving offline...")
                }
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions) {
            Button("Camera") {
                showingCamera = true
            }
            Button("Photo Library") {
                showingPhotoPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showingCamera) {
            CameraPickerView { imageData in
                self.photoData = imageData
                self.showingCamera = false
            }
        }
        .sheet(isPresented: $showingCropView) {
            if let imageToCrop = imageToCrop {
                ImageCropView(image: imageToCrop) { croppedData in
                    self.photoData = croppedData
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            loadSelectedPhoto(newValue)
        }
        .alert("Error", isPresented: .constant(viewModel.stoneError != nil)) {
            if let error = viewModel.stoneError, error.isImageUploadError {
                Button("Retry") {
                    viewModel.clearError()
                    saveStone()
                }
                Button("Continue Without Photo") {
                    photoData = nil
                    viewModel.clearError()
                    saveStone()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.clearError()
                }
            } else {
                Button("OK") {
                    viewModel.clearError()
                }
            }
        } message: {
            Text(viewModel.stoneError?.localizedDescription ?? "")
        }
        .alert("Location Access Needed", isPresented: $locationService.showSettingsAlert) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Location access is required to add stones with GPS coordinates. Please enable location services in Settings.")
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualCoordinateEntryView(latitude: $manualLatitude, longitude: $manualLongitude)
        }
        .sheet(isPresented: $showingMapPicker) {
            MapLocationPickerView(latitude: $manualLatitude, longitude: $manualLongitude)
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var photoSection: some View {
        VStack(spacing: 16) {
            Text("Stone Photo")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button("Change") {
                                    showingPhotoOptions = true
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .padding()
                            }
                        }
                    )
            } else {
                Button(action: {
                    showingPhotoOptions = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text("Add Photo")
                            .font(.headline)

                        Text("Take a photo or choose from library")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Location")
                    .font(.headline)

                Spacer()

                Toggle("Include Location", isOn: $includeLocation)
                    .labelsHidden()
                    .onChange(of: includeLocation) { _, newValue in
                        if !newValue {
                            // User toggled OFF - clear location
                            manualLatitude = ""
                            manualLongitude = ""
                            locationService.clearCachedLocation()
                        } else if newValue {
                            // User toggled ON - auto-fetch if no location exists
                            let hasLocation = (!manualLatitude.isEmpty && !manualLongitude.isEmpty) ||
                                            locationService.currentLocation != nil

                            if !hasLocation {
                                if [.authorizedWhenInUse, .authorizedAlways].contains(locationService.authorizationStatus) {
                                    requestLocation(userInitiated: false)
                                }
                            }
                        }
                    }
            }

            if includeLocation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location Name (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("e.g., Central Park, Rocky Trail", text: $locationName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .locationName)
                }

                // Show current location status
                if let location = locationService.currentLocation {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("GPS Location")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("\(location.coordinate.latitude, specifier: "%.4f"), \(location.coordinate.longitude, specifier: "%.4f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Update") {
                            requestLocation(userInitiated: true)
                        }
                        .font(.caption)
                    }
                } else if !manualLatitude.isEmpty && !manualLongitude.isEmpty,
                          let lat = Double(manualLatitude), let lon = Double(manualLongitude) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manual Location")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("\(lat, specifier: "%.4f"), \(lon, specifier: "%.4f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Edit") {
                            showingManualEntry = true
                        }
                        .font(.caption)
                    }
                } else {
                    VStack(spacing: 12) {
                        Button(action: {
                            requestLocation(userInitiated: true)
                        }) {
                            Label("Use Current GPS Location", systemImage: "location.fill")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                showingMapPicker = true
                            }) {
                                Label("Pick on Map", systemImage: "map")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }

                            Button(action: {
                                showingManualEntry = true
                            }) {
                                Label("Enter Coords", systemImage: "number")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.orange.opacity(0.1))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var visibilitySection: some View {
        VStack(spacing: 16) {
            Text("Visibility")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Button(action: {
                    isPublic = true
                }) {
                    HStack {
                        Image(systemName: isPublic ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Public")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Others can see and attempt this stone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(isPublic ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    isPublic = false
                }) {
                    HStack {
                        Image(systemName: !isPublic ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Private")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Only you can see this stone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(!isPublic ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var sectionDivider: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var offlineStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.title3)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("No Internet Connection")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Text("Your stone will be saved locally and uploaded when you're back online.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var formValidationMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("Complete these required fields:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                if stoneName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Stone name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                let hasConfirmedWeight = !weight.isEmpty && Double(weight) ?? 0 > 0
                let hasEstimatedWeight = !estimatedWeight.isEmpty && Double(estimatedWeight) ?? 0 > 0

                if !hasConfirmedWeight && !hasEstimatedWeight {
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("At least one weight (confirmed or estimated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Check for invalid weight ranges
                if let weightValue = Double(weight), !weight.isEmpty {
                    if weightValue < 1 || weightValue > 1000 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Confirmed weight must be between 1-1000 lbs")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                if let estimatedWeightValue = Double(estimatedWeight), !estimatedWeight.isEmpty {
                    if estimatedWeightValue < 1 || estimatedWeightValue > 1000 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Estimated weight must be between 1-1000 lbs")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        // Require stone name
        guard !stoneName.isEmpty else { return false }

        // Require at least one weight (confirmed or estimated)
        let hasConfirmedWeight = !weight.isEmpty && Double(weight) ?? 0 > 0
        let hasEstimatedWeight = !estimatedWeight.isEmpty && Double(estimatedWeight) ?? 0 > 0

        guard hasConfirmedWeight || hasEstimatedWeight else { return false }

        // Validate weight ranges (1-1000 lbs to match backend validation)
        if let weightValue = Double(weight), !weight.isEmpty {
            guard weightValue >= 1 && weightValue <= 1000 else { return false }
        }

        if let estimatedWeightValue = Double(estimatedWeight), !estimatedWeight.isEmpty {
            guard estimatedWeightValue >= 1 && estimatedWeightValue <= 1000 else { return false }
        }

        return true
    }

    // MARK: - Actions

    private func setupView() {
        logger.info("Setting up AddStoneView")

        // Clear any cached location from previous views
        // This ensures the user sees all three location input options
        locationService.clearCachedLocation()

        // Handle location permissions
        switch locationService.authorizationStatus {
        case .notDetermined:
            // Request permission for first time (system dialog)
            locationService.requestLocationPermission()
        case .denied, .restricted:
            logger.info("Location permissions denied - user can enable via 'Get Location' button if desired")
        case .authorizedWhenInUse, .authorizedAlways:
            logger.info("Location permissions granted")
            if includeLocation {
                requestLocation(userInitiated: false)
            }
        @unknown default:
            break
        }
    }

    private func showPhotoOptions() {
        let alert = UIAlertController(title: "Add Photo", message: "Choose a photo source", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            showingCamera = true
        })

        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            showingPhotoPicker = true
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // TODO: better way
        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        logger.info("Loading selected photo")

        item.loadTransferable(type: Data.self) { result in
            switch result {
            case let .success(data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.imageToCrop = image
                        self.showingCropView = true
                        self.logger.info("Photo loaded successfully, showing crop view")
                    }
                }
            case let .failure(error):
                logger.error("Failed to load photo", error: error)
            }
        }
    }

    /// Request current location
    /// - Parameter userInitiated: Whether this was triggered by user tapping a button (shows alert on failure)
    private func requestLocation(userInitiated: Bool = false) {
        logger.info("Requesting current location (user initiated: \(userInitiated))")

        Task {
            _ = await locationService.getCurrentLocation(showAlertOnFailure: userInitiated)
        }
    }

    private func saveStone() {
        let weightInfo = weight.isEmpty ? "estimated: \(estimatedWeight)" : "confirmed: \(weight)"
        logger.info("Saving stone with weight: \(weightInfo)")

        focusedField = nil

        Task {
            var finalLatitude: Double?
            var finalLongitude: Double?

            if includeLocation {
                if !manualLatitude.isEmpty && !manualLongitude.isEmpty,
                   let manualLat = Double(manualLatitude),
                   let manualLon = Double(manualLongitude) {
                    finalLatitude = manualLat
                    finalLongitude = manualLon
                    logger.info("Using manual coordinates: \(manualLat), \(manualLon)")
                } else if let gpsLocation = locationService.currentLocation {
                    finalLatitude = gpsLocation.coordinate.latitude
                    finalLongitude = gpsLocation.coordinate.longitude
                    logger.info("Using GPS coordinates")
                }
            }

            let request = CreateStoneRequest(
                name: stoneName.isEmpty ? nil : stoneName,
                weight: weight.isEmpty ? nil : Double(weight),
                estimatedWeight: estimatedWeight.isEmpty ? nil : Double(estimatedWeight),
                stoneType: stoneType.rawValue,
                description: description.isEmpty ? nil : description,
                imageUrl: nil, // Will be set by ViewModel after upload
                latitude: finalLatitude,
                longitude: finalLongitude,
                locationName: locationName.isEmpty ? nil : locationName,
                isPublic: isPublic,
                liftingLevel: liftingLevel.rawValue
            )

            if networkMonitor.isConnected {
                let stone = await viewModel.saveStone(request: request, photoData: photoData)

                if stone != nil {
                    dismiss()
                }
            } else {
                // Offline - save locally for later sync
                logger.info("No network connection - saving stone offline")
                let success = await offlineSyncService.saveStoneOffline(request: request, photoData: photoData)

                if success {
                    logger.info("Stone saved offline successfully")
                    dismiss()
                } else {
                    logger.error("Failed to save stone offline")
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Form field focus enumeration
enum StoneFormField {
    case name
    case weight
    case estimatedWeight
    case description
    case locationName
}

// MARK: - Preview

#Preview {
    AddStoneView()
}
