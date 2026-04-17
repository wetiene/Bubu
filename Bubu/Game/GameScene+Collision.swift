//
//  GameScene+Collision.swift
//  Bubu
//

import SpriteKit

extension GameScene {
    // MARK: - Collision / stumble

    func checkObstacleHits() {
        let p = playerHazardRect()
        for child in itemsLayer.children where child.name == "obstacle" {
            let o = forgivingObstacleRect(for: child)
            if p.intersects(o) {
                beginStumble()
                return
            }
        }
    }

    /// Tight box above the feet — torso / lower body only (smaller than sprite bounds).
    func playerHazardRect() -> CGRect {
        let cx = playerRoot.position.x
        let baseY = playerRoot.position.y
        return CGRect(
            x: cx - playerHazardWidth / 2,
            y: baseY + playerHazardLiftFromFeet,
            width: playerHazardWidth,
            height: playerHazardHeight
        )
    }

    /// Much smaller than art — heavy top/front shrink so grazing rarely counts.
    func forgivingObstacleRect(for obstacle: SKNode) -> CGRect {
        let r = obstacle.calculateAccumulatedFrame()
        let kind = obstacleKind(from: obstacle)
        // Fallen log art is very wide and low, so use lighter trims to keep hits reliable but fair.
        let insetX: CGFloat = (kind == .fallenLog) ? 8 : 18
        let insetTop: CGFloat = (kind == .fallenLog) ? 12 : 30
        let insetBottom: CGFloat = 2
        return CGRect(
            x: r.minX + insetX,
            y: r.minY + insetBottom,
            width: max(0, r.width - 2 * insetX),
            height: max(0, r.height - insetTop - insetBottom)
        )
    }

    func obstacleKind(from obstacle: SKNode) -> ObstacleKind? {
        guard let raw = obstacle.userData?["obstacleKind"] as? String else { return nil }
        return ObstacleKind(rawValue: raw)
    }

    func beginStumble() {
        guard !isStumbling else { return }
        showOopsBubble()
        onPurseShakeRequested?()
        let droppedKinds = dropAnimalsOnObstacleHit()
        let visualCap = 12
        for (i, k) in droppedKinds.prefix(visualCap).enumerated() {
            spawnDroppedAnimalFall(dropped: k, slot: i)
        }
        onPlayerHit?()
        isStumbling = true
        stumbleElapsed = 0
        velocityY = -280
        coyoteTimer = 0
        jumpBufferTimer = 0
        playerRoot.removeAction(forKey: "jumpJuice")
        playerRoot.removeAction(forKey: "landJuice")
        restorePlayerUniformScale()
        playHitShake()
    }
}
