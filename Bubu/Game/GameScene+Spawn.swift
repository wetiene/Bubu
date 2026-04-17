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
            guard child.name == "obstacle" || child.name == "animal" else { continue }
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
        let tex = SKTexture(imageNamed: kind.textureName)
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

        let sprite = SKSpriteNode(texture: SKTexture(imageNamed: kind.textureName))
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
}
