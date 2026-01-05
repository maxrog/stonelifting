# Performance Profiler

Analyze the codebase for performance bottlenecks, memory issues, and optimization opportunities. Especially critical for AR, camera, and image-heavy features.

## Instructions

Perform a comprehensive performance analysis across the entire codebase, focusing on critical performance areas.

### 1. Main Thread Analysis

**Identify Main Thread Blockers:**
Search for operations that could block the main thread:

- [ ] Heavy computation without `Task { }` or background queue
- [ ] Synchronous network calls on main thread
- [ ] Large data processing in view bodies
- [ ] Synchronous file I/O operations
- [ ] Image processing without async
- [ ] Large JSON encoding/decoding on main thread

**Patterns to Find:**
```swift
// Bad: Heavy work on main thread
@MainActor
func loadData() {
    let result = heavyComputation() // Blocks UI
}

// Bad: Synchronous file operations
let data = try Data(contentsOf: url) // Blocks thread

// Bad: Large loops in view body
var body: some View {
    VStack {
        ForEach(0..<10000) { // Expensive
            Text("\($0)")
        }
    }
}
```

**Search Commands:**
- `@MainActor` functions with heavy computation
- `URLSession` without `.data(for:)` async variant
- `Data(contentsOf:)` synchronous file reads
- Large `ForEach` loops in views
- Image processing without `Task { }`

### 2. Memory Management Analysis

**Find Potential Memory Issues:**

- [ ] Retain cycles in closures (missing `[weak self]`)
- [ ] Strong reference captures in Tasks
- [ ] Uncancelled tasks that might leak
- [ ] Large data caching without limits
- [ ] Image caching without memory pressure handling
- [ ] Continuation leaks (stored but never resumed)

**Patterns to Find:**
```swift
// Bad: Retain cycle
Task {
    await self.method() // Strong capture
}

// Bad: Uncancelled long-running task
func startTask() {
    Task {
        while true { // Runs forever
            await doWork()
        }
    }
}

// Bad: Unlimited cache
var imageCache: [String: UIImage] = [:] // Can grow indefinitely
```

**Search Commands:**
- `Task {` without `[weak self]`
- `while true` in tasks
- Cache dictionaries/arrays without size limits
- `URLSession` instances not cleaned up
- Continuation storage without cleanup

### 3. Image & Media Performance

**Check Image Handling:**

- [ ] Large images loaded without resizing
- [ ] No image caching strategy
- [ ] Images loaded synchronously
- [ ] No lazy loading for image lists
- [ ] Camera/photo library without memory limits
- [ ] No image compression before upload

**Patterns to Find:**
```swift
// Bad: Load full-size image
UIImage(named: "huge-image") // Not resized

// Bad: No caching
AsyncImage(url: url) // Re-downloads every time

// Bad: Synchronous image loading
let image = UIImage(contentsOfFile: path)

// Bad: No compression before upload
uploadService.upload(image: fullSizeImage) // Huge file
```

**Search Commands:**
- `UIImage(named:)` without resizing
- `AsyncImage` without caching
- Image upload without compression
- Photo library access without limits

### 4. Network Performance

**Identify Network Inefficiencies:**

- [ ] No request caching
- [ ] Serial requests that could be parallel
- [ ] No request deduplication
- [ ] Missing timeout configurations
- [ ] No retry logic with backoff
- [ ] Large payloads without pagination

**Patterns to Find:**
```swift
// Bad: Serial requests
for item in items {
    await api.fetch(item) // One at a time
}

// Bad: No timeout
URLSession.shared.data(from: url) // Could hang forever

// Bad: No caching
URLCache.shared.memoryCapacity = 0 // Disabled

// Bad: No pagination
func fetchAll() -> [Item] // Returns 10,000 items
```

**Search Commands:**
- Sequential `await` in loops
- `URLRequest` without `timeoutInterval`
- API calls without pagination
- No `URLCache` configuration

### 5. SwiftUI Performance

**Find SwiftUI Performance Issues:**

- [ ] Expensive computations in `body`
- [ ] Missing `@ViewBuilder` for complex views
- [ ] No view identity (causes unnecessary re-renders)
- [ ] Large view hierarchies not extracted
- [ ] Observable properties that trigger too often
- [ ] Missing `equatable` for list items

**Patterns to Find:**
```swift
// Bad: Computation in body
var body: some View {
    let processed = heavyComputation() // Runs on every render
    return Text(processed)
}

// Bad: No view extraction
var body: some View {
    VStack {
        // 200 lines of complex UI
    }
}

// Bad: Observable triggers too often
@Observable class ViewModel {
    var timestamp = Date() // Changes every second
}

// Bad: No identity
ForEach(items) { item in // Re-renders all on change
    ItemView(item)
}
```

**Search Commands:**
- Function calls in `var body`
- View files >200 lines without `@ViewBuilder` extracts
- `@Observable` with frequently-changing properties
- `ForEach` without `id:` parameter

### 6. Location Services Performance

**Check Location Usage:**

- [ ] Continuous location updates when not needed
- [ ] No distance filter (updates too frequently)
- [ ] High accuracy when not required
- [ ] Location updates not stopped when done
- [ ] No battery optimization

**Patterns to Find:**
```swift
// Bad: Continuous updates
manager.startUpdatingLocation() // Never stops

// Bad: No distance filter
manager.distanceFilter = kCLDistanceFilterNone // Updates constantly

// Bad: Always high accuracy
manager.desiredAccuracy = kCLLocationAccuracyBest // Drains battery
```

**Search Commands:**
- `startUpdatingLocation()` without `stopUpdatingLocation()`
- `desiredAccuracy` set to `Best` or `BestForNavigation`
- No `distanceFilter` configuration
- Location updates in background

### 7. Algorithm Efficiency

**Find Inefficient Algorithms:**

- [ ] Nested loops (O(n²) complexity)
- [ ] Linear search instead of hash lookup
- [ ] Repeated array filtering
- [ ] Sorting in loops
- [ ] String concatenation in loops

**Patterns to Find:**
```swift
// Bad: O(n²) nested loops
for item in items {
    for other in items { // n² complexity
        compare(item, other)
    }
}

// Bad: Linear search
items.first(where: { $0.id == searchId }) // O(n)
// Better: Dictionary lookup O(1)

// Bad: Repeated filtering
let filtered = items.filter { condition1 }
let filtered2 = items.filter { condition2 } // Filters again

// Bad: String concatenation in loop
var result = ""
for item in items {
    result += item // Creates new string each time
}
```

**Search Commands:**
- Nested `for` loops
- `.first(where:)` in hot paths
- Multiple `.filter()` calls on same array
- String `+=` in loops

### 8. Logging Performance

**Check for Excessive Logging:**

- [ ] Debug logs in production
- [ ] Logging in tight loops
- [ ] Large object logging
- [ ] Synchronous logging on critical path

**Patterns to Find:**
```swift
// Bad: Logging in loop
for item in items {
    logger.debug("Processing \(item)") // 1000s of logs
}

// Bad: Large object logging
logger.debug("Data: \(hugeArray)") // Expensive serialization

// Bad: On critical path
func render() {
    logger.info("Rendering...") // Slows down rendering
}
```

**Search Commands:**
- `logger.debug()` in loops
- `logger` calls in `body` computed property
- Logging large arrays/dictionaries

### 9. File I/O Performance

**Find File Operation Issues:**

- [ ] Synchronous file reads on main thread
- [ ] No file operation caching
- [ ] Large files read into memory at once
- [ ] Frequent small writes (should batch)

**Patterns to Find:**
```swift
// Bad: Synchronous read
let data = try Data(contentsOf: fileURL) // Blocks

// Bad: Read entire large file
let contents = try String(contentsOf: url) // 100MB file

// Bad: Frequent small writes
for item in items {
    try item.write(to: url) // Disk I/O for each
}
```

**Search Commands:**
- `Data(contentsOf:)` synchronous reads
- `String(contentsOf:)` synchronous reads
- File writes in loops

### 10. Task Management

**Check Async Task Handling:**

- [ ] Missing task cancellation
- [ ] No timeout on long operations
- [ ] Task priorities not set
- [ ] Detached tasks unnecessarily
- [ ] Missing error handling in tasks

**Patterns to Find:**
```swift
// Bad: No cancellation
Task {
    await longOperation() // Can't cancel
}

// Bad: No timeout
await api.fetch() // Could wait forever

// Bad: Unnecessary detached task
Task.detached { // Loses priority inheritance
    await work()
}
```

**Search Commands:**
- `Task {` without storing reference
- `await` without timeout
- `Task.detached` usage
- Long-running tasks without cancellation

## Output Format

```markdown
## ⚡ Performance Profile Report
**Analysis Date**: YYYY-MM-DD
**Files Analyzed**: X Swift files
**Issues Found**: Y issues (Z critical)
**Performance Score**: B+ (estimated)

---

## 🚨 CRITICAL Performance Issues

### Main Thread Blocking
**Impact**: High - Causes UI freezes and poor user experience

1. **File**: path/to/Service.swift:123
   - **Issue**: Synchronous network request on main thread
   - **Code**: `let data = try Data(contentsOf: url)`
   - **Impact**: Blocks UI for 1-3 seconds
   - **Fix**: Use async URLSession: `let (data, _) = try await URLSession.shared.data(from: url)`
   - **Priority**: 🔴 Critical

2. **File**: path/to/View.swift:45
   - **Issue**: Heavy computation in view body
   - **Code**: `let result = processThousandItems(items)`
   - **Impact**: Renders slowly, frame drops
   - **Fix**: Move to ViewModel with `@State` or computed property with caching
   - **Priority**: 🔴 Critical

---

## ⚠️ HIGH PRIORITY Issues

### Memory Management
**Impact**: Medium-High - Potential leaks and increased memory usage

1. **File**: path/to/ViewModel.swift:89
   - **Issue**: Retain cycle in Task closure
   - **Code**: `Task { await self.loadData() }`
   - **Impact**: ViewModel never deallocates
   - **Fix**: Use `[weak self]`: `Task { [weak self] in await self?.loadData() }`
   - **Priority**: 🟠 High

### Image Performance
**Impact**: High - Large memory footprint, slow scrolling

1. **File**: path/to/ImageView.swift:34
   - **Issue**: Full-resolution image loaded without resizing
   - **Code**: `UIImage(named: "photo")`
   - **Impact**: 12MB image for 100x100 view
   - **Fix**: Resize image to display size before showing
   - **Priority**: 🟠 High

---

## ℹ️ MEDIUM PRIORITY Issues

### Network Performance
**Impact**: Medium - Slower response times

1. **File**: path/to/APIService.swift:156
   - **Issue**: Serial API requests in loop
   - **Code**: `for item in items { await fetch(item) }`
   - **Impact**: 10 requests take 10x time instead of parallel
   - **Fix**: Use `await withTaskGroup { }` for concurrent requests
   - **Priority**: 🟡 Medium

### Algorithm Efficiency
**Impact**: Medium - Slower processing

1. **File**: path/to/DataProcessor.swift:78
   - **Issue**: Nested loops creating O(n²) complexity
   - **Code**: `for item in items { for other in items { } }`
   - **Impact**: Slow with large datasets (100 items = 10,000 operations)
   - **Fix**: Use hash map for O(n) lookup
   - **Priority**: 🟡 Medium

---

## ✅ Performance Strengths

- Proper use of async/await in most services
- Good separation of concerns (MVVM)
- Location service has timeout protection
- Observable pattern used correctly
- Most services use background queues

---

## 📊 Performance Metrics

### By Category
| Category | Issues | Critical | High | Medium |
|----------|--------|----------|------|--------|
| Main Thread | 5 | 3 | 2 | 0 |
| Memory | 8 | 0 | 4 | 4 |
| Images | 3 | 0 | 3 | 0 |
| Network | 4 | 0 | 1 | 3 |
| SwiftUI | 6 | 1 | 3 | 2 |
| Algorithms | 2 | 0 | 0 | 2 |

### By File
**Top 5 Files with Most Issues**:
1. `ImageUploadService.swift` - 8 issues
2. `StoneListView.swift` - 6 issues
3. `APIService.swift` - 5 issues
4. `LocationService.swift` - 4 issues
5. `AuthService.swift` - 3 issues

### Estimated Performance Impact
- **App Launch**: Could improve by 30% (main thread blocking in init)
- **Image Scrolling**: Could improve by 60% (image resizing, caching)
- **Network Operations**: Could improve by 40% (parallel requests, caching)
- **Memory Usage**: Could reduce by 50% (image optimization, leak fixes)
- **Battery Life**: Could improve by 20% (location service optimization)

---

## 🎯 Recommended Action Plan

### Week 1: Critical Fixes (Immediate Impact)
**Priority**: Fix UI freezes and crashes

1. **Fix main thread blocking** (3 issues)
   - Move synchronous network calls to async
   - Extract heavy computation from view bodies
   - Use background queues for image processing

2. **Optimize image loading** (3 issues)
   - Implement image resizing before display
   - Add image caching strategy
   - Compress images before upload

**Expected Impact**:
- UI freezes eliminated
- Scrolling FPS: 30 → 60
- Memory usage: -40%

### Week 2: High Priority (Performance Gains)
**Priority**: Improve responsiveness and memory

1. **Fix memory leaks** (4 issues)
   - Add `[weak self]` to Task closures
   - Implement cache size limits
   - Cancel tasks on cleanup

2. **Optimize network calls** (1 issue)
   - Implement parallel requests where possible
   - Add request caching
   - Implement pagination

**Expected Impact**:
- Memory leaks eliminated
- Network response time: -40%
- Less data usage

### Week 3: Medium Priority (Long-term Health)
**Priority**: Code quality and efficiency

1. **Algorithm optimization** (2 issues)
   - Replace O(n²) with hash maps
   - Cache filtered results
   - Batch operations

2. **SwiftUI optimization** (2 issues)
   - Extract complex views
   - Add view identity
   - Optimize observable triggers

**Expected Impact**:
- Better scalability with large datasets
- Smoother animations
- Lower CPU usage

---

## 🛠️ Specific Optimizations

### Image Optimization Pattern
```swift
// Before: Full resolution (12MB in memory)
AsyncImage(url: stoneImageURL)

// After: Resized and cached (<1MB in memory)
CachedAsyncImage(url: stoneImageURL, size: CGSize(width: 300, height: 300))
```

### Network Optimization Pattern
```swift
// Before: Serial (10 seconds total)
for stone in stones {
    await fetchDetails(stone)
}

// After: Parallel (1 second total)
await withTaskGroup(of: StoneDetails.self) { group in
    for stone in stones {
        group.addTask { await fetchDetails(stone) }
    }
    for await details in group {
        process(details)
    }
}
```

### Memory Optimization Pattern
```swift
// Before: Retain cycle
Task {
    await self.loadData() // Leaks
}

// After: Weak reference
Task { [weak self] in
    await self?.loadData() // Safe
}
```

### Main Thread Protection
```swift
// Before: Blocks UI
@MainActor
func processImage(_ image: UIImage) {
    let processed = heavyImageProcessing(image) // 2 seconds
    self.displayImage = processed
}

// After: Background processing
@MainActor
func processImage(_ image: UIImage) {
    Task {
        let processed = await Task.detached {
            heavyImageProcessing(image) // Off main thread
        }.value
        self.displayImage = processed // UI update on main
    }
}
```

---

## 📈 Performance Testing Recommendations

### Benchmarking
Create performance tests for critical paths:

```swift
func testImageLoadingPerformance() {
    measure {
        // Should complete in <100ms
        let image = loadAndResizeImage(url: testURL)
    }
}

func testAPIRequestPerformance() async {
    await measure {
        // Should complete in <500ms
        let stones = try await fetchStones()
    }
}
```

### Profiling with Instruments
Use Xcode Instruments to verify improvements:

1. **Time Profiler**: Find CPU hotspots
2. **Allocations**: Track memory usage
3. **Leaks**: Find memory leaks
4. **Network**: Monitor requests
5. **Energy Log**: Check battery impact

**Run Instruments On**:
- Stone list scrolling (60 FPS target)
- Image upload flow (memory spike check)
- Location tracking (battery impact)
- App launch (startup time)

### Real Device Testing
Test on low-end devices:
- iPhone SE (older hardware)
- Low memory conditions
- Poor network (throttle to 3G)
- Background mode performance

---

## 🎓 Performance Best Practices

### General Rules
1. **Main thread is for UI only** - Everything else goes to background
2. **Measure before optimizing** - Use Instruments to find real bottlenecks
3. **Optimize critical paths first** - Focus on what users do most
4. **Test on real devices** - Simulators don't show performance issues
5. **Profile regularly** - Catch regressions early

### SwiftUI Specific
1. **Extract complex views** - Keep `body` simple
2. **Use `@ViewBuilder`** - For reusable view components
3. **Minimize observable changes** - Only update when needed
4. **Add view identity** - Help SwiftUI with diffing
5. **Lazy load lists** - Use `LazyVStack` for long lists

### iOS Specific
1. **Resize images** - Never display full resolution unnecessarily
2. **Implement caching** - For images, network, computed values
3. **Use async/await** - Avoid blocking operations
4. **Cancel tasks** - Clean up when done
5. **Optimize location** - Use appropriate accuracy and distance filter

---

## 🔍 Monitoring & Regression Prevention

### Add Performance Monitoring
```swift
// Track critical metrics
logger.info("Image load time: \(duration)ms")
logger.info("API response time: \(duration)ms")
logger.info("Memory usage: \(memoryMB)MB")

// Set thresholds
assert(imageLoadTime < 100, "Image loading too slow")
assert(memoryUsage < 200, "Memory usage too high")
```

### CI Performance Tests
Add performance tests to CI:
- Fail build if critical path is too slow
- Track performance trends over time
- Alert on performance regressions

### User Metrics
Track in production:
- App launch time
- Screen load times
- Memory warnings
- Crash rate from OOM

---

**Remember**: Performance is a feature. Users notice slow apps and quick apps. Make yours quick.
```

## Special Focus Areas for This App

### AR/Camera Performance
- Camera feed processing
- ARKit session management
- Image capture and processing
- Real-time filters/effects

### Stone Photo Management
- Photo library access
- Image compression
- Upload queue management
- Thumbnail generation

### Location Tracking
- Continuous vs significant location
- Background location updates
- Battery optimization
- Caching recent locations

### List Performance
- Stone list scrolling
- Lazy loading
- Image thumbnails
- Pull to refresh

## Important Notes

- **Be specific**: Include file paths and line numbers
- **Measure impact**: Estimate performance improvement
- **Provide fixes**: Don't just identify, suggest solutions
- **Prioritize**: Critical issues first
- **Consider user impact**: Focus on user-facing performance
- **Think holistically**: Memory, CPU, battery, network all matter
- **Test recommendations**: Verify fixes improve performance

## Performance Targets

Set clear targets for critical paths:
- **App launch**: <2 seconds
- **Screen transitions**: <300ms
- **List scrolling**: 60 FPS
- **Image load**: <100ms
- **API requests**: <500ms
- **Memory usage**: <200MB typical
- **Battery drain**: <5% per hour active use
