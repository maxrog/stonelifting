# Swift Concurrency Expert

Review and fix Swift concurrency issues including actor isolation, Sendable conformance, and data race safety for Swift 6 readiness.

## Instructions

Perform a comprehensive Swift concurrency safety audit, preparing the codebase for Swift 6's strict concurrency checking.

### 1. Actor Isolation Analysis

**Check @MainActor Usage:**

Search for UI updates that need main actor isolation:

- [ ] SwiftUI view property updates
- [ ] Observable properties that trigger UI updates
- [ ] Methods that modify UI-affecting state
- [ ] URLSession completion handlers updating UI
- [ ] Notifications posting to UI

**Patterns to Find:**

```swift
// ❌ Bad: UI update from background
func fetchData() async {
    let data = try await api.fetch()
    self.items = data  // Potential data race if items drives UI
}

// ✅ Good: Main actor isolation
@MainActor
func fetchData() async {
    let data = try await api.fetch()
    self.items = data  // Safe - on main actor
}

// ✅ Also good: Explicit main actor
func fetchData() async {
    let data = try await api.fetch()
    await MainActor.run {
        self.items = data
    }
}
```

**Search Commands:**
- Find Observable classes without @MainActor: `@Observable\s+class` not followed by `@MainActor`
- Find UI property updates: property assignments in async functions
- Find view model methods: methods that modify `@Published` or observable properties

**Check for Global Mutable State:**

```swift
// ❌ Bad: Global mutable state (data race)
var sharedCache: [String: Any] = [:]

// ✅ Good: Actor-isolated
actor SharedCache {
    private var cache: [String: Any] = [:]

    func get(_ key: String) -> Any? {
        cache[key]
    }

    func set(_ key: String, value: Any) {
        cache[key] = value
    }
}

// ✅ Also good: Main actor for UI-related
@MainActor
class ThemeManager {
    static let shared = ThemeManager()
    var currentTheme: Theme = .light  // Safe - main actor isolated
}
```

### 2. Sendable Conformance

**Check Task Captures:**

Tasks require Sendable closures in Swift 6:

```swift
// ❌ Potential issue: Non-Sendable capture
class ViewModel {
    var items: [Item] = []

    func load() {
        Task {
            // Self is captured - is it Sendable?
            await self.fetchItems()
        }
    }
}

// ✅ Good: @MainActor makes it Sendable-safe
@MainActor
class ViewModel {
    var items: [Item] = []

    func load() {
        Task {  // Safe - MainActor isolation
            await self.fetchItems()
        }
    }
}

// ✅ Good: Weak capture
class MyClass {
    func load() {
        Task { [weak self] in
            await self?.fetchItems()
        }
    }
}
```

**Check Sendable Types:**

Types crossing concurrency boundaries should be Sendable:

```swift
// ❌ Bad: Non-Sendable struct with mutable reference
struct MyData {
    var items: NSMutableArray  // Not Sendable
}

// ✅ Good: Sendable-safe types
struct MyData: Sendable {
    let items: [Item]  // Sendable
    let name: String   // Sendable
    let count: Int     // Sendable
}

// ✅ Good: Sendable class (immutable or main-actor)
@MainActor
final class MyViewModel: Sendable {
    // Safe because main-actor isolated
}
```

**Search Commands:**
- Find Task without isolation: `Task\s*\{` without `@MainActor` or `[weak self]`
- Find async let with captures: `async let` with complex expressions
- Find detached tasks: `Task.detached` (usually wrong choice)

### 3. Data Race Prevention

**Check Property Access Patterns:**

```swift
// ❌ Bad: Mutable shared state without protection
class ImageCache {
    var cache: [String: UIImage] = [:]

    func get(_ key: String) -> UIImage? {
        cache[key]  // Data race if called from multiple threads
    }

    func set(_ key: String, image: UIImage) {
        cache[key] = image  // Data race
    }
}

// ✅ Good: Actor protection
actor ImageCache {
    private var cache: [String: UIImage] = [:]

    func get(_ key: String) -> UIImage? {
        cache[key]  // Safe - actor serializes access
    }

    func set(_ key: String, image: UIImage) {
        cache[key] = image  // Safe
    }
}

// ✅ Also good: Main actor for UI-related cache
@MainActor
class ImageCache {
    private var cache: [String: UIImage] = [:]
    // Safe - all access on main thread
}
```

**Check Service Singletons:**

```swift
// ❌ Potentially unsafe: No isolation
@Observable
class MyService {
    static let shared = MyService()
    var state: [String] = []  // Could be accessed from multiple contexts
}

// ✅ Good: Main actor isolation
@Observable
@MainActor
final class MyService {
    static let shared = MyService()
    var state: [String] = []  // Safe - main actor
}

// ✅ Good: Actor isolation for non-UI service
actor MyBackgroundService {
    static let shared = MyBackgroundService()
    var state: [String] = []  // Safe - actor
}
```

### 4. Continuation Safety

**Check for Continuation Leaks:**

Your LocationService has a great pattern - verify others follow it:

```swift
// ✅ Good: Actor-managed continuation (your LocationService)
actor ContinuationManager {
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var hasResumed = false

    func resumeIfNeeded(with location: CLLocation?) {
        guard !hasResumed, let cont = continuation else { return }
        hasResumed = true
        continuation = nil
        cont.resume(returning: location)
    }
}

// ❌ Bad: Continuation without protection
func requestLocation() async -> CLLocation? {
    await withCheckedContinuation { continuation in
        self.continuation = continuation  // Could be called multiple times
        manager.requestLocation()
    }
}
```

**Search Commands:**
- Find continuations: `withCheckedContinuation`, `withUnsafeContinuation`
- Check for multiple resume: ensure `resume` is called exactly once
- Check for leaks: stored continuations should have cleanup

### 5. Task Lifecycle Management

**Check Task Cancellation:**

```swift
// ❌ Bad: Long-running task without cancellation
class ViewModel {
    func startPolling() {
        Task {
            while true {  // Runs forever
                await poll()
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

// ✅ Good: Store task reference and support cancellation
class ViewModel {
    private var pollingTask: Task<Void, Never>?

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await poll()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

// ✅ Good: Task cancellation on cleanup
struct MyView: View {
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Text("Loading...")
            .task {
                await load()
            }
            .onDisappear {
                loadTask?.cancel()
            }
    }
}
```

**Check Task Groups:**

For parallel operations, verify TaskGroup usage:

```swift
// ❌ Bad: Manual parallel tasks (harder to manage)
func fetchAll() async -> [Item] {
    let task1 = Task { await fetch1() }
    let task2 = Task { await fetch2() }
    let task3 = Task { await fetch3() }

    return await [task1.value, task2.value, task3.value]
}

// ✅ Good: TaskGroup for structured concurrency
func fetchAll() async -> [Item] {
    await withTaskGroup(of: Item.self) { group in
        group.addTask { await fetch1() }
        group.addTask { await fetch2() }
        group.addTask { await fetch3() }

        var items: [Item] = []
        for await item in group {
            items.append(item)
        }
        return items
    }
}

// ✅ Also good: async let for fixed parallel tasks
func fetchAll() async -> [Item] {
    async let item1 = fetch1()
    async let item2 = fetch2()
    async let item3 = fetch3()

    return await [item1, item2, item3]
}
```

### 6. Async Function Patterns

**Check Async Function Design:**

```swift
// ❌ Bad: Mixing sync and async incorrectly
func processImage(_ image: UIImage) async -> Data {
    // Heavy sync work on caller's context
    let processed = expensiveImageProcessing(image)  // ⚠️ Blocks
    return processed.jpegData(compressionQuality: 0.8)!
}

// ✅ Good: Move heavy work to background
func processImage(_ image: UIImage) async -> Data {
    await Task.detached {
        let processed = expensiveImageProcessing(image)
        return processed.jpegData(compressionQuality: 0.8)!
    }.value
}

// ✅ Better: Use continuation for existing async API
func processImage(_ image: UIImage) async -> Data {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            let processed = expensiveImageProcessing(image)
            let data = processed.jpegData(compressionQuality: 0.8)!
            continuation.resume(returning: data)
        }
    }
}
```

### 7. Observable Macro Safety

**Check @Observable with Concurrency:**

```swift
// ⚠️ Verify: Observable without isolation
@Observable
class MyViewModel {
    var items: [Item] = []  // Where is this accessed from?

    func update() {
        items = []  // Safe?
    }
}

// ✅ Good: Clear main actor isolation
@Observable
@MainActor
final class MyViewModel {
    var items: [Item] = []  // Clear: main thread only

    func update() {
        items = []  // Safe: main actor
    }
}

// ✅ Good: Actor for background service
@Observable
actor BackgroundService {
    var state: ServiceState = .idle

    func perform() async {
        state = .working  // Safe: actor serialization
    }
}
```

## Output Format

```markdown
## 🔒 Swift Concurrency Safety Report
**Analysis Date**: YYYY-MM-DD
**Swift Version**: 6.0 readiness check
**Files Analyzed**: X Swift files
**Issues Found**: Y issues (Z critical)
**Safety Score**: A+ / A / B / C / D

---

## 🚨 CRITICAL Issues (Must Fix)

### Data Race Risks

1. **File**: Services/CacheService.swift:45
   - **Issue**: Mutable dictionary accessed from multiple contexts without isolation
   - **Code**: `var cache: [String: Data] = [:]`
   - **Risk**: Data race, potential crash, undefined behavior
   - **Fix**: Make class an `actor` or add `@MainActor`
   - **Priority**: 🔴 Critical

```swift
// Before
class CacheService {
    var cache: [String: Data] = [:]
}

// After
actor CacheService {
    private var cache: [String: Data] = [:]
}
```

2. **File**: ViewModels/ListViewModel.swift:89
   - **Issue**: Task captures self without isolation
   - **Code**: `Task { await self.load() }`
   - **Risk**: Sendable conformance error in Swift 6
   - **Fix**: Add `@MainActor` to class or use `[weak self]`
   - **Priority**: 🔴 Critical

---

## ⚠️ HIGH PRIORITY Issues

### Actor Isolation

1. **File**: Services/NetworkService.swift:120
   - **Issue**: Observable class without `@MainActor` annotation
   - **Code**: `@Observable class NetworkService`
   - **Risk**: Properties might be accessed from wrong context
   - **Fix**: Add `@MainActor` if UI-related, or use `actor` if not
   - **Priority**: 🟠 High

### Sendable Conformance

1. **File**: Models/Stone.swift:15
   - **Issue**: Struct with non-Sendable property
   - **Code**: `var metadata: NSMutableDictionary`
   - **Risk**: Can't safely cross concurrency boundaries
   - **Fix**: Use `[String: Any]` dictionary instead
   - **Priority**: 🟠 High

---

## ℹ️ MEDIUM PRIORITY Issues

### Task Management

1. **File**: Views/CameraView.swift:67
   - **Issue**: Unstructured task without cancellation
   - **Code**: `Task { await startCamera() }`
   - **Risk**: Task continues after view disappears
   - **Fix**: Store task reference and cancel in `onDisappear`
   - **Priority**: 🟡 Medium

---

## ✅ Excellent Concurrency Patterns Found

**Your codebase shows great concurrency practices:**

1. ✨ **LocationContinuationManager** (LocationService.swift:254)
   - Actor-based continuation management
   - Thread-safe resume tracking
   - Industry best practice

2. ✨ **ImageUploadService** (ImageUploadService.swift:17)
   - Proper @MainActor isolation
   - Background work with DispatchQueue
   - Clean async/await usage

3. ✨ **Weak self captures** (LocationService.swift:130)
   - Prevents retain cycles in closures
   - Proper memory management

4. ✨ **Timeout protection** (LocationService.swift:135)
   - 10-second timeout on async operations
   - Prevents hanging

5. ✨ **Parallel requests** (StoneListViewModel.swift:43)
   - async let for concurrent operations
   - Optimal performance

---

## 📊 Concurrency Health Metrics

### By Category
| Category | Issues | Critical | High | Medium |
|----------|--------|----------|------|--------|
| Actor Isolation | 4 | 1 | 2 | 1 |
| Sendable | 2 | 0 | 2 | 0 |
| Data Races | 1 | 1 | 0 | 0 |
| Task Lifecycle | 3 | 0 | 1 | 2 |
| Continuations | 0 | 0 | 0 | 0 |

### Swift 6 Readiness
- **Current**: ~85% ready
- **After fixes**: ~98% ready
- **Blocking issues**: 2 critical data race risks

### Files by Risk Level
**High Risk** (need immediate attention):
1. `CacheService.swift` - Unprotected shared state
2. `ListViewModel.swift` - Sendable violations

**Medium Risk** (should address soon):
1. `NetworkService.swift` - Missing isolation annotations
2. `CameraView.swift` - Task lifecycle issues

**Low Risk** (already good):
1. `LocationService.swift` - Excellent patterns
2. `ImageUploadService.swift` - Proper isolation
3. `StoneService.swift` - Good @MainActor usage

---

## 🎯 Action Plan

### Phase 1: Fix Critical Issues (1-2 hours)
**Goal**: Eliminate data race risks

1. **Make CacheService an actor** (30 min)
   - Convert class to actor
   - Update call sites to use await
   - Test concurrent access

2. **Add @MainActor to ViewModels** (30 min)
   - Annotate Observable view models
   - Verify UI updates are safe
   - Test with Thread Sanitizer

**Expected Impact**: No data races, Swift 6 critical issues resolved

### Phase 2: High Priority (2-3 hours)
**Goal**: Fix Sendable conformance

1. **Audit Sendable conformance** (1 hour)
   - Replace non-Sendable types
   - Add explicit Sendable conformance
   - Fix Task captures

2. **Add missing isolation** (1 hour)
   - Annotate services appropriately
   - Add @MainActor where needed
   - Use actors for background services

**Expected Impact**: Ready for Swift 6 strict mode

### Phase 3: Medium Priority (1-2 hours)
**Goal**: Improve task lifecycle

1. **Add task cancellation** (1 hour)
   - Store task references
   - Cancel on view disappear
   - Check Task.isCancelled in loops

**Expected Impact**: Better resource management, no leaks

---

## 🛠️ Specific Code Fixes

### Fix 1: Convert to Actor

```swift
// Before: Data race risk
class CacheService {
    private var cache: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        cache[key]
    }

    func set(_ key: String, data: Data) {
        cache[key] = data
    }
}

// After: Thread-safe
actor CacheService {
    private var cache: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        cache[key]
    }

    func set(_ key: String, data: Data) {
        cache[key] = data
    }
}

// Update call sites
let data = await cacheService.get("key")  // Now requires await
```

### Fix 2: Add @MainActor

```swift
// Before: Unsafe
@Observable
class ListViewModel {
    var items: [Item] = []

    func load() {
        Task {
            self.items = await fetch()  // Race condition
        }
    }
}

// After: Safe
@Observable
@MainActor
final class ListViewModel {
    var items: [Item] = []

    func load() {
        Task {
            self.items = await fetch()  // Safe - main actor
        }
    }
}
```

### Fix 3: Task Cancellation

```swift
// Before: Leaks
struct MyView: View {
    var body: some View {
        Text("Hello")
            .onAppear {
                Task {
                    await longRunningOperation()
                }
            }
    }
}

// After: Proper cleanup
struct MyView: View {
    @State private var task: Task<Void, Never>?

    var body: some View {
        Text("Hello")
            .task {
                await longRunningOperation()
            }  // Auto-cancels on disappear
    }
}
```

---

## 🧪 Testing Recommendations

### Enable Thread Sanitizer
In Xcode:
1. Edit Scheme → Run → Diagnostics
2. Enable "Thread Sanitizer"
3. Run app and perform concurrent operations
4. Check for data race warnings

### Enable Swift 6 Mode (Preview)
In build settings:
```
SWIFT_UPCOMING_FEATURE_FLAGS = StrictConcurrency
```

This will show warnings for all Swift 6 concurrency issues.

### Test Scenarios
Run these with Thread Sanitizer:
1. Upload 5 images simultaneously
2. Fetch stones while scrolling list
3. Update location while using AR
4. Background app and return quickly

---

## 📚 Resources

- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Actor Isolation](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
- [Sendable Types](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
- [MainActor](https://developer.apple.com/documentation/swift/mainactor)

---

**Note**: Your codebase is already quite good with concurrency! Most issues are about making implicit safety explicit for Swift 6 compliance.
```

## Important Notes

- Focus on actual data race risks first
- Swift 6 will make these checks mandatory
- Thread Sanitizer is your friend - use it
- Actor isolation is not about performance, it's about safety
- When in doubt, use @MainActor for UI-related code

## Special Considerations for Your Codebase

### Already Excellent:
- LocationService continuation management (actor-based)
- ImageUploadService background work
- Weak self captures in closures
- Async/await throughout

### Focus Areas:
- ImageCacheService (dictionary access patterns)
- Observable classes (add @MainActor explicitly)
- Task lifecycle in views
- Sendable conformance for model types
