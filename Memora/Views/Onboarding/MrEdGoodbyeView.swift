import SwiftUI

struct MrEdGoodbyeView: View {
    let onContinue: () -> Void

    var body: some View {
        MrEdOutcomeView(isSubscribed: false, onContinue: onContinue)
    }
}

#Preview {
    MrEdGoodbyeView { }
}
