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
    /// Bumped when new unlock events are ready in `latestUnlockBatch`.
    @Published private(set) var unlockEventsRevision: UInt = 0
    @Published private(set) var latestUnlockBatch: [AchievementUnlockEvent] = []

    private init() {
        progress = Self.loadProgress()
    }

    var newlyUnlockedAchievementIDs: Set<String> {
        Set(progress.newlyUnlockedAchievementIDs)
    }

    // MARK: - Gameplay events

    func recordAnimal(_ kind: AnimalKind) {
        applyProgressChange { progress in
            switch kind {
            case .lion: progress.totalLions += 1
            case .elephant: progress.totalElephants += 1
            case .giraffe: progress.totalGiraffes += 1
            }
            progress.totalAnimals += 1
        }
    }

    func recordJump() {
        applyProgressChange { $0.totalJumps += 1 }
    }

    func recordHeart() {
        applyProgressChange { $0.totalHearts += 1 }
    }

    func recordHit() {
        applyProgressChange { $0.totalHits += 1 }
    }

    func recordNightReached() {
        guard !progress.hasReachedNight else { return }
        applyProgressChange { $0.hasReachedNight = true }
    }

    func recordRunEnded(animalsCollected: Int) {
        guard animalsCollected > progress.bestRunAnimals else { return }
        applyProgressChange { $0.bestRunAnimals = animalsCollected }
    }

    // MARK: - Seen / NEW state

    func isNew(_ definition: AchievementDefinition) -> Bool {
        progress.newlyUnlockedAchievementIDs.contains(definition.id.rawValue)
    }

    func markAchievementsSeen() {
        guard !progress.newlyUnlockedAchievementIDs.isEmpty else { return }
        progress.newlyUnlockedAchievementIDs.removeAll()
        persist()
    }

    // MARK: - Queries

    func currentValue(for metric: AchievementMetric) -> Int {
        currentValue(for: metric, progress: progress)
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

    // MARK: - Progress + unlock detection

    private func applyProgressChange(_ change: (inout AchievementProgress) -> Void) {
        let before = unlockedIDs(for: progress)
        change(&progress)
        let after = unlockedIDs(for: progress)
        let freshIDs = after.subtracting(before)
        if !freshIDs.isEmpty {
            registerFreshUnlocks(freshIDs)
        }
        persist()
    }

    private func registerFreshUnlocks(_ ids: Set<AchievementID>) {
        let ordered = AchievementDefinition.catalog.map(\.id).filter { ids.contains($0) }
        for id in ordered {
            let raw = id.rawValue
            if !progress.newlyUnlockedAchievementIDs.contains(raw) {
                progress.newlyUnlockedAchievementIDs.append(raw)
            }
        }
        latestUnlockBatch = ordered.map { AchievementUnlockEvent(achievementID: $0) }
        unlockEventsRevision += 1
    }

    private func unlockedIDs(for progress: AchievementProgress) -> Set<AchievementID> {
        Set(
            AchievementDefinition.catalog.compactMap { definition in
                currentValue(for: definition.metric, progress: progress) >= definition.threshold
                    ? definition.id
                    : nil
            }
        )
    }

    private func currentValue(for metric: AchievementMetric, progress: AchievementProgress) -> Int {
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
