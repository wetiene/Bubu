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
        timeToNextHeartPickup -= dt

        if timeToNextObstacle <= 0, obstacleCount() < 1 {
            spawnObstacleIfClear()
            timeToNextObstacle = Double.random(in: 7.8...11.5)
        }
        if timeToNextAnimal <= 0, animalCount() < 1 {
            spawnAnimalIfClear()
            timeToNextAnimal = Double.random(in: 3.2...5.0)
        }

        if timeToNextHeartPickup <= 0, canSpawnHeartPickup() {
            let didWinChanceRoll = shouldSpawnHeartPickupNow()
            let didSpawn = didWinChanceRoll ? spawnHeartPickupIfClear() : false
            if didSpawn {
                heartSpawnCooldownUntil = sceneTime + Double.random(in: 10.0...13.5)
            }
            timeToNextHeartPickup = nextHeartSpawnDelay(afterAttemptSucceeded: didSpawn)
        }
    }

    func updateStumbleStateTransitions() {
        if stumbleElapsed >= 0.4 {
            endStumble()
        }
    }

    func updateNormalCollisionsAndStateTransitions() {
        guard !runEnded else { return }
        checkHeartPickupHits()
        if sceneTime >= invulnerableUntil {
            checkObstacleHits()
        }
    }

    func finalizeFrameCleanup() {
        pruneOffscreen()
    }

    override func update(_ currentTime: TimeInterval) {
        if isGameplayPaused {
            return
        }

        guard let dt = computeFrameDelta(currentTime: currentTime) else {
            return
        }
        let step = CGFloat(dt)

        // Keep per-frame branch decisions stable even if stumble ends mid-frame.
        let wasStumbling = isStumbling

        // 3) Update movement/physics.
        if wasStumbling {
            updateStumble(step: step, dt: dt)
        } else {
            updateNormalMovement(step: step)
            updatePlayerRunAnimationState()
            updatePlayerBikeAnimationState()
            updatePlayerScooterAnimationState()
        }

        if wasStumbling {
            stopBubuRunAnimation(holdAirborneFrame: false)
            stopBubuBikeAnimation(holdAirborneFrame: false)
            stopBubuScooterAnimation(holdAirborneFrame: false)
        }

        // Shared world movement/scrolling.
        updateSharedWorldScroll(step: step)
        updateEnvironment(deltaTime: dt)

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
        jumpsRemaining = maxJumpCount
        invulnerableUntil = sceneTime + 2.85
    }

    func obstacleCount() -> Int {
        itemsLayer.children.filter { $0.name == "obstacle" }.count
    }

    func animalCount() -> Int {
        itemsLayer.children.filter { $0.name == "animal" }.count
    }

    func heartPickupCount() -> Int {
        itemsLayer.children.filter { $0.name == "heartPickup" }.count
    }

    func pruneOffscreen() {
        for child in itemsLayer.children where child.position.x < -220 {
            child.removeFromParent()
        }
    }

    func canSpawnHeartPickup() -> Bool {
        guard lives < maxLives else { return false }
        guard heartPickupCount() == 0 else { return false }
        guard sceneTime >= heartSpawnCooldownUntil else { return false }
        return true
    }

    func shouldSpawnHeartPickupNow() -> Bool {
        var spawnChance: CGFloat = 0.18
        if sceneTime - lastDamageSceneTime <= 7.5 {
            spawnChance += 0.16
        }
        if lives <= 1 {
            spawnChance += 0.24
        } else if lives == 2 {
            spawnChance += 0.09
        }
        spawnChance = min(spawnChance, 0.72)
        return CGFloat.random(in: 0...1) < spawnChance
    }

    func nextHeartSpawnDelay(afterAttemptSucceeded: Bool) -> TimeInterval {
        if afterAttemptSucceeded {
            return Double.random(in: 10.8...14.2)
        }
        return Double.random(in: 2.2...3.8)
    }
}
