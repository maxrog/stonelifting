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
    @Binding var carryDistance: String
    @FocusState.Binding var focusedField: StoneFormField?

    // TODO this could be better DRY
    private func colorForLevel(_ level: LiftingLevel) -> Color {
        switch level.color {
        case "orange": return .orange
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        default: return .gray
        }
    }

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
                    Text("Lifting Level")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(spacing: 8) {
                        ForEach(LiftingLevel.allCases, id: \.self) { level in
                            Button(action: {
                                liftingLevel = level
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: liftingLevel == level ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(liftingLevel == level ? .blue : .gray)
                                        .font(.title3)

                                    Image(systemName: level.icon)
                                        .foregroundColor(colorForLevel(level))
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(level.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        Text(level.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(liftingLevel == level ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Carry Distance (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        TextField("0", text: $carryDistance)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .carryDistance)

                        Text("feet")
                            .foregroundColor(.secondary)
                    }

                    Text("How far did you carry the stone?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
