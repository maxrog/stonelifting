//
//  OnboardingView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/10/25.
//

import SwiftUI

struct OnboardingView: View {
    
    @State private var currentStep: OnboardingStep = .username

    let onComplete: () -> Void

    var body: some View {
        Group {
            switch currentStep {
            case .username:
                UsernamePickerView {
                    completeOnboarding()
                }
            }
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        onComplete()
    }
}

enum OnboardingStep {
    case username
    // Future steps can be added here:
    // case permissions
    // case tutorial
    // case preferences
}

#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
