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
    @Binding var liftingLevel: LiftingLevel
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
        VStack(alignment: .leading, spacing: 6) {
            TextField("Stone name (e.g., Big Boulder, River Rock)", text: $stoneName)
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

    @ViewBuilder
    private var detailsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Description (optional)", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .description)
                    .lineLimit(3 ... 6)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Lifting Level")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Menu {
                    ForEach(LiftingLevel.allCases, id: \.self) { level in
                        Button(action: {
                            liftingLevel = level
                        }) {
                            HStack {
                                Image(systemName: level.icon)
                                Text(level.displayName)
                                if liftingLevel == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: liftingLevel.icon)
                            .foregroundColor(liftingLevel.displayColor)
                        Text(liftingLevel.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                Text(liftingLevel.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
