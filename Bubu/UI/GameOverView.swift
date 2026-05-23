//
//  GameOverView.swift
//  Bubu
//

import SwiftUI

struct GameOverView: View {
    let runTotal: Int
    let bestRun: Int
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Run Over")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                VStack(spacing: 10) {
                    Text("Animals Saved")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(runTotal)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.2))
                    HStack(spacing: 8) {
                        Text("Best Run")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("\(bestRun)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 8)

                Button(action: onPlayAgain) {
                    Text("Play Again")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.2, green: 0.55, blue: 0.95))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play again")
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .padding(.horizontal, 28)
        }
    }
}

#Preview {
    GameOverView(runTotal: 7, bestRun: 12, onPlayAgain: {})
}
