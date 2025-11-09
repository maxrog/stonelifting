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
    @FocusState.Binding var focusedField: StoneFormField?

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
        }
    }
}
