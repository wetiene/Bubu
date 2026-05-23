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
}
