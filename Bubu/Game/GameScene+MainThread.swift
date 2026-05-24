//
//  GameScene+MainThread.swift
//  Bubu
//

import SwiftUI

extension GameScene {
    func performOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// Defers work to after the current run loop turn — required when mutating SwiftUI bindings
    /// from SpriteKit setup (`didMove`) or `UIViewRepresentable` lifecycle (always async).
    func deferSwiftUIState(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }
}
