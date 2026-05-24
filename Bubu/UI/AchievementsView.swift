//
//  AchievementsView.swift
//  Bubu
//

import SwiftUI

/// Full-screen stickers book (from home). Marks NEW badges seen on appear.
struct AchievementsView: View {
    @ObservedObject var store: AchievementStore
    let onBack: () -> Void

    var body: some View {
        StickersBookContent(store: store, markSeenOnAppear: true) {
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
    }
}

/// Shared stickers grid for home and purse overlay.
struct StickersBookContent<Footer: View>: View {
    @ObservedObject var store: AchievementStore
    var markSeenOnAppear: Bool
    var embedded: Bool = false
    @ViewBuilder var footer: () -> Footer

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        Group {
            if embedded {
                scrollBody
            } else {
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
                    scrollBody
                }
            }
        }
        .onAppear {
            if markSeenOnAppear {
                store.markAchievementsSeen()
            }
        }
    }

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 22) {
                if !embedded {
                    header
                }
                ForEach(AchievementSection.allCases) { section in
                    sectionBlock(section)
                }
                footer()
            }
            .padding(.horizontal, embedded ? 4 : 18)
            .padding(.top, embedded ? 4 : 12)
            .padding(.bottom, embedded ? 8 : 28)
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
                    AchievementBadgeCard(store: store, definition: definition)
                }
            }
        }
    }
}

struct AchievementBadgeCard: View {
    @ObservedObject var store: AchievementStore
    let definition: AchievementDefinition

    private var unlocked: Bool { store.isUnlocked(definition) }
    private var isNew: Bool { store.isNew(definition) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                badgeIcon
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
                .fill(unlocked ? Color.white : Color.white.opacity(0.55))
                .shadow(
                    color: glowColor,
                    radius: isNew ? 12 : (unlocked ? 10 : 0),
                    y: isNew || unlocked ? 3 : 0
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: isNew ? 3.5 : (unlocked ? 3 : 1.5))
        )
        .overlay(alignment: .topLeading) {
            if isNew {
                Text("NEW")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(red: 1.0, green: 0.42, blue: 0.55)))
                    .offset(x: 8, y: 8)
            }
        }
        .opacity(unlocked ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(definition.title)
        .accessibilityValue(accessibilityValueText)
    }

    private var glowColor: Color {
        if isNew {
            return Color(red: 1.0, green: 0.5, blue: 0.75).opacity(0.5)
        }
        return unlocked ? Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.45) : .clear
    }

    private var borderColor: Color {
        if isNew {
            return Color(red: 1.0, green: 0.55, blue: 0.78)
        }
        return unlocked ? Color(red: 1.0, green: 0.82, blue: 0.35) : Color.white.opacity(0.7)
    }

    private var accessibilityValueText: String {
        var parts: [String] = []
        if isNew { parts.append("New") }
        parts.append(unlocked ? "Unlocked" : "Locked")
        parts.append(store.progressText(for: definition))
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var badgeIcon: some View {
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

extension StickersBookContent where Footer == EmptyView {
    init(store: AchievementStore, markSeenOnAppear: Bool, embedded: Bool = false) {
        self.store = store
        self.markSeenOnAppear = markSeenOnAppear
        self.embedded = embedded
        self.footer = { EmptyView() }
    }
}

#Preview {
    AchievementsView(store: .shared, onBack: {})
}
