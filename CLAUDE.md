# StoneAtlas iOS App - Development Standards

## Overview
StoneAtlas is a production iOS app for discovering, documenting, and tracking stone lifting achievements. This document defines project-specific patterns and workflows.

**Related Documentation:**
- **Roadmap**: `iOS/StoneLifting/ROADMAP.md` - planned features
- **General iOS/Swift Patterns**: `iOS_Swift_Best_Practices.md` - reusable best practices
- **Slash Commands**: `.claude/commands/` - custom development tools

---

## Project Structure

```
/Users/maxrogers/Personal/iOS/stoneatlas/
├── iOS/StoneLifting/
│   ├── StoneLifting.xcodeproj/          # Open this in Xcode
│   ├── StoneLifting/
│   │   ├── App/                         # App entry point
│   │   ├── Models/                      # Data models
│   │   ├── Views/                       # SwiftUI views
│   │   ├── ViewModels/                  # View models
│   │   ├── Services/                    # Business logic & API
│   │   └── Utilities/Constants.swift    # API config (line 25 = environment)
│   └── ROADMAP.md
├── backend/Sources/StoneLifting/
│   ├── Controllers/                     # Route handlers
│   ├── Models/                          # Database models
│   ├── Services/                        # Business logic
│   └── Migrations/                      # Database migrations
└── README.md
```

**Quick Commands:**
- Build: Open `.xcodeproj` in Xcode, press `⌘+B`
- Run: `⌘+R` (requires physical device for LiDAR)
- Backend: `cd backend && swift run`
- Tests: `⌘+U`

---

## Architecture

### MVVM + Services
- **Views**: UI only, no business logic
- **ViewModels**: `@Observable` classes, presentation logic
- **Services**: Singletons with `static let shared`, handle data/API/device features
- **Models**: `Codable` structs

### Service Pattern
```swift
@Observable
final class MyService {
    static let shared = MyService()
    private let logger = AppLogger()

    private init() {
        logger.info("MyService initialized")
    }
}
```

### State Management
- `@State` for local UI state and ViewModel instances
- `@FocusState` for keyboard/focus
- Services hold shared/global state
- ViewModels hold view-specific state

---

## Swift 6 Concurrency

### Actor Isolation
- Use `@MainActor` for all UI services and ViewModels
- Use `actor` for shared mutable state across contexts
- All services must be `actor` or `@MainActor`

```swift
@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()
    var currentUser: User?
}

actor LocationContinuationManager {
    private var continuation: CheckedContinuation<Location, Error>?
}
```

### Parallel Operations
```swift
// Good: Parallel (2x faster)
async let userFetch = stoneService.fetchUserStones()
async let publicFetch = stoneService.fetchPublicStones()
_ = await (userFetch, publicFetch)

// Avoid: Sequential
await stoneService.fetchUserStones()
await stoneService.fetchPublicStones()
```

### Task Management
- Cancel tasks in `deinit` or cleanup
- Store task references for cancellation: `private var checkTask: Task<Void, Never>?`
- Use `[weak self]` in Task closures within classes
- Implement timeouts for network/location requests

---

## SwiftUI Patterns

### View Structure
```swift
struct MyView: View {
    @State private var viewModel = MyViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        // Extract complex sections as computed properties
    }

    private func handleAction() {
        // Actions here
    }
}
```

### View Extraction
Extract when:
- File > 200 lines
- Repeated 2+ times
- Clear single responsibility
- Reusable elsewhere

---

## Project-Specific Patterns

### OAuth Authentication
- Apple Sign In: Nonce validation, state verification, silent refresh not supported
- Google Sign In: Silent token refresh supported
- JWT access token: 1 hour expiration
- Refresh token: 9 months, rotates on each use
- Auto token refresh on 401 (APIService handles automatically)

### Content Moderation
- OpenAI moderation for usernames and stone names
- Retry logic for rate limits (free tier)
- Fallback to generic "user" for flagged auto-generated usernames
- Reject user-chosen inappropriate usernames with error message

### Availability Checking
Debounced real-time checks (username availability):
- 500ms debounce delay
- Show spinner while checking
- Display errors only when invalid/taken
- Green checkmark when valid

### Form Validation
- Validate on change, not on submit
- `@FocusState` for keyboard management
- Submit action on final field
- Haptic feedback on success/error

### Location Services
- Request permissions properly
- Handle all authorization states
- 10 second timeout protection
- 30 second location cache
- Actor-based continuation management

### Caching Strategy
- SwiftData for persistent stone cache
- Cache user stones and public stones separately
- Clear all caches on logout
- Parallel fetch + batch cache on app launch

---

## Security

### OAuth & Tokens
- Keychain for: JWT token, refresh token
- UserDefaults for: preferences only
- Never log tokens, passwords, PII
- HTTPS only, certificate validation

### Input Validation
- Validate all user input before processing
- Sanitize before API requests
- Content moderation for user-generated content (usernames, stone names, descriptions)

---

## Performance Budgets

- App launch: <2 seconds
- Screen transitions: <300ms
- List scrolling: 60 FPS
- API requests: <500ms
- Memory usage: <200MB typical

### Image Handling
- Resize before upload (prevent main thread blocking)
- Async image loading in lists
- Cache downloaded images
- Lazy loading

---

## Error Handling

### Custom Errors
```swift
enum MyServiceError: Error, LocalizedError {
    case notFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notFound: return "Item not found"
        case .invalidData: return "Invalid data format"
        }
    }
}
```

### Error Flow
1. Services throw errors
2. ViewModels catch and convert to user-facing messages
3. Views display via alerts/banners
4. Log all errors with context: `logger.error("Failed", error: error)`

---

## Code Organization

### MARK Comments
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Supporting Types
```

### Documentation
**Only document when necessary:**
- Public APIs needing usage explanation
- Complex algorithms or non-obvious logic
- Architectural "why" decisions

**Do NOT document:**
- Self-explanatory names (`fetchStones()`, `isLoading`)
- Obvious getters/setters

---

## Git Workflow

### Commit Messages
`<type>: <brief description>`

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

Examples:
- `feat: add username picker onboarding flow`
- `fix: clear onboarding state on logout`

### Branches
- `main`: Production-ready
- `feature/description`
- `fix/issue-description`
- `hotfix/critical-issue`

---

## Release Checklist

Before App Store submission:
- [ ] Version & build numbers incremented
- [ ] `CHANGELOG.md` updated (use `/appstore-changelog`)
- [ ] All tests passing
- [ ] No critical TODOs
- [ ] Screenshots updated if UI changed
- [ ] Tested on SE, regular, Pro Max sizes
- [ ] Tested on oldest supported iOS version
- [ ] Profiled with Instruments
- [ ] Memory leaks checked
- [ ] Thread Sanitizer run
- [ ] README updated if major features added

---

## Slash Commands

**Pre-commit:**
- `/review-staged` - Code review against standards

**Periodic:**
- `/concurrency-review` - Swift 6 safety audit (monthly)
- `/swiftui-refactor` - View structure analysis (when >200 lines)
- `/perf-profile` - Performance profiling (before release)
- `/security-scan` - Security scan (before production)
- `/accessibility-audit` - Accessibility check (quarterly)

**Release:**
- `/appstore-changelog` - Generate user-facing release notes

---

## Code Review Essentials

### Before Committing
- [ ] No force unwraps unless explicitly safe
- [ ] Proper error handling
- [ ] Memory leaks checked (`[weak self]` in closures)
- [ ] No hardcoded secrets
- [ ] Logging for important operations
- [ ] Tests for new functionality

### Security
- [ ] No sensitive data in logs
- [ ] HTTPS for all network calls
- [ ] Input validation on boundaries
- [ ] Keychain for sensitive storage

### Performance
- [ ] No main thread blocking
- [ ] Images optimized
- [ ] Proper resource cleanup

---

## When in Doubt

1. **Clarity over cleverness** - Write obvious code
2. **Test critical paths** - Don't skip tests
3. **Handle errors properly** - Never ignore errors
4. **Log with context** - Make debugging easier
5. **Secure by default** - Security is not optional
6. **Profile before optimizing** - Measure first
7. **Make it feel human** - Avoid AI-generated UI tells:
   - Use specific, contextual copy (not generic placeholders)
   - Avoid excessive emojis or overly formal language
   - Write error messages in your app's voice
   - Polish animations, transitions, micro-interactions

---

**Last Updated:** 2026-02-12
**Project:** StoneAtlas iOS App
**Language:** Swift 6.0 | **Platform:** iOS 18.0+ | **Framework:** SwiftUI
