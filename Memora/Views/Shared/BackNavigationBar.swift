//
//  BackNavigationBar.swift
//  Memora
//
//  Created by fuckdazeshit on 14/08/26.
//

import SwiftUI

struct BackNavigationBar<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let onBack: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onBack = onBack
        self.content = content
    }

    var body: some View {
        HStack {
            Button {
                if let onBack {
                    onBack()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            content()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)
        }
    }
}
