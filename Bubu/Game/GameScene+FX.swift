//
//  GameScene+FX.swift
//  Bubu
//

import SpriteKit

extension GameScene {
    // MARK: - Juice (visual-only)

    func applyJumpJuice(isSecondJump: Bool = false) {
        let b = playerUniformBaseScale
        playerRoot.removeAction(forKey: "jumpJuice")
        let stretchX: CGFloat = isSecondJump ? 0.94 : 0.96
        let stretchY: CGFloat = isSecondJump ? 1.13 : 1.09
        let squash = SKAction.group([
            SKAction.scaleX(to: b * 1.08, duration: 0.05),
            SKAction.scaleY(to: b * 0.92, duration: 0.05),
        ])
        squash.timingMode = .easeInEaseOut
        let stretch = SKAction.group([
            SKAction.scaleX(to: b * stretchX, duration: 0.07),
            SKAction.scaleY(to: b * stretchY, duration: 0.07),
        ])
        stretch.timingMode = .easeOut
        let restore = SKAction.group([
            SKAction.scaleX(to: b, duration: 0.09),
            SKAction.scaleY(to: b, duration: 0.09),
        ])
        restore.timingMode = .easeOut
        playerRoot.run(SKAction.sequence([squash, stretch, restore]), withKey: "jumpJuice")
    }

    func applyLandJuice() {
        let b = playerUniformBaseScale
        playerRoot.removeAction(forKey: "landJuice")
        let squash = SKAction.group([
            SKAction.scaleX(to: b * 1.1, duration: 0.07),
            SKAction.scaleY(to: b * 0.86, duration: 0.07),
        ])
        squash.timingMode = .easeOut
        let restore = SKAction.group([
            SKAction.scaleX(to: b, duration: 0.09),
            SKAction.scaleY(to: b, duration: 0.09),
        ])
        restore.timingMode = .easeOut
        playerRoot.run(SKAction.sequence([squash, restore]), withKey: "landJuice")
    }

    func restorePlayerUniformScale() {
        let b = playerUniformBaseScale
        playerRoot.xScale = b
        playerRoot.yScale = b
    }

    func playHitShake() {
        func makeShake() -> SKAction {
            let t: TimeInterval = 0.021
            return SKAction.sequence([
                SKAction.moveBy(x: 5, y: 0, duration: t),
                SKAction.moveBy(x: -9, y: 0, duration: t),
                SKAction.moveBy(x: 6, y: 0, duration: t),
                SKAction.moveBy(x: -2, y: 0, duration: t),
            ])
        }
        playerRoot.removeAction(forKey: "hitShake")
        itemsLayer.removeAction(forKey: "hitShake")
        playerRoot.run(makeShake(), withKey: "hitShake")
        itemsLayer.run(makeShake(), withKey: "hitShake")
    }

    func playAnimalPickupSparkle(at position: CGPoint) {
        let colors: [SKColor] = [
            SKColor(red: 1.0, green: 0.95, blue: 0.45, alpha: 1),
            SKColor(red: 1.0, green: 0.65, blue: 0.8, alpha: 1),
            SKColor(red: 0.55, green: 0.95, blue: 0.75, alpha: 1),
        ]
        for i in 0..<7 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...5))
            dot.fillColor = colors[i % colors.count]
            dot.strokeColor = SKColor(white: 1, alpha: 0.25)
            dot.lineWidth = 1
            dot.position = position
            dot.zPosition = 480
            addChild(dot)
            let ox = CGFloat.random(in: -28...28)
            let oy = CGFloat.random(in: 12...38)
            let move = SKAction.moveBy(x: ox, y: oy, duration: 0.24)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.24)
            dot.run(.sequence([.group([move, fade]), .removeFromParent()]))
        }
    }

    func showOopsBubble() {
        let bubuFrame = playerRoot.calculateAccumulatedFrame()
        let bubuTopY = max(bubuFrame.maxY, playerRoot.position.y + 72)
        let cx = min(max(playerRoot.position.x, 78), max(size.width - 78, 78))
        let cy = min(max(bubuTopY + 44, groundHeight + 130), size.height - 72)

        let label = SKLabelNode(text: "Oops")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 40
        label.fontColor = SKColor(red: 244.0 / 255.0, green: 93.0 / 255.0, blue: 126.0 / 255.0, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 640
        label.position = CGPoint(x: cx, y: cy)
        label.name = "oopsBubble"
        addChild(label)

        let rise = SKAction.moveBy(x: 0, y: 28, duration: 0.38)
        rise.timingMode = .easeOut
        let hold = SKAction.wait(forDuration: 0.92)
        let fade = SKAction.fadeOut(withDuration: 0.55)
        label.run(SKAction.sequence([rise, hold, fade, .removeFromParent()]))
    }

    func spawnDroppedAnimalFall(dropped kind: AnimalKind, slot: Int) {
        let tex = SKTexture(imageNamed: kind.textureName)
        tex.filteringMode = .linear
        let sprite = SKSpriteNode(texture: tex)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.name = "dropVisual"
        sprite.zPosition = 425

        let targetH: CGFloat = 46
        let th = tex.size().height
        if th > 0.5 {
            sprite.setScale(targetH / th)
        } else {
            sprite.setScale(0.38)
        }

        let zoneMinX = size.width * 0.15
        let zoneMaxX = size.width * 0.85
        let zoneWidth = max(zoneMaxX - zoneMinX, 1)
        let laneCount = 6
        let laneStep = zoneWidth / CGFloat(max(laneCount - 1, 1))
        let lane = slot % laneCount
        let row = slot / laneCount
        var startX = zoneMinX + CGFloat(lane) * laneStep + CGFloat.random(in: -12...12)
        if row > 0 {
            startX += (row % 2 == 0) ? -8 : 8
        }
        startX = min(max(startX, zoneMinX + 8), zoneMaxX - 8)
        let startY = min(
            max(size.height * 0.7 + CGFloat.random(in: -16...24) - CGFloat(row) * 10, groundHeight + 120),
            size.height - 90
        )
        sprite.position = CGPoint(x: startX, y: startY)

        addChild(sprite)

        let endX = min(max(startX + CGFloat.random(in: -20...20), zoneMinX + 8), zoneMaxX - 8)
        let landY = groundHeight + 12
        let duration: TimeInterval = 0.54 + Double(slot % 4) * 0.05
        let move = SKAction.move(to: CGPoint(x: endX, y: landY), duration: duration)
        move.timingMode = .easeIn
        let spin = SKAction.rotate(byAngle: CGFloat.random(in: -0.22...0.22), duration: duration)
        let settle = SKAction.sequence([
            SKAction.scaleX(to: sprite.xScale * 1.14, duration: 0.07),
            SKAction.scaleX(to: sprite.xScale, duration: 0.09),
        ])
        settle.timingMode = .easeOut
        sprite.run(SKAction.sequence([
            SKAction.group([move, spin]),
            settle,
            SKAction.wait(forDuration: 0.12),
            SKAction.fadeOut(withDuration: 0.22),
            .removeFromParent(),
        ]))
    }

    func playHappyCollect(at position: CGPoint) {
        let colors: [SKColor] = [
            SKColor(red: 1.0, green: 0.92, blue: 0.35, alpha: 1),
            SKColor(red: 1.0, green: 0.55, blue: 0.72, alpha: 1),
            SKColor(red: 0.45, green: 0.95, blue: 0.58, alpha: 1),
            SKColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 1),
        ]
        for i in 0..<12 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 3.5...7))
            dot.fillColor = colors[i % colors.count]
            dot.strokeColor = SKColor(white: 1, alpha: 0.35)
            dot.lineWidth = 1
            dot.position = position
            dot.zPosition = 250
            addChild(dot)
            let ox = CGFloat.random(in: -42...42)
            let oy = CGFloat.random(in: 18...52)
            let move = SKAction.moveBy(x: ox, y: oy, duration: 0.32)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.32)
            dot.run(.sequence([.group([move, fade]), .removeFromParent()]))
        }
    }
}
