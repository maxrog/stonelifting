# Pre-Commit Code Review

Review all staged changes against CLAUDE.md standards before committing.

## Instructions

1. **Get staged changes**: Run `git diff --staged` to see what will be committed

2. **Review each file** against these criteria:

### 🔒 Security Checklist
- [ ] No hardcoded secrets, API keys, tokens, or passwords
- [ ] Sensitive data stored in Keychain (not UserDefaults)
- [ ] HTTPS for all external network calls
- [ ] Input validation on user-facing inputs
- [ ] No sensitive data logged (passwords, tokens, PII)

### ⚡ Async/Await & Concurrency
- [ ] UI updates use `@MainActor` or `await MainActor.run { }`
- [ ] Long-lived closures use `[weak self]`
- [ ] Proper task cancellation (store task references, check `Task.isCancelled`)
- [ ] Thread-safe shared state (use actors if needed)

### 🧠 Memory Management
- [ ] `[weak self]` in closures that outlive their context
- [ ] Resources cleaned up in `onDisappear` or deinit
- [ ] No obvious retain cycles

### ❌ Error Handling
- [ ] Custom errors conform to `LocalizedError`
- [ ] All errors have `errorDescription`
- [ ] Proper do-catch blocks (no silent ignoring)
- [ ] Errors logged with context
- [ ] No `try!` (use proper error handling)
- [ ] `try?` only for non-critical operations

### 📐 Code Organization
- [ ] MARK comments present (Properties, Initialization, Public Methods, Private Methods)
- [ ] Naming conventions: UpperCamelCase (types), lowerCamelCase (properties/methods)
- [ ] Services use singleton pattern: `static let shared` + private init
- [ ] Services use `@Observable` (not `ObservableObject`)

### 🎯 Swift Best Practices
- [ ] No force unwraps unless explicitly safe
- [ ] SwiftUI views are structs
- [ ] Prefer `@Observable` over `ObservableObject`
- [ ] Use `private(set)` for observable properties
- [ ] Proper use of `@MainActor`, `@State`, `@Bindable`

### 📝 Code Quality
- [ ] No TODO comments for critical issues
- [ ] Comments explain "why" not "what"
- [ ] No dead code or unused imports
- [ ] DRY principle followed (no unnecessary duplication)

## Output Format

Provide feedback in this structure:

```markdown
## 🎯 Review Summary
**Status**: ✅ APPROVED / ⚠️ NEEDS CHANGES / 🔴 BLOCKED

**Files Reviewed**: X files
**Issues Found**: Y issues (Z critical)

## 📋 Issues by File

### path/to/file.swift
**Critical Issues (Must Fix)**
- [Line X] Description of issue

**Warnings (Should Fix)**
- [Line Y] Description of concern

**Suggestions (Optional)**
- [Line Z] Improvement suggestion

## ✅ Good Practices Found
- List positive observations

## 📝 Suggested Commit Message
(Only if APPROVED)

```
<type>: <brief description>
```

## 🚀 Next Steps
- Fix critical issues before committing
- Consider warnings for this commit or next
- Run tests if available
```

## Special Checks

### For Service Files (`Services/*.swift`)
- Verify singleton pattern with `@Observable`
- Check `AppLogger` usage
- Verify private initializer

### For SwiftUI Views
- Check for business logic in views (should be in ViewModels)
- Verify proper state management
- Check accessibility labels

### For ViewModels
- Verify `@Observable` macro usage
- Check `@MainActor` on methods that update state
- Verify proper service injection

### For Models
- Check `Codable` conformance for API models
- Verify proper equatable/hashable if needed

## Important Notes

- Be constructive and specific in feedback
- Prioritize issues: Critical > Warnings > Suggestions
- If no issues found, still acknowledge good practices
- Generate commit message ONLY if approved
- Use line numbers from git diff for precise feedback
