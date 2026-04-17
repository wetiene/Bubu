//
//  GameScene+Loop.swift
//  Bubu
//

import SpriteKit

extension GameScene {
    // MARK: - Loop

    func resetFrameTiming() {
        lastUpdateTime = 0
    }

    /// Returns nil on first frame (or after a reset), otherwise a clamped frame delta.
    func computeFrameDelta(currentTime: TimeInterval) -> TimeInterval? {
        sceneTime = currentTime
        guard lastUpdateTime > 0 else {
            lastUpdateTime = currentTime
            return nil
        }

        let rawDelta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        return min(max(rawDelta, 0), maxFrameDelta)
    }

    func updateSharedWorldScroll(step: CGFloat) {
        for child in itemsLayer.children {
            child.position.x -= effectiveScrollSpeed() * step
        }
        scrollSkyIfNeeded(step: step)
        scrollDistantParallaxIfNeeded(step: step)
    }

    func updateStumble(step: CGFloat, dt: TimeInterval) {
        stumbleElapsed += dt
        velocityY += gravity * step
        playerRoot.position.y += velocityY * step
        playerRoot.position.y = max(playerRoot.position.y, groundHeight - 8)

        let wobble = sin(stumbleElapsed * 24) * 0.18
        playerRoot.zRotation = CGFloat(-1.18 + wobble)
    }

    func updateNormalMovement(step: CGFloat) {
        velocityY += gravity * step
        playerRoot.position.y += velocityY * step
        if playerRoot.position.y < groundHeight {
            playerRoot.position.y = groundHeight
            velocityY = 0
        }

        let grounded = isGrounded()

        if grounded {
            if jumpJuiceWasInAir, velocityY <= 10 {
                applyLandJuice()
                jumpJuiceWasInAir = false
            }
            jumpsRemaining = maxJumpCount
        }

        if !grounded {
            jumpJuiceWasInAir = true
        }
    }

    func updateSpawning(dt: TimeInterval) {
        timeToNextObstacle -= dt
        timeToNextAnimal -= dt

        if timeToNextObstacle <= 0, obstacleCount() < 1 {
            spawnObstacleIfClear()
            timeToNextObstacle = Double.random(in: 7.8...11.5)
        }
        if timeToNextAnimal <= 0, animalCount() < 1 {
            spawnAnimalIfClear()
            timeToNextAnimal = Double.random(in: 3.2...5.0)
        }
    }

    func updateStumbleStateTransitions() {
        if stumbleElapsed >= 0.4 {
            endStumble()
        }
    }

    func updateNormalCollisionsAndStateTransitions() {
        if sceneTime >= invulnerableUntil {
            checkObstacleHits()
        }
    }

    func finalizeFrameCleanup() {
        pruneOffscreen()
    }

    override func update(_ currentTime: TimeInterval) {
        // 1) Compute dt.
        guard let dt = computeFrameDelta(currentTime: currentTime) else {
            return
        }
        let step = CGFloat(dt)

        // 2) Guard pause.
        if gameplayPausedFromUI {
            return
        }

        // Keep per-frame branch decisions stable even if stumble ends mid-frame.
        let wasStumbling = isStumbling

        // 3) Update movement/physics.
        if wasStumbling {
            updateStumble(step: step, dt: dt)
        } else {
            updateNormalMovement(step: step)
        }

        // Shared world movement/scrolling.
        updateSharedWorldScroll(step: step)

        // 4) Update spawning/timers.
        if !wasStumbling {
            updateSpawning(dt: dt)
        }

        // 5) Update collisions/state transitions.
        if wasStumbling {
            updateStumbleStateTransitions()
        } else {
            updateNormalCollisionsAndStateTransitions()
        }

        // 6) Cleanup/render side effects.
        finalizeFrameCleanup()
    }

    func endStumble() {
        isStumbling = false
        stumbleElapsed = 0
        velocityY = 0
        playerRoot.position.y = groundHeight
        playerRoot.zRotation = 0
        restorePlayerUniformScale()
        coyoteTimer = coyoteSeconds
        jumpBufferTimer = 0
        jumpsRemaining = maxJumpCount
        invulnerableUntil = sceneTime + 2.85
    }

    func obstacleCount() -> Int {
        itemsLayer.children.filter { $0.name == "obstacle" }.count
    }

    func animalCount() -> Int {
        itemsLayer.children.filter { $0.name == "animal" }.count
    }

    func pruneOffscreen() {
        for child in itemsLayer.children where child.position.x < -220 {
            child.removeFromParent()
        }
    }
}
