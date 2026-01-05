# StoneLifting

A community app for stone lifting enthusiasts to track their progress and discover new stones.

## Quick Start

1. Clone the repo
2. Run `scripts/setup-dev.sh`
3. Open `ios/StoneLifting.xcodeproj` in Xcode
4. Start the backend with `cd backend && swift run`

## Development Workflow

This project includes custom Claude Code slash commands for automated code quality and analysis:

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

---

See [iOS/StoneLifting/ROADMAP.md](iOS/StoneLifting/ROADMAP.md) for future automation tools and feature roadmap.

---

## Architecture

- **Backend**: Swift Vapor API
- **iOS**: Native Swift app
- **Database**: PostgreSQL
- **CI/CD**: GitHub Actions
