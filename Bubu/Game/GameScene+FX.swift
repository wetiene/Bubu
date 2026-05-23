//
//  GameScene+FX.swift
//  Bubu
//

import SpriteKit
import AudioToolbox

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
        func makeShake(amplitude: CGFloat) -> SKAction {
            let t: TimeInterval = 0.02
            return SKAction.sequence([
                SKAction.moveBy(x: amplitude * 0.65, y: 1.2, duration: t),
                SKAction.moveBy(x: -amplitude, y: -1.6, duration: t),
                SKAction.moveBy(x: amplitude * 0.72, y: 1.0, duration: t),
                SKAction.moveBy(x: -amplitude * 0.4, y: -0.6, duration: t),
                SKAction.moveBy(x: amplitude * 0.2, y: 0, duration: t),
            ])
        }
        playerRoot.removeAction(forKey: "hitShake")
        playerRoot.removeAction(forKey: "hitSquash")
        itemsLayer.removeAction(forKey: "hitShake")
        playerRoot.run(makeShake(amplitude: 14), withKey: "hitShake")
        itemsLayer.run(makeShake(amplitude: 8), withKey: "hitShake")

        let b = playerUniformBaseScale
        let squash = SKAction.group([
            SKAction.scaleX(to: b * 1.08, duration: 0.07),
            SKAction.scaleY(to: b * 0.88, duration: 0.07),
        ])
        squash.timingMode = .easeOut
        let restore = SKAction.group([
            SKAction.scaleX(to: b, duration: 0.12),
            SKAction.scaleY(to: b, duration: 0.12),
        ])
        restore.timingMode = .easeOut
        playerRoot.run(SKAction.sequence([squash, restore]), withKey: "hitSquash")
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
        // Keep landed drops from looking flat by biasing away from near-zero tilt.
        let tiltSign: CGFloat = Bool.random() ? 1 : -1
        let landedTilt = tiltSign * CGFloat.random(in: 0.28...0.62)
        let spin = SKAction.rotate(toAngle: landedTilt, duration: duration)
        spin.timingMode = .easeIn
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

    func playPurseCollectPulse(at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 13)
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.95)
        ring.lineWidth = 2.4
        ring.position = position
        ring.zPosition = 505
        addChild(ring)

        let expand = SKAction.scale(to: 1.55, duration: 0.16)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.16)
        ring.run(.sequence([.group([expand, fade]), .removeFromParent()]))

        for i in 0..<5 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...3.5))
            dot.fillColor = SKColor(red: 1.0, green: 0.95, blue: 0.55, alpha: 1)
            dot.strokeColor = SKColor(white: 1, alpha: 0.35)
            dot.lineWidth = 0.8
            dot.position = position
            dot.zPosition = 504
            addChild(dot)

            let angle = CGFloat(i) * (.pi * 2 / 5) + CGFloat.random(in: -0.18...0.18)
            let radius = CGFloat.random(in: 16...24)
            let move = SKAction.moveBy(x: cos(angle) * radius, y: sin(angle) * radius, duration: 0.17)
            move.timingMode = .easeOut
            let fadeOut = SKAction.fadeOut(withDuration: 0.17)
            dot.run(.sequence([.group([move, fadeOut]), .removeFromParent()]))
        }
    }

    func playHeartHealPickupFX(at position: CGPoint) {
        let heartFlash = SKSpriteNode(texture: SKTexture(imageNamed: "heart-full"))
        heartFlash.zPosition = 560
        heartFlash.position = position
        heartFlash.setScale(0.52)
        addChild(heartFlash)

        let popOut = SKAction.scale(to: 0.9, duration: 0.08)
        popOut.timingMode = .easeOut
        let settle = SKAction.scale(to: 0.68, duration: 0.1)
        settle.timingMode = .easeInEaseOut
        let fade = SKAction.fadeOut(withDuration: 0.08)
        heartFlash.run(.sequence([popOut, settle, .group([fade]), .removeFromParent()]))

        let colors: [SKColor] = [
            SKColor(red: 1.0, green: 0.88, blue: 0.95, alpha: 1),
            SKColor(red: 1.0, green: 0.72, blue: 0.84, alpha: 1),
            SKColor(red: 1.0, green: 0.96, blue: 0.55, alpha: 1),
        ]
        for i in 0..<9 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.4...4.2))
            dot.fillColor = colors[i % colors.count]
            dot.strokeColor = SKColor(white: 1, alpha: 0.28)
            dot.lineWidth = 0.8
            dot.position = position
            dot.zPosition = 552
            addChild(dot)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let radius = CGFloat.random(in: 18...34)
            let rise = CGFloat.random(in: 8...20)
            let move = SKAction.moveBy(x: cos(angle) * radius, y: sin(angle) * radius + rise, duration: 0.23)
            move.timingMode = .easeOut
            let fadeOut = SKAction.fadeOut(withDuration: 0.23)
            dot.run(.sequence([.group([move, fadeOut]), .removeFromParent()]))
        }

        let pulse = SKAction.sequence([
            SKAction.scale(to: playerUniformBaseScale * 1.06, duration: 0.08),
            SKAction.scale(to: playerUniformBaseScale, duration: 0.12),
        ])
        pulse.timingMode = .easeOut
        playerRoot.removeAction(forKey: "healPulse")
        playerRoot.run(pulse, withKey: "healPulse")

        AudioServicesPlaySystemSound(1103)
    }
}
