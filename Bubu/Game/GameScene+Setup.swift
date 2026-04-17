//
//  GameScene+Setup.swift
//  Bubu
//

import SpriteKit
import SwiftUI
import UIKit

extension GameScene {
    // MARK: - Scene setup

    /// Visual-only; `currentRide` lives in SwiftUI — call this when the binding changes.
    func applyRideVisual(_ ride: RideType) {
        playerRoot.removeAction(forKey: "jumpJuice")
        playerRoot.removeAction(forKey: "landJuice")
        let name = resolvedAssetName(for: ride)
        playerRoot.texture = SKTexture(imageNamed: name)
        let th = targetHeight(for: ride)
        let h = playerRoot.texture?.size().height ?? 0
        if h > 0.5 {
            playerRoot.setScale(th / h)
        } else {
            playerRoot.setScale(0.32)
        }
        playerUniformBaseScale = playerRoot.xScale
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
        lionBinding?.wrappedValue = 0
        elephantBinding?.wrappedValue = 0
        giraffeBinding?.wrappedValue = 0
        velocityY = 0
        coyoteTimer = 0
        jumpBufferTimer = 0
        jumpJuiceWasInAir = false
        playerUniformBaseScale = 1
        jumpsRemaining = maxJumpCount
        peakCollectedThisRun = 0
        totalCollectedThisRun = 0
        runOverDispatched = false

        buildSky()
        buildDistantParallaxIfAssetAvailable()
        buildGround()
        addChild(itemsLayer)

        playerRoot = makePlayerSprite()
        playerRoot.zPosition = 80
        playerRoot.position = CGPoint(x: 140, y: groundHeight)
        playerRoot.zRotation = 0
        addChild(playerRoot)

        timeToNextObstacle = Double.random(in: 7.2...10.0)
        timeToNextAnimal = Double.random(in: 3.4...5.2)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayoutSkyTilesIfPresent()
    }

    // MARK: - World

    /// Repositions/rescales the two sky tiles after `size` changes (e.g. first valid layout after `didMove`).
    func relayoutSkyTilesIfPresent() {
        guard let a = skyTile0, let b = skyTile1 else { return }
        let W = max(size.width, 2)
        let H = max(size.height, 2)

        if skyLoopUsesAssetTexture,
           let tex = a.texture,
           tex.size().width > 0.5,
           tex.size().height > 0.5 {
            tex.filteringMode = .linear
            let th = tex.size().height
            let tw = tex.size().width
            let scale = H / th
            skyTileWidth = tw * scale
            a.colorBlendFactor = 0
            b.colorBlendFactor = 0
            a.anchorPoint = CGPoint(x: 0, y: 0)
            b.anchorPoint = CGPoint(x: 0, y: 0)
            a.zPosition = -40
            b.zPosition = -40
            a.setScale(scale)
            b.setScale(scale)
            a.texture = tex
            b.texture = tex
            a.position = CGPoint(x: 0, y: 0)
            b.position = CGPoint(x: skyTileWidth, y: 0)
        } else {
            skyTileWidth = W
            a.anchorPoint = CGPoint(x: 0, y: 0)
            b.anchorPoint = CGPoint(x: 0, y: 0)
            a.zPosition = -40
            b.zPosition = -40
            a.size = CGSize(width: W, height: H)
            b.size = CGSize(width: W, height: H)
            a.position = CGPoint(x: 0, y: 0)
            b.position = CGPoint(x: W, y: 0)
        }
    }

    /// Called from `didMove(to:)` after `removeAllChildren()` — always rebuilds the two-tile sky layer.
    func buildSky() {
        skyTile0?.removeFromParent()
        skyTile1?.removeFromParent()
        skyTile0 = nil
        skyTile1 = nil
        skyTileWidth = 0
        skyLoopUsesAssetTexture = false

        let W = max(size.width, 2)
        let H = max(size.height, 2)

        if UIImage(named: Self.skyAssetName) == nil {
            print(
                "[Bubu GameScene] SKY: UIImage(named: \"\(Self.skyAssetName)\") is nil — asset missing or imageset PNG not in bundle (see Assets.xcassets/\(Self.skyAssetName).imageset). Using magenta DEBUG fallback (two scrolling tiles)."
            )
            let a = SKSpriteNode(color: SKColor(red: 1.0, green: 0.2, blue: 0.95, alpha: 1), size: CGSize(width: W, height: H))
            let b = SKSpriteNode(color: SKColor(red: 1.0, green: 0.2, blue: 0.95, alpha: 1), size: CGSize(width: W, height: H))
            skyTile0 = a
            skyTile1 = b
            addChild(a)
            addChild(b)
            relayoutSkyTilesIfPresent()
            return
        }

        let tex = SKTexture(imageNamed: Self.skyAssetName)
        tex.filteringMode = .linear
        let th = tex.size().height
        let tw = tex.size().width
        guard th > 0.5, tw > 0.5 else {
            print("[Bubu GameScene] SKY: texture '\(Self.skyAssetName)' has invalid size — using magenta DEBUG fallback.")
            let a = SKSpriteNode(color: SKColor(red: 1.0, green: 0.2, blue: 0.95, alpha: 1), size: CGSize(width: W, height: H))
            let b = SKSpriteNode(color: SKColor(red: 1.0, green: 0.2, blue: 0.95, alpha: 1), size: CGSize(width: W, height: H))
            skyTile0 = a
            skyTile1 = b
            addChild(a)
            addChild(b)
            relayoutSkyTilesIfPresent()
            return
        }

        let a = SKSpriteNode(texture: tex)
        let b = SKSpriteNode(texture: tex)
        skyTile0 = a
        skyTile1 = b
        skyLoopUsesAssetTexture = true
        addChild(a)
        addChild(b)
        relayoutSkyTilesIfPresent()
    }

    func scrollSkyIfNeeded(step: CGFloat) {
        guard let a = skyTile0, let b = skyTile1 else { return }
        let w = skyTileWidth
        guard w > 1 else { return }
        let dx = effectiveScrollSpeed() * skyScrollMultiplier * step
        a.position.x -= dx
        b.position.x -= dx
        if a.position.x + w < 0 {
            a.position.x = b.position.x + w
        }
        if b.position.x + w < 0 {
            b.position.x = a.position.x + w
        }
    }

    /// Two identical wide sprites, bottom-aligned above `groundHeight`, for seamless horizontal wrap.
    func buildDistantParallaxIfAssetAvailable() {
        distantTile0?.removeFromParent()
        distantTile1?.removeFromParent()
        distantTile0 = nil
        distantTile1 = nil
        distantTileWidth = 0

        guard let asset = distantParallaxTileAssetName, UIImage(named: asset) != nil else { return }

        let tex = SKTexture(imageNamed: asset)
        tex.filteringMode = .linear
        let th = tex.size().height
        guard th > 0.5 else { return }

        let targetH = min(size.height * 0.26, 200)
        let scale = targetH / th
        let displayW = tex.size().width * scale
        distantTileWidth = displayW

        let marginAboveGround: CGFloat = 10
        let baseY = groundHeight + marginAboveGround

        let a = SKSpriteNode(texture: tex)
        let b = SKSpriteNode(texture: tex)
        for node in [a, b] {
            node.anchorPoint = CGPoint(x: 0, y: 0)
            node.setScale(scale)
            node.zPosition = -12
        }
        a.position = CGPoint(x: 0, y: baseY)
        b.position = CGPoint(x: displayW, y: baseY)
        addChild(a)
        addChild(b)
        distantTile0 = a
        distantTile1 = b
    }

    func scrollDistantParallaxIfNeeded(step: CGFloat) {
        guard let a = distantTile0, let b = distantTile1 else { return }
        let w = distantTileWidth
        guard w > 1 else { return }
        let dx = effectiveScrollSpeed() * distantParallaxScrollMultiplier * step
        a.position.x -= dx
        b.position.x -= dx
        if a.position.x + w < 0 {
            a.position.x = b.position.x + w
        }
        if b.position.x + w < 0 {
            b.position.x = a.position.x + w
        }
    }

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
        switch ride {
        case .run: return 128
        case .bike: return 124
        case .scooter: return 126
        case .skate: return 126
        }
    }

    /// Uses catalog image when present; otherwise falls back so the game never crashes on a missing asset.
    func resolvedAssetName(for ride: RideType) -> String {
        if UIImage(named: ride.assetName) != nil {
            return ride.assetName
        }
        return "bubu"
    }

    func makePlayerSprite() -> SKSpriteNode {
        let name = resolvedAssetName(for: .run)
        let sprite = SKSpriteNode(texture: SKTexture(imageNamed: name))
        sprite.name = "player"
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        return sprite
    }
}
