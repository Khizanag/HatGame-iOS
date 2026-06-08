//
//  ConfettiView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import SwiftUI

/// Lightweight, dependency-free confetti view used for win/celebration moments.
/// Pieces fall, spin, and fade. Honors Reduce Motion by skipping animation entirely.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether confetti should burst right now. Toggle to true to trigger a fresh burst.
    let isActive: Bool
    /// Tint colors used for the pieces. Defaults to a vibrant palette.
    let palette: [Color]
    /// Number of confetti pieces to render.
    let pieceCount: Int
    /// Bump this to re-fire the burst (e.g. after returning from a sheet).
    let retriggerId: Int

    init(
        isActive: Bool,
        palette: [Color] = ConfettiView.defaultPalette,
        pieceCount: Int = 60,
        retriggerId: Int = 0
    ) {
        self.isActive = isActive
        self.palette = palette
        self.pieceCount = pieceCount
        self.retriggerId = retriggerId
    }

    static let defaultPalette: [Color] = [
        Color(red: 1.00, green: 0.78, blue: 0.27),
        Color(red: 1.00, green: 0.45, blue: 0.40),
        Color(red: 0.42, green: 0.55, blue: 1.00),
        Color(red: 0.78, green: 0.38, blue: 0.95),
        Color(red: 0.36, green: 0.85, blue: 0.50),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<pieceCount, id: \.self) { index in
                    ConfettiPiece(
                        color: palette[index % palette.count],
                        size: geometry.size,
                        seed: index,
                        isActive: isActive,
                        reduceMotion: reduceMotion,
                        retriggerId: retriggerId
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct ConfettiPiece: View {
    let color: Color
    let size: CGSize
    let seed: Int
    let isActive: Bool
    let reduceMotion: Bool
    let retriggerId: Int

    @State private var hasAppeared: Bool = false

    private var startX: CGFloat {
        let normalized = Double((seed * 73) % 100) / 100.0
        return size.width * CGFloat(normalized)
    }

    private var rotation: Double {
        Double((seed * 37) % 360)
    }

    private var endRotation: Double {
        rotation + Double((seed * 11) % 540) - 270
    }

    private var horizontalDrift: CGFloat {
        let value = CGFloat((seed * 53) % 80) - 40
        return value
    }

    private var fallDuration: Double {
        2.0 + Double((seed * 7) % 18) / 10.0
    }

    private var delay: Double {
        Double((seed * 13) % 100) / 100.0 * 0.6
    }

    private var pieceWidth: CGFloat {
        6 + CGFloat((seed * 5) % 6)
    }

    private var pieceHeight: CGFloat {
        10 + CGFloat((seed * 3) % 8)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: pieceWidth, height: pieceHeight)
            .rotationEffect(.degrees(hasAppeared ? endRotation : rotation))
            .position(
                x: startX + (hasAppeared ? horizontalDrift : 0),
                y: hasAppeared ? size.height + pieceHeight : -pieceHeight
            )
            .opacity(hasAppeared ? 0 : 1)
            .onAppear { fire() }
            .onChange(of: isActive) { _, _ in fire() }
            .onChange(of: retriggerId) { _, _ in fire() }
    }

    private func fire() {
        guard isActive, !reduceMotion else { return }
        hasAppeared = false
        DispatchQueue.main.async {
            withAnimation(.easeIn(duration: fallDuration).delay(delay)) {
                hasAppeared = true
            }
        }
    }
}

#Preview {
    ConfettiView(isActive: true)
        .background(Color.black.opacity(0.2))
}
