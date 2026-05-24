//
//  BubuApp.swift
//  Bubu
//
//  Created by William on 17/4/2026.
//

import SwiftUI

@main
struct BubuApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AchievementStore.shared)
        }
    }
}
