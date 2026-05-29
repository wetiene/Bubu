//
//  GameTextures.swift
//  Bubu
//

import SpriteKit
import UIKit

enum GameTextures {
    private static var cache: [String: SKTexture] = [:]

    static func named(_ name: String) -> SKTexture {
        if let cached = cache[name] {
            return cached
        }
        let texture = SKTexture(imageNamed: name)
        prepareCartoon(texture)
        cache[name] = texture
        return texture
    }

    /// Returns nil when the asset catalog has no image for `name` (safe fallback checks).
    static func optionalNamed(_ name: String) -> SKTexture? {
        guard UIImage(named: name) != nil else { return nil }
        return named(name)
    }

    static func prepareCartoon(_ texture: SKTexture) {
        texture.filteringMode = .linear
    }
}
