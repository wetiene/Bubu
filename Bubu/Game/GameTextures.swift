//
//  GameTextures.swift
//  Bubu
//

import SpriteKit

enum GameTextures {
    private static var cache: [String: SKTexture] = [:]

    static func named(_ name: String) -> SKTexture {
        if let cached = cache[name] {
            return cached
        }
        let texture = SKTexture(imageNamed: name)
        cache[name] = texture
        return texture
    }
}
