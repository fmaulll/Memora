import SwiftUI

struct LibraryView: View {
    var body: some View {
        AppBackground {
            Color.clear
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LibraryView()
}
