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

private struct SkyGradientPalette: Equatable {
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

    /// Matches `.sunset` at t=0 of sunset→night; bottom is pre-darkened for a monotonic dusk path.
    static let sunsetAdjusted = SkyGradientPalette(
        top: SKColor(hex: 0x9B7ACB),
        middle: SKColor(hex: 0xF48BA5),
        bottom: SKColor(hex: 0xFFB77A)
    )

    func lerp(to other: SkyGradientPalette, t: CGFloat) -> SkyGradientPalette {
        let u = SkyMath.clamp(t, min: 0, max: 1)
        return SkyGradientPalette(
            top: top.mixed(with: other.top, t: u),
            middle: middle.mixed(with: other.middle, t: u),
            bottom: bottom.mixed(with: other.bottom, t: u)
        )
    }

    /// Sunset→night: keep top/middle on schedule; pull the horizon darker a bit earlier.
    func lerpSunsetToNight(t: CGFloat) -> SkyGradientPalette {
        let u = SkyMath.smoothstep(t)
        let uBottom = SkyMath.clamp(u * 1.18, min: 0, max: 1)
        return SkyGradientPalette(
            top: top.mixed(with: SkyGradientPalette.night.top, t: u),
            middle: middle.mixed(with: SkyGradientPalette.night.middle, t: u),
            bottom: bottom.mixed(with: SkyGradientPalette.night.bottom, t: uBottom)
        )
    }
}

/// Per-frame sky state: palette is lerped phase-to-phase; influences drive clouds/stars/moon.
private struct SkyPhaseState {
    let palette: SkyGradientPalette
    let dayInfluence: CGFloat
    let sunsetInfluence: CGFloat
    let nightInfluence: CGFloat
}

// MARK: - Controller

final class SkyEnvironmentController {
    enum Z {
        static let sky: CGFloat = -50
        static let stars: CGFloat = -48
        static let moon: CGFloat = -47
        static let clouds: CGFloat = -45
        static let atmosphere: CGFloat = -44
    }

    private weak var scene: GameScene?
    private let root = SKNode()
    private var skyA: SKSpriteNode?
    private var skyB: SKSpriteNode?
    private var skyCrossfadeFrontIsB = false
    private var moon: SKSpriteNode?
    private let starsContainer = SKNode()
    private let cloudsContainer = SKNode()
    private var atmosphere: SKSpriteNode?
    private var clouds: [SKSpriteNode] = []
    private var stars: [SKSpriteNode] = []

    private var elapsed: TimeInterval = 0
    private var lastPalette: SkyGradientPalette?
    private var lastGradientRebuildTime: TimeInterval = -1
    private let gradientRebuildMinInterval: TimeInterval = 0.12
    private let moonOnLeft: Bool
    private let moonWidthFraction: CGFloat = 0.14
    #if DEBUG
    private var lastPaletteDebugKey: String?
    #endif

    init(scene: GameScene) {
        self.scene = scene
        moonOnLeft = Bool.random()
    }

    func attach(to scene: GameScene) {
        detach()
        self.scene = scene

        root.name = "environment"
        root.zPosition = Z.sky
        scene.addChild(root)

        let W = max(scene.size.width, 2)
        let H = max(scene.size.height, 2)

        let a = SKSpriteNode(color: .clear, size: CGSize(width: W, height: H))
        a.anchorPoint = CGPoint(x: 0, y: 0)
        a.position = .zero
        let b = SKSpriteNode(color: .clear, size: CGSize(width: W, height: H))
        b.anchorPoint = CGPoint(x: 0, y: 0)
        b.position = .zero
        skyA = a
        skyB = b
        root.addChild(a)
        root.addChild(b)

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

        let atmo = SKSpriteNode(color: .white, size: CGSize(width: W, height: H))
        atmo.anchorPoint = CGPoint(x: 0, y: 0)
        atmo.position = .zero
        atmo.zPosition = Z.atmosphere - Z.sky
        atmo.alpha = 0
        atmo.blendMode = .alpha
        atmosphere = atmo
        root.addChild(atmo)

        elapsed = 0
        lastPalette = nil
        relayout()
    }

    func detach() {
        root.removeFromParent()
        skyA = nil
        skyB = nil
        moon = nil
        atmosphere = nil
        clouds = []
        stars = []
        lastPalette = nil
    }

    func relayout() {
        guard let scene else { return }
        let W = max(scene.size.width, 2)
        let H = max(scene.size.height, 2)
        let screen = CGSize(width: W, height: H)

        for sky in [skyA, skyB] {
            sky?.size = screen
            sky?.position = .zero
        }
        atmosphere?.size = screen

        if let moon, let tex = moon.texture, tex.size().width > 0.5 {
            let targetW = W * moonWidthFraction
            moon.setScale(targetW / tex.size().width)
            let cornerX: CGFloat = moonOnLeft ? 0.16 : 0.84
            moon.position = CGPoint(x: W * cornerX, y: H * 0.78)
        }

        layoutClouds(screen: screen)
        layoutStars(screen: screen)
        lastPalette = nil
        lastGradientRebuildTime = -1
        #if DEBUG
        lastPaletteDebugKey = nil
        #endif
        applyVisuals(state: phaseState(at: elapsed), forceGradient: true)
    }

    func update(deltaTime dt: TimeInterval) {
        elapsed += dt
        if elapsed >= SkyEnvironmentTiming.cycleDuration {
            elapsed = elapsed.truncatingRemainder(dividingBy: SkyEnvironmentTiming.cycleDuration)
            lastGradientRebuildTime = -1
        }
        let state = phaseState(at: elapsed)
        applyVisuals(state: state, forceGradient: false)
        driftClouds(deltaTime: dt)
        twinkleStars()
        scene?.backgroundColor = state.palette.bottom
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
            state = SkyPhaseState(
                palette: .day,
                dayInfluence: 1,
                sunsetInfluence: 0,
                nightInfluence: 0
            )
        case 1:
            state = SkyPhaseState(
                palette: SkyGradientPalette.day.lerp(to: .sunset, t: eased),
                dayInfluence: 1 - eased,
                sunsetInfluence: eased,
                nightInfluence: 0
            )
        case 2:
            state = SkyPhaseState(
                palette: .sunset,
                dayInfluence: 0,
                sunsetInfluence: 1,
                nightInfluence: 0
            )
        case 3:
            let palette = SkyGradientPalette.sunsetAdjusted.lerpSunsetToNight(t: u)
            state = SkyPhaseState(
                palette: palette,
                dayInfluence: 0,
                sunsetInfluence: 1 - eased,
                nightInfluence: eased
            )
        case 4:
            state = SkyPhaseState(
                palette: .night,
                dayInfluence: 0,
                sunsetInfluence: 0,
                nightInfluence: 1
            )
        case 5:
            state = SkyPhaseState(
                palette: SkyGradientPalette.night.lerp(to: .day, t: eased),
                dayInfluence: eased,
                sunsetInfluence: 0,
                nightInfluence: 1 - eased
            )
        default:
            state = SkyPhaseState(
                palette: .day,
                dayInfluence: 1,
                sunsetInfluence: 0,
                nightInfluence: 0
            )
        }

        state.palette.debugAssertValid()
        debugLogPaletteIfNeeded(segment: index, u: u, eased: eased, palette: state.palette)
        return state
    }

    #if DEBUG
    private func debugLogPaletteIfNeeded(
        segment: Int,
        u: CGFloat,
        eased: CGFloat,
        palette: SkyGradientPalette
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

        func lum(_ color: SKColor) -> CGFloat {
            let c = color.skyRGBA
            return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        }
        let topL = lum(palette.top)
        let midL = lum(palette.middle)
        let botL = lum(palette.bottom)
        print(
            "[SkyEnvironment] \(milestone) u=\(String(format: "%.3f", u)) eased=\(String(format: "%.3f", eased)) "
                + "lum top=\(String(format: "%.3f", topL)) mid=\(String(format: "%.3f", midL)) bot=\(String(format: "%.3f", botL))"
        )
        if botL > 0.72 {
            print("[SkyEnvironment] warning: bottom luminance unusually high during dusk")
        }
    }
    #else
    private func debugLogPaletteIfNeeded(
        segment: Int,
        u: CGFloat,
        eased: CGFloat,
        palette: SkyGradientPalette
    ) {}
    #endif

    private func applyVisuals(state: SkyPhaseState, forceGradient: Bool) {
        updateSkyGradient(palette: state.palette, force: forceGradient)
        updateAtmosphere(state: state)
        updateCloudsAppearance(state: state)
        updateStarsAndMoon(state: state)
    }

    // MARK: - Sky

    private func updateSkyGradient(palette: SkyGradientPalette, force: Bool) {
        guard let skyA, let skyB, let scene else { return }
        if !force, let last = lastPalette, last == palette { return }
        let sinceLastRebuild = elapsed - lastGradientRebuildTime
        if !force,
           lastPalette != nil,
           sinceLastRebuild >= 0,
           sinceLastRebuild < gradientRebuildMinInterval {
            return
        }

        let tex = SkyGradientTexture.make(size: scene.size, palette: palette)
        tex.filteringMode = .linear

        skyA.removeAllActions()
        skyB.removeAllActions()

        let front = skyCrossfadeFrontIsB ? skyB : skyA
        let back = skyCrossfadeFrontIsB ? skyA : skyB
        front.texture = tex
        front.alpha = 1
        back.texture = tex
        back.alpha = 0

        if lastPalette == nil {
            skyCrossfadeFrontIsB = true
        }

        lastPalette = palette
        lastGradientRebuildTime = elapsed
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
            0.34,
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

    private func populateStars() {
        stars = []
        let textures = ["star1", "stars1", "stars2"]
        let placements: [(CGFloat, CGFloat, CGFloat, Int, CGFloat)] = [
            (0.08, 0.88, 0.5, 0, 0),
            (0.18, 0.92, 0.35, 1, 1.2),
            (0.28, 0.85, 0.4, 2, 2.1),
            (0.42, 0.9, 0.45, 0, 0.8),
            (0.55, 0.86, 0.38, 1, 2.5),
            (0.68, 0.93, 0.42, 2, 1.6),
            (0.78, 0.87, 0.36, 0, 3.2),
            (0.88, 0.91, 0.48, 1, 0.4),
            (0.32, 0.94, 0.32, 2, 1.9),
            (0.62, 0.95, 0.3, 0, 2.8),
        ]
        for p in placements {
            let star = SKSpriteNode(imageNamed: textures[p.3 % textures.count])
            star.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            star.alpha = 0
            star.userData = NSMutableDictionary()
            star.userData?["xFrac"] = p.0
            star.userData?["yFrac"] = p.1
            star.userData?["baseScale"] = p.2
            star.userData?["twinklePhase"] = p.4
            starsContainer.addChild(star)
            stars.append(star)
        }
    }

    private func layoutStars(screen: CGSize) {
        for star in stars {
            let xFrac = star.userData?["xFrac"] as? CGFloat ?? 0.5
            let yFrac = star.userData?["yFrac"] as? CGFloat ?? 0.9
            let baseScale = star.userData?["baseScale"] as? CGFloat ?? 0.4
            if let tex = star.texture, tex.size().width > 0.5 {
                star.setScale((screen.width * 0.04 * baseScale) / tex.size().width)
            }
            star.position = CGPoint(x: screen.width * xFrac, y: screen.height * yFrac)
        }
    }

    private func twinkleStars() {
        for star in stars {
            let phase = star.userData?["twinklePhase"] as? CGFloat ?? 0
            let base = star.userData?["displayAlpha"] as? CGFloat ?? 0
            let twinkle = 0.78 + 0.22 * sin(elapsed * 1.4 + Double(phase))
            star.alpha = base * CGFloat(twinkle)
        }
    }

    private func updateStarsAndMoon(state: SkyPhaseState) {
        let nightRise = SkyMath.smoothstep(
            SkyMath.clamp((state.nightInfluence - 0.05) / 0.55, min: 0, max: 1)
        )
        let starBase = nightRise * 0.55
        for star in stars {
            star.userData?["displayAlpha"] = starBase
        }

        guard let moon else { return }
        let moonRise = SkyMath.smoothstep(
            SkyMath.clamp((state.nightInfluence - 0.12) / 0.65, min: 0, max: 1)
        )
        let fadeBeforeDay = 1 - SkyMath.smoothstep(
            SkyMath.clamp((state.dayInfluence - 0.72) / 0.28, min: 0, max: 1)
        )
        moon.alpha = moonRise * fadeBeforeDay * 0.92
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

private extension SkyGradientPalette {
    static func == (lhs: SkyGradientPalette, rhs: SkyGradientPalette) -> Bool {
        lhs.top.isNear(rhs.top) && lhs.middle.isNear(rhs.middle) && lhs.bottom.isNear(rhs.bottom)
    }

    func debugAssertValid() {
        #if DEBUG
        for (name, color) in [("top", top), ("middle", middle), ("bottom", bottom)] {
            let rgba = color.skyRGBA
            guard rgba.isValid else {
                assertionFailure(
                    "[SkyEnvironment] invalid \(name) sky color r=\(rgba.r) g=\(rgba.g) b=\(rgba.b) a=\(rgba.a)"
                )
                print(
                    "[SkyEnvironment] invalid \(name) sky color r=\(rgba.r) g=\(rgba.g) b=\(rgba.b) a=\(rgba.a)"
                )
                continue
            }
        }
        #endif
    }
}
