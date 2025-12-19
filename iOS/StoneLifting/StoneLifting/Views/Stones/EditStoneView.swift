//
//  EditStoneView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/30/25.
//

import PhotosUI
import SwiftUI

// MARK: - Edit Stone View

/// Stone editing view that allows users to modify existing stone records
// swiftlint:disable type_body_length
struct EditStoneView: View {
    // MARK: - Properties

    @Binding var stone: Stone

    @State private var viewModel: StoneFormViewModel

    @Bindable private var locationService = LocationService.shared
    private let logger = AppLogger()

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingPhotoOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingCropView = false
    @State private var imageToCrop: UIImage?
    @State private var hasPhotoChanged = false
    @State private var includeLocation = false
    @State private var manualLatitude: String = ""
    @State private var manualLongitude: String = ""
    @State private var showingMapPicker = false
    @State private var showingManualEntry = false

    @FocusState private var focusedField: StoneFormField?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    init(stone: Binding<Stone>) {
        _stone = stone
        if let stoneId = stone.wrappedValue.id {
            _viewModel = State(initialValue: StoneFormViewModel(stoneId: stoneId))
        } else {
            _viewModel = State(initialValue: StoneFormViewModel())
        }
        // Initialize includeLocation based on whether stone has location
        _includeLocation = State(initialValue: stone.wrappedValue.hasValidLocation)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        StonePhotoFormView(photoData: $photoData, showingPhotoOptions: $showingPhotoOptions)

                        StoneDetailsFormView(
                            stoneName: nameBinding,
                            description: descriptionBinding,
                            liftingLevel: $stone.liftingLevel,
                            focusedField: $focusedField
                        )

                        StoneWeightFormView(
                            weight: weightBinding,
                            estimatedWeight: estimatedWeightBinding,
                            stoneType: stoneTypeBinding,
                            photoData: $photoData,
                            focusedField: $focusedField
                        )

                        locationSection
                        visibilitySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .navigationTitle("Edit Stone")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            logger.info("User cancelled stone editing")
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            updateStone()
                        }
                        .disabled(!isFormValid || viewModel.isLoading)
                    }
                }
                .onAppear {
                    setupView()
                }

                if viewModel.isLoading {
                    LoadingView(message: "Updating stone...")
                }
            }
        }
        .confirmationDialog("Change Photo", isPresented: $showingPhotoOptions) {
            Button("Camera") {
                showingCamera = true
            }
            Button("Photo Library") {
                showingPhotoPicker = true
            }
            if stone.imageUrl != nil || photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoData = nil
                    hasPhotoChanged = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showingCamera) {
            CameraPickerView { imageData in
                self.photoData = imageData
                self.hasPhotoChanged = true
                self.showingCamera = false
            }
        }
        .sheet(isPresented: $showingCropView) {
            if let imageToCrop = imageToCrop {
                ImageCropView(image: imageToCrop) { croppedData in
                    self.photoData = croppedData
                    self.hasPhotoChanged = true
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
                    updateStone()
                }
                Button("Continue Without Photo") {
                    photoData = nil
                    hasPhotoChanged = true
                    viewModel.clearError()
                    updateStone()
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
            Text("Location access is required to update stone GPS coordinates. Please enable location services in Settings.")
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualCoordinateEntryView(latitude: $manualLatitude, longitude: $manualLongitude)
                .onDisappear {
                    // Update stone with manual coordinates when sheet closes
                    if !manualLatitude.isEmpty && !manualLongitude.isEmpty,
                       let lat = Double(manualLatitude), let lon = Double(manualLongitude) {
                        stone.latitude = lat
                        stone.longitude = lon
                    }
                }
        }
        .sheet(isPresented: $showingMapPicker) {
            MapLocationPickerView(latitude: $manualLatitude, longitude: $manualLongitude)
                .onDisappear {
                    // Update stone with manual coordinates when sheet closes
                    if !manualLatitude.isEmpty && !manualLongitude.isEmpty,
                       let lat = Double(manualLatitude), let lon = Double(manualLongitude) {
                        stone.latitude = lat
                        stone.longitude = lon
                    }
                }
        }
    }

    // MARK: - View Components

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
                            stone.latitude = nil
                            stone.longitude = nil
                            stone.locationName = nil
                        } else if newValue && !stone.hasValidLocation {
                            // User toggled ON but no location
                            // Only auto-fetch if they have permissions, otherwise show button
                            if [.authorizedWhenInUse, .authorizedAlways].contains(locationService.authorizationStatus) {
                                requestLocation(userInitiated: false)
                            }
                        }
                    }
            }

            if includeLocation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location Name (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("e.g., Central Park, Rocky Trail", text: Binding(
                        get: { stone.locationName ?? "" },
                        set: { stone.locationName = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .locationName)
                }

                if let latitude = stone.latitude, let longitude = stone.longitude {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)

                            Text("Current: \(latitude, specifier: "%.4f"), \(longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()
                        }

                        // Update location options
                        Menu {
                            Button(action: {
                                requestLocation(userInitiated: true)
                            }) {
                                Label("Use Current GPS", systemImage: "location.fill")
                            }

                            Button(action: {
                                // Pre-fill with current coordinates
                                manualLatitude = String(format: "%.6f", latitude)
                                manualLongitude = String(format: "%.6f", longitude)
                                showingMapPicker = true
                            }) {
                                Label("Pick on Map", systemImage: "map")
                            }

                            Button(action: {
                                // Pre-fill with current coordinates
                                manualLatitude = String(format: "%.6f", latitude)
                                manualLongitude = String(format: "%.6f", longitude)
                                showingManualEntry = true
                            }) {
                                Label("Enter Coordinates", systemImage: "number")
                            }
                        } label: {
                            Text("Update Location")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    // No current location - offer three options
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
                    stone.isPublic = true
                }) {
                    HStack {
                        Image(systemName: stone.isPublic ? "checkmark.circle.fill" : "circle")
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
                    .background(stone.isPublic ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    stone.isPublic = false
                }) {
                    HStack {
                        Image(systemName: !stone.isPublic ? "checkmark.circle.fill" : "circle")
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
                    .background(!stone.isPublic ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Binding Helpers

    /*
     Forms intake string bindings
     */

    private var nameBinding: Binding<String> {
        Binding(
            get: { stone.name ?? "" },
            set: { stone.name = $0.isEmpty ? nil : $0 }
        )
    }

    private var descriptionBinding: Binding<String> {
        Binding(
            get: { stone.description ?? "" },
            set: { stone.description = $0.isEmpty ? nil : $0 }
        )
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { stone.weight != nil ? String(format: "%.1f", stone.weight!) : "" },
            set: { stone.weight = $0.isEmpty ? nil : Double($0) }
        )
    }

    private var estimatedWeightBinding: Binding<String> {
        Binding(
            get: { stone.estimatedWeight != nil ? String(format: "%.1f", stone.estimatedWeight!) : "" },
            set: { stone.estimatedWeight = $0.isEmpty ? nil : Double($0) }
        )
    }

    private var stoneTypeBinding: Binding<StoneType> {
        Binding(
            get: {
                if let typeString = stone.stoneType,
                   let type = StoneType(rawValue: typeString) {
                    return type
                }
                return .granite // Default
            },
            set: { stone.stoneType = $0.rawValue }
        )
    }

    private var locationNameBinding: Binding<String> {
        Binding(
            get: { stone.locationName ?? "" },
            set: { stone.locationName = $0.isEmpty ? nil : $0 }
        )
    }

    private var includeLocationBinding: Binding<Bool> {
        Binding(
            get: { stone.hasValidLocation },
            set: { includeLocation in
                if !includeLocation {
                    stone.latitude = nil
                    stone.longitude = nil
                    stone.locationName = nil
                }
            }
        )
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        // Require stone name
        guard !(stone.name?.isEmpty ?? true) else { return false }

        // Require at least one weight (confirmed or estimated)
        let hasConfirmedWeight = stone.weight ?? 0 > 0
        let hasEstimatedWeight = stone.estimatedWeight ?? 0 > 0

        guard hasConfirmedWeight || hasEstimatedWeight else { return false }

        // Validate weight ranges (1-1000 lbs to match backend validation)
        if let weight = stone.weight {
            guard weight >= 1 && weight <= 1000 else { return false }
        }

        if let estimatedWeight = stone.estimatedWeight {
            guard estimatedWeight >= 1 && estimatedWeight <= 1000 else { return false }
        }

        return true
    }

    private var hasChanges: Bool {
        // Since we're working directly with bindings, we could track this differently
        // For now, assume there are always potential changes if the form is valid
        hasPhotoChanged
    }

    // MARK: - Actions

    private func setupView() {
        logger.info("Setting up EditStoneView for stone: \(stone.name ?? "unnamed")")

        if let imageUrl = stone.imageUrl, !imageUrl.isEmpty {
            loadImageFromURL(imageUrl)
        }

        // Handle location permissions
        switch locationService.authorizationStatus {
        case .notDetermined:
            // Request permission for first time (system dialog)
            locationService.requestLocationPermission()
        case .denied, .restricted:
            // Don't show alert - user can tap "Get Location" button if desired
            logger.info("Location permissions denied - user can enable via buttons if desired")
        case .authorizedWhenInUse, .authorizedAlways:
            // If location is enabled and stone has no location, auto-fetch silently
            if includeLocation && !stone.hasValidLocation {
                requestLocation(userInitiated: false)
            }
        @unknown default:
            break
        }
    }

    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    self.photoData = data
                }
            } catch {
                logger.error("Failed to load image from URL", error: error)
            }
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        logger.info("Loading selected photo for edit")

        item.loadTransferable(type: Data.self) { result in
            switch result {
            case let .success(data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.imageToCrop = image
                        self.showingCropView = true
                        self.logger.info("Photo loaded successfully for edit, showing crop view")
                    }
                }
            case let .failure(error):
                logger.error("Failed to load photo for edit", error: error)
            }
        }
    }

    private func requestLocation(userInitiated: Bool = true) {
        logger.info("Requesting location update for stone edit (user initiated: \(userInitiated))")

        Task {
            let location = await locationService.getCurrentLocation(showAlertOnFailure: userInitiated)
            if let location = location {
                await MainActor.run {
                    stone.latitude = location.coordinate.latitude
                    stone.longitude = location.coordinate.longitude
                    logger.info("Location updated for stone edit")
                }
            }
        }
    }

    private func updateStone() {
        guard stone.id != nil else {
            viewModel.stoneError = .unknownError("Unable to update stone - missing ID")
            return
        }

        logger.info("Updating stone: \(stone.name ?? "unnamed")")

        // Dismiss keyboard
        focusedField = nil

        Task {
            let request = CreateStoneRequest(
                name: stone.name,
                weight: stone.weight,
                estimatedWeight: stone.estimatedWeight,
                stoneType: stone.stoneType,
                description: stone.description,
                imageUrl: stone.imageUrl,
                latitude: stone.latitude,
                longitude: stone.longitude,
                locationName: stone.locationName,
                isPublic: stone.isPublic,
                liftingLevel: stone.liftingLevel.rawValue
            )

            let updatedStone = await viewModel.saveStone(
                request: request,
                photoData: photoData,
                hasPhotoChanged: hasPhotoChanged
            )

            if let updatedStone = updatedStone {
                stone = updatedStone
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditStoneView(stone: .constant(Stone(
        id: UUID(),
        name: "Test Boulder",
        weight: 125.5,
        estimatedWeight: 120.0,
        description: "A challenging boulder from the local park",
        imageUrl: nil,
        latitude: 40.7128,
        longitude: -74.0060,
        locationName: "Central Park",
        isPublic: true,
        liftingLevel: .chest,
        createdAt: Date(),
        user: User(
            id: UUID(),
            username: "testuser",
            email: "test@example.com",
            createdAt: Date()
        )
    )))
}
