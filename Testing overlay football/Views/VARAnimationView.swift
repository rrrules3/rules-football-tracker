//
//  VARAnimationView.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import SwiftUI

struct VARAnimationView: View {
    let teamName: String
    let teamColor: Color
    let scorerName: String?   // player whose goal was rescinded (nil if unknown)
    let score: String         // corrected score after rescission

    @State private var bgOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            // Dark semi-transparent background — deliberately not a color flash
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.80))
                .opacity(bgOpacity)

            VStack(spacing: 5) {
                // "VAR" label — small, clinical, authoritative
                Text("VAR")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(5)

                // "NO GOAL" — dominant, red
                Text("NO GOAL")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)

                // Corrected score
                Text(score)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

                // Team whose goal was cancelled
                Text(teamName)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))

                // Scorer name with red strikethrough — visually communicates "doesn't count"
                if let scorer = scorerName {
                    Text(scorer)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                        .strikethrough(true, color: .red.opacity(0.85))
                }
            }
            .scaleEffect(textScale)
            .opacity(textOpacity)
        }
        .onAppear {
            animate()
        }
    }

    private func animate() {
        // Fade in the dark backdrop quickly
        withAnimation(.easeOut(duration: 0.2)) {
            bgOpacity = 1.0
        }
        // Spring the text in
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            textScale = 1.0
            textOpacity = 1.0
        }
        // Hold for ~3.5s then fade out
        withAnimation(.easeIn(duration: 0.7).delay(3.2)) {
            bgOpacity = 0.0
            textOpacity = 0.0
            textScale = 0.9
        }
    }
}
