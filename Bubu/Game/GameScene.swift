//
//  GameScene.swift
//  Bubu
//

import SpriteKit
import SwiftUI
import UIKit

enum RideType: CaseIterable {
    case run
    case bike
    case scooter
    case skate

    var assetName: String {
        switch self {
        case .run: return "bubu"
        case .bike: return "bubu-bike"
        case .scooter: return "bubu-scooter"
        case .skate: return "bubu-skate"
        }
    }

    var shortLabel: String {
        switch self {
        case .run: return "Run"
        case .bike: return "Bike"
        case .scooter: return "Scooter"
        case .skate: return "Skate"
        }
    }

    /// Run → Bike → Scooter → Skate → Run
    var nextRide: RideType {
        switch self {
        case .run: return .bike
        case .bike: return .scooter
        case .scooter: return .skate
        case .skate: return .run
        }
    }
}

/// Collectible animals (textures: "lion", "elephant", "giraffe").
private enum AnimalKind: Int, CaseIterable {
    case lion = 0
    case elephant = 1
    case giraffe = 2

    var textureName: String {
        switch self {
        case .lion: return "lion"
        case .elephant: return "elephant"
        case .giraffe: return "giraffe"
        }
    }

    /// Target on-screen height after scaling (points).
    var targetHeight: CGFloat {
        switch self {
        case .lion: return 108
        case .elephant: return 102
        case .giraffe: return 118
        }
    }

    /// Extra Y added to `groundHeight` so feet sit on the grass if the asset has uneven padding.
    var groundYOffset: CGFloat {
        switch self {
        case .lion: return 0
        case .elephant: return 0
        case .giraffe: return 0
        }
    }
}

final class GameScene: SKScene {
    private var lionBinding: Binding<Int>?
    private var elephantBinding: Binding<Int>?
    private var giraffeBinding: Binding<Int>?

    /// Mirrored from SwiftUI when purse overlay is open — pauses SKView from outside.
    private(set) var gameplayPausedFromUI = false

    private var sceneTime: TimeInterval = 0

    private var isStumbling = false
    private var stumbleElapsed: TimeInterval = 0
    private var invulnerableUntil: TimeInterval = 0

    private var lastUpdateTime: TimeInterval = 0
    private var timeToNextObstacle: TimeInterval = 3.8
    private var timeToNextAnimal: TimeInterval = 3.0

    private let itemsLayer = SKNode()
    private var playerRoot: SKSpriteNode!

    // Tweak: overall difficulty / feel
    private let scrollSpeed: CGFloat = 86
    private let gravity: CGFloat = -1100
    private let jumpImpulse: CGFloat = 1040

    /// Horizontal gap between obstacle/animal spawn centers (reduces tap vs jump conflicts).
    private let minSpawnSeparationX: CGFloat = 310

    /// Near-miss taps still count as collects before a jump is issued.
    private let animalTapSlopPoints: CGFloat = 132

    private var velocityY: CGFloat = 0
    private let groundHeight: CGFloat = 92

    /// Smaller than the sprite — torso / feet only (not hair, not full art bounds).
    private let playerHazardWidth: CGFloat = 24
    private let playerHazardHeight: CGFloat = 28
    private let playerHazardLiftFromFeet: CGFloat = 10

    private var coyoteTimer: CGFloat = 0
    private let coyoteSeconds: CGFloat = 0.16

    private var jumpBufferTimer: CGFloat = 0
    private let jumpBufferSeconds: CGFloat = 0.14

    func bind(
        lion: Binding<Int>,
        elephant: Binding<Int>,
        giraffe: Binding<Int>
    ) {
        lionBinding = lion
        elephantBinding = elephant
        giraffeBinding = giraffe
    }

    func syncGameplayPaused(_ paused: Bool) {
        gameplayPausedFromUI = paused
    }

    /// Top-left purse hotspot in scene coords (matches SwiftUI: leading 16 + half 56, top 12 + half 56).
    private func pursePointInScene() -> CGPoint {
        CGPoint(x: 44, y: size.height - 40)
    }

    private func arcMoveToPurse(from start: CGPoint, to end: CGPoint, duration: TimeInterval) -> SKAction {
        let midX = (start.x + end.x) / 2
        let lift: CGFloat = min(140, size.height * 0.22)
        let control = CGPoint(x: midX, y: max(start.y, end.y) + lift)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return SKAction.follow(path, asOffset: false, orientToPath: false, duration: duration)
    }

    private func animalKind(from animal: SKNode) -> AnimalKind? {
        if let raw = animal.userData?["kind"] as? Int, let k = AnimalKind(rawValue: raw) {
            return k
        }
        return nil
    }

    private func registerCollect(kind: AnimalKind) {
        switch kind {
        case .lion: lionBinding?.wrappedValue += 1
        case .elephant: elephantBinding?.wrappedValue += 1
        case .giraffe: giraffeBinding?.wrappedValue += 1
        }
        playHappyCollect(at: pursePointInScene())
    }

    /// Visual-only; `currentRide` lives in SwiftUI — call this when the binding changes.
    func applyRideVisual(_ ride: RideType) {
        let name = resolvedAssetName(for: ride)
        playerRoot.texture = SKTexture(imageNamed: name)
        let th = targetHeight(for: ride)
        let h = playerRoot.texture?.size().height ?? 0
        if h > 0.5 {
            playerRoot.setScale(th / h)
        } else {
            playerRoot.setScale(0.32)
        }
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

        buildSky()
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

    // MARK: - World

    private func buildSky() {
        let top = SKSpriteNode(color: SKColor(red: 0.62, green: 0.88, blue: 0.98, alpha: 1), size: CGSize(width: max(size.width, 400) * 2, height: size.height))
        top.anchorPoint = CGPoint(x: 0, y: 0)
        top.position = .zero
        top.zPosition = -20
        addChild(top)
    }

    private func buildGround() {
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

    private func targetHeight(for ride: RideType) -> CGFloat {
        switch ride {
        case .run: return 128
        case .bike: return 124
        case .scooter: return 126
        case .skate: return 126
        }
    }

    /// Uses catalog image when present; otherwise falls back so the game never crashes on a missing asset.
    private func resolvedAssetName(for ride: RideType) -> String {
        if UIImage(named: ride.assetName) != nil {
            return ride.assetName
        }
        return "bubu"
    }

    private func makePlayerSprite() -> SKSpriteNode {
        let name = resolvedAssetName(for: .run)
        let sprite = SKSpriteNode(texture: SKTexture(imageNamed: name))
        sprite.name = "player"
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        return sprite
    }

    private func isGrounded() -> Bool {
        playerRoot.position.y <= groundHeight + 2.5 && velocityY <= 16
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        if gameplayPausedFromUI {
            return
        }
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        sceneTime = currentTime
        let step = CGFloat(dt)

        if isStumbling {
            stumbleElapsed += dt
            velocityY += gravity * step
            playerRoot.position.y += velocityY * step
            playerRoot.position.y = max(playerRoot.position.y, groundHeight - 8)

            let wobble = sin(stumbleElapsed * 24) * 0.12
            playerRoot.zRotation = CGFloat(-0.9 + wobble)

            if stumbleElapsed >= 0.4 {
                endStumble()
            }

            for child in itemsLayer.children {
                child.position.x -= scrollSpeed * step
            }
            pruneOffscreen()
            return
        }

        velocityY += gravity * step
        playerRoot.position.y += velocityY * step
        if playerRoot.position.y < groundHeight {
            playerRoot.position.y = groundHeight
            velocityY = 0
        }

        let grounded = isGrounded()
        if grounded {
            coyoteTimer = coyoteSeconds
            if jumpBufferTimer > 0 {
                velocityY = jumpImpulse
                jumpBufferTimer = 0
            }
        } else {
            coyoteTimer = max(0, coyoteTimer - step)
            jumpBufferTimer = max(0, jumpBufferTimer - step)
        }

        for child in itemsLayer.children {
            child.position.x -= scrollSpeed * step
        }

        pruneOffscreen()
        if sceneTime >= invulnerableUntil {
            checkObstacleHits()
        }

        timeToNextObstacle -= dt
        timeToNextAnimal -= dt

        if timeToNextObstacle <= 0, obstacleCount() < 1 {
            spawnObstacleIfClear()
            timeToNextObstacle = Double.random(in: 7.8...11.5)
        }
        if timeToNextAnimal <= 0, animalCount() < 1 {
            spawnAnimalIfClear()
            timeToNextAnimal = Double.random(in: 3.2...5.0)
        }
    }

    private func endStumble() {
        isStumbling = false
        stumbleElapsed = 0
        velocityY = 0
        playerRoot.position.y = groundHeight
        playerRoot.zRotation = 0
        coyoteTimer = coyoteSeconds
        jumpBufferTimer = 0
        invulnerableUntil = sceneTime + 2.85
    }

    private func obstacleCount() -> Int {
        itemsLayer.children.filter { $0.name == "obstacle" }.count
    }

    private func animalCount() -> Int {
        itemsLayer.children.filter { $0.name == "animal" }.count
    }

    private func pruneOffscreen() {
        for child in itemsLayer.children where child.position.x < -220 {
            child.removeFromParent()
        }
    }

    private func checkObstacleHits() {
        let p = playerHazardRect()
        for child in itemsLayer.children where child.name == "obstacle" {
            let o = forgivingObstacleRect(for: child)
            if p.intersects(o) {
                beginStumble()
                return
            }
        }
    }

    /// Tight box above the feet — torso / lower body only (smaller than sprite bounds).
    private func playerHazardRect() -> CGRect {
        let cx = playerRoot.position.x
        let baseY = playerRoot.position.y
        return CGRect(
            x: cx - playerHazardWidth / 2,
            y: baseY + playerHazardLiftFromFeet,
            width: playerHazardWidth,
            height: playerHazardHeight
        )
    }

    /// Much smaller than art — heavy top/front shrink so grazing rarely counts.
    private func forgivingObstacleRect(for obstacle: SKNode) -> CGRect {
        let r = obstacle.calculateAccumulatedFrame()
        let insetX: CGFloat = 18
        let insetTop: CGFloat = 30
        let insetBottom: CGFloat = 2
        return CGRect(
            x: r.minX + insetX,
            y: r.minY + insetBottom,
            width: max(0, r.width - 2 * insetX),
            height: max(0, r.height - insetTop - insetBottom)
        )
    }

    private func beginStumble() {
        guard !isStumbling else { return }
        isStumbling = true
        stumbleElapsed = 0
        velocityY = -280
        coyoteTimer = 0
        jumpBufferTimer = 0
    }

    private func tryJump() {
        if isStumbling { return }
        if isGrounded() || coyoteTimer > 0 {
            velocityY = jumpImpulse
            coyoteTimer = 0
            jumpBufferTimer = 0
            return
        }
        jumpBufferTimer = jumpBufferSeconds
    }

    // MARK: - Spawning (short obstacles, spaced apart)

    private func spawnObstacleIfClear() {
        for _ in 0..<18 {
            let cx = size.width + CGFloat.random(in: 85...210)
            if isSpawnLocationFree(centerX: cx) {
                spawnObstacle(atCenterX: cx)
                return
            }
        }
        spawnObstacle(atCenterX: size.width + 240)
    }

    private func spawnAnimalIfClear() {
        for _ in 0..<18 {
            let cx = size.width + CGFloat.random(in: 55...130)
            if isSpawnLocationFree(centerX: cx) {
                spawnAnimal(atCenterX: cx)
                return
            }
        }
        spawnAnimal(atCenterX: size.width + 175)
    }

    private func isSpawnLocationFree(centerX: CGFloat) -> Bool {
        for child in itemsLayer.children {
            guard child.name == "obstacle" || child.name == "animal" else { continue }
            if abs(child.position.x - centerX) < minSpawnSeparationX {
                return false
            }
        }
        return true
    }

    private func spawnObstacle(atCenterX cx: CGFloat) {
        let kind = Int.random(in: 0...2)
        let node: SKNode
        let centerY: CGFloat
        switch kind {
        case 0:
            node = makeRock()
            centerY = groundHeight + 13
        case 1:
            node = makeHole()
            centerY = groundHeight + 9
        default:
            node = makeRamp()
            centerY = groundHeight + 11
        }
        node.position = CGPoint(x: cx, y: centerY)
        node.name = "obstacle"
        node.zPosition = 20
        itemsLayer.addChild(node)
    }

    private func makeRock() -> SKNode {
        let n = SKNode()
        let body = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -26, y: 0))
        path.addLine(to: CGPoint(x: -14, y: 24))
        path.addLine(to: CGPoint(x: 16, y: 23))
        path.addLine(to: CGPoint(x: 26, y: 0))
        path.closeSubpath()
        body.path = path
        body.fillColor = SKColor(red: 0.58, green: 0.58, blue: 0.62, alpha: 1)
        body.strokeColor = SKColor(white: 0, alpha: 0.1)
        body.lineWidth = 1
        n.addChild(body)
        return n
    }

    private func makeHole() -> SKNode {
        let n = SKNode()
        let pit = SKShapeNode(rectOf: CGSize(width: 70, height: 15), cornerRadius: 6)
        pit.fillColor = SKColor(red: 0.2, green: 0.16, blue: 0.14, alpha: 1)
        pit.strokeColor = .clear
        pit.position = CGPoint(x: 0, y: 5)
        n.addChild(pit)
        let lipL = SKShapeNode(rectOf: CGSize(width: 14, height: 8), cornerRadius: 2)
        lipL.fillColor = SKColor(red: 0.65, green: 0.65, blue: 0.68, alpha: 1)
        lipL.strokeColor = .clear
        lipL.position = CGPoint(x: -34, y: 12)
        n.addChild(lipL)
        let lipR = SKShapeNode(rectOf: CGSize(width: 14, height: 8), cornerRadius: 2)
        lipR.fillColor = SKColor(red: 0.65, green: 0.65, blue: 0.68, alpha: 1)
        lipR.strokeColor = .clear
        lipR.position = CGPoint(x: 34, y: 12)
        n.addChild(lipR)
        return n
    }

    private func makeRamp() -> SKNode {
        let n = SKNode()
        let ramp = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -38, y: 0))
        path.addLine(to: CGPoint(x: 38, y: 0))
        path.addLine(to: CGPoint(x: 8, y: 22))
        path.closeSubpath()
        ramp.path = path
        ramp.fillColor = SKColor(red: 0.8, green: 0.64, blue: 0.44, alpha: 1)
        ramp.strokeColor = SKColor(white: 0, alpha: 0.08)
        ramp.lineWidth = 1
        n.addChild(ramp)
        return n
    }

    private func spawnAnimal(atCenterX cx: CGFloat) {
        let all = AnimalKind.allCases
        let kind = all[Int.random(in: 0..<all.count)]
        let node = makeAnimalSprite(kind: kind)
        node.position = CGPoint(x: cx, y: groundHeight + kind.groundYOffset)
        node.name = "animal"
        node.zPosition = 40
        itemsLayer.addChild(node)
    }

    private func makeAnimalSprite(kind: AnimalKind) -> SKNode {
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

    private func addAnimalTapTarget(to root: SKNode, scaledHeight: CGFloat) {
        let hit = SKShapeNode(circleOfRadius: 118)
        hit.fillColor = SKColor(white: 1, alpha: 0.001)
        hit.strokeColor = .clear
        hit.name = "animalTap"
        hit.zPosition = 50
        hit.position = CGPoint(x: 0, y: scaledHeight * 0.5)
        root.addChild(hit)
    }

    // MARK: - Touches (near-animal first, then exact hit, then jump)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if gameplayPausedFromUI {
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

    private func nearestAnimal(to point: CGPoint, maxDistance: CGFloat) -> SKNode? {
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

    private func animalRoot(from node: SKNode) -> SKNode? {
        var current: SKNode? = node
        while let c = current {
            if c.name == "animal" { return c }
            current = c.parent
        }
        return nil
    }

    private func collect(_ animal: SKNode) {
        guard let kind = animalKind(from: animal) else { return }

        let worldStart = itemsLayer.convert(animal.position, to: self)
        animal.removeFromParent()
        animal.position = worldStart
        animal.name = "flyingToPurse"
        animal.zPosition = 500
        addChild(animal)

        let dest = pursePointInScene()
        let duration: TimeInterval = 0.38
        let move = arcMoveToPurse(from: worldStart, to: dest, duration: duration)
        let shrink = SKAction.scale(to: 0.2, duration: duration)
        shrink.timingMode = .easeIn

        let done = SKAction.run { [weak self] in
            animal.removeFromParent()
            self?.registerCollect(kind: kind)
        }

        animal.run(SKAction.sequence([SKAction.group([move, shrink]), done]))
    }

    private func playHappyCollect(at position: CGPoint) {
        let colors: [SKColor] = [
            SKColor(red: 1.0, green: 0.92, blue: 0.35, alpha: 1),
            SKColor(red: 1.0, green: 0.55, blue: 0.72, alpha: 1),
            SKColor(red: 0.45, green: 0.95, blue: 0.58, alpha: 1),
            SKColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 1),
        ]
        for i in 0..<9 {
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
