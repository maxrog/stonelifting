# StoneLifting

A community app for stone lifting enthusiasts to track their progress and discover new stones.

## Quick Start

1. Clone the repo
2. Run `scripts/setup-dev.sh`
3. Open `ios/StoneLifting.xcodeproj` in Xcode
4. Start the backend with `cd backend && swift run`

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

## Architecture

- **Backend**: Swift Vapor API
- **iOS**: Native Swift app
- **Database**: PostgreSQL
- **CI/CD**: GitHub Actions
