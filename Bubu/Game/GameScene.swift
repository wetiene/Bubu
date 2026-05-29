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

    var nextRide: RideType {
        switch self {
        case .run: return .bike
        case .bike: return .scooter
        case .scooter: return .skate
        case .skate: return .run
        }
    }
}

enum AnimalKind: Int, CaseIterable {
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

    var targetHeight: CGFloat {
        switch self {
        case .lion: return 108
        case .elephant: return 102
        case .giraffe: return 140
        }
    }

    var groundYOffset: CGFloat {
        switch self {
        case .lion: return 0
        case .elephant: return 0
        case .giraffe: return 0
        }
    }
}

enum ObstacleKind: String, CaseIterable {
    case rock = "rock"
    case bush = "bush"
    case cactus = "cactus"
    case fallenLog = "fallen-log"
    case tallGrass = "tall-grass"

    var textureName: String { rawValue }

    var targetHeight: CGFloat {
        switch self {
        case .rock: return 58
        case .bush: return 52
        case .cactus: return 62
        case .fallenLog: return 46
        case .tallGrass: return 108
        }
    }

    var groundYOffset: CGFloat {
        switch self {
        case .rock: return 0
        case .bush: return 0
        case .cactus: return 0
        case .fallenLog: return 0
        case .tallGrass: return 0
        }
    }
}

final class GameScene: SKScene {
    var lionBinding: Binding<Int>?
    var elephantBinding: Binding<Int>?
    var giraffeBinding: Binding<Int>?

    var gameplayPausedFromUI = false
    var appLifecyclePaused = false
    var purseDestinationFromUI: CGPoint?

    var isGameplayPaused: Bool {
        gameplayPausedFromUI || appLifecyclePaused
    }

    var sceneTime: TimeInterval = 0
    var isStumbling = false
    var stumbleElapsed: TimeInterval = 0
    var invulnerableUntil: TimeInterval = 0

    var lastUpdateTime: TimeInterval = 0
    let maxFrameDelta: TimeInterval = 1.0 / 30.0
    var timeToNextObstacle: TimeInterval = 3.8
    var timeToNextAnimal: TimeInterval = 3.0

    let itemsLayer = SKNode()
    var playerRoot: SKSpriteNode!

    let baseScrollSpeed: CGFloat = 84
    let gravity: CGFloat = -1060
    let firstJumpImpulse: CGFloat = 700
    let secondJumpImpulse: CGFloat = 620
    let maxJumpCount = 2

    let speedStepPerAnimal: CGFloat = 6.00
    let maxScrollSpeed: CGFloat = 240

    var onPurseShakeRequested: (() -> Void)?
    var onPlayerHit: (() -> Void)?
    var onPlayerHealed: (() -> Void)?
    var onGroundTopChanged: ((CGFloat) -> Void)?
    var onAnimalCollected: ((AnimalKind) -> Void)?
    var onJumpPerformed: (() -> Void)?
    var onNightReached: (() -> Void)?

    var skyEnvironment: SkyEnvironmentController?

    let minSpawnSeparationX: CGFloat = 310
    let animalTapSlopPoints: CGFloat = 132

    var velocityY: CGFloat = 0
    var jumpsRemaining = 2
    let groundHeight: CGFloat = 92

    let playerHazardWidth: CGFloat = 24
    let playerHazardHeight: CGFloat = 28
    let playerHazardLiftFromFeet: CGFloat = 10

    var playerUniformBaseScale: CGFloat = 1
    var activeRideVisual: RideType = .run
    var bubuRunTextures: [SKTexture]?
    var bubuBikeTextures: [SKTexture]?
    var bubuScooterTextures: [SKTexture]?
    static let bubuRunAnimationKey = "bubuRunAnimation"
    static let bubuBikeAnimationKey = "bubuBikeAnimation"
    static let bubuScooterAnimationKey = "bubuScooterAnimation"
    static let bubuRunFrameNames = ["bubu-run-1", "bubu-run-2", "bubu-run-3", "bubu-run-4", "bubu-run-5", "bubu-run-6" ,"bubu-run-7" ,"bubu-run-8" ,"bubu-run-9" ,"bubu-run-10" ,"bubu-run-11"]
    static let bubuRunAirborneFrameName = "bubu-run-3"
    static let bubuRunMinFrameCount = 11
    /// Per-frame duration for the 3-step run cycle (playful, not frantic).
    static let bubuRunTimePerFrame: TimeInterval = 0.09
    var playerRunLockedDisplaySize: CGSize?
    var playerBikeLockedDisplaySize: CGSize?
    var playerScooterLockedDisplaySize: CGSize?
    static let bubuScooterExpectedFrameCount = 8
    static let bubuScooterMinFrameCount = 2
    static let bubuScooterAirborneFrameName = "bubu-scooter-3"
    /// Slightly slower than 8-frame rides (catalog currently has 5 scooter frames).
    static let bubuScooterTimePerFrame: TimeInterval = 0.12
    static let bubuBikeFrameNames = [
        "bubu-bike-1", "bubu-bike-2", "bubu-bike-3", "bubu-bike-4",
        "bubu-bike-5", "bubu-bike-6", "bubu-bike-7" ,"bubu-bike-8" 
    ]
    static let bubuBikeAirborneFrameName = "bubu-bike-3"
    static let bubuBikeTimePerFrame: TimeInterval = 0.13
    var jumpJuiceWasInAir = false
    let maxLives = 4
    /// Authoritative run lives; mirrored to SwiftUI via `livesBinding`.
    var lives = 4
    var runEnded = false
    var livesBinding: Binding<Int>?
    var timeToNextHeartPickup: TimeInterval = 7.5
    var heartSpawnCooldownUntil: TimeInterval = 0
    var lastDamageSceneTime: TimeInterval = -100

    func bind(
        lion: Binding<Int>,
        elephant: Binding<Int>,
        giraffe: Binding<Int>,
        lives: Binding<Int>
    ) {
        lionBinding = lion
        elephantBinding = elephant
        giraffeBinding = giraffe
        livesBinding = lives
        deferSwiftUIState { [weak self] in
            guard let self else { return }
            self.livesBinding?.wrappedValue = self.lives
        }
    }

    func syncLivesToUI() {
        performOnMain { [weak self] in
            guard let self else { return }
            self.livesBinding?.wrappedValue = self.lives
        }
    }

    func syncGameplayPaused(_ paused: Bool) {
        gameplayPausedFromUI = paused
        refreshGameplayPauseState()
    }

    func syncAppLifecyclePaused(_ paused: Bool) {
        appLifecyclePaused = paused
        refreshGameplayPauseState()
    }

    func refreshGameplayPauseState() {
        let shouldPause = isGameplayPaused
        guard isPaused != shouldPause else { return }
        isPaused = shouldPause
        resetFrameTiming()
    }

    func setPurseCollectDestination(_ point: CGPoint?) {
        purseDestinationFromUI = point
    }
}
