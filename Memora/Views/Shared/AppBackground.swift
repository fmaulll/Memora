//
//  AppBackground.swift
//  Memora
//
//  Created by fuckdazeshit on 14/08/26.
//

import SwiftUI

struct AppBackground<Content: View>: View {
    @ViewBuilder let content: Content

    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            // DecorativeBackground()
            //     .ignoresSafeArea()

            content
        }
    }
}
