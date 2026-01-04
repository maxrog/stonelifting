//
//  StoneLiftingApp.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import SwiftUI

/*
TODO:
 • Fix Associated Domains for AutoFill Passwords (bundleID: com.marfodub.StoneLifting)
 • Switch DATABASE_PUBLIC_URL to RAILWAY_PRIVATE_DOMAIN to avoid egress fees
   (Currently using DATABASE_PUBLIC_URL -> RAILWAY_TCP_PROXY_DOMAIN)

 DESIGN NOTES:
 • Rework add stone form - feels cluttered
 • Icon: SF Symbol circle.dotted.and.circle (rotated, wiggle animation) - icons 8 (sf icons)
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
