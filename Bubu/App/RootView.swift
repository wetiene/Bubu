//
//  RootView.swift
//  Bubu
//

import SwiftUI

private enum RootScreen {
    case home
    case achievements
    case playing
}

struct RootView: View {
    @EnvironmentObject private var achievementStore: AchievementStore
    @State private var screen: RootScreen = .home
    @State private var currentRide: RideType = .run

    var body: some View {
        Group {
            switch screen {
            case .home:
                HomeView(
                    onPlay: { screen = .playing },
                    onAchievements: { screen = .achievements }
                )
            case .achievements:
                AchievementsView(store: achievementStore) {
                    screen = .home
                }
            case .playing:
                GameView(currentRide: $currentRide)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AchievementStore.shared)
}
