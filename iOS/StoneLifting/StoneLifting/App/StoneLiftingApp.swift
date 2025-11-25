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
 
 This variable references a public endpoint through this variable:
 DATABASE_PUBLIC_URL -> RAILWAY_TCP_PROXY_DOMAIN
 Connecting to a public endpoint will incur egress fees. That might happen if this variable, DATABASE_PUBLIC_URL, is used to establish a connection to a database or another service.
 You can avoid the egress fees by switching to a private endpoint (e.g., RAILWAY_PRIVATE_DOMAIN). Check out our documentation for more information!

 DESIGN NOTES:
 • Rework add stone form - feels cluttered and
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
