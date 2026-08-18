//
//  AddStoneView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/25/25.
//

import PhotosUI
import SwiftUI

// MARK: - Add Stone Step

private enum AddStoneStep: Int, CaseIterable {
    case photo
    case details
    case weight
    case location
    case visibility

    var title: String {
        switch self {
        case .photo: "Add a Photo"
        case .details: "Name Your Stone"
        case .weight: "Stone Weight"
        case .location: "Location"
        case .visibility: "Visibility"
        }
    }

    var subtitle: String {
        switch self {
        case .photo: "Help others recognize this stone"
        case .details: "Give your stone an identity"
        case .weight: "How heavy is this stone?"
        case .location: "Where can this stone be found?"
        case .visibility: "Who can discover this stone?"
        }
    }

    var isOptional: Bool {
        switch self {
        case .photo, .location, .visibility: true
        case .details, .weight: false
        }
    }
}

// MARK: - Add Stone View

/// Multi-step stone creation flow
// swiftlint:disable type_body_length
struct AddStoneView: View {

    // MARK: - Properties

    @State private var viewModel = StoneFormViewModel()
    @Bindable private var locationService = LocationService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let offlineSyncService = OfflineSyncService.shared
    private let logger = AppLogger()

    @State private var currentStep: AddStoneStep = .photo
    @State private var isGoingForward = true

    @State private var stoneName = ""
    @State private var weight = ""
    @State private var estimatedWeight = ""
    @State private var stoneType: StoneType = .granite
    @State private var notes = ""
    @State private var isPublic = true
    @State private var liftingLevel: LiftingLevel = .notLifted
    @State private var manualLatitude = ""
    @State private var manualLongitude = ""

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingPhotoOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingCropView = false
    @State private var imageToCrop: UIImage?

    @State private var showingMapPicker = false
    @State private var showingManualEntry = false

    @FocusState private var focusedField: StoneFormField?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    progressBar

                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            stepHeader

                            Group {
                                stepContent
                            }
                            .id(currentStep)
                            .transition(.asymmetric(
                                insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
                                removal: .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
                            ))

                            if currentStep == .visibility && !networkMonitor.isConnected {
                                offlineBanner
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                    }
                    .safeAreaInset(edge: .bottom) {
                        bottomBar
                            .background(Color(.systemBackground))
                    }
                }

                if viewModel.isLoading {
                    LoadingView(message: networkMonitor.isConnected ? "Adding stone..." : "Saving offline...")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { setupLocationIfNeeded() }
        }
        .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions) {
            Button("Camera") { showingCamera = true }
            Button("Photo Library") { showingPhotoPicker = true }
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
            if let imageToCrop {
                ImageCropView(image: imageToCrop) { croppedData in
                    self.photoData = croppedData
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            loadSelectedPhoto(newValue)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualCoordinateEntryView(latitude: $manualLatitude, longitude: $manualLongitude)
        }
        .sheet(isPresented: $showingMapPicker) {
            MapLocationPickerView(latitude: $manualLatitude, longitude: $manualLongitude)
        }
        .alert("Error", isPresented: .constant(viewModel.stoneError != nil)) {
            if let error = viewModel.stoneError, error.isImageUploadError {
                Button("Retry") { viewModel.clearError(); saveStone() }
                Button("Continue Without Photo") { photoData = nil; viewModel.clearError(); saveStone() }
                Button("Cancel", role: .cancel) { viewModel.clearError() }
            } else {
                Button("OK") { viewModel.clearError() }
            }
        } message: {
            Text(viewModel.stoneError?.localizedDescription ?? "")
        }
        .alert("Location Access Needed", isPresented: $locationService.showSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Location access is required to add stones with GPS coordinates. Please enable location services in Settings.")
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(AddStoneStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color(.systemGray4))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Step Header

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if currentStep.isOptional {
                Text("Optional")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            Text(currentStep.title)
                .font(.title2)
                .fontWeight(.bold)
            Text(currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .photo:
            StonePhotoFormView(photoData: $photoData, showingPhotoOptions: $showingPhotoOptions)
        case .details:
            StoneDetailsFormView(
                stoneName: $stoneName,
                notes: $notes,
                liftingLevel: $liftingLevel,
                focusedField: $focusedField
            )
        case .weight:
            StoneWeightFormView(
                weight: $weight,
                estimatedWeight: $estimatedWeight,
                stoneType: $stoneType,
                photoData: $photoData,
                focusedField: $focusedField
            )
        case .location:
            locationStepContent
        case .visibility:
            visibilityStepContent
        }
    }

    // MARK: - Location Step

    @ViewBuilder
    private var locationStepContent: some View {
        VStack(spacing: 16) {
            if let location = locationService.currentLocation {
                locationStatusRow(
                    icon: "location.fill",
                    color: .green,
                    label: "GPS Location",
                    detail: String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
                )
            } else if let lat = Double(manualLatitude), let lon = Double(manualLongitude),
                      !manualLatitude.isEmpty {
                locationStatusRow(
                    icon: "mappin.circle.fill",
                    color: .blue,
                    label: "Manual Location",
                    detail: String(format: "%.4f, %.4f", lat, lon)
                )
            }

            Button(action: {
                manualLatitude = ""
                manualLongitude = ""
                requestLocation(userInitiated: true)
            }) {
                Label("Use Current GPS", systemImage: "location.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Button(action: { showingMapPicker = true }) {
                    Label("Pick on Map", systemImage: "map")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }

                Button(action: { showingManualEntry = true }) {
                    Label("Enter Coords", systemImage: "number")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }

            let hasLocation = locationService.currentLocation != nil || !manualLatitude.isEmpty
            if hasLocation {
                Button(role: .destructive) {
                    manualLatitude = ""
                    manualLongitude = ""
                    locationService.clearCachedLocation()
                } label: {
                    Text("Clear Location")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func locationStatusRow(icon: String, color: Color, label: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Visibility Step

    @ViewBuilder
    private var visibilityStepContent: some View {
        VStack(spacing: 12) {
            visibilityOption(
                title: "Public",
                description: "Others can see and attempt this stone",
                isSelected: isPublic,
                action: { isPublic = true }
            )
            visibilityOption(
                title: "Private",
                description: "Only you can see this stone",
                isSelected: !isPublic,
                action: { isPublic = false }
            )
        }
    }

    private func visibilityOption(title: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            if currentStep.rawValue > 0 {
                Button(action: retreat) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                        Text("Back")
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                }
            }

            Spacer()

            if currentStep == .visibility {
                Button(action: saveStone) {
                    Text(networkMonitor.isConnected ? "Save Stone" : "Save Offline")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isFormValid ? Color.accentColor : Color(.systemGray3))
                        .cornerRadius(10)
                }
                .disabled(!isFormValid || viewModel.isLoading)
            } else {
                Button(action: advance) {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(canAdvance ? .white : Color(.systemGray))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(canAdvance ? Color.accentColor : Color(.systemGray5))
                    .cornerRadius(10)
                }
                .disabled(!canAdvance)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 0.5)
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
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

    // MARK: - Computed Properties

    private var weightStepValid: Bool {
        let hasConfirmedWeight = !weight.isEmpty && (Double(weight) ?? 0) > 0
        let hasEstimatedWeight = !estimatedWeight.isEmpty && (Double(estimatedWeight) ?? 0) > 0
        if !hasConfirmedWeight && !hasEstimatedWeight { return false }
        if let w = Double(weight), !weight.isEmpty, w < 1 || w > 1000 { return false }
        if let ew = Double(estimatedWeight), !estimatedWeight.isEmpty, ew < 1 || ew > 1000 { return false }
        return true
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .photo, .location, .visibility: return true
        case .details: return !stoneName.isEmpty
        case .weight: return weightStepValid
        }
    }

    private var isFormValid: Bool {
        !stoneName.isEmpty && weightStepValid
    }

    // MARK: - Navigation Actions

    private func advance() {
        guard let next = AddStoneStep(rawValue: currentStep.rawValue + 1) else { return }
        focusedField = nil
        isGoingForward = true
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = next
        }
    }

    private func retreat() {
        guard let prev = AddStoneStep(rawValue: currentStep.rawValue - 1) else { return }
        focusedField = nil
        isGoingForward = false
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = prev
        }
    }

    // MARK: - Setup

    private func setupLocationIfNeeded() {
        switch locationService.authorizationStatus {
        case .notDetermined:
            locationService.requestLocationPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            if let existing = locationService.currentLocation {
                if -existing.timestamp.timeIntervalSinceNow > 30 {
                    requestLocation(userInitiated: false)
                }
            } else {
                requestLocation(userInitiated: false)
            }
        default:
            break
        }
    }

    private func requestLocation(userInitiated: Bool = false) {
        Task {
            _ = await locationService.getCurrentLocation(showAlertOnFailure: userInitiated)
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case let .success(data):
                if let data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.imageToCrop = image
                        self.showingCropView = true
                    }
                }
            case let .failure(error):
                logger.error("Failed to load photo", error: error)
            }
        }
    }

    private func saveStone() {
        logger.info("Saving stone: \(stoneName)")
        focusedField = nil

        Task {
            var finalLatitude: Double?
            var finalLongitude: Double?

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

            let request = CreateStoneRequest(
                name: stoneName.isEmpty ? nil : stoneName,
                weight: weight.isEmpty ? nil : Double(weight),
                estimatedWeight: estimatedWeight.isEmpty ? nil : Double(estimatedWeight),
                stoneType: stoneType.rawValue,
                description: notes.isEmpty ? nil : notes,
                imageUrl: nil,
                latitude: finalLatitude,
                longitude: finalLongitude,
                isPublic: isPublic,
                liftingLevel: liftingLevel.rawValue
            )

            if networkMonitor.isConnected {
                if await viewModel.saveStone(request: request, photoData: photoData) != nil {
                    dismiss()
                }
            } else {
                logger.info("No network connection - saving stone offline")
                if await offlineSyncService.saveStoneOffline(request: request, photoData: photoData) {
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
    case notes
}

// MARK: - Preview

#Preview {
    AddStoneView()
}
