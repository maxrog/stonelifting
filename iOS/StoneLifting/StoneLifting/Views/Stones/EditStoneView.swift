//
//  EditStoneView.swift
//  StoneAtlas
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

    /// Local working copy — mutations stay local until Save succeeds
    @State private var editedStone: Stone

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
        _editedStone = State(initialValue: stone.wrappedValue)
        if let stoneId = stone.wrappedValue.id {
            _viewModel = State(initialValue: StoneFormViewModel(stoneId: stoneId))
        } else {
            _viewModel = State(initialValue: StoneFormViewModel())
        }
        _includeLocation = State(initialValue: stone.wrappedValue.hasValidLocation)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        StonePhotoFormView(photoData: $photoData, showingPhotoOptions: $showingPhotoOptions)

                        sectionDivider

                        StoneDetailsFormView(
                            stoneName: nameBinding,
                            notes: notesBinding,
                            liftingLevel: $editedStone.liftingLevel,
                            focusedField: $focusedField
                        )

                        sectionDivider

                        StoneWeightFormView(
                            weight: weightBinding,
                            estimatedWeight: estimatedWeightBinding,
                            stoneType: stoneTypeBinding,
                            photoData: $photoData,
                            focusedField: $focusedField
                        )

                        sectionDivider

                        locationSection

                        sectionDivider

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
            if editedStone.imageUrl != nil || photoData != nil {
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
                    if !manualLatitude.isEmpty && !manualLongitude.isEmpty,
                       let lat = Double(manualLatitude), let lon = Double(manualLongitude) {
                        editedStone.latitude = lat
                        editedStone.longitude = lon
                    }
                }
        }
        .sheet(isPresented: $showingMapPicker) {
            MapLocationPickerView(latitude: $manualLatitude, longitude: $manualLongitude)
                .onDisappear {
                    if !manualLatitude.isEmpty && !manualLongitude.isEmpty,
                       let lat = Double(manualLatitude), let lon = Double(manualLongitude) {
                        editedStone.latitude = lat
                        editedStone.longitude = lon
                    }
                }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var sectionDivider: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
            .padding(.vertical, 8)
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
                            editedStone.latitude = nil
                            editedStone.longitude = nil
                        } else if !editedStone.hasValidLocation {
                            if [.authorizedWhenInUse, .authorizedAlways].contains(locationService.authorizationStatus) {
                                requestLocation(userInitiated: false)
                            }
                        }
                    }
            }

            if includeLocation {
                if let latitude = editedStone.latitude, let longitude = editedStone.longitude {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)

                            Text("Current: \(latitude, specifier: "%.4f"), \(longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()
                        }

                        Menu {
                            Button(action: {
                                requestLocation(userInitiated: true)
                            }) {
                                Label("Use Current GPS", systemImage: "location.fill")
                            }

                            Button(action: {
                                manualLatitude = String(format: "%.6f", latitude)
                                manualLongitude = String(format: "%.6f", longitude)
                                showingMapPicker = true
                            }) {
                                Label("Pick on Map", systemImage: "map")
                            }

                            Button(action: {
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
                    editedStone.isPublic = true
                }) {
                    HStack {
                        Image(systemName: editedStone.isPublic ? "checkmark.circle.fill" : "circle")
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
                    .background(editedStone.isPublic ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    editedStone.isPublic = false
                }) {
                    HStack {
                        Image(systemName: !editedStone.isPublic ? "checkmark.circle.fill" : "circle")
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
                    .background(!editedStone.isPublic ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Binding Helpers

    private var nameBinding: Binding<String> {
        Binding(
            get: { editedStone.name ?? "" },
            set: { editedStone.name = $0.isEmpty ? nil : $0 }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { editedStone.description ?? "" },
            set: { editedStone.description = $0.isEmpty ? nil : $0 }
        )
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { editedStone.weight != nil ? String(format: "%.1f", editedStone.weight!) : "" },
            set: { editedStone.weight = $0.isEmpty ? nil : Double($0) }
        )
    }

    private var estimatedWeightBinding: Binding<String> {
        Binding(
            get: { editedStone.estimatedWeight != nil ? String(format: "%.1f", editedStone.estimatedWeight!) : "" },
            set: { editedStone.estimatedWeight = $0.isEmpty ? nil : Double($0) }
        )
    }

    private var stoneTypeBinding: Binding<StoneType> {
        Binding(
            get: {
                if let typeString = editedStone.stoneType,
                   let type = StoneType(rawValue: typeString) {
                    return type
                }
                return .granite
            },
            set: { editedStone.stoneType = $0.rawValue }
        )
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        guard !(editedStone.name?.isEmpty ?? true) else { return false }

        let hasConfirmedWeight = editedStone.weight ?? 0 > 0
        let hasEstimatedWeight = editedStone.estimatedWeight ?? 0 > 0
        guard hasConfirmedWeight || hasEstimatedWeight else { return false }

        if let weight = editedStone.weight {
            guard weight >= 1 && weight <= 1000 else { return false }
        }

        if let estimatedWeight = editedStone.estimatedWeight {
            guard estimatedWeight >= 1 && estimatedWeight <= 1000 else { return false }
        }

        return true
    }

    // MARK: - Actions

    private func setupView() {
        logger.info("Setting up EditStoneView for stone: \(editedStone.name ?? "unnamed")")

        if let imageUrl = editedStone.imageUrl, !imageUrl.isEmpty {
            loadImageFromURL(imageUrl)
        }

        if locationService.authorizationStatus == .notDetermined {
            locationService.requestLocationPermission()
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
                    editedStone.latitude = location.coordinate.latitude
                    editedStone.longitude = location.coordinate.longitude
                    logger.info("Location updated for stone edit")
                }
            }
        }
    }

    private func updateStone() {
        guard editedStone.id != nil else {
            viewModel.stoneError = .unknownError("Unable to update stone - missing ID")
            return
        }

        logger.info("Updating stone: \(editedStone.name ?? "unnamed")")
        focusedField = nil

        Task {
            let request = CreateStoneRequest(
                name: editedStone.name,
                weight: editedStone.weight,
                estimatedWeight: editedStone.estimatedWeight,
                stoneType: editedStone.stoneType,
                description: editedStone.description,
                imageUrl: editedStone.imageUrl,
                latitude: editedStone.latitude,
                longitude: editedStone.longitude,
                isPublic: editedStone.isPublic,
                liftingLevel: editedStone.liftingLevel.rawValue
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
