//
//  CenteredScrollView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

/// Centers its content vertically in the space it is given, like a VStack
/// between two Spacers, but scrolls once the content is taller than that
/// space — at the largest accessibility text sizes — instead of squeezing
/// and truncating it. Pin bottom actions with `actionBar { … }`
/// so they stay reachable.
struct CenteredScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
