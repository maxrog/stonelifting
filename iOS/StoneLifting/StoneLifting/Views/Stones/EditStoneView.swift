//
//  EditStoneView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/30/25.
//

import SwiftUI
import PhotosUI

// MARK: - Edit Stone View

/// Stone editing view that allows users to modify existing stone records
struct EditStoneView: View {

    // MARK: - Properties

    @Binding var stone: Stone

    private let stoneService = StoneService.shared
    private let locationService = LocationService.shared
    private let logger = AppLogger()

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingPhotoOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var hasPhotoChanged = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: StoneFormField?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    init(stone: Binding<Stone>) {
        self._stone = stone
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    StonePhotoFormView(photoData: $photoData, showingPhotoOptions: $showingPhotoOptions)

                    StoneDetailsFormView(
                        stoneName: nameBinding,
                        description: descriptionBinding,
                        liftingLevel: $stone.liftingLevel,
                        carryDistance: carryDistanceBinding,
                        focusedField: $focusedField
                    )

                    StoneWeightFormView(
                        weight: weightBinding,
                        estimatedWeight: estimatedWeightBinding,
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
                    .disabled(!isFormValid || isLoading)
                }
            }
            .onAppear {
                setupView()
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
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showingCamera) {
            CameraPickerView { imageData in
                self.photoData = imageData
                self.hasPhotoChanged = true
                self.showingCamera = false
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            loadSelectedPhoto(newValue)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
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

                Toggle("Include Location", isOn: Binding(
                    get: { stone.hasLocation },
                    set: { includeLocation in
                        if !includeLocation {
                            stone.latitude = nil
                            stone.longitude = nil
                            stone.locationName = nil
                        }
                    }
                ))
                .labelsHidden()
            }

            if stone.hasLocation || stone.latitude != nil || stone.longitude != nil {
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
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)

                        Text("Current: \(latitude, specifier: "%.4f"), \(longitude, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Update Location") {
                            requestLocation()
                        }
                        .font(.caption)
                    }
                } else {
                    // No current location - offer to add one
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.orange)

                        Text("Tap to add current location")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Get Location") {
                            requestLocation()
                        }
                        .font(.caption)
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
            get: { String(format: "%.1f", stone.weight) },
            set: { if let weight = Double($0) { stone.weight = weight } }
        )
    }

    private var estimatedWeightBinding: Binding<String> {
        Binding(
            get: { stone.estimatedWeight != nil ? String(format: "%.1f", stone.estimatedWeight!) : "" },
            set: { stone.estimatedWeight = $0.isEmpty ? nil : Double($0) }
        )
    }

    private var carryDistanceBinding: Binding<String> {
        Binding(
            get: { stone.carryDistance != nil ? String(format: "%.1f", stone.carryDistance!) : "" },
            set: { stone.carryDistance = $0.isEmpty ? nil : Double($0) }
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
            get: { stone.hasLocation },
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
        stone.weight > 0 && !(stone.name?.isEmpty ?? true)
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

        // Request location permission if needed for location updates
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
            case .success(let data):
                if let data = data {
                    DispatchQueue.main.async {
                        self.photoData = data
                        self.hasPhotoChanged = true
                        self.logger.info("Photo loaded successfully for edit")
                    }
                }
            case .failure(let error):
                logger.error("Failed to load photo for edit", error: error)
            }
        }
    }

    private func requestLocation() {
        logger.info("Requesting location update for stone edit")

        Task {
            let location = await locationService.getCurrentLocation()
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
        guard let stoneId = stone.id else {
            errorMessage = "Unable to update stone - missing ID"
            return
        }

        logger.info("Updating stone: \(stone.name ?? "unnamed")")

        // Dismiss keyboard
        focusedField = nil
        isLoading = true

        // Update location if user requested it
        if let currentLocation = locationService.currentLocation {
            stone.latitude = currentLocation.coordinate.latitude
            stone.longitude = currentLocation.coordinate.longitude
        }

        let request = CreateStoneRequest(
            name: stone.name,
            weight: stone.weight,
            estimatedWeight: stone.estimatedWeight,
            description: stone.description,
            imageUrl: stone.imageUrl, // TODO when working Keep existing image URL for now
            latitude: stone.latitude,
            longitude: stone.longitude,
            locationName: stone.locationName,
            isPublic: stone.isPublic,
            liftingLevel: stone.liftingLevel.rawValue,
            carryDistance: stone.carryDistance
        )

        Task {
            let updatedStone = await stoneService.updateStone(id: stoneId, with: request)

            await MainActor.run {
                isLoading = false
                if let updatedStone = updatedStone {
                    logger.info("Stone updated successfully")
                    // Update the binding with the fresh server data
                    stone = updatedStone
                    dismiss()
                } else {
                    logger.error("Failed to update stone")
                    errorMessage = "Failed to update stone. Please try again."
                }
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
        carryDistance: 25,
        createdAt: Date(),
        user: User(
            id: UUID(),
            username: "testuser",
            email: "test@example.com",
            createdAt: Date()
        )
    )))
}
