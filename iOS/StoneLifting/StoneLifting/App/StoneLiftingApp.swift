//
//  StoneLiftingApp.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import SwiftUI

/*
 TODO:
 • Optional completion (don't select getting wind by default)
 • Optional weight (might be unknown)
 • Reorder add stone form
 • Fix Associated Domains for AutoFill Passwords (bundleID: com.marfodub.StoneLifting)

 DESIGN NOTES:
 • Icon: SF Symbol circle.dotted.and.circle (rotated, wiggle animation)
 • Make UI less AI-ish
 • Consider sparkle effect for weight estimation feature

 See ROADMAP.md for feature planning
 */

@main
struct StoneLiftingApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
