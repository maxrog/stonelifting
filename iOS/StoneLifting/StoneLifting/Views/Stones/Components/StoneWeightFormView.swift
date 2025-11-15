//
//  StoneWeightFormView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/27/25.
//

import SwiftUI

// MARK: - Weight Input View

/// Weight input component for stone creation
struct StoneWeightFormView: View {
    @Binding var weight: String
    @Binding var estimatedWeight: String
    @Binding var stoneType: StoneType
    @FocusState.Binding var focusedField: StoneFormField?
    @State private var showingWeightEstimation = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Weight")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Actual Weight")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .weight)

                        Text("lbs")
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Estimated Weight")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        TextField("Optional", text: $estimatedWeight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .estimatedWeight)

                        Text("lbs")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Weight difference indicator
            if let actualWeight = Double(weight),
               let estimatedWeight = Double(estimatedWeight),
               actualWeight > 0 && estimatedWeight > 0 {
                let difference = abs(actualWeight - estimatedWeight)
                let percentage = (difference / actualWeight) * 100

                HStack {
                    Image(systemName: percentage < 10 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(percentage < 10 ? .green : .orange)

                    Text("Difference: \(difference, specifier: "%.1f") lbs (\(percentage, specifier: "%.1f")%)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Stone Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Menu {
                    ForEach(StoneType.allCases, id: \.self) { type in
                        Button(action: {
                            stoneType = type
                        }) {
                            HStack {
                                Text(type.displayName)
                                if stoneType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: stoneType.icon)
                            .foregroundColor(.blue)
                        Text(stoneType.displayName)
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

                Text(stoneType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                showingWeightEstimation = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.body.weight(.semibold))
                    Text("Estimate Weight")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
            }
        }
        .sheet(isPresented: $showingWeightEstimation) {
            CameraWeightView(stoneType: stoneType) { estimatedWeightValue in
                estimatedWeight = String(format: "%.1f", estimatedWeightValue)
            }
        }
    }
}
