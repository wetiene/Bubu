//
//  GameView.swift
//  Bubu
//

import SpriteKit
import SwiftUI

struct GameView: View {
    @Binding var currentRide: RideType
    @State private var livesRemaining: Int = 4
    @State private var lionCount = 0
    @State private var elephantCount = 0
    @State private var giraffeCount = 0
    @AppStorage("bestRunAnimals") private var bestRunAnimals = 0
    @State private var purseOverlayOpen = false
    /// Purse center in SpriteKit scene space; measured from SwiftUI layout.
    @State private var purseSceneTarget: CGPoint?
    @State private var purseShakeSignal = 0
    @State private var purseShakeAngle: Double = 0
    @State private var playerHitSignal = 0
    @State private var playerHealSignal = 0
    @State private var latestRunTotal = 0
    @State private var groundTopY: CGFloat?
    @State private var rideButtonHeight: CGFloat = 0
    @State private var gameOverRunTotal: Int?
    @State private var gameSessionID = UUID()
    @State private var isRestartingRun = false
    @State private var purseBadgeScale: CGFloat = 1
    @State private var purseBadgeOpacity: Double = 1
    @State private var heartScales: [CGFloat] = Array(repeating: 1, count: 4)
    @State private var heartOpacities: [Double] = Array(repeating: 1, count: 4)
    @State private var heartsRowScale: CGFloat = 1
    @State private var heartsRowOpacity: Double = 1
    @State private var isGameOverTransitioning = false
    @State private var runEndBeatToken = 0

    private var totalCollected: Int {
        lionCount + elephantCount + giraffeCount
    }

    private var nextRide: RideType {
        currentRide.nextRide
    }

    private var gameplayOverlayOpen: Bool {
        purseOverlayOpen || gameOverRunTotal != nil || isGameOverTransitioning
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                GameSKBridge(
                    size: geo.size,
                    currentRide: $currentRide,
                    lionCount: $lionCount,
                    elephantCount: $elephantCount,
                    giraffeCount: $giraffeCount,
                    gameplayPaused: gameplayOverlayOpen,
                    purseCollectTargetInScene: purseSceneTarget,
                    purseShakeSignal: $purseShakeSignal,
                    playerHitSignal: $playerHitSignal,
                    playerHealSignal: $playerHealSignal,
                    latestRunTotal: $latestRunTotal,
                    groundTopY: $groundTopY
                )
                .id(gameSessionID)
                .ignoresSafeArea()

                if !gameplayOverlayOpen {
                    Button {
                        purseOverlayOpen = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image("purse")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                                .rotationEffect(.degrees(purseShakeAngle), anchor: UnitPoint(x: 0.5, y: 0.82))

                            Text("\(totalCollected)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.red.opacity(0.9)))
                                .offset(x: 10, y: -6)
                                .scaleEffect(purseBadgeScale)
                                .opacity(purseBadgeOpacity)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(GameControlPressStyle())
                    .padding(.top, 12)
                    .padding(.leading, 16)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PurseButtonFramePreferenceKey.self,
                                value: proxy.frame(in: .named("playSpace"))
                            )
                        }
                    }
                }
            }
            .coordinateSpace(name: "playSpace")
            .onPreferenceChange(PurseButtonFramePreferenceKey.self) { frame in
                guard frame.size.width > 0.5, frame.size.height > 0.5 else { return }
                purseSceneTarget = CGPoint(
                    x: frame.midX,
                    y: geo.size.height - frame.midY
                )
            }
            .onChange(of: purseShakeSignal) { _, _ in
                Task { @MainActor in
                    withAnimation(.easeOut(duration: 0.07)) { purseShakeAngle = 11 }
                    try? await Task.sleep(for: .milliseconds(72))
                    withAnimation(.easeInOut(duration: 0.09)) { purseShakeAngle = -9 }
                    try? await Task.sleep(for: .milliseconds(95))
                    withAnimation(.easeOut(duration: 0.11)) { purseShakeAngle = 0 }
                }
                Task { @MainActor in
                    withAnimation(.easeOut(duration: 0.08)) {
                        purseBadgeScale = 1.18
                        purseBadgeOpacity = 0.92
                    }
                    try? await Task.sleep(for: .milliseconds(78))
                    withAnimation(.easeOut(duration: 0.12)) {
                        purseBadgeScale = 1
                        purseBadgeOpacity = 1
                    }
                }
            }
            .onPreferenceChange(RideButtonHeightPreferenceKey.self) { height in
                if height > 0.5 {
                    rideButtonHeight = height
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !gameplayOverlayOpen {
                    Button {
                        currentRide = currentRide.nextRide
                    } label: {
                        Text(nextRide.shortLabel)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.black.opacity(0.28))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(GameControlPressStyle())
                    .padding(.leading, 16)
                    .padding(.bottom, rideBottomPadding(sceneHeight: geo.size.height))
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: RideButtonHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if !gameplayOverlayOpen {
                    heartsOverlay
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                }
            }
            .overlay {
                if purseOverlayOpen {
                    purseInventoryOverlay
                }
            }
            .overlay {
                if let runTotal = gameOverRunTotal {
                    GameOverView(
                        runTotal: runTotal,
                        bestRun: bestRunAnimals,
                        onPlayAgain: restartRun
                    )
                }
            }
            .onChange(of: gameOverRunTotal) { _, newValue in
                guard let runTotal = newValue else { return }
                bestRunAnimals = max(bestRunAnimals, runTotal)
                purseOverlayOpen = false
            }
            .onChange(of: playerHitSignal) { _, _ in
                guard !isRestartingRun else { return }
                guard gameOverRunTotal == nil else { return }
                let previousLives = livesRemaining
                let updatedLives = max(0, previousLives - 1)
                livesRemaining = updatedLives
                animateHeartLoss(previousLives: previousLives, updatedLives: updatedLives)
                if updatedLives == 0 {
                    runEndBeatToken += 1
                    let beatToken = runEndBeatToken
                    isGameOverTransitioning = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(280))
                        guard beatToken == runEndBeatToken else { return }
                        guard !isRestartingRun else { return }
                        guard gameOverRunTotal == nil else { return }
                        guard livesRemaining == 0 else {
                            isGameOverTransitioning = false
                            return
                        }
                        gameOverRunTotal = latestRunTotal
                        isGameOverTransitioning = false
                    }
                }
            }
            .onChange(of: playerHealSignal) { _, _ in
                guard !isRestartingRun else { return }
                let previousLives = livesRemaining
                let updatedLives = min(4, previousLives + 1)
                guard updatedLives > previousLives else { return }
                livesRemaining = updatedLives
                animateHeartRefill(refilledIndex: previousLives)
            }
        }
        .background(Color(red: 0.5, green: 0.78, blue: 0.95))
    }

    private var heartsOverlay: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Image(index < livesRemaining ? "heart-full" : "heart-empty")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .scaleEffect(heartScales[index])
                    .opacity(heartOpacities[index])
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
        .scaleEffect(heartsRowScale)
        .opacity(heartsRowOpacity)
    }

    private func rideBottomPadding(sceneHeight: CGFloat) -> CGFloat {
        let desiredBottomInset: CGFloat = 12
        guard let groundTopY else { return desiredBottomInset }
        let groundBandHeight = max(0, sceneHeight - groundTopY)
        let maxBottomPaddingToStayInGround = max(0, groundBandHeight - rideButtonHeight - 2)
        return min(desiredBottomInset, maxBottomPaddingToStayInGround)
    }

    private var purseInventoryOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Purse")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                VStack(spacing: 10) {
                    Text("Current Run Collection")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(totalCollected)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.97, green: 0.34, blue: 0.56))
                    HStack(spacing: 8) {
                        Text("Best Run")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("\(bestRunAnimals)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Text("Hits make you drop animals.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )

                VStack(alignment: .leading, spacing: 16) {
                    animalRow(label: "Lion", count: lionCount, imageName: "lion")
                    animalRow(label: "Elephant", count: elephantCount, imageName: "elephant")
                    animalRow(label: "Giraffe", count: giraffeCount, imageName: "giraffe")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )

                Button {
                    purseOverlayOpen = false
                } label: {
                    Text("Back")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.2, green: 0.55, blue: 0.95))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
    }

    private func animalRow(label: String, count: Int, imageName: String) -> some View {
        HStack(spacing: 14) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("\(label): \(count)")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
        }
    }

    private func restartRun() {
        isRestartingRun = true
        runEndBeatToken += 1
        isGameOverTransitioning = false
        purseOverlayOpen = false
        // Reset hit signal while game over is still active so the onChange guard suppresses it.
        playerHitSignal = 0
        playerHealSignal = 0
        latestRunTotal = 0
        livesRemaining = 4
        heartScales = Array(repeating: 1, count: 4)
        heartOpacities = Array(repeating: 1, count: 4)
        heartsRowScale = 1
        heartsRowOpacity = 1
        purseBadgeScale = 1
        purseBadgeOpacity = 1
        gameOverRunTotal = nil
        lionCount = 0
        elephantCount = 0
        giraffeCount = 0
        gameSessionID = UUID()
        DispatchQueue.main.async {
            isRestartingRun = false
        }
    }

    private func animateHeartLoss(previousLives: Int, updatedLives: Int) {
        guard previousLives > updatedLives else { return }
        let lostIndex = max(0, min(3, updatedLives))
        if previousLives > 0, previousLives <= 4, updatedLives >= 0, updatedLives < 4 {
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.08)) {
                    heartScales[lostIndex] = 1.15
                    heartOpacities[lostIndex] = 0.8
                }
                try? await Task.sleep(for: .milliseconds(86))
                withAnimation(.easeInOut(duration: 0.1)) {
                    heartScales[lostIndex] = 0.78
                    heartOpacities[lostIndex] = 0.3
                }
                try? await Task.sleep(for: .milliseconds(86))
                withAnimation(.easeOut(duration: 0.14)) {
                    heartScales[lostIndex] = 1
                    heartOpacities[lostIndex] = 1
                }
            }
            return
        }

        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.09)) {
                heartsRowScale = 1.04
                heartsRowOpacity = 0.83
            }
            try? await Task.sleep(for: .milliseconds(94))
            withAnimation(.easeOut(duration: 0.12)) {
                heartsRowScale = 1
                heartsRowOpacity = 1
            }
        }
    }

    private func animateHeartRefill(refilledIndex: Int) {
        guard refilledIndex >= 0, refilledIndex < 4 else { return }
        Task { @MainActor in
            heartScales[refilledIndex] = 0.62
            heartOpacities[refilledIndex] = 0.4
            withAnimation(.easeOut(duration: 0.1)) {
                heartScales[refilledIndex] = 1.26
                heartOpacities[refilledIndex] = 1
            }
            try? await Task.sleep(for: .milliseconds(94))
            withAnimation(.easeInOut(duration: 0.13)) {
                heartScales[refilledIndex] = 1
                heartOpacities[refilledIndex] = 1
            }
        }
    }
}

// MARK: - UIKit bridge

private struct PurseButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.size.width > 0.5, next.size.height > 0.5 {
            value = next
        }
    }
}

private struct RideButtonHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0.5 {
            value = next
        }
    }
}

private struct GameControlPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}

private struct GameSKBridge: UIViewRepresentable {
    let size: CGSize
    @Binding var currentRide: RideType
    @Binding var lionCount: Int
    @Binding var elephantCount: Int
    @Binding var giraffeCount: Int
    let gameplayPaused: Bool
    var purseCollectTargetInScene: CGPoint?
    @Binding var purseShakeSignal: Int
    @Binding var playerHitSignal: Int
    @Binding var playerHealSignal: Int
    @Binding var latestRunTotal: Int
    @Binding var groundTopY: CGFloat?

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false
        view.backgroundColor = .clear

        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        scene.bind(
            lion: $lionCount,
            elephant: $elephantCount,
            giraffe: $giraffeCount
        )
        let coordinator = context.coordinator
        coordinator.purseShakeBinding = $purseShakeSignal
        coordinator.hitSignalBinding = $playerHitSignal
        coordinator.healSignalBinding = $playerHealSignal
        coordinator.latestRunTotalBinding = $latestRunTotal
        coordinator.groundTopBinding = $groundTopY
        scene.onPurseShakeRequested = { [weak coordinator] in
            coordinator?.purseShakeBinding?.wrappedValue += 1
        }
        scene.onPlayerHit = { [weak coordinator, weak scene] in
            DispatchQueue.main.async {
                coordinator?.hitSignalBinding?.wrappedValue += 1
                coordinator?.latestRunTotalBinding?.wrappedValue = scene?.totalCollectedThisRun ?? 0
            }
        }
        scene.onPlayerHealed = { [weak coordinator] in
            DispatchQueue.main.async {
                coordinator?.healSignalBinding?.wrappedValue += 1
            }
        }
        scene.onGroundTopChanged = { [weak coordinator] groundTop in
            DispatchQueue.main.async {
                coordinator?.groundTopBinding?.wrappedValue = groundTop
            }
        }
        view.presentScene(scene)
        context.coordinator.scene = scene
        context.coordinator.lastAppliedRide = nil
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        let coordinator = context.coordinator
        coordinator.purseShakeBinding = $purseShakeSignal
        coordinator.hitSignalBinding = $playerHitSignal
        coordinator.healSignalBinding = $playerHealSignal
        coordinator.latestRunTotalBinding = $latestRunTotal
        coordinator.groundTopBinding = $groundTopY
        scene.onPurseShakeRequested = { [weak coordinator] in
            coordinator?.purseShakeBinding?.wrappedValue += 1
        }
        scene.onPlayerHit = { [weak coordinator, weak scene] in
            DispatchQueue.main.async {
                coordinator?.hitSignalBinding?.wrappedValue += 1
                coordinator?.latestRunTotalBinding?.wrappedValue = scene?.totalCollectedThisRun ?? 0
            }
        }
        scene.onPlayerHealed = { [weak coordinator] in
            DispatchQueue.main.async {
                coordinator?.healSignalBinding?.wrappedValue += 1
            }
        }
        scene.onGroundTopChanged = { [weak coordinator] groundTop in
            DispatchQueue.main.async {
                coordinator?.groundTopBinding?.wrappedValue = groundTop
            }
        }
        scene.syncGameplayPaused(gameplayPaused)
        scene.setPurseCollectDestination(purseCollectTargetInScene)

        if scene.size != size {
            scene.size = size
        }
        if context.coordinator.lastAppliedRide.map({ $0 != currentRide }) ?? true {
            context.coordinator.lastAppliedRide = currentRide
            scene.applyRideVisual(currentRide)
        }
        scene.publishGroundTopChanged()
    }

    static func dismantleUIView(_ uiView: SKView, coordinator: Coordinator) {
        coordinator.scene = nil
        uiView.presentScene(nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var scene: GameScene?
        var lastAppliedRide: RideType?
        var purseShakeBinding: Binding<Int>?
        var hitSignalBinding: Binding<Int>?
        var healSignalBinding: Binding<Int>?
        var latestRunTotalBinding: Binding<Int>?
        var groundTopBinding: Binding<CGFloat?>?
    }
}

#Preview {
    GameView(currentRide: .constant(.run))
}
