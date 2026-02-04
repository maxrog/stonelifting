//
//  ManualCoordinateEntryView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 12/16/25.
//

import SwiftUI

// MARK: - Manual Coordinate Entry View

/// View for manually entering GPS coordinates
struct ManualCoordinateEntryView: View {
    // MARK: - Properties

    @Binding var latitude: String
    @Binding var longitude: String

    @State private var localLatitude: String = ""
    @State private var localLongitude: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    @FocusState private var focusedField: CoordinateField?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latitude")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., 40.7128", text: $localLatitude)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($focusedField, equals: .latitude)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .longitude
                            }

                        Text("Valid range: -90 to 90")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Longitude")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., -74.0060", text: $localLongitude)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($focusedField, equals: .longitude)
                            .submitLabel(.done)
                            .onSubmit {
                                saveCoordinates()
                            }

                        Text("Valid range: -180 to 180")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("GPS Coordinates")
                } footer: {
                    Text("Enter decimal degrees (e.g., 40.7128, -74.0060). Use negative values for South latitude and West longitude.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Finding Coordinates")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text("You can find coordinates by:")
                            .font(.caption)
                        Text("• Opening Maps and long-pressing a location")
                            .font(.caption)
                        Text("• Using Google Maps and tapping a location")
                            .font(.caption)
                        Text("• Searching online for \"[location name] coordinates\"")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Enter Coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveCoordinates()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                localLatitude = latitude
                localLongitude = longitude
                focusedField = .latitude
            }
            .alert("Invalid Coordinates", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        guard let lat = Double(localLatitude),
              let lon = Double(localLongitude) else {
            return false
        }

        return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }

    // MARK: - Actions

    private func saveCoordinates() {
        guard let lat = Double(localLatitude),
              let lon = Double(localLongitude) else {
            errorMessage = "Please enter valid numbers for both latitude and longitude."
            showingError = true
            return
        }

        guard lat >= -90 && lat <= 90 else {
            errorMessage = "Latitude must be between -90 and 90 degrees."
            showingError = true
            return
        }

        guard lon >= -180 && lon <= 180 else {
            errorMessage = "Longitude must be between -180 and 180 degrees."
            showingError = true
            return
        }

        // Update bindings
        latitude = localLatitude
        longitude = localLongitude

        dismiss()
    }
}

// MARK: - Supporting Types

enum CoordinateField {
    case latitude
    case longitude
}

// MARK: - Preview

#Preview {
    ManualCoordinateEntryView(
        latitude: .constant("40.7128"),
        longitude: .constant("-74.0060")
    )
}
