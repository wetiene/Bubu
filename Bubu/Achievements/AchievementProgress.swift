//
//  AchievementProgress.swift
//  Bubu
//

import Foundation

struct AchievementProgress: Codable, Equatable {
    var totalLions = 0
    var totalElephants = 0
    var totalGiraffes = 0
    var totalAnimals = 0
    var totalJumps = 0
    var totalHearts = 0
    var totalHits = 0
    var hasReachedNight = false
    var bestRunAnimals = 0
    /// Unlocked stickers the player has not opened in the Stickers book yet.
    var newlyUnlockedAchievementIDs: [String] = []
}
