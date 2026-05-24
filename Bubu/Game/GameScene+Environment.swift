//
//  GameScene+Environment.swift
//  Bubu
//

import SpriteKit
import UIKit

// MARK: - Timing & palettes (tune here)

enum SkyEnvironmentTiming {
    /// Full day → sunset → night → day loop (~6 minutes by default).
    static let cycleDuration: TimeInterval = 40

    static let dayHoldDuration: TimeInterval = 10
    static let dayToSunsetDuration: TimeInterval = 5
    static let sunsetHoldDuration: TimeInterval = 5
    static let sunsetToNightDuration: TimeInterval = 5
    static let nightHoldDuration: TimeInterval = 10
    static let nightToDayDuration: TimeInterval = 5

    static var segmentDurations: [TimeInterval] {
        [
            dayHoldDuration,
            dayToSunsetDuration,
            sunsetHoldDuration,
            sunsetToNightDuration,
            nightHoldDuration,
            nightToDayDuration,
        ]
    }
}

private struct SkyGradientPalette {
    let top: SKColor
    let middle: SKColor
    let bottom: SKColor

    static let day = SkyGradientPalette(
        top: SKColor(hex: 0x5DBCEB),
        middle: SKColor(hex: 0x9DE0F4),
        bottom: SKColor(hex: 0xEAFBFF)
    )
    static let sunset = SkyGradientPalette(
        top: SKColor(hex: 0x9B7ACB),
        middle: SKColor(hex: 0xF48BA5),
        bottom: SKColor(hex: 0xFFB77A)
    )
    /// Night sky — darker than original so sunset→night never brightens on the horizon.
    static let night = SkyGradientPalette(
        top: SKColor(hex: 0x101936),
        middle: SKColor(hex: 0x1D315F),
        bottom: SKColor(hex: 0x3F5F91)
    )

    static func blendedBottomColor(
        dayWeight: CGFloat,
        sunsetWeight: CGFloat,
        nightWeight: CGFloat
    ) -> SKColor {
        let d = Self.day.bottom.skyRGBA
        let s = Self.sunset.bottom.skyRGBA
        let n = Self.night.bottom.skyRGBA
        return SkyRGBA(
            r: d.r * dayWeight + s.r * sunsetWeight + n.r * nightWeight,
            g: d.g * dayWeight + s.g * sunsetWeight + n.g * nightWeight,
            b: d.b * dayWeight + s.b * sunsetWeight + n.b * nightWeight,
            a: d.a * dayWeight + s.a * sunsetWeight + n.a * nightWeight
        ).skColor
    }
}

private struct StarPlacement {
    let xFrac: CGFloat
    let yFrac: CGFloat
    let baseScale: CGFloat
    let textureName: String
    let textureWidth: CGFloat
    let twinklePhase: CGFloat
    let zRotation: CGFloat
}

private enum StarField {
    static let minCount = 9
    static let maxCount = 16
    static let minSpacing: CGFloat = 0.095
    static let xRange: ClosedRange<CGFloat> = 0.06...0.94
    static let yRange: ClosedRange<CGFloat> = 0.72...0.96
    static let baseScaleRange: ClosedRange<CGFloat> = 0.92...1.08
    static let baseScalePreferred: ClosedRange<CGFloat> = 0.6...1.04
    static let twinklePhaseMax: CGFloat = 3.5
    static let textureNames = ["star1", "star2", "star3"]
    static let maxCandidateAttempts = 50
    static let moonYFrac: CGFloat = 0.78
    static let moonAvoidRadius: CGFloat = 0.12
    static let peakAlpha: CGFloat = 0.75
    static let twinkleMin: CGFloat = 0.92
    static let twinkleMax: CGFloat = 1.00
    static let rotationDegreesRange: ClosedRange<CGFloat> = -15...15
    /// Screen-width fraction used for uniform on-screen star size (independent of texture pixel dimensions).
    static let screenWidthScale: CGFloat = 0.04
}

/// Per-frame sky alphas (sum ≤ 1 during transitions); drives pre-baked gradient layers.
private struct SkyPhaseState {
    let dayAlpha: CGFloat
    let sunsetAlpha: CGFloat
    let nightAlpha: CGFloat

    var dayInfluence: CGFloat { dayAlpha }
    var sunsetInfluence: CGFloat { sunsetAlpha }
    var nightInfluence: CGFloat { nightAlpha }

    var backgroundBottomColor: SKColor {
        SkyGradientPalette.blendedBottomColor(
            dayWeight: dayAlpha,
            sunsetWeight: sunsetAlpha,
            nightWeight: nightAlpha
        )
    }
}

// MARK: - Controller

final class SkyEnvironmentController {
    enum Z {
        static let sky: CGFloat = -50
        static let stars: CGFloat = -46
        static let moon: CGFloat = -47
        static let clouds: CGFloat = -45
        static let atmosphere: CGFloat = -44
    }

    private weak var scene: GameScene?
    private let root = SKNode()
    private var daySky: SKSpriteNode?
    private var sunsetSky: SKSpriteNode?
    private var nightSky: SKSpriteNode?
    private var moon: SKSpriteNode?
    private let starsContainer = SKNode()
    private let cloudsContainer = SKNode()
    private var atmosphere: SKSpriteNode?
    private var clouds: [SKSpriteNode] = []
    private var stars: [SKSpriteNode] = []
    private var starPlacements: [StarPlacement] = []
    private let starFieldSeed: UInt64
    /// Night visibility scalar for all stars (updated each frame; avoids per-star userData alpha reads).
    private var starNightVisibility: CGFloat = 0

    private var elapsed: TimeInterval = 0
    private var didReportNightThisCycle = false
    private let moonOnLeft: Bool
    private let moonWidthFraction: CGFloat = 0.14
    #if DEBUG
    private var lastPaletteDebugKey: String?
    #endif

    init(scene: GameScene) {
        self.scene = scene
        moonOnLeft = Bool.random()
        starFieldSeed = UInt64.random(in: .min ... .max)
    }

    func attach(to scene: GameScene) {
        detach()
        self.scene = scene

        root.name = "environment"
        root.zPosition = Z.sky
        scene.addChild(root)

        let day = makeSkyLayer(name: "daySky", z: 0)
        let sunset = makeSkyLayer(name: "sunsetSky", z: 1)
        let night = makeSkyLayer(name: "nightSky", z: 2)
        daySky = day
        sunsetSky = sunset
        nightSky = night
        root.addChild(day)
        root.addChild(sunset)
        root.addChild(night)

        starsContainer.zPosition = Z.stars - Z.sky
        root.addChild(starsContainer)
        populateStars()

        let moonNode = SKSpriteNode(imageNamed: "moon")
        moonNode.name = "moon"
        moonNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        moonNode.zPosition = Z.moon - Z.sky
        moonNode.alpha = 0
        moon = moonNode
        root.addChild(moonNode)

        cloudsContainer.zPosition = Z.clouds - Z.sky
        root.addChild(cloudsContainer)
        populateClouds()

        let W = max(scene.size.width, 2)
        let H = max(scene.size.height, 2)
        let atmo = SKSpriteNode(color: .white, size: CGSize(width: W, height: H))
        atmo.anchorPoint = CGPoint(x: 0, y: 0)
        atmo.position = .zero
        atmo.zPosition = Z.atmosphere - Z.sky
        atmo.alpha = 0
        atmo.blendMode = .alpha
        atmosphere = atmo
        root.addChild(atmo)

        elapsed = 0
        didReportNightThisCycle = false
        relayout()
    }

    func detach() {
        root.removeFromParent()
        daySky = nil
        sunsetSky = nil
        nightSky = nil
        moon = nil
        atmosphere = nil
        clouds = []
        stars = []
        starPlacements = []
        starNightVisibility = 0
    }

    func relayout() {
        guard let scene else { return }
        let W = max(scene.size.width, 2)
        let H = max(scene.size.height, 2)
        let screen = CGSize(width: W, height: H)

        regenerateSkyTextures(screenSize: screen)
        atmosphere?.size = screen

        if let moon, let tex = moon.texture, tex.size().width > 0.5 {
            let targetW = W * moonWidthFraction
            moon.setScale(targetW / tex.size().width)
            let cornerX: CGFloat = moonOnLeft ? 0.16 : 0.84
            moon.position = CGPoint(x: W * cornerX, y: H * 0.78)
        }

        layoutClouds(screen: screen)
        layoutStars(screen: screen)
        #if DEBUG
        lastPaletteDebugKey = nil
        #endif
        applyVisuals(state: phaseState(at: elapsed))
        twinkleStars()
    }

    func update(deltaTime dt: TimeInterval) {
        elapsed += dt
        if elapsed >= SkyEnvironmentTiming.cycleDuration {
            elapsed = elapsed.truncatingRemainder(dividingBy: SkyEnvironmentTiming.cycleDuration)
        }
        let state = phaseState(at: elapsed)
        reportNightIfNeeded(state: state)
        applyVisuals(state: state)
        driftClouds(deltaTime: dt)
        twinkleStars()
        scene?.backgroundColor = state.backgroundBottomColor
    }

    private func makeSkyLayer(name: String, z: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(color: .clear, size: .zero)
        node.name = name
        node.anchorPoint = CGPoint(x: 0, y: 0)
        node.position = .zero
        node.zPosition = z
        node.alpha = 0
        return node
    }

    /// Called only from `attach` / `relayout` — never from `update`.
    private func regenerateSkyTextures(screenSize: CGSize) {
        let dayTex = SkyGradientTexture.make(size: screenSize, palette: .day)
        let sunsetTex = SkyGradientTexture.make(size: screenSize, palette: .sunset)
        let nightTex = SkyGradientTexture.make(size: screenSize, palette: .night)
        for (node, tex) in [(daySky, dayTex), (sunsetSky, sunsetTex), (nightSky, nightTex)] {
            guard let node else { continue }
            tex.filteringMode = .linear
            node.texture = tex
            node.size = screenSize
            node.position = .zero
        }
    }

    private func reportNightIfNeeded(state: SkyPhaseState) {
        if state.nightAlpha >= 0.92 {
            guard !didReportNightThisCycle else { return }
            didReportNightThisCycle = true
            scene?.onNightReached?()
            return
        }
        if state.dayAlpha >= 0.92 {
            didReportNightThisCycle = false
        }
    }

    // MARK: - Cycle

    private func phaseState(at elapsed: TimeInterval) -> SkyPhaseState {
        let segments = SkyEnvironmentTiming.segmentDurations
        var t = elapsed.truncatingRemainder(dividingBy: SkyEnvironmentTiming.cycleDuration)
        var index = segments.count - 1
        for (i, dur) in segments.enumerated() {
            if t < dur {
                index = i
                break
            }
            t -= dur
        }

        let segmentDuration = segments[index]
        let u = segmentDuration > 0 ? CGFloat(t / segmentDuration) : 0
        let eased = SkyMath.smoothstep(u)

        let state: SkyPhaseState
        switch index {
        case 0:
            state = SkyPhaseState(dayAlpha: 1, sunsetAlpha: 0, nightAlpha: 0)
        case 1:
            state = SkyPhaseState(dayAlpha: 1 - eased, sunsetAlpha: eased, nightAlpha: 0)
        case 2:
            state = SkyPhaseState(dayAlpha: 0, sunsetAlpha: 1, nightAlpha: 0)
        case 3:
            state = SkyPhaseState(dayAlpha: 0, sunsetAlpha: 1 - eased, nightAlpha: eased)
        case 4:
            state = SkyPhaseState(dayAlpha: 0, sunsetAlpha: 0, nightAlpha: 1)
        case 5:
            state = SkyPhaseState(dayAlpha: eased, sunsetAlpha: 0, nightAlpha: 1 - eased)
        default:
            state = SkyPhaseState(dayAlpha: 1, sunsetAlpha: 0, nightAlpha: 0)
        }

        debugLogSkyAlphasIfNeeded(segment: index, u: u, eased: eased, state: state)
        return state
    }

    #if DEBUG
    private func debugLogSkyAlphasIfNeeded(
        segment: Int,
        u: CGFloat,
        eased: CGFloat,
        state: SkyPhaseState
    ) {
        let milestone: String?
        switch segment {
        case 2 where u >= 0.98:
            milestone = "end-sunset-hold"
        case 3 where u < 0.05:
            milestone = "start-sunset-to-night"
        case 3 where u >= 0.45 && u <= 0.55:
            milestone = "mid-sunset-to-night"
        case 3 where u >= 0.98:
            milestone = "end-sunset-to-night"
        default:
            milestone = nil
        }
        guard let milestone else { return }
        let key = "\(segment)-\(milestone)"
        guard key != lastPaletteDebugKey else { return }
        lastPaletteDebugKey = key

        let bot = state.backgroundBottomColor.skyRGBA
        let botL = 0.2126 * bot.r + 0.7152 * bot.g + 0.0722 * bot.b
        print(
            "[SkyEnvironment] \(milestone) u=\(String(format: "%.3f", u)) "
                + "alphas day=\(String(format: "%.2f", state.dayAlpha)) "
                + "sunset=\(String(format: "%.2f", state.sunsetAlpha)) "
                + "night=\(String(format: "%.2f", state.nightAlpha)) "
                + "botL=\(String(format: "%.3f", botL))"
        )
    }
    #else
    private func debugLogSkyAlphasIfNeeded(
        segment: Int,
        u: CGFloat,
        eased: CGFloat,
        state: SkyPhaseState
    ) {}
    #endif

    private func applyVisuals(state: SkyPhaseState) {
        updateSkyAlphas(state: state)
        updateAtmosphere(state: state)
        updateCloudsAppearance(state: state)
        updateStarsAndMoon(state: state)
    }

    // MARK: - Sky

    private func updateSkyAlphas(state: SkyPhaseState) {
        daySky?.alpha = state.dayAlpha
        sunsetSky?.alpha = state.sunsetAlpha
        nightSky?.alpha = state.nightAlpha
    }

    private func updateAtmosphere(state: SkyPhaseState) {
        guard let atmosphere else { return }
        let warm = state.sunsetInfluence * 0.22 + state.nightInfluence * 0.05
        atmosphere.color = SKColor(red: 1, green: 0.82, blue: 0.72, alpha: 1)
        atmosphere.colorBlendFactor = warm
        atmosphere.alpha = warm * 0.35
    }

    // MARK: - Clouds

    private func populateClouds() {
        clouds = []
        let specs: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            ("cloud1", 0.42, 9, 0.95, 0.72),
            ("cloud2", 0.28, 6, 0.88, 0.82),
            ("cloud3", 0.36, 11, 0.92, 0.64),
            ("cloud4", 0.22, 5, 0.85, 0.76),
        ]
        for spec in specs {
            let node = SKSpriteNode(imageNamed: spec.0)
            node.name = spec.0
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.userData = NSMutableDictionary()
            node.userData?["baseScale"] = spec.1
            node.userData?["driftSpeed"] = spec.2
            node.userData?["baseAlpha"] = spec.3
            node.userData?["yFrac"] = spec.4
            cloudsContainer.addChild(node)
            clouds.append(node)
        }
    }

    private func layoutClouds(screen: CGSize) {
        let slots: [CGFloat] = [0.12, 0.38, 0.58, 0.82]
        for (i, cloud) in clouds.enumerated() {
            let baseScale = cloud.userData?["baseScale"] as? CGFloat ?? 0.3
            if let tex = cloud.texture, tex.size().width > 0.5 {
                cloud.setScale((screen.width * baseScale) / tex.size().width)
            }
            let yFrac = cloud.userData?["yFrac"] as? CGFloat ?? 0.7
            cloud.position = CGPoint(
                x: screen.width * slots[i % slots.count],
                y: screen.height * yFrac
            )
        }
    }

    private func driftClouds(deltaTime dt: TimeInterval) {
        guard let scene else { return }
        let W = scene.size.width
        guard W > 1 else { return }
        for cloud in clouds {
            let speed = cloud.userData?["driftSpeed"] as? CGFloat ?? 8
            cloud.position.x -= speed * CGFloat(dt)
            let halfW = cloud.frame.width * 0.5
            if cloud.position.x + halfW < -40 {
                cloud.position.x = W + halfW + 30
            }
        }
    }

    private func updateCloudsAppearance(state: SkyPhaseState) {
        let alpha = SkyMath.lerp(
            SkyMath.lerp(0.92, 0.9, state.sunsetInfluence),
            1.04,
            state.nightInfluence
        )
        let tintDay = SKColor(white: 1, alpha: 1)
        let tintSunset = SKColor(red: 1, green: 0.88, blue: 0.78, alpha: 1)
        let tintNight = SKColor(red: 0.62, green: 0.72, blue: 0.88, alpha: 1)
        var tint = tintDay
        if state.sunsetInfluence > 0.001 {
            tint = tint.mixed(with: tintSunset, t: min(1, state.sunsetInfluence))
        }
        if state.nightInfluence > 0.001 {
            tint = tint.mixed(with: tintNight, t: min(1, state.nightInfluence))
        }

        for cloud in clouds {
            let base = cloud.userData?["baseAlpha"] as? CGFloat ?? 0.9
            cloud.alpha = alpha * base
            cloud.color = tint
            cloud.colorBlendFactor = state.nightInfluence > 0.2 ? 0.55 : (state.sunsetInfluence > 0.2 ? 0.35 : 0.12)
        }
    }

    // MARK: - Stars

    private struct SeededRNG {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed == 0 ? 0xA5A5_A5A5_A5A5_A5A5 : seed
        }

        mutating func nextUnit() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return CGFloat((state >> 11) & 0x1FFFFF) / CGFloat(0x1FFFFF)
        }

        mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
            range.lowerBound + (range.upperBound - range.lowerBound) * nextUnit()
        }

        mutating func nextInt(in range: ClosedRange<Int>) -> Int {
            let span = range.upperBound - range.lowerBound + 1
            return range.lowerBound + Int(nextUnit() * CGFloat(span)) % span
        }

        mutating func pick<T>(_ items: [T]) -> T? {
            guard !items.isEmpty else { return nil }
            return items[nextInt(in: 0...(items.count - 1))]
        }
    }

    private func resolvedStarTextureNames() -> [String] {
        let available = StarField.textureNames.filter { UIImage(named: $0) != nil }
        if available.isEmpty {
            return StarField.textureNames
        }
        return available
    }

    private func moonXFrac() -> CGFloat {
        moonOnLeft ? 0.16 : 0.84
    }

    private func isTooCloseToMoon(xFrac: CGFloat, yFrac: CGFloat) -> Bool {
        let dx = xFrac - moonXFrac()
        let dy = yFrac - StarField.moonYFrac
        let r = StarField.moonAvoidRadius
        return dx * dx + dy * dy < r * r
    }

    private func isTooCloseToExistingPlacements(
        xFrac: CGFloat,
        yFrac: CGFloat,
        existing: [StarPlacement]
    ) -> Bool {
        let minDist = StarField.minSpacing
        for placed in existing {
            let dx = xFrac - placed.xFrac
            let dy = yFrac - placed.yFrac
            if dx * dx + dy * dy < minDist * minDist {
                return true
            }
        }
        return false
    }

    private func generateStarPlacements() -> [StarPlacement] {
        var rng = SeededRNG(seed: starFieldSeed)
        let textures = resolvedStarTextureNames()
        let targetCount = rng.nextInt(in: StarField.minCount...StarField.maxCount)
        var placements: [StarPlacement] = []
        placements.reserveCapacity(targetCount)

        var attempts = 0
        let attemptLimit = targetCount * StarField.maxCandidateAttempts

        while placements.count < targetCount, attempts < attemptLimit {
            attempts += 1
            let xFrac = rng.nextCGFloat(in: StarField.xRange)
            let yFrac = rng.nextCGFloat(in: StarField.yRange)

            if isTooCloseToMoon(xFrac: xFrac, yFrac: yFrac) { continue }
            if isTooCloseToExistingPlacements(xFrac: xFrac, yFrac: yFrac, existing: placements) {
                continue
            }

            let baseScale: CGFloat
            if rng.nextUnit() < 0.75 {
                baseScale = rng.nextCGFloat(in: StarField.baseScalePreferred)
            } else {
                baseScale = rng.nextCGFloat(in: StarField.baseScaleRange)
            }

            guard let textureName = rng.pick(textures) else { continue }

            let tex = GameTextures.named(textureName)
            let textureWidth = max(tex.size().width, 1)
            let rotationDegrees = rng.nextCGFloat(in: StarField.rotationDegreesRange)

            placements.append(
                StarPlacement(
                    xFrac: xFrac,
                    yFrac: yFrac,
                    baseScale: baseScale,
                    textureName: textureName,
                    textureWidth: textureWidth,
                    twinklePhase: rng.nextCGFloat(in: 0...StarField.twinklePhaseMax),
                    zRotation: rotationDegrees * (.pi / 180)
                )
            )
        }

        return placements
    }

    private func populateStars() {
        stars = []
        if starPlacements.isEmpty {
            starPlacements = generateStarPlacements()
        }

        for p in starPlacements {
            let star = SKSpriteNode(texture: GameTextures.named(p.textureName))
            star.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            star.zRotation = p.zRotation
            star.alpha = 0
            star.userData = NSMutableDictionary()
            star.userData?["xFrac"] = NSNumber(value: Double(p.xFrac))
            star.userData?["yFrac"] = NSNumber(value: Double(p.yFrac))
            star.userData?["baseScale"] = NSNumber(value: Double(p.baseScale))
            star.userData?["textureWidth"] = NSNumber(value: Double(p.textureWidth))
            star.userData?["twinklePhase"] = NSNumber(value: Double(p.twinklePhase))
            starsContainer.addChild(star)
            stars.append(star)
        }
    }

    private func layoutStars(screen: CGSize) {
        for star in stars {
            let xFrac = userDataCGFloat(star.userData, key: "xFrac") ?? 0.5
            let yFrac = userDataCGFloat(star.userData, key: "yFrac") ?? 0.9
            let baseScale = userDataCGFloat(star.userData, key: "baseScale") ?? 0.95
            let textureWidth = userDataCGFloat(star.userData, key: "textureWidth") ?? 1
            let targetWidth = screen.width * StarField.screenWidthScale * baseScale
            star.setScale(targetWidth / textureWidth)
            star.position = CGPoint(x: screen.width * xFrac, y: screen.height * yFrac)
        }
    }

    private func twinkleStars() {
        guard starNightVisibility > 0.001 else {
            for star in stars where star.alpha > 0.001 {
                star.alpha = 0
            }
            return
        }

        let twinkleSpan = StarField.twinkleMax - StarField.twinkleMin
        for star in stars {
            let phase = userDataCGFloat(star.userData, key: "twinklePhase") ?? 0
            let shimmer = StarField.twinkleMin + twinkleSpan * (0.5 + 0.5 * sin(elapsed * 1.4 + Double(phase)))
            star.alpha = starNightVisibility * shimmer
        }
    }

    /// Stars fade in with night, stay up while the sky still reads dark, fade out when day wins.
    private func starVisibility(state: SkyPhaseState) -> CGFloat {
        let rise = SkyMath.smoothstep(
            SkyMath.clamp((state.nightInfluence - 0.05) / 0.55, min: 0, max: 1)
        )
        let fadeForDay = 1 - SkyMath.smoothstep(
            SkyMath.clamp((state.dayInfluence - 0.50) / 0.30, min: 0, max: 1)
        )
        return rise * fadeForDay
    }

    private func updateStarsAndMoon(state: SkyPhaseState) {
        starNightVisibility = starVisibility(state: state) * StarField.peakAlpha

        guard let moon else { return }
        let moonRise = SkyMath.smoothstep(
            SkyMath.clamp((state.nightInfluence - 0.12) / 0.65, min: 0, max: 1)
        )
        let fadeBeforeDay = 1 - SkyMath.smoothstep(
            SkyMath.clamp((state.dayInfluence - 0.72) / 0.28, min: 0, max: 1)
        )
        moon.alpha = moonRise * fadeBeforeDay * 0.92
    }

    private func userDataCGFloat(_ userData: NSMutableDictionary?, key: String) -> CGFloat? {
        guard let value = userData?[key] else { return nil }
        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }
        if let cg = value as? CGFloat {
            return cg
        }
        return nil
    }
}

// MARK: - GameScene hooks

extension GameScene {
    func buildEnvironment() {
        skyEnvironment?.detach()
        let controller = SkyEnvironmentController(scene: self)
        skyEnvironment = controller
        controller.attach(to: self)
    }

    func relayoutEnvironmentIfNeeded() {
        skyEnvironment?.relayout()
    }

    func updateEnvironment(deltaTime: TimeInterval) {
        skyEnvironment?.update(deltaTime: deltaTime)
    }
}

// MARK: - Helpers

private enum SkyMath {
    static func smoothstep(_ t: CGFloat) -> CGFloat {
        let x = clamp(t, min: 0, max: 1)
        return x * x * (3 - 2 * x)
    }

    static func clamp(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, v))
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

private enum SkyGradientTexture {
    static func make(size: CGSize, palette: SkyGradientPalette) -> SKTexture {
        let w = max(Int(size.width.rounded()), 2)
        let h = max(Int(size.height.rounded()), 2)
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let cgColors = [
                palette.top.skyCGColor,
                palette.middle.skyCGColor,
                palette.bottom.skyCGColor,
            ] as CFArray
            let locations: [CGFloat] = [0, 0.52, 1]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors,
                locations: locations
            ) {
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: CGFloat(h)),
                    options: []
                )
            } else {
                #if DEBUG
                print("[SkyEnvironment] CGGradient creation failed — filling with blended middle color")
                #endif
                ctx.cgContext.setFillColor(palette.middle.skyCGColor)
                ctx.cgContext.fill(rect)
            }
        }
        return SKTexture(image: image)
    }
}

private struct SkyRGBA {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat

    var isValid: Bool {
        [r, g, b, a].allSatisfy { $0.isFinite && $0 >= -0.001 && $0 <= 1.001 }
            && (r + g + b) > 0.02
    }

    var clamped: SkyRGBA {
        SkyRGBA(
            r: SkyMath.clamp(r, min: 0, max: 1),
            g: SkyMath.clamp(g, min: 0, max: 1),
            b: SkyMath.clamp(b, min: 0, max: 1),
            a: SkyMath.clamp(a, min: 0, max: 1)
        )
    }

    var skColor: SKColor {
        let c = clamped
        return SKColor(red: c.r, green: c.g, blue: c.b, alpha: max(c.a, 0.001))
    }

    var cgColor: CGColor {
        let c = clamped
        let space = CGColorSpaceCreateDeviceRGB()
        let components = [c.r, c.g, c.b, max(c.a, 0.001)]
        return CGColor(colorSpace: space, components: components)
            ?? CGColor(colorSpace: space, components: [0.36, 0.74, 0.96, 1])!
    }
}

private extension SKColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    var skyRGBA: SkyRGBA {
        if let converted = cgColor.converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ), let comps = converted.components, comps.count >= 3 {
            let r = comps[0]
            let g = comps.count > 1 ? comps[1] : r
            let b = comps.count > 2 ? comps[2] : r
            let a = comps.count > 3 ? comps[3] : 1
            return SkyRGBA(r: r, g: g, b: b, a: a).clamped
        }
        #if DEBUG
        print("[SkyEnvironment] failed to read RGB from SKColor — using sky fallback")
        #endif
        return SkyRGBA(r: 0.36, g: 0.74, b: 0.96, a: 1)
    }

    var skyCGColor: CGColor { skyRGBA.cgColor }

    func mixed(with other: SKColor, t: CGFloat) -> SKColor {
        let u = SkyMath.clamp(t, min: 0, max: 1)
        let a = skyRGBA
        let b = other.skyRGBA
        return SkyRGBA(
            r: a.r + (b.r - a.r) * u,
            g: a.g + (b.g - a.g) * u,
            b: a.b + (b.b - a.b) * u,
            a: a.a + (b.a - a.a) * u
        ).skColor
    }

    func isNear(_ other: SKColor, epsilon: CGFloat = 0.012) -> Bool {
        let a = skyRGBA
        let b = other.skyRGBA
        return abs(a.r - b.r) < epsilon
            && abs(a.g - b.g) < epsilon
            && abs(a.b - b.b) < epsilon
    }
}

