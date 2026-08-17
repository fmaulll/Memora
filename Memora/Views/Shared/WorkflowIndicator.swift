import SwiftUI

/// Step progress indicator used across the New Study Deck creation flow.
struct WorkflowIndicator: View {
    let numberOfSteps: Int
    let currentStep: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<max(numberOfSteps, 1), id: \.self) { step in
                Capsule()
                    .fill(step == currentStep ? accent : .white.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of \(max(numberOfSteps, 1))")
    }
}
