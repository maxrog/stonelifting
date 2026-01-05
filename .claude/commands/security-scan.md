# Security Scanner

Scan the entire codebase for security vulnerabilities, hardcoded secrets, and insecure patterns.

## Instructions

1. **Scan all Swift files**: Use grep/search to find security issues across the entire codebase

2. **Security Checks**:

### 🔐 Secrets & Credentials Detection
Search for patterns that indicate hardcoded secrets:
- API keys: `apiKey`, `api_key`, `API_KEY`
- Tokens: `token`, `auth`, `bearer`
- Passwords: `password =`, `pwd =`
- URLs with credentials: `http://user:pass@`
- Common secret patterns: long alphanumeric strings assigned to variables
- Environment-specific configs that might contain secrets

**Check these locations**:
- [ ] Services/*.swift
- [ ] ViewModels/*.swift
- [ ] Models/*.swift
- [ ] Config files
- [ ] .env files (should be in .gitignore)

### 🗄️ Insecure Data Storage
- [ ] Check for sensitive data stored in UserDefaults (should use Keychain)
- [ ] Look for `UserDefaults.standard.set` with passwords, tokens, or PII
- [ ] Verify Keychain usage for: authentication tokens, user credentials, sensitive settings
- [ ] Check that cache/temp storage doesn't contain sensitive data

### 🌐 Network Security
- [ ] All URLSession requests use HTTPS (no HTTP)
- [ ] Check for certificate pinning in production code
- [ ] Verify SSL/TLS validation is not disabled
- [ ] Look for `AllowsArbitraryLoads` in Info.plist (should be false)

### 🛡️ Input Validation
- [ ] User input is validated before processing
- [ ] Email/username validation exists
- [ ] Password strength requirements enforced
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention in web views
- [ ] Path traversal prevention in file operations

### 📝 Logging Security
- [ ] No passwords logged
- [ ] No tokens/API keys logged
- [ ] No PII (email, phone, address) in debug logs
- [ ] Check `logger.debug()`, `logger.info()`, `print()` statements
- [ ] Verify sensitive data is redacted in error messages

### ⚡ Common Vulnerabilities (OWASP Mobile Top 10)
- [ ] **M1: Improper Platform Usage** - Check for iOS API misuse
- [ ] **M2: Insecure Data Storage** - Keychain vs UserDefaults
- [ ] **M3: Insecure Communication** - HTTPS enforcement
- [ ] **M4: Insecure Authentication** - Token handling, session management
- [ ] **M5: Insufficient Cryptography** - Check encryption usage
- [ ] **M6: Insecure Authorization** - Role/permission checks
- [ ] **M7: Client Code Quality** - Force unwraps, unsafe code
- [ ] **M8: Code Tampering** - Jailbreak detection (if needed)
- [ ] **M9: Reverse Engineering** - Obfuscation (if needed)
- [ ] **M10: Extraneous Functionality** - Debug code in production

### 🚨 Code Safety Issues
- [ ] Excessive force unwraps (`!`) without safety guarantees
- [ ] `try!` usage (should use proper error handling)
- [ ] Force casts (`as!`) without type checking
- [ ] Implicit unwrapped optionals in unsafe contexts
- [ ] Unsafe memory access patterns

### 🔑 Authentication & Authorization
- [ ] Token refresh logic is secure
- [ ] Session timeout implemented
- [ ] Logout clears all sensitive data
- [ ] Biometric auth properly implemented
- [ ] No authentication bypass logic in debug builds that could leak to production

## Scanning Strategy

1. **Use targeted searches** for each category:
```bash
# Example: Search for hardcoded API keys
grep -r "apiKey\s*=\s*\"" --include="*.swift" .

# Search for UserDefaults with sensitive data
grep -r "UserDefaults.*password\|token\|secret" --include="*.swift" .

# Search for HTTP (insecure) URLs
grep -r "http://" --include="*.swift" .
```

2. **Read flagged files** to understand context
3. **Categorize findings** by severity

## Output Format

```markdown
## 🔒 Security Scan Report
**Scan Date**: YYYY-MM-DD
**Files Scanned**: X Swift files
**Issues Found**: Y issues (Z critical)

---

## 🚨 CRITICAL Issues (Fix Immediately)

### Hardcoded Secrets
- **File**: path/to/file.swift:line
  - **Issue**: Hardcoded API key detected
  - **Code**: `let apiKey = "sk_live_..."`
  - **Fix**: Move to Keychain or environment variable

### Insecure Data Storage
- **File**: path/to/file.swift:line
  - **Issue**: Password stored in UserDefaults
  - **Code**: `UserDefaults.standard.set(password, forKey: "pwd")`
  - **Fix**: Use KeychainService instead

---

## ⚠️ HIGH PRIORITY Warnings

### Input Validation Missing
- **File**: path/to/file.swift:line
  - **Issue**: User input not validated
  - **Recommendation**: Add validation before processing

### Insecure Network Calls
- **File**: path/to/file.swift:line
  - **Issue**: HTTP URL detected (should be HTTPS)
  - **Code**: `URL(string: "http://api.example.com")`

---

## ℹ️ MEDIUM PRIORITY Suggestions

### Code Safety
- **File**: path/to/file.swift:line
  - **Issue**: Force unwrap without safety check
  - **Code**: `let value = dict["key"]!`
  - **Recommendation**: Use optional binding

---

## ✅ Security Strengths Found

- Keychain properly used for authentication tokens
- All API calls use HTTPS
- Input validation present on registration forms
- Proper error handling in sensitive operations

---

## 📊 Scan Statistics

- **Total Swift Files**: X
- **Files with Issues**: Y
- **Critical Issues**: Z
- **High Priority**: A
- **Medium Priority**: B

**By Category**:
- Secrets Detection: X issues
- Data Storage: Y issues
- Network Security: Z issues
- Input Validation: A issues
- Logging Security: B issues
- Code Safety: C issues

---

## 🚀 Recommended Actions

**Immediate (Before Next Commit)**:
1. Fix all critical issues
2. Review high priority warnings

**Short Term (This Week)**:
1. Address medium priority suggestions
2. Add missing input validation
3. Audit logging statements

**Long Term (Next Sprint)**:
1. Implement certificate pinning
2. Add jailbreak detection (if needed)
3. Security code review training

---

## 📚 Resources

- [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/)
- [iOS Security Guide](https://developer.apple.com/security/)
- [Swift Security Best Practices](https://swift.org/documentation/security/)
```

## Special Focus Areas

### For Authentication Code
- Token storage (must use Keychain)
- Token refresh mechanism
- Session management
- Logout completeness

### For Network Layer
- HTTPS enforcement
- Certificate validation
- Request/response logging (no sensitive data)
- API key handling

### For Data Models
- Sensitive fields properly marked
- Codable implementations don't expose secrets
- PII handling

### For User Input
- Registration forms
- Login forms
- Search inputs
- File uploads

## Important Notes

- **Context matters**: Some patterns may be acceptable in test files
- **Be thorough**: Secrets can hide in comments, strings, or variable names
- **Check .gitignore**: Ensure credential files are excluded
- **Prioritize**: Critical issues block deployment, warnings are technical debt
- **Be specific**: Always include file paths and line numbers
- **Provide fixes**: Don't just identify problems, suggest solutions

## False Positives to Watch For

- Test files with mock/dummy credentials (acceptable if clearly marked)
- Example code in comments
- String constants that look like keys but aren't (e.g., dictionary keys)
- Development/local environment configs (if properly excluded from production)

When in doubt about a finding, flag it and let the developer decide.
