//
//  StoneDetailView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/30/25.
//

import MapKit
import SwiftUI

// MARK: - Stone Detail View

/// Displays complete stone information with edit and delete options
/// Shows stone photo, stats, location, and user details
struct StoneDetailView: View {
    // MARK: - Properties

    @State var stone: Stone

    private let stoneService = StoneService.shared
    private let authService = AuthService.shared
    private let geocodingService = ReverseGeocodingService.shared
    private let logger = AppLogger()

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var showingReportConfirmation = false
    @State private var isReporting = false
    @State private var reportSuccessMessage: String?
    @State private var reportErrorMessage: String?
    @State private var selectedReportReason: String = ""
    @State private var reportRefreshTrigger = false
    @State private var locationName: String?

    private var isOwnStone: Bool {
        stone.user.id == authService.currentUser?.id
    }

    private var hasReported: Bool {
        guard let stoneId = stone.id else { return false }
        _ = reportRefreshTrigger
        return stoneService.hasReportedStone(id: stoneId)
    }

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    stoneImageSection
                    stoneInfoSection
                    stoneStatsSection

                    if stone.hasValidLocation {
                        locationSection
                    }

                    ownerSection

                    if !isOwnStone {
                        reportSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle(stone.name ?? "Stone Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isOwnStone {
                        Menu {
                            Button("Edit Stone") {
                                showingEdit = true
                            }

                            Button("Delete Stone", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                EditStoneView(stone: $stone)
            }
            .confirmationDialog(
                "Delete Stone",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteStone()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(stone.name ?? "this stone")\"? This action cannot be undone.")
            }
            .alert("Report Submitted", isPresented: .constant(reportSuccessMessage != nil)) {
                Button("OK") {
                    reportSuccessMessage = nil
                    dismiss()
                }
            } message: {
                Text(reportSuccessMessage ?? "")
            }
            .alert("Report Failed", isPresented: .constant(reportErrorMessage != nil)) {
                Button("OK") {
                    reportErrorMessage = nil
                }
            } message: {
                Text(reportErrorMessage ?? "")
            }
            .task {
                if let lat = stone.latitude, let lon = stone.longitude {
                    locationName = await geocodingService.locationName(for: lat, longitude: lon)
                }
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var stoneImageSection: some View {
        if let imageUrl = stone.imageUrl, !imageUrl.isEmpty {
            RemoteImage(url: URL(string: imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()
                    .cornerRadius(16)
            } placeholder: {
                stoneImagePlaceholder
                    .frame(height: 300)
            }
        } else {
            stoneImagePlaceholder
                .frame(height: 300)
        }
    }

    @ViewBuilder
    private var stoneImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray5))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No Photo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
    }

    @ViewBuilder
    private var stoneInfoSection: some View {
        VStack(spacing: 16) {
            // Name and visibility
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stone.name ?? "Unnamed Stone")
                        .font(.title)
                        .fontWeight(.bold)

                    HStack {
                        Image(systemName: stone.isPublic ? "globe" : "lock.fill")
                            .foregroundColor(stone.isPublic ? .green : .orange)

                        Text(stone.isPublic ? "Public Stone" : "Private Stone")
                            .font(.subheadline)
                            .foregroundColor(stone.isPublic ? .green : .orange)
                    }
                }

                Spacer()

                // Lifting completion
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: stone.liftingLevel.icon)
                            .foregroundColor(stone.liftingLevel.displayColor)
                            .font(.title2)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(stone.liftingLevel.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }

                    HStack(spacing: 2) {
                        ForEach(1 ... 4, id: \.self) { level in
                            Circle()
                                .fill(level <= stone.liftingLevel.level ? stone.liftingLevel.displayColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }

            // Notes
            if let description = stone.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)

                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var stoneStatsSection: some View {
        VStack(spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                // Show confirmed weight if available
                if let weight = stone.weight {
                    StatCard(
                        title: "Confirmed",
                        value: String(format: "%.1f lbs", weight),
                        icon: "checkmark.seal.fill",
                        color: .green
                    )
                }

                // Show estimated weight if available
                if let estimatedWeight = stone.estimatedWeight {
                    StatCard(
                        title: "Estimated",
                        value: String(format: "%.1f lbs", estimatedWeight),
                        icon: "questionmark.circle.fill",
                        color: .orange
                    )
                }

                if let createdAt = stone.createdAt {
                    StatCard(
                        title: "Logged",
                        value: createdAt.formatted(.dateTime.month().day()),
                        icon: "calendar",
                        color: .blue
                    )
                }
            }

            // Weight estimation accuracy
            if let weight = stone.weight, let estimatedWeight = stone.estimatedWeight {
                let difference = abs(weight - estimatedWeight)
                let percentage = (difference / weight) * 100

                HStack {
                    Image(systemName: percentage < 10 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(percentage < 10 ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estimation Accuracy")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Off by \(difference, specifier: "%.1f") lbs (\(percentage, specifier: "%.1f")%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            let achievementTier = stone.achievementTier
            if achievementTier != .none {
                HStack {
                    Image(systemName: achievementTier.icon)
                        .font(.title2)
                        .foregroundColor(colorForAchievement(achievementTier))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievement Unlocked")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(colorForAchievement(achievementTier))

                        Text(achievementTier.displayName)
                            .font(.headline)
                            .fontWeight(.bold)

                        Text("Lifted \(stone.formattedWeight) to chest level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(colorForAchievement(achievementTier).opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var locationSection: some View {
        VStack(spacing: 16) {
            Text("Location")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let latitude = stone.latitude, let longitude = stone.longitude {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker("Stone Location", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                        .tint(.blue)
                }
                .frame(height: 200)
                .cornerRadius(12)

                // Location details
                VStack(spacing: 8) {
                    if let locationName = locationName {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.blue)

                            Text(locationName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()
                        }
                    }

                    // Coordinates
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)

                        Text("\(latitude, specifier: "%.4f"), \(longitude, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Open in Maps") {
                            openInMaps(latitude: latitude, longitude: longitude)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var reportSection: some View {
        VStack(spacing: 12) {
            if hasReported {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Report Submitted")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Thank you for helping keep a tidy community!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                Button(action: {
                    showingReportConfirmation = true
                }) {
                    HStack(spacing: 12) {
                        if isReporting {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                                .font(.title3)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(isReporting ? "Reporting..." : "Report Stone")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text("Help us maintain community standards")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !isReporting {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isReporting)
                .confirmationDialog(
                    "Report Stone",
                    isPresented: $showingReportConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Inappropriate Content") {
                        selectedReportReason = "inappropriate content"
                        reportStone()
                    }

                    Button("Inaccurate Information") {
                        selectedReportReason = "inaccurate information"
                        reportStone()
                    }

                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Why are you reporting this stone?")
                }
            }
        }
    }

    @ViewBuilder
    private var ownerSection: some View {
        VStack(spacing: 12) {
            Text("Stone Logger")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                UserAvatarView(username: stone.user.username)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stone.user.username)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let createdAt = stone.createdAt {
                        Text("Logged \(createdAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isOwnStone {
                    Text("You")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Helper Methods

    private func colorForAchievement(_ tier: AchievementTier) -> Color {
        switch tier.color {
        case "bronze": return .orange
        case "silver": return .gray
        case "gold": return .yellow
        case "purple": return .purple
        default: return .gray
        }
    }

    private func openInMaps(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = stone.name ?? "Stone Location"
        mapItem.openInMaps()
    }

    private func deleteStone() {
        guard let stoneId = stone.id else { return }

        logger.info("Deleting stone: \(stone.name ?? "unnamed")")

        Task {
            let success = await stoneService.deleteStone(id: stoneId)

            await MainActor.run {
                if success {
                    logger.info("Stone deleted successfully")
                    dismiss()
                } else {
                    logger.error("Failed to delete stone")
                }
            }
        }
    }

    private func reportStone() {
        guard let stoneId = stone.id else { return }

        logger.info("Reporting stone: \(stone.name ?? "unnamed") for reason: \(selectedReportReason)")
        isReporting = true

        Task {
            let success = await stoneService.reportStone(id: stoneId)

            await MainActor.run {
                isReporting = false

                if success {
                    logger.info("Stone reported successfully")

                    // Trigger view refresh to update hasReported state
                    reportRefreshTrigger.toggle()

                    reportSuccessMessage = "Thank you for reporting this stone. We'll review it shortly and take appropriate action if needed."
                } else {
                    logger.error("Failed to report stone")
                    reportErrorMessage = stoneService.stoneError?.localizedDescription ?? "We couldn't submit your report. Please check your connection and try again."
                }
            }
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    StoneDetailView(stone: Stone(
        id: UUID(),
        name: "Big Boulder",
        weight: 150.5,
        estimatedWeight: 145.0,
        description: "Found this massive boulder by the river. Took everything I had to lift it!",
        imageUrl: nil,
        latitude: 40.7128,
        longitude: -74.0060,
        isPublic: true,
        liftingLevel: .chest,
        createdAt: Date(),
        user: User(
            id: UUID(),
            username: "stonelifter",
            email: "stone@example.com",
            createdAt: Date()
        )
    ))
}
