//
//  GameScene+Collision.swift
//  Bubu
//

import SpriteKit

extension GameScene {
    // MARK: - Collision / stumble

    func checkHeartPickupHits() {
        guard estimatedLives < maxLives else { return }
        let p = playerHazardRect()
        for child in itemsLayer.children where child.name == "heartPickup" {
            let pickupRect = heartPickupRect(for: child)
            if p.intersects(pickupRect) {
                collectHeartPickup(child)
                return
            }
        }
    }

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

    func heartPickupRect(for pickup: SKNode) -> CGRect {
        // Collision uses the visible heart sprite only (excludes the soft halo shape), then adds a
        // modest AABB buffer so slight horizontal misses still count — sprite art size unchanged.
        guard let sprite = pickup.childNode(withName: "heartSprite") as? SKSpriteNode,
              let layer = pickup.parent else {
            return outsetHeartPickupCollisionRect(pickup.calculateAccumulatedFrame())
        }
        let localSpriteFrame = sprite.calculateAccumulatedFrame()
        let inItemsLayer = heartRectInParentCoordinates(localSpriteFrame, node: pickup, parent: layer)
        return outsetHeartPickupCollisionRect(inItemsLayer)
    }

    /// Converts an axis-aligned rect from `node` space into `parent` space (handles tilt on the pickup root).
    private func heartRectInParentCoordinates(_ rect: CGRect, node: SKNode, parent: SKNode) -> CGRect {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ]
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for p in corners {
            let q = parent.convert(p, from: node)
            minX = min(minX, q.x)
            maxX = max(maxX, q.x)
            minY = min(minY, q.y)
            maxY = max(maxY, q.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func outsetHeartPickupCollisionRect(_ r: CGRect) -> CGRect {
        let padX: CGFloat = 14
        let padY: CGFloat = 9
        return CGRect(
            x: r.minX - padX,
            y: r.minY - padY,
            width: r.width + padX * 2,
            height: r.height + padY * 2
        )
    }

    func collectHeartPickup(_ pickup: SKNode) {
        guard pickup.parent != nil else { return }
        pickup.name = nil
        let worldPoint = itemsLayer.convert(pickup.position, to: self)
        pickup.removeFromParent()
        playHeartHealPickupFX(at: worldPoint)
        estimatedLives = min(maxLives, estimatedLives + 1)
        onPlayerHealed?()
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
        estimatedLives = max(0, estimatedLives - 1)
        lastDamageSceneTime = sceneTime
        isStumbling = true
        stumbleElapsed = 0
        velocityY = -280
        playerRoot.removeAction(forKey: "jumpJuice")
        playerRoot.removeAction(forKey: "landJuice")
        restorePlayerUniformScale()
        playHitShake()
    }
}
