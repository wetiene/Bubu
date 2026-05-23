//
//  GameScene+Spawn.swift
//  Bubu
//

import SpriteKit

extension GameScene {
    // MARK: - Spawning (short obstacles, spaced apart)

    func spawnObstacleIfClear() {
        for _ in 0..<18 {
            let cx = size.width + CGFloat.random(in: 85...210)
            if isSpawnLocationFree(centerX: cx) {
                spawnObstacle(atCenterX: cx)
                return
            }
        }
        spawnObstacle(atCenterX: size.width + 240)
    }

    func spawnAnimalIfClear() {
        for _ in 0..<18 {
            let cx = size.width + CGFloat.random(in: 55...130)
            if isSpawnLocationFree(centerX: cx) {
                spawnAnimal(atCenterX: cx)
                return
            }
        }
        spawnAnimal(atCenterX: size.width + 175)
    }

    func isSpawnLocationFree(centerX: CGFloat) -> Bool {
        for child in itemsLayer.children {
            guard child.name == "obstacle" || child.name == "animal" || child.name == "heartPickup" else { continue }
            if abs(child.position.x - centerX) < minSpawnSeparationX {
                return false
            }
        }
        return true
    }

    func spawnObstacle(atCenterX cx: CGFloat) {
        let all = ObstacleKind.allCases
        let kind = all[Int.random(in: 0..<all.count)]
        let node = makeObstacleSprite(kind: kind)
        if node.userData == nil {
            node.userData = NSMutableDictionary()
        }
        node.userData?["obstacleKind"] = kind.rawValue
        let centerY = groundHeight + kind.groundYOffset
        node.position = CGPoint(x: cx, y: centerY)
        node.name = "obstacle"
        node.zPosition = 20
        itemsLayer.addChild(node)
    }

    func makeObstacleSprite(kind: ObstacleKind) -> SKNode {
        let tex = GameTextures.named(kind.textureName)
        tex.filteringMode = .linear
        let sprite = SKSpriteNode(texture: tex)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        let texH = tex.size().height
        if texH > 0.5 {
            sprite.setScale(kind.targetHeight / texH)
        } else {
            sprite.setScale(0.34)
        }
        return sprite
    }

    func spawnAnimal(atCenterX cx: CGFloat) {
        let all = AnimalKind.allCases
        let kind = all[Int.random(in: 0..<all.count)]
        let node = makeAnimalSprite(kind: kind)
        node.position = CGPoint(x: cx, y: groundHeight + kind.groundYOffset)
        node.name = "animal"
        node.zPosition = 40
        itemsLayer.addChild(node)
    }

    func makeAnimalSprite(kind: AnimalKind) -> SKNode {
        let root = SKNode()
        root.name = "animal"
        let ud = NSMutableDictionary()
        ud["kind"] = kind.rawValue
        root.userData = ud

        let sprite = SKSpriteNode(texture: GameTextures.named(kind.textureName))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.name = "animalSprite"
        let th = kind.targetHeight
        let texH = sprite.texture?.size().height ?? 0
        if texH > 0.5 {
            sprite.setScale(th / texH)
        } else {
            sprite.setScale(0.35)
        }
        root.addChild(sprite)

        addAnimalTapTarget(to: root, scaledHeight: th)
        return root
    }

    func addAnimalTapTarget(to root: SKNode, scaledHeight: CGFloat) {
        let hit = SKShapeNode(circleOfRadius: 118)
        hit.fillColor = SKColor(white: 1, alpha: 0.001)
        hit.strokeColor = .clear
        hit.name = "animalTap"
        hit.zPosition = 50
        hit.position = CGPoint(x: 0, y: scaledHeight * 0.5)
        root.addChild(hit)
    }

    func spawnHeartPickupIfClear() -> Bool {
        for _ in 0..<18 {
            // Spawn a bit farther past the right edge so the heart spends longer on approach (more react time).
            let cx = size.width + CGFloat.random(in: 215...365)
            if isSpawnLocationFree(centerX: cx) {
                spawnHeartPickup(atCenterX: cx)
                return true
            }
        }
        return false
    }

    func spawnHeartPickup(atCenterX cx: CGFloat) {
        let node = makeHeartPickupNode()
        let centerY = heartPickupSpawnY()

        node.position = CGPoint(x: cx, y: centerY)
        node.name = "heartPickup"
        node.zPosition = 46
        itemsLayer.addChild(node)
    }

    func makeHeartPickupNode() -> SKNode {
        let root = SKNode()
        root.name = "heartPickup"

        let texture = GameTextures.named("heart-full")
        texture.filteringMode = .linear
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.name = "heartSprite"
        let targetHeartHeight = 54.0
        let texH = texture.size().height
        let baseScale: CGFloat
        if texH > 0.5 {
            baseScale = targetHeartHeight / texH
        } else {
            baseScale = 0.3
        }
        sprite.setScale(baseScale)
        root.addChild(sprite)

        let halo = SKShapeNode(circleOfRadius: 15)
        halo.fillColor = SKColor(red: 1.0, green: 0.56, blue: 0.75, alpha: 0.18)
        halo.strokeColor = SKColor(red: 1.0, green: 0.8, blue: 0.9, alpha: 0.45)
        halo.lineWidth = 1.3
        halo.zPosition = -1
        root.addChild(halo)

        let bobUp = SKAction.moveBy(x: 0, y: 4, duration: 0.52)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SKAction.moveBy(x: 0, y: -4, duration: 0.52)
        bobDown.timingMode = .easeInEaseOut
        root.run(.repeatForever(.sequence([bobUp, bobDown])), withKey: "heartBob")

        let pulseOut = SKAction.scale(to: baseScale * 1.08, duration: 0.4)
        pulseOut.timingMode = .easeInEaseOut
        let pulseIn = SKAction.scale(to: baseScale, duration: 0.4)
        pulseIn.timingMode = .easeInEaseOut
        sprite.run(.repeatForever(.sequence([pulseOut, pulseIn])), withKey: "heartPulse")

        let tiltRight = SKAction.rotate(toAngle: 0.08, duration: 0.58, shortestUnitArc: true)
        tiltRight.timingMode = .easeInEaseOut
        let tiltLeft = SKAction.rotate(toAngle: -0.08, duration: 0.58, shortestUnitArc: true)
        tiltLeft.timingMode = .easeInEaseOut
        root.run(.repeatForever(.sequence([tiltRight, tiltLeft])), withKey: "heartTilt")

        return root
    }

    func heartPickupSpawnY() -> CGFloat {
        let g = max(abs(gravity), 1)
        let singleJumpApexY = groundHeight + (firstJumpImpulse * firstJumpImpulse) / (2 * g)
        let doubleJumpApexY = singleJumpApexY + (secondJumpImpulse * secondJumpImpulse) / (2 * g)

        // Keep pickups in the upper reachable double-jump band.
        let lower = min(singleJumpApexY + 28, size.height - 180)
        let upper = min(doubleJumpApexY - 38, size.height - 132)
        let safeUpper = max(lower + 10, upper)
        return CGFloat.random(in: lower...safeUpper)
    }
}
