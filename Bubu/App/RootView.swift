//
//  RootView.swift
//  Bubu
//

import SwiftUI

private enum RootScreen {
    case home
    case playing
}

struct RootView: View {
    @State private var screen: RootScreen = .home
    @State private var currentRide: RideType = .run

    var body: some View {
        Group {
            switch screen {
            case .home:
                HomeView {
                    screen = .playing
                }
            case .playing:
                GameView(currentRide: $currentRide)
            }
        }
    }
}

#Preview {
    RootView()
}
