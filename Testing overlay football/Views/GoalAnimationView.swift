//
//  GoalAnimationView.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import SwiftUI
//For Goal Sound Notif
import AudioToolbox

struct GoalAnimationView: View {
    let teamColor: Color
    let teamName: String
    let score: String   // e.g. "2 - 1"

    @State private var showFlash = false
    @State private var showText = false
    @State private var textScale: CGFloat = 0.3
    @State private var flashOpacity: Double = 0.8
    @State private var textOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0.8

    var body: some View {
        ZStack {
            // Color flash background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(teamColor.gradient)
                .opacity(flashOpacity)

            // Expanding ring
            Circle()
                .stroke(teamColor.opacity(0.6), lineWidth: 3)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Goal text
            VStack(spacing: 4) {
                Text("GOAL!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                Text(score)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

                Text(teamName)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                /* Adding Scorer Name to goal animation?
                 Text(scorerName)
                    .font(.caption.bold())
                    .foregroundStyle(white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                 */
            }
            .scaleEffect(textScale)
            .opacity(textOpacity)
        }
        .onAppear {
            animate()
        }
    }

    private func animate() {
        // Phase 1: Play Goal Noise (macOS "Glass" system sound)
        NSSound(named: "Glass")?.play()

        // Phase 2: Flash in + text spring
        withAnimation(.easeOut(duration: 0.15)) {
            flashOpacity = 0.85
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            textScale = 1.0
            textOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 3.0
            ringOpacity = 0.0
        }

        // Phase 2: Hold, then fade out
        withAnimation(.easeIn(duration: 0.8).delay(2.0)) {
            flashOpacity = 0.0
            textOpacity = 0.0
            textScale = 0.8
        }
    }
}
