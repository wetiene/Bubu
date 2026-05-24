//
//  AchievementUnlockQueue.swift
//  Bubu
//

import Combine
import SwiftUI

/// Serial presentation queue for in-game unlock cards (SwiftUI layer only).
@MainActor
final class AchievementUnlockQueue: ObservableObject {
    @Published private(set) var current: AchievementUnlockEvent?

    private var pending: [AchievementUnlockEvent] = []
    private var dismissTask: Task<Void, Never>?

    private let visibleDuration: Duration = .milliseconds(2500)
    private let gapBetweenCards: Duration = .milliseconds(380)

    func enqueue(_ events: [AchievementUnlockEvent]) {
        guard !events.isEmpty else { return }
        pending.append(contentsOf: events)
        presentNextIfIdle()
    }

    func enqueue(_ event: AchievementUnlockEvent) {
        enqueue([event])
    }

    private func presentNextIfIdle() {
        guard current == nil, let next = pending.first else { return }
        pending.removeFirst()
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
            current = next
        }
        AchievementUnlockFeedback.playUnlockSound?(next.achievementID)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: self?.visibleDuration ?? .milliseconds(2500))
            guard !Task.isCancelled else { return }
            await self?.finishCurrentAndContinue()
        }
    }

    private func finishCurrentAndContinue() async {
        withAnimation(.easeInOut(duration: 0.32)) {
            current = nil
        }
        try? await Task.sleep(for: gapBetweenCards)
        presentNextIfIdle()
    }
}
