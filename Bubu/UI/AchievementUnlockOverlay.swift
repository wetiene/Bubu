//
//  AchievementUnlockOverlay.swift
//  Bubu
//

import SwiftUI

struct AchievementUnlockOverlay: View {
    let event: AchievementUnlockEvent

    @State private var appeared = false
    @State private var sparklePhase = false

    var body: some View {
        VStack(spacing: 10) {
            Text("⭐ NEW STICKER!")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.85, green: 0.45, blue: 0.12))

            ZStack {
                badgeIcon
                    .frame(width: 56, height: 56)

                sparkleDots
            }

            Text(event.definition.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.38))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
                .shadow(color: Color(red: 0.55, green: 0.35, blue: 0.9).opacity(0.22), radius: 14, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 1.0, green: 0.86, blue: 0.45), lineWidth: 2.5)
        )
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("New sticker unlocked, \(event.definition.title)")
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.76)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                sparklePhase = true
            }
        }
    }

    @ViewBuilder
    private var badgeIcon: some View {
        let definition = event.definition
        if let imageName = definition.imageName {
            Image(imageName)
                .resizable()
                .scaledToFit()
        } else if let emoji = definition.emoji {
            Text(emoji)
                .font(.system(size: 48))
        } else {
            Text("🏅")
                .font(.system(size: 48))
        }
    }

    private var sparkleDots: some View {
        ZStack {
            Text("✨")
                .font(.system(size: 14))
                .offset(x: -34, y: sparklePhase ? -18 : -14)
                .opacity(sparklePhase ? 1 : 0.55)
            Text("✨")
                .font(.system(size: 12))
                .offset(x: 34, y: sparklePhase ? 16 : 12)
                .opacity(sparklePhase ? 0.7 : 1)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()
        AchievementUnlockOverlay(event: AchievementUnlockEvent(achievementID: .lions10))
            .padding(.top, 60)
    }
}
