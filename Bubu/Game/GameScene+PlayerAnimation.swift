//
//  GameScene+PlayerAnimation.swift
//  Bubu
//

import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Bubu run cycle (visual only)

    func loadBubuRunTextures() -> [SKTexture]? {
        var textures: [SKTexture] = []
        var missing: [String] = []
        for name in Self.bubuRunFrameNames {
            if let texture = GameTextures.optionalNamed(name) {
                textures.append(texture)
            } else {
                missing.append(name)
            }
        }

        if textures.count == Self.bubuRunFrameNames.count {
            return textures
        }

        #if DEBUG
        if !missing.isEmpty {
            let mode = textures.count >= Self.bubuRunMinFrameCount
                ? "\(textures.count) available frame(s)"
                : "static bubu"
            print("Bubu: missing run frames [\(missing.joined(separator: ", "))]; falling back to \(mode).")
        }
        #endif

        guard textures.count >= Self.bubuRunMinFrameCount else { return nil }
        return textures
    }

    /// Locks on-screen size from the largest run frame so `SKAction.animate(resize: false)` never resizes per texture.
    func computeRunLockedDisplaySize() -> CGSize? {
        guard let textures = bubuRunTextures, !textures.isEmpty else { return nil }
        let th = targetHeight(for: .run)
        let maxH = textures.map { $0.size().height }.max() ?? 0
        let maxW = textures.map { $0.size().width }.max() ?? 0
        guard maxH > 0.5 else { return nil }
        let scale = th / maxH
        return CGSize(width: maxW * scale, height: th)
    }

    func applyPlayerDisplayScale(for ride: RideType) {
        if ride == .run, let locked = computeRunLockedDisplaySize() {
            playerRunLockedDisplaySize = locked
            playerBikeLockedDisplaySize = nil
            playerScooterLockedDisplaySize = nil
            playerRoot.size = locked
            playerRoot.setScale(1)
            playerUniformBaseScale = 1
            return
        }

        if ride == .bike, let locked = computeBikeLockedDisplaySize() {
            playerRunLockedDisplaySize = nil
            playerBikeLockedDisplaySize = locked
            playerScooterLockedDisplaySize = nil
            playerRoot.size = locked
            playerRoot.setScale(1)
            playerUniformBaseScale = 1
            return
        }

        if ride == .scooter, let locked = computeScooterLockedDisplaySize() {
            playerRunLockedDisplaySize = nil
            playerBikeLockedDisplaySize = nil
            playerScooterLockedDisplaySize = locked
            playerRoot.size = locked
            playerRoot.setScale(1)
            playerUniformBaseScale = 1
            return
        }

        playerRunLockedDisplaySize = nil
        playerBikeLockedDisplaySize = nil
        playerScooterLockedDisplaySize = nil
        applyRideLockedDisplaySize(for: ride)
    }

    // MARK: - Bubu bike cycle (visual only)

    func loadBubuBikeTextures() -> [SKTexture]? {
        var textures: [SKTexture] = []
        var missing: [String] = []
        for name in Self.bubuBikeFrameNames {
            if let texture = GameTextures.optionalNamed(name) {
                textures.append(texture)
            } else {
                missing.append(name)
            }
        }

        if textures.count == Self.bubuBikeFrameNames.count {
            return textures
        }

        #if DEBUG
        if !missing.isEmpty {
            print("Bubu: missing bike frames [\(missing.joined(separator: ", "))]; falling back to static bubu-bike.")
        }
        #endif

        return nil
    }

    /// Bike uses a fixed on-screen size independent of raw frame padding (see `rideVisualDisplaySize(.bike)`).
    func computeBikeLockedDisplaySize() -> CGSize? {
        guard bubuBikeTextures != nil else { return nil }
        return rideVisualDisplaySize(for: .bike)
    }

    func updatePlayerBikeAnimationState() {
        guard shouldPlayBubuBikeAnimation() else {
            let holdAirborne = activeRideVisual == .bike && !isGrounded() && !isStumbling && !runEnded
            stopBubuBikeAnimation(holdAirborneFrame: holdAirborne)
            return
        }
        startBubuBikeAnimationIfNeeded()
    }

    func shouldPlayBubuBikeAnimation() -> Bool {
        guard activeRideVisual == .bike else { return false }
        guard bubuBikeTextures != nil else { return false }
        guard !runEnded, !isStumbling, !isGameplayPaused else { return false }
        return isGrounded()
    }

    func startBubuBikeAnimationIfNeeded() {
        guard let textures = bubuBikeTextures, !textures.isEmpty else { return }
        guard playerRoot.action(forKey: Self.bubuBikeAnimationKey) == nil else { return }

        let step = SKAction.animate(
            with: textures,
            timePerFrame: Self.bubuBikeTimePerFrame,
            resize: false,
            restore: false
        )
        playerRoot.run(SKAction.repeatForever(step), withKey: Self.bubuBikeAnimationKey)
    }

    func stopBubuBikeAnimation(holdAirborneFrame: Bool) {
        guard playerRoot.action(forKey: Self.bubuBikeAnimationKey) != nil else {
            if holdAirborneFrame {
                applyBubuBikeAirborneHoldFrame()
            }
            return
        }
        playerRoot.removeAction(forKey: Self.bubuBikeAnimationKey)
        if holdAirborneFrame {
            applyBubuBikeAirborneHoldFrame()
        }
    }

    private func applyBubuBikeAirborneHoldFrame() {
        guard activeRideVisual == .bike else { return }
        if let hold = GameTextures.optionalNamed(Self.bubuBikeAirborneFrameName) {
            applyBikeFrameTexture(hold)
            return
        }
        if let first = bubuBikeTextures?.first {
            applyBikeFrameTexture(first)
            return
        }
        applyBikeFrameTexture(GameTextures.named(resolvedAssetName(for: .bike)))
    }

    func applyBikeFrameTexture(_ texture: SKTexture) {
        playerRoot.texture = texture
        if let locked = playerBikeLockedDisplaySize {
            playerRoot.size = locked
        }
    }

    // MARK: - Bubu scooter cycle (visual only)

    func loadBubuScooterTextures() -> [SKTexture]? {
        var textures: [SKTexture] = []
        var missing: [String] = []
        for index in 1...Self.bubuScooterExpectedFrameCount {
            let name = "bubu-scooter-\(index)"
            if let texture = GameTextures.optionalNamed(name) {
                textures.append(texture)
            } else {
                missing.append(name)
                break
            }
        }

        guard textures.count >= Self.bubuScooterMinFrameCount else {
            #if DEBUG
            if !missing.isEmpty {
                print("Bubu: insufficient scooter frames (\(textures.count)); falling back to static bubu-scooter.")
            }
            #endif
            return nil
        }

        #if DEBUG
        if !missing.isEmpty, textures.count < Self.bubuScooterExpectedFrameCount {
            print("Bubu: using \(textures.count) scooter frame(s); missing [\(missing.joined(separator: ", "))].")
        }
        #endif

        return textures
    }

    func computeScooterLockedDisplaySize() -> CGSize? {
        guard bubuScooterTextures != nil else { return nil }
        return rideVisualDisplaySize(for: .scooter)
    }

    func updatePlayerScooterAnimationState() {
        guard shouldPlayBubuScooterAnimation() else {
            let holdAirborne = activeRideVisual == .scooter && !isGrounded() && !isStumbling && !runEnded
            stopBubuScooterAnimation(holdAirborneFrame: holdAirborne)
            return
        }
        startBubuScooterAnimationIfNeeded()
    }

    func shouldPlayBubuScooterAnimation() -> Bool {
        guard activeRideVisual == .scooter else { return false }
        guard bubuScooterTextures != nil else { return false }
        guard !runEnded, !isStumbling, !isGameplayPaused else { return false }
        return isGrounded()
    }

    func startBubuScooterAnimationIfNeeded() {
        guard let textures = bubuScooterTextures, !textures.isEmpty else { return }
        guard playerRoot.action(forKey: Self.bubuScooterAnimationKey) == nil else { return }

        let step = SKAction.animate(
            with: textures,
            timePerFrame: Self.bubuScooterTimePerFrame,
            resize: false,
            restore: false
        )
        playerRoot.run(SKAction.repeatForever(step), withKey: Self.bubuScooterAnimationKey)
    }

    func stopBubuScooterAnimation(holdAirborneFrame: Bool) {
        guard playerRoot.action(forKey: Self.bubuScooterAnimationKey) != nil else {
            if holdAirborneFrame {
                applyBubuScooterAirborneHoldFrame()
            }
            return
        }
        playerRoot.removeAction(forKey: Self.bubuScooterAnimationKey)
        if holdAirborneFrame {
            applyBubuScooterAirborneHoldFrame()
        }
    }

    private func applyBubuScooterAirborneHoldFrame() {
        guard activeRideVisual == .scooter else { return }
        if let hold = GameTextures.optionalNamed(Self.bubuScooterAirborneFrameName) {
            applyScooterFrameTexture(hold)
            return
        }
        if let first = bubuScooterTextures?.first {
            applyScooterFrameTexture(first)
            return
        }
        applyScooterFrameTexture(GameTextures.named(resolvedAssetName(for: .scooter)))
    }

    func applyScooterFrameTexture(_ texture: SKTexture) {
        playerRoot.texture = texture
        if let locked = playerScooterLockedDisplaySize {
            playerRoot.size = locked
        }
    }

    func updatePlayerRunAnimationState() {
        guard shouldPlayBubuRunAnimation() else {
            let holdAirborne = activeRideVisual == .run && !isGrounded() && !isStumbling && !runEnded
            stopBubuRunAnimation(holdAirborneFrame: holdAirborne)
            return
        }
        startBubuRunAnimationIfNeeded()
    }

    func shouldPlayBubuRunAnimation() -> Bool {
        guard activeRideVisual == .run else { return false }
        guard bubuRunTextures != nil else { return false }
        guard !runEnded, !isStumbling, !isGameplayPaused else { return false }
        return isGrounded()
    }

    func startBubuRunAnimationIfNeeded() {
        guard let textures = bubuRunTextures, !textures.isEmpty else { return }
        guard playerRoot.action(forKey: Self.bubuRunAnimationKey) == nil else { return }

        let step = SKAction.animate(
            with: textures,
            timePerFrame: Self.bubuRunTimePerFrame,
            resize: false,
            restore: false
        )
        playerRoot.run(SKAction.repeatForever(step), withKey: Self.bubuRunAnimationKey)
    }

    func stopBubuRunAnimation(holdAirborneFrame: Bool) {
        guard playerRoot.action(forKey: Self.bubuRunAnimationKey) != nil else {
            if holdAirborneFrame {
                applyBubuAirborneHoldFrame()
            }
            return
        }
        playerRoot.removeAction(forKey: Self.bubuRunAnimationKey)
        if holdAirborneFrame {
            applyBubuAirborneHoldFrame()
        }
    }

    private func applyBubuAirborneHoldFrame() {
        guard activeRideVisual == .run else { return }
        if let hold = GameTextures.optionalNamed(Self.bubuRunAirborneFrameName) {
            applyRunFrameTexture(hold)
            return
        }
        if let first = bubuRunTextures?.first {
            applyRunFrameTexture(first)
            return
        }
        applyRunFrameTexture(GameTextures.named(resolvedAssetName(for: .run)))
    }

    /// Applies a run texture without changing the locked display size used for alignment.
    func applyRunFrameTexture(_ texture: SKTexture) {
        playerRoot.texture = texture
        if let locked = playerRunLockedDisplaySize {
            playerRoot.size = locked
        }
    }
}
