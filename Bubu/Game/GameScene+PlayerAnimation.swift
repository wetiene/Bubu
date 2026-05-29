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
            playerRoot.size = locked
            playerRoot.setScale(1)
            playerUniformBaseScale = 1
            return
        }

        playerRunLockedDisplaySize = nil
        applyRideLockedDisplaySize(for: ride)
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
