//
//  GameOverView.swift
//  Bubu
//

import SwiftUI

struct GameOverView: View {
    let score: Int
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.18, blue: 0.22)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Nice try!")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text("Score")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(score)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.35))
                }

                Button(action: onPlayAgain) {
                    Text("Play Again")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(red: 0.35, green: 0.75, blue: 0.45))
                        )
                }
                .padding(.horizontal, 36)
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}

#Preview {
    GameOverView(score: 7, onPlayAgain: {})
}
