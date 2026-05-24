//
//  AchievementDefinition.swift
//  Bubu
//

import Foundation

enum AchievementID: String, CaseIterable, Identifiable {
    case lions10, lions50, lions100
    case elephants10, elephants50, elephants100
    case giraffes10, giraffes50, giraffes100
    case total10, total50, total100, total250, total500
    case firstJump, firstHeart, firstNight, firstOops, superHelper

    var id: String { rawValue }
}

enum AchievementSection: String, CaseIterable, Identifiable {
    case lions = "Lions"
    case elephants = "Elephants"
    case giraffes = "Giraffes"
    case allAnimals = "All Animals"
    case fun = "Fun Badges"

    var id: String { rawValue }
}

enum AchievementMetric {
    case lions
    case elephants
    case giraffes
    case totalAnimals
    case jumps
    case hearts
    case hits
    case night
    case bestRun
}

struct AchievementDefinition: Identifiable {
    let id: AchievementID
    let title: String
    let threshold: Int
    let metric: AchievementMetric
    let section: AchievementSection
    let imageName: String?
    let emoji: String?

    static let catalog: [AchievementDefinition] = [
        // Lions
        .init(id: .lions10, title: "10 Lions", threshold: 10, metric: .lions, section: .lions, imageName: "lion", emoji: nil),
        .init(id: .lions50, title: "50 Lions", threshold: 50, metric: .lions, section: .lions, imageName: "lion", emoji: nil),
        .init(id: .lions100, title: "100 Lions", threshold: 100, metric: .lions, section: .lions, imageName: "lion", emoji: nil),
        // Elephants
        .init(id: .elephants10, title: "10 Elephants", threshold: 10, metric: .elephants, section: .elephants, imageName: "elephant", emoji: nil),
        .init(id: .elephants50, title: "50 Elephants", threshold: 50, metric: .elephants, section: .elephants, imageName: "elephant", emoji: nil),
        .init(id: .elephants100, title: "100 Elephants", threshold: 100, metric: .elephants, section: .elephants, imageName: "elephant", emoji: nil),
        // Giraffes
        .init(id: .giraffes10, title: "10 Giraffes", threshold: 10, metric: .giraffes, section: .giraffes, imageName: "giraffe", emoji: nil),
        .init(id: .giraffes50, title: "50 Giraffes", threshold: 50, metric: .giraffes, section: .giraffes, imageName: "giraffe", emoji: nil),
        .init(id: .giraffes100, title: "100 Giraffes", threshold: 100, metric: .giraffes, section: .giraffes, imageName: "giraffe", emoji: nil),
        // Total animals
        .init(id: .total10, title: "10 Animals", threshold: 10, metric: .totalAnimals, section: .allAnimals, imageName: nil, emoji: "🐾"),
        .init(id: .total50, title: "50 Animals", threshold: 50, metric: .totalAnimals, section: .allAnimals, imageName: nil, emoji: "🐾"),
        .init(id: .total100, title: "100 Animals", threshold: 100, metric: .totalAnimals, section: .allAnimals, imageName: nil, emoji: "🐾"),
        .init(id: .total250, title: "250 Animals", threshold: 250, metric: .totalAnimals, section: .allAnimals, imageName: nil, emoji: "🐾"),
        .init(id: .total500, title: "500 Animals", threshold: 500, metric: .totalAnimals, section: .allAnimals, imageName: nil, emoji: "🐾"),
        // Fun
        .init(id: .firstJump, title: "First Jump", threshold: 1, metric: .jumps, section: .fun, imageName: nil, emoji: "⬆️"),
        .init(id: .firstHeart, title: "First Heart", threshold: 1, metric: .hearts, section: .fun, imageName: "heart-full", emoji: nil),
        .init(id: .firstNight, title: "First Night", threshold: 1, metric: .night, section: .fun, imageName: "moon", emoji: nil),
        .init(id: .firstOops, title: "First Oops", threshold: 1, metric: .hits, section: .fun, imageName: nil, emoji: "💥"),
        .init(id: .superHelper, title: "Super Helper", threshold: 25, metric: .bestRun, section: .fun, imageName: "purse", emoji: nil),
    ]

    static func definitions(in section: AchievementSection) -> [AchievementDefinition] {
        catalog.filter { $0.section == section }
    }
}
