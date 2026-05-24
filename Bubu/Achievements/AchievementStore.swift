//
//  AchievementStore.swift
//  Bubu
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class AchievementStore: ObservableObject {
    static let shared = AchievementStore()

    private static let storageKey = "achievementProgress"
    private static let legacyBestRunKey = "bestRunAnimals"

    @Published private(set) var progress: AchievementProgress

    private init() {
        progress = Self.loadProgress()
    }

    // MARK: - Gameplay events

    func recordAnimal(_ kind: AnimalKind) {
        switch kind {
        case .lion: progress.totalLions += 1
        case .elephant: progress.totalElephants += 1
        case .giraffe: progress.totalGiraffes += 1
        }
        progress.totalAnimals += 1
        persist()
    }

    func recordJump() {
        progress.totalJumps += 1
        persist()
    }

    func recordHeart() {
        progress.totalHearts += 1
        persist()
    }

    func recordHit() {
        progress.totalHits += 1
        persist()
    }

    func recordNightReached() {
        guard !progress.hasReachedNight else { return }
        progress.hasReachedNight = true
        persist()
    }

    func recordRunEnded(animalsCollected: Int) {
        guard animalsCollected > progress.bestRunAnimals else { return }
        progress.bestRunAnimals = animalsCollected
        persist()
    }

    // MARK: - Queries

    func currentValue(for metric: AchievementMetric) -> Int {
        switch metric {
        case .lions: return progress.totalLions
        case .elephants: return progress.totalElephants
        case .giraffes: return progress.totalGiraffes
        case .totalAnimals: return progress.totalAnimals
        case .jumps: return progress.totalJumps
        case .hearts: return progress.totalHearts
        case .hits: return progress.totalHits
        case .night: return progress.hasReachedNight ? 1 : 0
        case .bestRun: return progress.bestRunAnimals
        }
    }

    func isUnlocked(_ definition: AchievementDefinition) -> Bool {
        currentValue(for: definition.metric) >= definition.threshold
    }

    func progressText(for definition: AchievementDefinition) -> String {
        let current = min(currentValue(for: definition.metric), definition.threshold)
        return "\(current) / \(definition.threshold)"
    }

    func unlockedCount() -> Int {
        AchievementDefinition.catalog.filter { isUnlocked($0) }.count
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadProgress() -> AchievementProgress {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AchievementProgress.self, from: data) {
            return mergeLegacyBestRun(into: decoded)
        }
        let fresh = AchievementProgress()
        return mergeLegacyBestRun(into: fresh)
    }

    /// Migrates pre-achievements `bestRunAnimals` AppStorage value.
    private static func mergeLegacyBestRun(into progress: AchievementProgress) -> AchievementProgress {
        var merged = progress
        let legacy = UserDefaults.standard.integer(forKey: legacyBestRunKey)
        if legacy > merged.bestRunAnimals {
            merged.bestRunAnimals = legacy
        }
        return merged
    }
}
