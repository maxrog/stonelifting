//
//  StoneDetailView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/30/25.
//

import SwiftUI
import MapKit

// MARK: - Stone Detail View

/// Displays complete stone information with edit and delete options
/// Shows stone photo, stats, location, and user details
struct StoneDetailView: View {

    // MARK: - Properties

    let stone: Stone

    private let stoneService = StoneService.shared
    private let authService = AuthService.shared
    private let logger = AppLogger()

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false

    private var isOwnStone: Bool {
        stone.user.id == authService.currentUser?.id
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

                    if stone.hasLocation {
                        locationSection
                    }

                    ownerSection
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

                if isOwnStone {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
                EditStoneView(stone: stone)
            }
            .confirmationDialog(
                "Delete Stone",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteStone()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete \"\(stone.name ?? "this stone")\"? This action cannot be undone.")
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var stoneImageSection: some View {
        if let imageUrl = stone.imageUrl, !imageUrl.isEmpty {
            AsyncImage(url: URL(string: imageUrl)) { image in
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

                // Difficulty rating
                if let difficulty = stone.difficultyRating {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= difficulty ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.title3)
                            }
                        }

                        Text(difficultyDescription(difficulty))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Description
            if let description = stone.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
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
                StatCard(
                    title: "Weight",
                    value: stone.formattedWeight,
                    icon: "scalemass.fill",
                    color: .blue
                )

                if let estimatedWeight = stone.estimatedWeight {
                    StatCard(
                        title: "Estimated",
                        value: String(format: "%.1f lbs", estimatedWeight),
                        icon: "brain.head.profile",
                        color: .purple
                    )
                }

                if let createdAt = stone.createdAt {
                    StatCard(
                        title: "Logged",
                        value: createdAt.formatted(.dateTime.month().day()),
                        icon: "calendar",
                        color: .green
                    )
                }
            }

            // Weight estimation accuracy
            if let estimatedWeight = stone.estimatedWeight {
                let difference = abs(stone.weight - estimatedWeight)
                let percentage = (difference / stone.weight) * 100

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
                    if let locationName = stone.locationName {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.blue)

                            Text(locationName)
                                .font(.subheadline)

                            Spacer()
                        }
                    }

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
    private var ownerSection: some View {
        VStack(spacing: 12) {
            Text("Stone Logger")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // TODO User avatar placeholder
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(stone.user.username.prefix(1).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

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

    /// TODO RESUSED
    private func difficultyDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return ""
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

// MARK: - Edit Stone View Placeholder

/// TODO Placeholder for edit stone functionality
struct EditStoneView: View {
    let stone: Stone
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Edit Stone Feature")
                    .font(.title)

                Text("Coming Soon!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Stone: \(stone.name ?? "Unnamed")")
                    .padding()
            }
            .navigationTitle("Edit Stone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
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
        locationName: "Central Park",
        isPublic: true,
        difficultyRating: 4,
        createdAt: Date(),
        user: User(
            id: UUID(),
            username: "stonelifter",
            email: "stone@example.com",
            createdAt: Date()
        )
    ))
}
