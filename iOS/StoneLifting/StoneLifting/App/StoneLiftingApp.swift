//
//  StoneLiftingApp.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import SwiftUI

/*
 TODO:
 Cannot show Automatic Strong Passwords for app bundleID: com.marfodub.StoneLifting due to error: Cannot save passwords for this app. Make sure you have set up Associated Domains for your app and AutoFill Passwords is enabled in Settings
 Pull to refresh on stone list causes error - network error please check connection
 - icon8 system sf icons
 or
 􁊕 feature circle.dotted.and.circle in app, rotated so dotted is vertical and with wiggle animation (palette / hierarchical coloring with accent) - wiggle makes it seem like you're picking it up
 Design make less AI - ish pretty obvious
 Claude help document git repo etc
 AI sparkle thing for stone weight estimation
 App Name: Go On
 Subtitle: Pick it up
 Badges for half/full sterker 
 CI/CD
 Localization
 Theming
 Accessibility
 Widgets
 Push
 Apple/Google Sign In
 Run profiler for optimization
 
 ### Recommended Backend Improvements
 1. **Add Database Indexes** (see main README)
 2. **Set up Sentry** for error tracking
 3. **Add rate limiting** for production
 4. **Custom domain** (Railway supports this)

 */

@main
struct StoneLiftingApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
