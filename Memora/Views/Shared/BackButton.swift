//
//  BackButton.swift
//  Memora
//
//  Created by fuckdazeshit on 14/08/26.
//

import SwiftUI

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 56, height: 56)
                .background(.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BackButton()
    }
}
