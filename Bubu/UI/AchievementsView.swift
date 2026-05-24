//
//  AchievementsView.swift
//  Bubu
//

import SwiftUI

struct AchievementsView: View {
    @ObservedObject var store: AchievementStore
    let onBack: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.88, blue: 1.0),
                    Color(red: 0.85, green: 0.95, blue: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header
                    ForEach(AchievementSection.allCases) { section in
                        sectionBlock(section)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Stickers")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.35, green: 0.2, blue: 0.55))

            Text("\(store.unlockedCount()) / \(AchievementDefinition.catalog.count) unlocked")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.6))

            Button(action: onBack) {
                Text("Back Home")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.35, green: 0.55, blue: 0.98))
                    )
            }
            .accessibilityLabel("Back home")
            .padding(.top, 4)
        }
        .padding(.bottom, 6)
    }

    private func sectionBlock(_ section: AchievementSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.rawValue)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.3, green: 0.25, blue: 0.5))
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(AchievementDefinition.definitions(in: section)) { definition in
                    badgeCard(definition)
                }
            }
        }
    }

    private func badgeCard(_ definition: AchievementDefinition) -> some View {
        let unlocked = store.isUnlocked(definition)

        return VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                badgeIcon(definition)
                    .frame(width: 64, height: 64)

                if unlocked {
                    Text("⭐")
                        .font(.system(size: 22))
                        .offset(x: 6, y: -6)
                }
            }

            Text(definition.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(unlocked ? Color(red: 0.2, green: 0.15, blue: 0.35) : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(store.progressText(for: definition))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(unlocked ? Color(red: 0.15, green: 0.55, blue: 0.35) : Color(red: 0.5, green: 0.45, blue: 0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    unlocked
                        ? Color.white
                        : Color.white.opacity(0.55)
                )
                .shadow(
                    color: unlocked ? Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.45) : .clear,
                    radius: unlocked ? 10 : 0,
                    y: unlocked ? 3 : 0
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    unlocked ? Color(red: 1.0, green: 0.82, blue: 0.35) : Color.white.opacity(0.7),
                    lineWidth: unlocked ? 3 : 1.5
                )
        )
        .opacity(unlocked ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(definition.title)
        .accessibilityValue(unlocked ? "Unlocked, \(store.progressText(for: definition))" : "Locked, \(store.progressText(for: definition))")
    }

    @ViewBuilder
    private func badgeIcon(_ definition: AchievementDefinition) -> some View {
        if let imageName = definition.imageName {
            Image(imageName)
                .resizable()
                .scaledToFit()
        } else if let emoji = definition.emoji {
            Text(emoji)
                .font(.system(size: 52))
        } else {
            Text("🏅")
                .font(.system(size: 52))
        }
    }
}

#Preview {
    AchievementsView(store: .shared, onBack: {})
}
