//
//  HomeView.swift
//  Bubu
//

import SwiftUI

struct HomeView: View {
    let onPlay: () -> Void
    let onAchievements: () -> Void
    @AppStorage("musicEnabled") private var musicEnabled = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.55, green: 0.85, blue: 1.0), Color(red: 0.75, green: 0.95, blue: 0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("Bubu")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                Button(action: onPlay) {
                    Text("Play")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color(red: 1.0, green: 0.45, blue: 0.55))
                        )
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .accessibilityLabel("Play")
                .padding(.horizontal, 40)

                Button(action: onAchievements) {
                    Text("Sticker Book")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(red: 0.55, green: 0.4, blue: 0.95))
                        )
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                }
                .accessibilityLabel("Sticker Book")
                .padding(.horizontal, 40)

                Toggle(isOn: $musicEnabled) {
                    Label("Music", systemImage: musicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .toggleStyle(.switch)
                .tint(Color(red: 1.0, green: 0.45, blue: 0.55))
                .padding(.horizontal, 40)
                .accessibilityLabel("Background music")
                .onChange(of: musicEnabled) { _, enabled in
                    BubuAudioManager.shared.setMusicEnabled(enabled)
                }
            }
        }
        .onAppear {
            BubuAudioManager.shared.setMusicEnabled(musicEnabled)
        }
    }
}

#Preview {
    HomeView(onPlay: {}, onAchievements: {})
}
