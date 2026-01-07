# StoneLifting iOS App - Development Standards

## Overview
StoneLifting is a production iOS application for tracking stone lifting activities. This document defines code quality standards, architectural patterns, and best practices for the project.

**Related Documentation:**
- **Feature Roadmap**: See `iOS/StoneLifting/ROADMAP.md` for planned features and development automation tools
- **Development Commands**: Custom slash commands are in `.claude/commands/` directory

---

## Architecture Patterns

### MVVM Structure
- **Views**: SwiftUI views (in `Views/`) - Handle UI only, no business logic
- **ViewModels**: Observable view models (in `ViewModels/`) - Handle presentation logic and state
- **Services**: Singleton services (in `Services/`) - Handle data access, API calls, device features
- **Models**: Data models (in `Models/`) - Codable structs for data representation

### Service Layer
All services follow these patterns:
- Singleton pattern with `static let shared`
- Use `@Observable` macro for reactive state
- Include comprehensive logging with `AppLogger()`
- Private initializer for singletons
- Proper error handling with custom error types

**Example:**
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
- Use `@Observable` macro (not `ObservableObject`)
- Use `@State` in views for local UI state
- Use `@FocusState` for keyboard/focus management
- Services hold shared/global state
- ViewModels hold view-specific state

---

## Swift Coding Standards

### Naming Conventions
- **Types**: UpperCamelCase (`UserProfile`, `StoneService`)
- **Properties/Methods**: lowerCamelCase (`currentUser`, `fetchStones()`)
- **Constants**: lowerCamelCase (`maxRetries`, `apiTimeout`)
- **Enums**: UpperCamelCase for type, lowerCamelCase for cases
- **Private members**: Prefix with `private` modifier, not underscore

### Code Organization
Use MARK comments to organize files:
```swift
// MARK: - Type Definition
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Supporting Types
```

### Documentation
- Add documentation for public APIs and complex logic
- Use triple-slash `///` for doc comments
- Include parameter and return value descriptions
- Keep inline comments minimal - code should be self-documenting

### SwiftUI Patterns

#### View Structure
All views should follow this organization:
```swift
struct MyView: View {
    // MARK: - Properties
    @State private var viewModel = MyViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body
    var body: some View {
        content
    }

    // MARK: - View Components
    @ViewBuilder
    private var content: some View {
        // ...
    }

    // MARK: - Actions
    private func handleAction() {
        // ...
    }
}
```

#### View Extraction Guidelines
Extract views when:
- View file exceeds 200 lines
- Code block is repeated 2+ times
- Section has clear single responsibility
- Component could be reused elsewhere

**Example:**
```swift
// Extract large sections
struct StoneDetailView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StoneDetailHeader(stone: stone)
                StoneDetailInfo(stone: stone)
                StoneDetailStats(stone: stone)
            }
        }
    }
}
```

#### ViewBuilder Best Practices
- Use `@ViewBuilder` for complex composed views
- Use `@ViewBuilder` for conditional logic
- Use descriptive names for view components (`headerSection`, not `header`)
- Keep view body simple and readable

#### State Management in Views
- `@State` for view-local UI state ONLY (searchText, isShowing, focusedField)
- `@State` for ViewModel instances (`@State private var viewModel = MyViewModel()`)
- NO business logic in views - belongs in ViewModels
- Use `.constant()` for preview-only bindings
- Leverage `#Preview` macro for previews

**Example:**
```swift
// Good: UI state only in view
struct MyView: View {
    @State private var viewModel = MyViewModel()
    @State private var searchText = ""  // UI state
    @FocusState private var focusedField: Field?

    var body: some View {
        TextField("Search", text: $searchText)
            .task {
                await viewModel.search(searchText)  // Logic in VM
            }
    }
}
```

---

## Async/Await & Concurrency

### Prefer async/await over callbacks
```swift
// Good
func fetchData() async throws -> Data {
    try await apiService.get(endpoint: "/data")
}

// Avoid
func fetchData(completion: @escaping (Result<Data, Error>) -> Void)
```

### Main Actor Annotation
- Annotate UI-updating methods with `@MainActor`
- Service methods that update observable properties should use `@MainActor`
- Use `await MainActor.run { }` when updating from background context

### Actor-Based Thread Safety
- Use actors for shared mutable state across concurrency boundaries
- Example: `LocationContinuationManager` actor for continuation safety
- Prevents race conditions and data races

### Task Management
- Cancel tasks properly in cleanup
- Use `Task { }` for async work from sync context
- Implement timeouts for network/location requests
- Store task references if cancellation is needed

### Swift 6 Concurrency Safety

#### Actor Isolation
- Use `actor` for shared mutable state accessed from multiple contexts
- Use `@MainActor` for all UI-updating code and services
- Global mutable state must be actor-isolated or main-actor-isolated

**Example:**
```swift
// Good: Actor for shared cache
actor ImageCache {
    private var cache: [String: UIImage] = [:]

    func get(_ key: String) -> UIImage? {
        cache[key]
    }
}

// Good: MainActor for UI services
@Observable
@MainActor
final class ThemeService {
    static let shared = ThemeService()
    var currentTheme: Theme = .light
}
```

#### Sendable Conformance
- Types crossing concurrency boundaries should conform to `Sendable`
- Task closures require Sendable captures in Swift 6
- Use `@MainActor` or `[weak self]` in Task blocks

**Example:**
```swift
// Good: MainActor makes Task safe
@MainActor
class ViewModel {
    func load() {
        Task {  // Safe - MainActor isolation
            await fetchData()
        }
    }
}

// Good: Weak capture for non-MainActor
class MyClass {
    func load() {
        Task { [weak self] in
            await self?.fetchData()
        }
    }
}
```

#### Data Race Prevention
- All services should be either `actor` or `@MainActor`
- Never access mutable state from multiple contexts without protection
- Use `isolated` parameters when passing actor instances
- Run `/concurrency-review` regularly to catch data race risks

---

## Error Handling

### Custom Error Types
Define typed errors with `LocalizedError`:
```swift
enum MyServiceError: Error, LocalizedError {
    case notFound
    case invalidData
    case networkError

    var errorDescription: String? {
        switch self {
        case .notFound: return "Item not found"
        case .invalidData: return "Invalid data format"
        case .networkError: return "Network connection failed"
        }
    }
}
```

### Error Handling Strategy
- Use `do-catch` blocks for throwing operations
- Store errors in observable properties for UI display
- Log all errors with context using `logger.error()`
- Provide user-friendly error messages (separate from technical logs)
- Clear errors after user acknowledgment

### Error Propagation
- Service methods throw errors up the stack
- ViewModels catch and convert to user-facing messages
- Views display errors via alerts/banners
- Never silently ignore errors

---

## Validation Patterns

### Form Validation
- Create `ValidationResult` enum for validation states
- Validate on input change (with debouncing for API checks)
- Show errors only, not success states (saves space)
- Visual feedback: green checkmark on field when valid

### Debouncing
Use debouncing for expensive operations:
```swift
@State private var checkTask: Task<Void, Never>?

func checkAvailability(_ value: String) {
    checkTask?.cancel()
    checkTask = Task {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        guard !Task.isCancelled else { return }
        // Perform check
    }
}
```

---

## Memory Management

### Avoid Retain Cycles
- Use `[weak self]` in closures that might outlive their context
- Use `[weak self]` in Task closures within classes
- Check `guard let self` after weak capture
- Use `[unowned self]` only when lifetime is guaranteed

### Cleanup & Lifecycle
- Cancel tasks in deinit or cleanup methods
- Remove observers/listeners when done
- Clear cached data when permissions revoked
- Implement proper view lifecycle handling

### Resource Management
- Close URLSessions when appropriate
- Stop location updates when not needed
- Clean up continuations to prevent leaks

---

## Security Standards

### Secrets Management
- **NEVER** commit API keys, tokens, or credentials
- Use environment variables or secure configuration files
- Store sensitive data in Keychain only
- Use `.gitignore` for credential files

### Network Security
- HTTPS only for all network requests
- Implement certificate pinning for production APIs
- Validate SSL certificates
- Use URLSession with proper security configuration

### Data Protection
- Keychain for: tokens, passwords, sensitive user data
- UserDefaults for: preferences, non-sensitive settings only
- Never log sensitive data (passwords, tokens, PII)
- Implement biometric authentication where appropriate

### Input Validation
- Validate all user input before processing
- Sanitize data before API requests
- Use parameterized queries (prevent injection)
- Validate email formats, usernames, passwords

---

## Logging Standards

### Use AppLogger
```swift
private let logger = AppLogger()

// Info: Normal operations
logger.info("User logged in successfully")

// Debug: Detailed debugging info
logger.debug("Cache hit for key: \(key)")

// Warning: Unexpected but handled situations
logger.warning("Retrying request after timeout")

// Error: Actual errors with context
logger.error("Failed to fetch data", error: error)
```

### What to Log
- Service initialization
- State transitions (auth status, permissions)
- Network requests/responses (without sensitive data)
- Errors with full context
- Performance-critical operations

### What NOT to Log
- Passwords, tokens, or credentials
- Full user personal information
- Excessive debug info in production
- Secrets or API keys

---

## Testing Requirements

### Test Coverage Goals
- Critical paths: 100% coverage (authentication, payments, data integrity)
- New features: 80%+ coverage
- Bug fixes: Add test that would have caught the bug
- Overall target: 70%+ coverage

### Testing Strategy
- **Unit tests**: Business logic, validation, transformations
- **Integration tests**: API service interactions, data flow
- **UI tests**: Critical user flows (registration, login, core features)
- **Snapshot tests**: Complex UI components

### Test Organization
- Mirror source structure in test target
- Use descriptive test names: `test_methodName_scenario_expectedResult`
- Arrange-Act-Assert structure
- One assertion per test (or related assertions)

### Async Testing
```swift
func testAsyncOperation() async throws {
    let result = await service.fetchData()
    XCTAssertNotNil(result)
}
```

### Mocking
- Mock external dependencies (APIs, services)
- Use protocols for dependency injection
- Don't mock SwiftUI or Apple frameworks
- Verify behavior, not implementation

---

## Code Review Checklist

### Automated Code Reviews

Use slash commands for comprehensive reviews:
- `/review-staged` - Pre-commit code review against CLAUDE.md standards
- `/concurrency-review` - Swift 6 concurrency safety audit
- `/swiftui-refactor` - View structure and performance analysis
- `/perf-profile` - Performance bottleneck identification
- `/security-scan` - Security vulnerability scanning
- `/accessibility-audit` - Accessibility compliance check

### Review Frequency
- Run `/review-staged` before every commit
- Run `/concurrency-review` monthly or after major concurrency changes
- Run `/swiftui-refactor` when views exceed 200 lines
- Run `/perf-profile` before each release
- Run `/security-scan` before production deployments
- Run `/accessibility-audit` quarterly

### Before Committing
- [ ] Code follows Swift naming conventions
- [ ] No force unwraps unless explicitly safe
- [ ] Proper error handling in place
- [ ] Memory leaks checked (weak self in closures)
- [ ] No hardcoded credentials or secrets
- [ ] Logging added for important operations
- [ ] Comments explain "why", not "what"
- [ ] No TODO comments for critical issues
- [ ] Tests added for new functionality
- [ ] Existing tests still pass

### Security Review
- [ ] No sensitive data in logs
- [ ] HTTPS for all network calls
- [ ] Input validation on boundaries
- [ ] Keychain used for sensitive storage
- [ ] No API keys in code

### Performance Review
- [ ] No main thread blocking
- [ ] Efficient algorithms/data structures
- [ ] Images optimized
- [ ] Pagination for large lists
- [ ] Proper resource cleanup

---

## UI/UX Patterns

### Accessibility
- Add `.accessibilityLabel()` to all interactive elements
- Add `.accessibilityHint()` for non-obvious actions
- Support Dynamic Type
- Ensure proper color contrast
- Test with VoiceOver

### Haptic Feedback
Use haptic feedback for important user actions:
```swift
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success) // or .error, .warning
```

### Loading States
- Show progress indicators for async operations
- Disable buttons during loading (prevent double-tap)
- Provide visual feedback for all user actions
- Handle empty states gracefully

### Form Validation UX
- Validate on change, not on submit
- Show errors only (not success confirmations)
- Visual indicators: checkmarks for valid fields
- Clear, actionable error messages

---

## Performance Guidelines

### Network Optimization
- Batch API requests when possible
- Implement request debouncing
- Cache responses appropriately
- Use pagination for large datasets
- Implement request timeouts

### Image Handling
- Resize images before upload
- Use appropriate image formats
- Lazy load images in lists
- Cache downloaded images
- Use async image loading

### Main Thread Protection
- Never block main thread with heavy computation
- Move network calls to background
- Use Task for async operations
- Profile with Instruments before release

### Performance Monitoring
- Use `/perf-profile` command for comprehensive performance analysis
- Track metrics: app launch time, screen load time, memory usage
- Profile with Instruments before each release
- Set performance budgets:
  - App launch: <2 seconds
  - Screen transitions: <300ms
  - List scrolling: 60 FPS
  - Image load: <100ms
  - API requests: <500ms
  - Memory usage: <200MB typical

### Performance Testing
Create performance tests for critical paths:
```swift
func testImageUploadPerformance() async throws {
    measure {
        Task {
            _ = await ImageUploadService.shared.uploadImage(testData)
        }
    }
    // Target: <100ms for compression + encoding
}

func testStoneListLoadPerformance() async throws {
    measure {
        await viewModel.fetchStones()
    }
    // Target: <500ms for typical load
}
```

### Parallel Operations
Use `async let` or `TaskGroup` for concurrent operations:
```swift
// Good: Parallel requests (2x faster)
func refreshAllStones() async {
    async let userFetch = stoneService.fetchUserStones()
    async let publicFetch = stoneService.fetchPublicStones()
    _ = await (userFetch, publicFetch)
}

// Avoid: Sequential requests (slower)
func refreshAllStones() async {
    await stoneService.fetchUserStones()
    await stoneService.fetchPublicStones()  // Waits for first to complete
}
```

---

## Common Patterns in This Project

### Availability Checking
Debounced real-time availability checks (username, email):
- 500ms debounce delay
- Show spinner while checking
- Display errors only when invalid/taken
- Green checkmark when valid and available

### Location Services
- Request permissions properly
- Handle all authorization states
- Timeout protection (10 seconds)
- Cache recent locations (30 seconds)
- Actor-based continuation management

### Form Handling
- Focus state management with `@FocusState`
- Field-by-field validation
- Submit action on final field
- Keyboard dismissal on submit
- Haptic feedback on success

### Settings Navigation
- Alert with "Open Settings" action
- Handle denied/restricted permissions gracefully
- Educate users about why permissions needed

---

## TODO Management

### TODO Comment Guidelines
- Use `// TODO:` for improvements and non-critical work
- Use `// FIXME:` for bugs that need attention
- Include context and reason
- Link to issue tracker if available
- Example: `// TODO: Add pagination when API supports it`

### Critical vs Nice-to-Have
- Critical issues should be fixed before commit
- Non-critical TODOs can remain with context
- Track TODOs in issue tracker for visibility
- Review and prune TODOs regularly

---

## Git Workflow

### Commit Messages
Format: `<type>: <brief description>`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `docs`: Documentation
- `test`: Adding tests
- `chore`: Maintenance tasks

Examples:
- `feat: add password strength indicator`
- `fix: resolve location continuation leak`
- `refactor: extract validation logic to service`

### Branch Strategy
- `main`: Production-ready code
- Feature branches: `feature/description`
- Bug fixes: `fix/issue-description`
- Hotfixes: `hotfix/critical-issue`

### Pull Requests
- Descriptive title and summary
- Link related issues
- Include test plan
- Request review before merging
- Squash commits if needed

---

## Release Management

### Versioning
- Use semantic versioning: `MAJOR.MINOR.PATCH`
- Increment MAJOR for breaking changes
- Increment MINOR for new features
- Increment PATCH for bug fixes

### Changelog Maintenance
- Keep `CHANGELOG.md` updated with all changes
- Use `/appstore-changelog` command to generate user-facing release notes
- Separate developer changelog from App Store release notes

**Developer Changelog Format:**
```markdown
## [1.2.0] - 2026-01-15

### Added
- AR-based stone weight estimation with LiDAR support
- Map clustering for nearby stones
- Parallel network requests for faster loading

### Fixed
- Base64 encoding blocking main thread in ImageUploadService
- Location timeout not being respected in LocationService

### Performance
- Image upload responsiveness improved by 20%
- Stone list refresh 2x faster with parallel fetching
- Request timeouts added to prevent hanging
```

**App Store Release Notes Format:**
```
What's New in Version 1.2:

Point your camera at a stone and get an instant weight estimate!

NEW FEATURES
• Smart weight estimation using AR
• See groups of nearby stones on the map

IMPROVEMENTS
• 2x faster loading
• Smoother photo uploads
• Better location accuracy
```

### Pre-Release Checklist
Before submitting to App Store:
- [ ] Version number incremented in Xcode
- [ ] Build number incremented
- [ ] `CHANGELOG.md` updated
- [ ] Release notes written (use `/appstore-changelog`)
- [ ] All tests passing
- [ ] No critical TODOs in code
- [ ] Screenshots updated if UI changed
- [ ] Privacy policy updated if needed
- [ ] Tested on multiple device sizes (SE, regular, Pro Max)
- [ ] Tested on oldest supported iOS version
- [ ] Performance profiled with Instruments
- [ ] Memory leaks checked
- [ ] Thread Sanitizer run

---

## Tools & Automation

### SwiftLint
Run SwiftLint on all Swift files:
```bash
swiftlint lint --strict
```

Auto-fix issues:
```bash
swiftlint --fix
```

### SwiftFormat
Format code consistently:
```bash
swiftformat .
```

### Testing
Run full test suite:
```bash
swift test
```

Run with coverage:
```bash
xcodebuild test -scheme StoneLifting -enableCodeCoverage YES
```

---

## When in Doubt

1. **Clarity over cleverness** - Write obvious code
2. **Test critical paths** - Don't skip tests
3. **Handle errors properly** - Never ignore errors
4. **Log with context** - Make debugging easier
5. **Think about the user** - UX matters
6. **Secure by default** - Security is not optional
7. **Profile before optimizing** - Measure first
8. **Document the why** - Not the what
9. **Make it feel human** - Avoid AI-generated tells in UI:
   - Use specific, contextual copy instead of generic placeholders
   - Avoid excessive emojis or overly formal language
   - Choose meaningful icons that fit the app's personality
   - Vary spacing and layouts to feel intentional, not templated
   - Write error messages in your app's voice, not boilerplate
   - Use real-world examples in placeholder text
   - Polish the details - animations, transitions, micro-interactions

---

## Resources

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [iOS Security Best Practices](https://developer.apple.com/security/)

---

**Last Updated:** 2026-01-07
**Project:** StoneLifting iOS App
**Language:** Swift 6.0
**Platform:** iOS 18.0+
**Framework:** SwiftUI
**Xcode:** 16+

**Slash Commands Available:**
- `/review-staged` - Pre-commit code review
- `/concurrency-review` - Swift 6 concurrency safety audit
- `/swiftui-refactor` - View structure analysis
- `/perf-profile` - Performance profiling
- `/security-scan` - Security vulnerability scan
- `/accessibility-audit` - Accessibility compliance
- `/test-gen` - Test generation
- `/appstore-changelog` - Release notes generator
