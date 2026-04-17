//
//  GameView.swift
//  Bubu
//

import SpriteKit
import SwiftUI

struct GameView: View {
    @Binding var currentRide: RideType
    @State private var lionCount = 0
    @State private var elephantCount = 0
    @State private var giraffeCount = 0
    @State private var purseOverlayOpen = false
    /// Purse center in SpriteKit scene space; measured from SwiftUI layout.
    @State private var purseSceneTarget: CGPoint?

    private var totalCollected: Int {
        lionCount + elephantCount + giraffeCount
    }

    private var nextRide: RideType {
        currentRide.nextRide
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
                    gameplayPaused: $purseOverlayOpen,
                    purseCollectTargetInScene: purseSceneTarget
                )
                .ignoresSafeArea()

                if !purseOverlayOpen {
                    Button {
                        purseOverlayOpen = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image("purse")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)

                            Text("\(totalCollected)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.red.opacity(0.9)))
                                .offset(x: 10, y: -6)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
            .overlay(alignment: .topTrailing) {
                if !purseOverlayOpen {
                    Button {
                        currentRide = currentRide.nextRide
                    } label: {
                        Text(nextRide.shortLabel)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 92)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.12, green: 0.14, blue: 0.2))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                }
            }
            .overlay {
                if purseOverlayOpen {
                    purseInventoryOverlay
                }
            }
        }
        .background(Color(red: 0.5, green: 0.78, blue: 0.95))
    }

    private var purseInventoryOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Purse")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

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

private struct GameSKBridge: UIViewRepresentable {
    let size: CGSize
    @Binding var currentRide: RideType
    @Binding var lionCount: Int
    @Binding var elephantCount: Int
    @Binding var giraffeCount: Int
    @Binding var gameplayPaused: Bool
    var purseCollectTargetInScene: CGPoint?

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
        view.presentScene(scene)
        context.coordinator.scene = scene
        context.coordinator.lastAppliedRide = nil
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        scene.syncGameplayPaused(gameplayPaused)
        scene.setPurseCollectDestination(purseCollectTargetInScene)
        uiView.isPaused = gameplayPaused

        if scene.size != size {
            scene.size = size
        }
        if context.coordinator.lastAppliedRide.map({ $0 != currentRide }) ?? true {
            context.coordinator.lastAppliedRide = currentRide
            scene.applyRideVisual(currentRide)
        }
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
    }
}

#Preview {
    GameView(currentRide: .constant(.run))
}
