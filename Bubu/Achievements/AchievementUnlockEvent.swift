//
//  AchievementUnlockEvent.swift
//  Bubu
//

import Foundation

struct AchievementUnlockEvent: Identifiable, Equatable {
    let id: UUID
    let achievementID: AchievementID

    init(achievementID: AchievementID, id: UUID = UUID()) {
        self.id = id
        self.achievementID = achievementID
    }

    var definition: AchievementDefinition {
        AchievementDefinition.catalog.first { $0.id == achievementID }
            ?? AchievementDefinition.catalog[0]
    }
}

/// Optional hook for future unlock celebration sounds.
enum AchievementUnlockFeedback {
    static var playUnlockSound: ((AchievementID) -> Void)?
}
