# StoneAtlas

A mobile app for discovering, documenting, and tracking stone lifting achievements.

## Overview

StoneAtlas is an iOS app that helps strongman athletes, fitness enthusiasts, and stone lifting communities discover and log natural stones around the world. Find local stones, track your lifts, and share your achievements with the community.

## Features

- **Stone Discovery**: Find nearby stones using interactive maps with clustering
- **AR Weight Estimation**: Estimate stone weight using LiDAR and AR technology
- **Achievement Tracking**: Log your lifts and track personal records
- **Community Sharing**: Discover public stones and share your own
- **Offline Support**: Cache stones and sync when you're back online
- **OAuth Authentication**: Sign in with Apple or Google

## Tech Stack

### iOS App
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI
- **Minimum iOS**: 18.0+
- **Architecture**: MVVM with services layer
- **Key Technologies**:
  - ARKit & LiDAR for weight estimation
  - MapKit for stone discovery
  - Core Location for GPS tracking
  - SwiftData for offline caching
  - Keychain for secure token storage

### Backend
- **Language**: Swift
- **Framework**: Vapor 4
- **Database**: PostgreSQL
- **Authentication**: JWT tokens with OAuth 2.0 (Apple Sign In, Google Sign In)
- **Hosting**: Railway
- **Image Storage**: Cloudinary

## Quick Start

1. Clone the repo
2. Run `scripts/setup-dev.sh`
3. Open `iOS/StoneLifting/StoneLifting.xcodeproj` in Xcode
4. Start the backend with `cd backend && swift run`

## Project Structure

```
stoneatlas/
├── iOS/StoneLifting/           # iOS app
│   └── StoneLifting/
│       ├── App/                # App entry point
│       ├── Models/             # Data models
│       ├── Views/              # SwiftUI views
│       ├── ViewModels/         # View models
│       ├── Services/           # Business logic & API
│       └── Utilities/          # Helpers & constants
└── backend/                    # Vapor backend
    └── Sources/StoneLifting/
        ├── Controllers/        # API endpoints
        ├── Models/             # Database models
        ├── Services/           # Business logic
        └── Migrations/         # Database migrations
```

## Development Workflow

This project includes **8 custom Claude Code slash commands** for automated code quality and analysis:

### Quick Reference
| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/review-staged` | Pre-commit code review | Before every commit |
| `/security-scan` | Security vulnerability scan | Before production deploys |
| `/test-gen` | Generate unit tests | When writing new code |
| `/perf-profile` | Performance profiling | Before releases |
| `/accessibility-audit` | Accessibility compliance | Quarterly audits |
| `/concurrency-review` | Swift 6 concurrency safety | Monthly or after concurrency changes |
| `/swiftui-refactor` | View structure analysis | When views exceed 200 lines |
| `/appstore-changelog` | Release notes generator | Before App Store submissions |

### Detailed Documentation

### `/review-staged` - Pre-Commit Code Review
Reviews all staged changes against CLAUDE.md standards before committing.

**Usage:**
```bash
git add <files>
/review-staged
```

**Checks:**
- Security (no hardcoded secrets, proper Keychain usage, HTTPS only)
- Async/await & concurrency (proper @MainActor, [weak self], task cancellation)
- Memory management (retain cycles, resource cleanup)
- Error handling (custom errors, proper do-catch, no silent failures)
- Code organization (MARK comments, naming conventions, singleton patterns)
- Swift best practices (no force unwraps, proper @Observable usage)

### `/security-scan` - Security Vulnerability Scanner
Scans the entire codebase for security issues, hardcoded secrets, and insecure patterns.

**Usage:**
```bash
/security-scan
```

**Detects:**
- Hardcoded API keys, tokens, passwords
- Insecure data storage (UserDefaults vs Keychain)
- HTTP instead of HTTPS
- Missing input validation
- Sensitive data in logs
- OWASP Mobile Top 10 vulnerabilities
- Code safety issues (force unwraps, unsafe patterns)

### `/test-gen` - Test Generator
Generates comprehensive unit and integration tests for services and ViewModels.

**Usage:**
```bash
/test-gen <file-path-or-class-name>
```

**Examples:**
```bash
/test-gen iOS/StoneLifting/Services/AuthService.swift
/test-gen StoneService
```

**Generates:**
- Happy path tests
- Edge case tests (empty, nil, boundaries)
- Error handling tests
- Async/await tests
- State management tests
- Mock objects and protocols

### `/perf-profile` - Performance Profiler
Analyzes the codebase for performance bottlenecks and optimization opportunities.

**Usage:**
```bash
/perf-profile
```

**Analyzes:**
- Main thread blocking operations
- Memory management (leaks, retain cycles)
- Image & media performance
- Network efficiency
- SwiftUI render performance
- Location service battery impact
- Algorithm complexity
- Task management

### `/accessibility-audit` - Accessibility Auditor
Audits the iOS app for accessibility compliance and WCAG standards.

**Usage:**
```bash
/accessibility-audit
```

**Checks:**
- VoiceOver support (labels, hints, traits)
- Dynamic Type compatibility
- Color contrast (WCAG AA/AAA)
- Touch target sizes (44x44pt minimum)
- Keyboard navigation and focus management
- Reduce motion support
- High contrast mode
- Form accessibility and error announcements

### `/concurrency-review` - Swift Concurrency Expert
Reviews and audits Swift concurrency patterns for Swift 6 readiness and data race safety.

**Usage:**
```bash
/concurrency-review
```

**Analyzes:**
- Actor isolation patterns (@MainActor, actor classes)
- Sendable conformance for types crossing concurrency boundaries
- Task captures and [weak self] usage
- Data race risks in shared mutable state
- Continuation safety and leak prevention
- Task lifecycle management and cancellation
- Thread-safe service patterns

**Prepares for:**
- Swift 6 strict concurrency checking
- Thread Sanitizer validation
- Production stability

### `/swiftui-refactor` - SwiftUI View Analyzer
Analyzes SwiftUI views for structure, performance, and maintainability improvements.

**Usage:**
```bash
/swiftui-refactor
```

**Identifies:**
- Views exceeding 200 lines (extraction candidates)
- Code duplication opportunities
- Business logic in views (should be in ViewModels)
- Missing @ViewBuilder usage
- Complex body computations
- View extraction opportunities
- State management patterns

**Provides:**
- Refactoring recommendations with code examples
- Performance optimization suggestions
- Complexity metrics and health scores

### `/appstore-changelog` - Release Notes Generator
Generates user-facing App Store release notes from git commit history.

**Usage:**
```bash
/appstore-changelog
```

**Generates:**
- App Store release notes (user-friendly language)
- TestFlight beta notes (more technical context)
- Developer CHANGELOG.md entries
- Commit categorization (features, fixes, improvements)

**Features:**
- Translates technical commits to user benefits
- 4000 character App Store limit handling
- Semantic versioning guidance
- Pre-release checklist

**Example:**
```
What's New in Version 1.2:

Point your camera at a stone for instant weight estimation!

NEW FEATURES
• Smart weight estimation using AR
• See groups of nearby stones on the map

IMPROVEMENTS
• 2x faster loading
• Smoother photo uploads
```

---

### Recommended Workflow

**Daily Development:**
```bash
# 1. Write code
# 2. Generate tests
/test-gen MyNewService

# 3. Review before committing
git add .
/review-staged

# 4. Commit if approved
git commit -m "feat: add new feature"
```

**Before Pull Requests:**
```bash
/perf-profile          # Check performance
/concurrency-review    # Verify thread safety
/swiftui-refactor      # Check view structure
```

**Before Releases:**
```bash
/perf-profile          # Final performance check
/security-scan         # Security audit
/accessibility-audit   # Accessibility compliance
/appstore-changelog    # Generate release notes
```

**Monthly Maintenance:**
```bash
/concurrency-review    # Swift 6 readiness
/security-scan         # Security posture
```

---

See [iOS/StoneLifting/ROADMAP.md](iOS/StoneLifting/ROADMAP.md) for future automation tools and feature roadmap.

See [CLAUDE.md](CLAUDE.md) for comprehensive development standards and best practices.

---

## Getting Started

### Prerequisites
- Xcode 16+
- Swift 6.0+
- PostgreSQL (for local backend development)
- Apple Developer account (for testing Sign in with Apple)
- Google Cloud project (for Google Sign In)

### iOS App Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/maxrog/stoneatlas.git
   cd stoneatlas/iOS/StoneLifting
   ```

2. Open the Xcode project:
   ```bash
   open StoneLifting.xcodeproj
   ```

3. Configure API endpoint in `Constants.swift`:
   ```swift
   static let currentEnvironment: Environment = .development
   ```

4. Add your OAuth credentials to `StoneAtlas-Info.plist`

5. Build and run on a physical device (required for LiDAR features)

### Backend Setup

1. Install dependencies:
   ```bash
   cd backend
   swift package resolve
   ```

2. Set up PostgreSQL database:
   ```bash
   createdb vapor_database
   ```

3. Configure environment variables:
   ```bash
   export DATABASE_HOST=localhost
   export DATABASE_NAME=vapor_database
   export DATABASE_USERNAME=vapor_username
   export DATABASE_PASSWORD=vapor_password
   export JWT_SECRET=your-secret-key
   ```

4. Run migrations and start server:
   ```bash
   swift run
   ```

## Authentication

StoneAtlas supports two OAuth providers:

- **Sign in with Apple**: Provides secure, privacy-focused authentication
- **Google Sign In**: OAuth 2.0 flow with silent token refresh

JWT tokens expire after 7 days and are automatically refreshed when the app launches.

## Contributing

This is a personal project, but suggestions and bug reports are welcome via GitHub Issues.

## License

Copyright © 2025 Max Rogers. All rights reserved.
