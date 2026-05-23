//
//  GameScene+Inventory.swift
//  Bubu
//

import SpriteKit
import SwiftUI

extension GameScene {
    /// Top-left purse hotspot in scene coords (SwiftUI target when known; else layout fallback).
    func pursePointInScene() -> CGPoint {
        if let p = purseDestinationFromUI {
            return p
        }
        return CGPoint(x: 44, y: size.height - 40)
    }

    func arcMoveToPurse(from start: CGPoint, to end: CGPoint, duration: TimeInterval) -> SKAction {
        let midX = (start.x + end.x) / 2
        let lift: CGFloat = min(140, size.height * 0.22)
        let control = CGPoint(x: midX, y: max(start.y, end.y) + lift)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return SKAction.follow(path, asOffset: false, orientToPath: false, duration: duration)
    }

    func animalKind(from animal: SKNode) -> AnimalKind? {
        if let raw = animal.userData?["kind"] as? Int, let k = AnimalKind(rawValue: raw) {
            return k
        }
        return nil
    }

    func registerCollect(kind: AnimalKind) {
        let pursePoint = pursePointInScene()
        switch kind {
        case .lion: lionBinding?.wrappedValue += 1
        case .elephant: elephantBinding?.wrappedValue += 1
        case .giraffe: giraffeBinding?.wrappedValue += 1
        }
        totalCollectedThisRun += 1
        refreshPeakCollectedForSpeed()
        playHappyCollect(at: pursePoint)
        playPurseCollectPulse(at: pursePoint)
    }

    func currentTotalCollected() -> Int {
        (lionBinding?.wrappedValue ?? 0) + (elephantBinding?.wrappedValue ?? 0) + (giraffeBinding?.wrappedValue ?? 0)
    }

    func refreshPeakCollectedForSpeed() {
        let t = currentTotalCollected()
        if t > peakCollectedThisRun {
            peakCollectedThisRun = t
        }
    }

    func requestRunOverIfNeeded() {
        guard !runOverDispatched else { return }
        guard currentTotalCollected() == 0 else { return }
        // Avoid ending the run if the player is hit before collecting anything.
        guard totalCollectedThisRun > 0 || peakCollectedThisRun > 0 else { return }
        runOverDispatched = true
        onRunOverRequested?(totalCollectedThisRun)
    }

    /// Scroll speed from best purse total this run; never drops when animals are lost.
    func effectiveScrollSpeed() -> CGFloat {
        min(baseScrollSpeed + CGFloat(peakCollectedThisRun) * speedStepPerAnimal, maxScrollSpeed)
    }

    /// On obstacle hit: lose 5%–10% of current total (min 1 if any), spread across species by weight. Returns kinds removed (for visuals).
    @discardableResult
    func dropAnimalsOnObstacleHit() -> [AnimalKind] {
        let total = currentTotalCollected()
        guard total > 0 else { return [] }
        let fraction = CGFloat.random(in: 0.05...0.10)
        var drop = Int(ceil(CGFloat(total) * fraction))
        drop = max(1, min(drop, total))
        return subtractAnimalsWeightedReturningKinds(count: drop)
    }

    func subtractAnimalsWeightedReturningKinds(count: Int) -> [AnimalKind] {
        var removed: [AnimalKind] = []
        var remaining = count
        while remaining > 0 {
            let l = lionBinding?.wrappedValue ?? 0
            let e = elephantBinding?.wrappedValue ?? 0
            let g = giraffeBinding?.wrappedValue ?? 0
            let sum = l + e + g
            guard sum > 0 else { break }
            let pick = Int.random(in: 0..<sum)
            if pick < l {
                lionBinding?.wrappedValue = l - 1
                removed.append(.lion)
            } else if pick < l + e {
                elephantBinding?.wrappedValue = e - 1
                removed.append(.elephant)
            } else {
                giraffeBinding?.wrappedValue = g - 1
                removed.append(.giraffe)
            }
            remaining -= 1
        }
        return removed
    }
}
