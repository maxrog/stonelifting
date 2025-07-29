//
//  StoneDetailsFormView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/27/25.
//

import SwiftUI

// MARK: - Stone Details View

/// Details input for stone creation
struct StoneDetailsFormView: View {

    @Binding var stoneName: String
    @Binding var description: String
    @Binding var difficultyRating: Int
    @FocusState.Binding var focusedField: StoneFormField?

    var body: some View {
        VStack(spacing: 24) {
            nameSection
            detailsSection
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var nameSection: some View {
        VStack(spacing: 16) {
            Text("Stone Name")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("e.g., Big Boulder, River Rock, Atlas Stone", text: $stoneName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        focusedField = .weight
                    }

                Text("Give your stone a memorable name")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(spacing: 16) {
            Text("Details")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Description (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Tell us about this stone...", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .description)
                    .lineLimit(3...6)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Difficulty Rating")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    ForEach(1...5, id: \.self) { rating in
                        Button(action: {
                            difficultyRating = rating
                        }) {
                            Image(systemName: rating <= difficultyRating ? "star.fill" : "star")
                                .foregroundColor(rating <= difficultyRating ? .yellow : .gray)
                                .font(.title2)
                        }
                    }

                    Spacer()

                    Text(difficultyDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Computed Properties

    // TODO I think this is reused other places
    private var difficultyDescription: String {
        switch difficultyRating {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return ""
        }
    }
}
