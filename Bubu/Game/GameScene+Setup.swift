//
//  GameScene+Setup.swift
//  Bubu
//

import SpriteKit
import SwiftUI
import UIKit

extension GameScene {
    // MARK: - Scene setup

    /// Reports ground top in SwiftUI/top-origin view coordinates (deferred for SwiftUI safety).
    func publishGroundTopChanged() {
        let groundTop = size.height - groundHeight
        deferSwiftUIState { [weak self] in
            self?.onGroundTopChanged?(groundTop)
        }
    }

    /// Visual-only; `currentRide` lives in SwiftUI — call this when the binding changes.
    func applyRideVisual(_ ride: RideType) {
        activeRideVisual = ride
        playerRoot.removeAction(forKey: "jumpJuice")
        playerRoot.removeAction(forKey: "landJuice")
        stopBubuRunAnimation(holdAirborneFrame: false)

        if ride == .run, let first = bubuRunTextures?.first {
            applyPlayerDisplayScale(for: ride)
            applyRunFrameTexture(first)
            return
        }

        applyPlayerDisplayScale(for: ride)
        playerRoot.texture = GameTextures.named(resolvedAssetName(for: ride))
        applyRideLockedDisplaySize(for: ride)
    }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.55, green: 0.82, blue: 0.96, alpha: 1)

        removeAllChildren()
        itemsLayer.removeAllChildren()

        lastUpdateTime = 0
        sceneTime = 0
        isStumbling = false
        stumbleElapsed = 0
        invulnerableUntil = 0
        velocityY = 0
        jumpJuiceWasInAir = false
        playerUniformBaseScale = 1
        activeRideVisual = .run
        playerRunLockedDisplaySize = nil
        bubuRunTextures = loadBubuRunTextures()
        jumpsRemaining = maxJumpCount
        lives = maxLives
        runEnded = false
        heartSpawnCooldownUntil = 0
        lastDamageSceneTime = -100

        buildEnvironment()
        buildGround()
        addChild(itemsLayer)

        playerRoot = makePlayerSprite()
        playerRoot.zPosition = 80
        playerRoot.position = CGPoint(x: 140, y: groundHeight)
        playerRoot.zRotation = 0
        addChild(playerRoot)
        applyPlayerDisplayScale(for: .run)

        applyDeferredSwiftUIReset()

        timeToNextObstacle = Double.random(in: 7.2...10.0)
        timeToNextAnimal = Double.random(in: 3.4...5.2)
        timeToNextHeartPickup = Double.random(in: 8.5...12.0)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayoutEnvironmentIfNeeded()
        publishGroundTopChanged()
    }

    // MARK: - World

    func buildGround() {
        let w = max(size.width, 400) * 2
        let strip = SKSpriteNode(
            color: SKColor(red: 0.45, green: 0.78, blue: 0.42, alpha: 1),
            size: CGSize(width: w, height: groundHeight)
        )
        strip.anchorPoint = CGPoint(x: 0, y: 0)
        strip.position = .zero
        strip.zPosition = -5
        addChild(strip)

        let grassLine = SKShapeNode(rectOf: CGSize(width: w, height: 6))
        grassLine.fillColor = SKColor(red: 0.32, green: 0.62, blue: 0.28, alpha: 1)
        grassLine.strokeColor = .clear
        grassLine.position = CGPoint(x: w / 2, y: groundHeight - 3)
        grassLine.zPosition = -4
        addChild(grassLine)
    }

    // MARK: - Bubu (sprite) & rides

    func targetHeight(for ride: RideType) -> CGFloat {
        rideVisualDisplaySize(for: ride).height
    }

    /// On-screen ride size in points (not PNG pixels). Keeps rides consistent regardless of texture bounds.
    func rideVisualDisplaySize(for ride: RideType) -> CGSize {
        switch ride {
        case .run:
            return CGSize(width: 83, height: 128)
        case .bike:
            return CGSize(width: 117, height: 124)
        case .scooter:
            return CGSize(width: 105, height: 122)
        case .skate:
            return CGSize(width: 94, height: 108)
        }
    }

    func applyRideLockedDisplaySize(for ride: RideType) {
        let display = rideVisualDisplaySize(for: ride)
        playerRoot.size = display
        playerRoot.setScale(1)
        playerUniformBaseScale = 1
    }

    /// Uses catalog image when present; otherwise falls back so the game never crashes on a missing asset.
    func resolvedAssetName(for ride: RideType) -> String {
        if UIImage(named: ride.assetName) != nil {
            return ride.assetName
        }
        return "bubu"
    }

    /// Pushes run-start inventory/lives/ground layout into SwiftUI after `didMove` completes.
    private func applyDeferredSwiftUIReset() {
        let groundTop = size.height - groundHeight
        deferSwiftUIState { [weak self] in
            guard let self else { return }
            self.lionBinding?.wrappedValue = 0
            self.elephantBinding?.wrappedValue = 0
            self.giraffeBinding?.wrappedValue = 0
            self.livesBinding?.wrappedValue = self.lives
            self.onGroundTopChanged?(groundTop)
        }
    }

    func makePlayerSprite() -> SKSpriteNode {
        let texture: SKTexture
        if let first = bubuRunTextures?.first {
            texture = first
        } else {
            texture = GameTextures.named(resolvedAssetName(for: .run))
        }
        let sprite = SKSpriteNode(texture: texture)
        sprite.name = "player"
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        return sprite
    }
}
