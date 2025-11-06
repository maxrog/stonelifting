//
//  AddStoneView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/25/25.
//

import SwiftUI
import PhotosUI

// TOOD: offline saving

// MARK: - Add Stone View

/// Stone creation view with camera, weight input, and location capture
/// Allows users to log new stone lifting records
struct AddStoneView: View {

    // MARK: - Properties

    private let stoneService = StoneService.shared
    private let locationService = LocationService.shared
    private let logger = AppLogger()

    @State private var stoneName: String = ""
    @State private var weight: String = ""
    @State private var estimatedWeight: String = ""
    @State private var description: String = ""
    @State private var locationName: String = ""
    @State private var isPublic = true
    @State private var liftingLevel: LiftingLevel = .wind
    @State private var carryDistance: String = ""
    @State private var includeLocation = true

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingPhotoOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    @FocusState private var focusedField: StoneFormField?

    /// Dismissal action
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    StonePhotoFormView(
                        photoData: $photoData,
                        showingPhotoOptions: $showingPhotoOptions
                    )

                    StoneDetailsFormView(
                        stoneName: $stoneName,
                        description: $description,
                        liftingLevel: $liftingLevel,
                        carryDistance: $carryDistance,
                        focusedField: $focusedField
                    )

                    StoneWeightFormView(
                        weight: $weight,
                        estimatedWeight: $estimatedWeight,
                        focusedField: $focusedField
                    )
                    locationSection
                    visibilitySection
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
                    .disabled(!isFormValid || stoneService.isCreatingStone)
                }
            }
            .onAppear {
                setupView()
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions) {
            Button("Camera") {
                showingCamera = true
            }
            Button("Photo Library") {
                showingPhotoPicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showingCamera) {
            CameraPickerView { imageData in
                self.photoData = imageData
                self.showingCamera = false
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            loadSelectedPhoto(newValue)
        }
        .alert("Stone Creation Error", isPresented: .constant(stoneService.stoneError != nil)) {
            Button("OK") {
                stoneService.clearError()
            }
        } message: {
            Text(stoneService.stoneError?.localizedDescription ?? "")
        }
        .alert("Image Upload Failed", isPresented: $showingError) {
            Button("Retry") {
                showingError = false
                saveStone()
            }
            Button("Continue Without Photo") {
                showingError = false
                // Clear photo data and retry
                photoData = nil
                saveStone()
            }
            Button("Cancel", role: .cancel) {
                showingError = false
                isLoading = false
            }
        } message: {
            Text(errorMessage)
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

                if let location = locationService.currentLocation {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)

                        Text("GPS coordinates captured")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Update") {
                            requestLocation()
                        }
                        .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.orange)

                        Text("Tap to capture current location")
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

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !weight.isEmpty &&
        !stoneName.isEmpty &&
        Double(weight) != nil &&
        Double(weight)! > 0
    }

    // MARK: - Actions

    private func setupView() {
        logger.info("Setting up AddStoneView")

        // Request location permission if needed
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestLocationPermission()
        }

        // Get current location if authorized
        if locationService.authorizationStatus == .authorizedWhenInUse ||
            locationService.authorizationStatus == .authorizedAlways {
            requestLocation()
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

        // TODO better way
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
            case .success(let data):
                if let data = data {
                    DispatchQueue.main.async {
                        self.photoData = data
                        self.logger.info("Photo loaded successfully")
                    }
                }
            case .failure(let error):
                logger.error("Failed to load photo", error: error)
            }
        }
    }

    /// Request current location
    private func requestLocation() {
        logger.info("Requesting current location")

        Task {
            _ = await locationService.getCurrentLocation()
        }
    }

    private func saveStone() {
        logger.info("Saving stone with weight: \(weight)")

        focusedField = nil

        Task {
            var imageURL: String?

            if let photoData = photoData {
                logger.info("Uploading image for new stone")
                imageURL = await ImageUploadService.shared.uploadImage(photoData)

                if imageURL == nil {
                    await MainActor.run {
                        logger.error("Failed to upload image")
                        errorMessage = "Failed to upload image. Please try again or continue without a photo."
                        showingError = true
                        isLoading = false
                    }
                    return
                }
            }

            let request = CreateStoneRequest(
                name: stoneName.isEmpty ? nil : stoneName,
                weight: Double(weight) ?? 0,
                estimatedWeight: Double(estimatedWeight),
                description: description.isEmpty ? nil : description,
                imageUrl: imageURL,
                latitude: includeLocation ? locationService.currentLocation?.coordinate.latitude : nil,
                longitude: includeLocation ? locationService.currentLocation?.coordinate.longitude : nil,
                locationName: locationName.isEmpty ? nil : locationName,
                isPublic: isPublic,
                liftingLevel: liftingLevel.rawValue,
                carryDistance: carryDistance.isEmpty ? nil : Double(carryDistance)
            )

            let stone = await stoneService.createStone(request)

            await MainActor.run {
                if stone != nil {
                    logger.info("Stone created successfully")
                    dismiss()
                } else {
                    logger.error("Failed to create stone")
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
    case carryDistance
}

// MARK: - Preview

#Preview {
    AddStoneView()
}
