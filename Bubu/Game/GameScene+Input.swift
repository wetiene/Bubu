//
//  GameScene+Input.swift
//  Bubu
//

import SpriteKit

extension GameScene {
    // MARK: - Input / jump / collect

    func isGrounded() -> Bool {
        playerRoot.position.y <= groundHeight + 2.5 && velocityY <= 16
    }

    func tryJump() {
        if isStumbling { return }
        guard jumpsRemaining > 0 else { return }

        let grounded = isGrounded()
        let isSecondJump = !grounded && jumpsRemaining == 1
        velocityY = isSecondJump ? secondJumpImpulse : firstJumpImpulse
        jumpsRemaining -= 1
        jumpJuiceWasInAir = true
        applyJumpJuice(isSecondJump: isSecondJump)
    }

    // MARK: - Touches (near-animal first, then exact hit, then jump)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if isGameplayPaused {
            return
        }
        let location = touch.location(in: self)

        if nodes(at: location).contains(where: { $0.name == "flyingToPurse" }) {
            return
        }

        if let near = nearestAnimal(to: location, maxDistance: animalTapSlopPoints) {
            collect(near)
            return
        }

        for node in nodes(at: location) {
            if let animal = animalRoot(from: node), animal.name == "animal" {
                collect(animal)
                return
            }
        }

        tryJump()
    }

    func nearestAnimal(to point: CGPoint, maxDistance: CGFloat) -> SKNode? {
        var best: SKNode?
        var bestD = maxDistance
        for child in itemsLayer.children where child.name == "animal" {
            let d = hypot(point.x - child.position.x, point.y - child.position.y)
            if d < bestD {
                bestD = d
                best = child
            }
        }
        return best
    }

    func animalRoot(from node: SKNode) -> SKNode? {
        var current: SKNode? = node
        while let c = current {
            if c.name == "animal" { return c }
            current = c.parent
        }
        return nil
    }

    func collect(_ animal: SKNode) {
        guard let kind = animalKind(from: animal) else { return }

        let worldStart = itemsLayer.convert(animal.position, to: self)
        let dest = pursePointInScene()
        animal.removeFromParent()
        animal.position = worldStart
        animal.name = "flyingToPurse"
        animal.zPosition = 500
        animal.alpha = 1
        addChild(animal)

        playAnimalPickupSparkle(at: worldStart)

        let duration: TimeInterval = 0.38
        let move = arcMoveToPurse(from: worldStart, to: dest, duration: duration)
        let shrink = SKAction.scale(to: 0.2, duration: duration)
        shrink.timingMode = .easeIn

        let prePop = SKAction.group([
            SKAction.scale(to: 1.18, duration: 0.055),
            SKAction.moveBy(x: 0, y: 8, duration: 0.055),
        ])
        prePop.timingMode = .easeOut
        let settle = SKAction.group([
            SKAction.scale(to: 1.02, duration: 0.05),
            SKAction.moveBy(x: 0, y: -6, duration: 0.05),
        ])
        settle.timingMode = .easeInEaseOut
        let flight = SKAction.group([move, shrink])
        let landFade = SKAction.fadeOut(withDuration: 0.055)
        landFade.timingMode = .easeIn

        let done = SKAction.run { [weak self] in
            animal.removeFromParent()
            self?.registerCollect(kind: kind)
        }

        animal.run(SKAction.sequence([prePop, settle, flight, landFade, done]))
    }
}
