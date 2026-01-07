# SwiftUI View Refactor

Refactor SwiftUI views for consistent structure, proper dependency injection, and maintainability following MVVM best practices.

## Instructions

Analyze SwiftUI views and suggest refactorings for better code organization, performance, and maintainability.

### 1. View Structure Analysis

**Check File Organization:**

All views should follow this structure:

```swift
// MARK: - View Definition
struct MyView: View {
    // MARK: - Properties

    // Dependencies (injected or environment)
    @Environment(\.dismiss) private var dismiss
    @Bindable private var service = MyService.shared

    // View state
    @State private var viewModel = MyViewModel()
    @State private var isShowingSheet = false

    // View-local UI state
    @State private var searchText = ""
    @FocusState private var focusedField: Field?

    // MARK: - Body

    var body: some View {
        content
    }

    // MARK: - View Components

    @ViewBuilder
    private var content: some View {
        NavigationStack {
            VStack {
                headerSection
                listSection
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        // ...
    }

    @ViewBuilder
    private var listSection: some View {
        // ...
    }

    // MARK: - Actions

    private func handleSubmit() {
        // ...
    }
}
```

**Search Commands:**
- Find views >200 lines: Check file size, flag for extraction
- Find complex body: Look for `var body` with >20 lines
- Find missing MARK comments: Views should have clear sections

### 2. Extract Complex Views

**Identify Extraction Opportunities:**

**Too Large (>200 lines):**
```swift
// ❌ Bad: Monolithic view
struct StoneDetailView: View {
    var body: some View {
        ScrollView {
            // 50 lines of header
            VStack {
                // ...
            }

            // 60 lines of details
            VStack {
                // ...
            }

            // 40 lines of stats
            VStack {
                // ...
            }

            // 50 lines of actions
            HStack {
                // ...
            }
        }
    }
}

// ✅ Good: Extracted sections
struct StoneDetailView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StoneDetailHeader(stone: stone)
                StoneDetailInfo(stone: stone)
                StoneDetailStats(stone: stone)
                StoneDetailActions(stone: stone)
            }
        }
    }
}

// Each section is now a focused, reusable component
struct StoneDetailHeader: View {
    let stone: Stone
    // ...
}
```

**Repeated Patterns:**
```swift
// ❌ Bad: Repeated code
struct ListView: View {
    var body: some View {
        List {
            ForEach(items1) { item in
                HStack {
                    Image(systemName: item.icon)
                    Text(item.title)
                    Spacer()
                    Text(item.subtitle)
                }
            }

            ForEach(items2) { item in
                HStack {
                    Image(systemName: item.icon)
                    Text(item.title)
                    Spacer()
                    Text(item.subtitle)
                }
            }
        }
    }
}

// ✅ Good: Extracted component
struct ItemRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Text(subtitle)
        }
    }
}

struct ListView: View {
    var body: some View {
        List {
            ForEach(items1) { item in
                ItemRow(icon: item.icon, title: item.title, subtitle: item.subtitle)
            }

            ForEach(items2) { item in
                ItemRow(icon: item.icon, title: item.title, subtitle: item.subtitle)
            }
        }
    }
}
```

**Complex Conditionals:**
```swift
// ❌ Bad: Complex body logic
var body: some View {
    VStack {
        if isLoading {
            ProgressView()
        } else if items.isEmpty {
            if searchText.isEmpty {
                Text("No items")
            } else {
                Text("No results")
            }
        } else {
            List(items) { item in
                // ...
            }
        }
    }
}

// ✅ Good: Extracted view builders
var body: some View {
    VStack {
        contentView
    }
}

@ViewBuilder
private var contentView: some View {
    if isLoading {
        loadingView
    } else if items.isEmpty {
        emptyStateView
    } else {
        listView
    }
}

@ViewBuilder
private var emptyStateView: some View {
    if searchText.isEmpty {
        Text("No items")
    } else {
        Text("No results for '\(searchText)'")
    }
}
```

### 3. State Management Review

**Check Proper State Ownership:**

```swift
// ❌ Bad: Business logic in view
struct StoneListView: View {
    @State private var stones: [Stone] = []
    @State private var isLoading = false

    var body: some View {
        List(stones) { stone in
            Text(stone.name)
        }
        .task {
            isLoading = true
            do {
                let data = try await URLSession.shared.data(from: apiURL)
                stones = try JSONDecoder().decode([Stone].self, from: data.0)
            } catch {
                print(error)
            }
            isLoading = false
        }
    }
}

// ✅ Good: Business logic in ViewModel
struct StoneListView: View {
    @State private var viewModel = StoneListViewModel()

    var body: some View {
        List(viewModel.stones) { stone in
            Text(stone.name)
        }
        .task {
            await viewModel.fetchStones()
        }
    }
}

@Observable
@MainActor
final class StoneListViewModel {
    private let stoneService = StoneService.shared

    var stones: [Stone] { stoneService.stones }
    var isLoading: Bool { stoneService.isLoading }

    func fetchStones() async {
        await stoneService.fetchStones()
    }
}
```

**State Property Usage:**

```swift
// ✅ Good: Proper state property usage
struct MyView: View {
    // UI state only in views
    @State private var searchText = ""
    @State private var isShowingSheet = false
    @FocusState private var focusedField: Field?

    // Business logic in ViewModel
    @State private var viewModel = MyViewModel()

    // Shared services via dependency injection
    @Bindable private var authService = AuthService.shared

    // Environment values
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
}
```

### 4. Dependency Injection Patterns

**Check for Implicit Dependencies:**

```swift
// ❌ Bad: Direct service access
struct MyView: View {
    var body: some View {
        Button("Fetch") {
            Task {
                await StoneService.shared.fetchStones()  // Hard to test
            }
        }
    }
}

// ✅ Good: Injected ViewModel
struct MyView: View {
    @State private var viewModel = MyViewModel()

    var body: some View {
        Button("Fetch") {
            Task {
                await viewModel.fetchStones()  // Testable
            }
        }
    }
}

// ViewModel handles service interaction
@Observable
@MainActor
final class MyViewModel {
    private let stoneService: StoneServiceProtocol

    init(stoneService: StoneServiceProtocol = StoneService.shared) {
        self.stoneService = stoneService
    }

    func fetchStones() async {
        await stoneService.fetchStones()
    }
}
```

### 5. Performance Patterns

**Check for Performance Issues:**

**Expensive Operations in Body:**
```swift
// ❌ Bad: Computation in body (runs on every render)
var body: some View {
    let filtered = stones.filter { $0.weight > 100 }  // Recomputed every time
    let sorted = filtered.sorted { $0.weight > $1.weight }

    List(sorted) { stone in
        Text(stone.name)
    }
}

// ✅ Good: Computed property with caching
var body: some View {
    List(heavyStones) { stone in
        Text(stone.name)
    }
}

private var heavyStones: [Stone] {
    stones
        .filter { $0.weight > 100 }
        .sorted { $0.weight > $1.weight }
}

// ✅ Better: Cached in ViewModel
@Observable
final class ViewModel {
    var stones: [Stone] = []

    var heavyStones: [Stone] {
        stones
            .filter { $0.weight > 100 }
            .sorted { $0.weight > $1.weight }
    }
}
```

**Missing View Identity:**
```swift
// ⚠️ Potential issue: No explicit identity
List(stones) { stone in
    StoneRow(stone: stone)  // SwiftUI uses stone.id
}

// ✅ Good: Explicit identity helps diffing
List(stones, id: \.id) { stone in
    StoneRow(stone: stone)
}

// ✅ Also good: Stable identity for complex rows
List(stones) { stone in
    StoneRow(stone: stone)
        .id(stone.id)  // Explicit identity
}
```

**Task Modifiers:**
```swift
// ❌ Bad: Manual task management
struct MyView: View {
    @State private var task: Task<Void, Never>?

    var body: some View {
        Text("Loading...")
            .onAppear {
                task = Task {
                    await load()
                }
            }
            .onDisappear {
                task?.cancel()
            }
    }
}

// ✅ Good: Built-in task modifier
struct MyView: View {
    var body: some View {
        Text("Loading...")
            .task {
                await load()  // Auto-cancels on disappear
            }
    }
}

// ✅ Good: Task with ID for refresh
struct MyView: View {
    @State private var filter: FilterType = .all

    var body: some View {
        Text("Loading...")
            .task(id: filter) {
                await load(filter)  // Restarts when filter changes
            }
    }
}
```

### 6. Code Duplication (DRY)

**Find Duplicate Code:**

```swift
// ❌ Bad: Duplicate color mapping (your StoneListView:243)
private func colorForLevel(_ level: LiftingLevel) -> Color {
    switch level.color {
    case "orange": return .orange
    case "yellow": return .yellow
    case "blue": return .blue
    case "green": return .green
    default: return .gray
    }
}

// ✅ Good: Extension on model
extension LiftingLevel {
    var displayColor: Color {
        switch color {
        case "orange": return .orange
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        default: return .gray
        }
    }
}

// Usage
Text(stone.liftingLevel.displayName)
    .foregroundColor(stone.liftingLevel.displayColor)  // No helper function needed
```

### 7. ViewBuilder Best Practices

**When to Use @ViewBuilder:**

```swift
// ✅ Use for complex composed views
@ViewBuilder
private var headerSection: some View {
    VStack {
        titleView
        subtitleView
        actionButtons
    }
}

// ✅ Use for conditional views
@ViewBuilder
private var statusIndicator: some View {
    if isLoading {
        ProgressView()
    } else if hasError {
        ErrorView()
    } else {
        SuccessView()
    }
}

// ✅ Use for reusable view functions
@ViewBuilder
private func itemRow(_ item: Item) -> some View {
    HStack {
        Text(item.title)
        Spacer()
        Text(item.subtitle)
    }
}

// ❌ Don't use for simple single views
@ViewBuilder  // Unnecessary
private var title: some View {
    Text("Title")
}

// Better
private var title: some View {
    Text("Title")
}
```

## Output Format

```markdown
## 🎨 SwiftUI Refactor Report
**Analysis Date**: YYYY-MM-DD
**Views Analyzed**: X views
**Refactor Opportunities**: Y opportunities (Z high priority)
**Code Health**: A / B / C / D

---

## 🔴 HIGH PRIORITY Refactors

### Views That Are Too Large

1. **StoneDetailView.swift** (345 lines)
   - **Issue**: Single view file too large and complex
   - **Current Structure**: Everything in one body
   - **Recommendation**: Extract into 4 focused components:
     - `StoneDetailHeader` (image, name, weight)
     - `StoneDetailInfo` (location, date, description)
     - `StoneDetailStats` (achievements, level, status)
     - `StoneDetailActions` (edit, delete, share buttons)
   - **Benefits**:
     - Easier to maintain
     - Faster compile times
     - Reusable components
     - Better testability
   - **Effort**: 1-2 hours
   - **Priority**: 🔴 High

### Business Logic in Views

1. **AddStoneView.swift:120-140**
   - **Issue**: Image upload logic in view
   - **Code**: Direct ImageUploadService calls in view
   - **Recommendation**: Move to StoneFormViewModel
   - **Benefits**: Testable, reusable logic
   - **Effort**: 30 minutes
   - **Priority**: 🔴 High

---

## ⚠️ MEDIUM PRIORITY Refactors

### Code Duplication

1. **StoneListView.swift:243 & StoneDetailView.swift:156**
   - **Issue**: Duplicate colorForLevel function (marked TODO: DRY)
   - **Code**: Same color mapping logic in two places
   - **Recommendation**: Create LiftingLevel extension
   - **Benefits**: Single source of truth, consistency
   - **Effort**: 15 minutes
   - **Priority**: 🟠 Medium

```swift
// Add to LiftingLevel model
extension LiftingLevel {
    var displayColor: Color {
        switch color {
        case "orange": return .orange
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        default: return .gray
        }
    }
}
```

### View Extraction Opportunities

1. **StoneListView.swift:238-362**
   - **Issue**: StoneRowView could be in separate file
   - **Recommendation**: Extract to `Views/Components/StoneRowView.swift`
   - **Benefits**: Reusable, easier to test, cleaner structure
   - **Effort**: 10 minutes
   - **Priority**: 🟠 Medium

### Performance Optimizations

1. **StoneListView.swift:152**
   - **Issue**: Computed property runs filtering on every access
   - **Code**: `filteredStones` computed property
   - **Recommendation**: Cache filtered results in ViewModel
   - **Benefits**: Better performance with large datasets
   - **Effort**: 30 minutes
   - **Priority**: 🟠 Medium

---

## ℹ️ LOW PRIORITY Improvements

### ViewBuilder Extraction

1. **MapView.swift:86-130**
   - **Issue**: Map content could be extracted
   - **Recommendation**: Extract map annotations to separate @ViewBuilder
   - **Benefits**: Cleaner code, easier to modify
   - **Effort**: 20 minutes
   - **Priority**: 🟡 Low

### Naming Consistency

1. **Various files**
   - **Issue**: Some private vars use `view` suffix, some don't
   - **Examples**: `headerSection` vs `contentView`
   - **Recommendation**: Consistent naming (prefer `Section` suffix)
   - **Effort**: 15 minutes
   - **Priority**: 🟡 Low

---

## ✅ Well-Structured Views

**Your codebase shows excellent SwiftUI patterns:**

1. ✨ **StoneListView.swift**
   - Clean MVVM separation
   - Good use of @ViewBuilder
   - Proper state management
   - Clear section extraction

2. ✨ **AddStoneView.swift**
   - Multi-step form well organized
   - Good focus state management
   - Proper validation patterns

3. ✨ **RemoteImage.swift**
   - Perfect example of simple, focused component
   - Clean API design
   - Reusable and testable

4. ✨ **FilterChip.swift** (in StoneListView)
   - Small, focused component
   - Reusable design
   - Good encapsulation

---

## 📊 View Complexity Metrics

### By Line Count
| View | Lines | Status | Recommended Action |
|------|-------|--------|-------------------|
| StoneDetailView | 345 | 🔴 Too large | Extract 4 components |
| StoneListView | 415 | 🔴 Too large | Extract StoneRowView |
| AddStoneView | 280 | 🟡 OK | Monitor growth |
| MapView | 200 | ✅ Good | None |
| ProfileView | 180 | ✅ Good | None |

### By Complexity
| View | Conditionals | ViewBuilders | Status |
|------|--------------|--------------|--------|
| StoneDetailView | 12 | 2 | 🔴 Complex |
| StoneListView | 8 | 4 | 🟡 Moderate |
| AddStoneView | 15 | 6 | 🟡 Moderate |

### State Management
| Pattern | Count | Status |
|---------|-------|--------|
| @State with ViewModel | 15 | ✅ Excellent |
| @State for UI only | 25 | ✅ Excellent |
| Business logic in View | 2 | 🟡 Needs fixing |

---

## 🎯 Refactor Action Plan

### Phase 1: High Priority (4-6 hours)
**Goal**: Fix structural issues

1. **Extract StoneDetailView sections** (2 hours)
   - Create 4 separate view files
   - Update imports and references
   - Test functionality

2. **Move business logic to ViewModels** (1 hour)
   - Extract image upload to ViewModel
   - Extract validation logic
   - Test with existing views

3. **Fix code duplication** (1 hour)
   - Create LiftingLevel extension
   - Update all usage sites
   - Remove duplicate functions

**Expected Benefits**:
- Faster compile times (40% for large files)
- Easier to find and modify code
- Better code reuse

### Phase 2: Medium Priority (2-3 hours)
**Goal**: Performance and organization

1. **Cache filtered results** (1 hour)
   - Update StoneListViewModel
   - Invalidate cache on changes
   - Performance test

2. **Extract reusable components** (1 hour)
   - StoneRowView to separate file
   - Create Components directory
   - Update imports

**Expected Benefits**:
- Better list performance
- Clearer project structure
- Easier testing

### Phase 3: Polish (1-2 hours)
**Goal**: Consistency and maintainability

1. **Consistent naming** (30 min)
2. **ViewBuilder extraction** (1 hour)

---

## 🛠️ Refactor Examples

### Example 1: Extract Complex View

**Before** (StoneDetailView.swift - 345 lines):
```swift
struct StoneDetailView: View {
    let stone: Stone

    var body: some View {
        ScrollView {
            // 80 lines of header
            VStack {
                AsyncImage(url: stone.imageURL)
                Text(stone.name)
                Text(stone.formattedWeight)
                // ... more header code
            }

            // 60 lines of info
            VStack {
                // ... location, date, description
            }

            // 50 lines of stats
            VStack {
                // ... achievements, level
            }

            // 40 lines of actions
            HStack {
                // ... edit, delete, share
            }
        }
    }
}
```

**After** (StoneDetailView.swift - 80 lines):
```swift
struct StoneDetailView: View {
    let stone: Stone

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StoneDetailHeader(stone: stone)
                StoneDetailInfo(stone: stone)
                StoneDetailStats(stone: stone)
                StoneDetailActions(
                    stone: stone,
                    onEdit: handleEdit,
                    onDelete: handleDelete,
                    onShare: handleShare
                )
            }
        }
    }

    private func handleEdit() { /* ... */ }
    private func handleDelete() { /* ... */ }
    private func handleShare() { /* ... */ }
}

// Each component is now focused and reusable
// StoneDetailHeader.swift (40 lines)
// StoneDetailInfo.swift (30 lines)
// StoneDetailStats.swift (35 lines)
// StoneDetailActions.swift (45 lines)
```

### Example 2: Move Business Logic

**Before** (View with business logic):
```swift
struct AddStoneView: View {
    @State private var image: UIImage?
    @State private var isUploading = false

    var body: some View {
        Button("Upload") {
            Task {
                isUploading = true
                guard let imageData = image?.jpegData(compressionQuality: 0.8) else { return }
                let url = await ImageUploadService.shared.uploadImage(imageData)
                isUploading = false
                // ... more logic
            }
        }
    }
}
```

**After** (Business logic in ViewModel):
```swift
struct AddStoneView: View {
    @State private var viewModel = StoneFormViewModel()

    var body: some View {
        Button("Upload") {
            Task {
                await viewModel.uploadImage()
            }
        }
        .disabled(viewModel.isUploading)
    }
}

@Observable
@MainActor
final class StoneFormViewModel {
    private(set) var isUploading = false

    func uploadImage() async {
        isUploading = true
        defer { isUploading = false }

        guard let imageData = image?.jpegData(compressionQuality: 0.8) else { return }
        imageUrl = await ImageUploadService.shared.uploadImage(imageData)
    }
}
```

---

## 📏 View Structure Guidelines

### Ideal View Size
- **Small**: < 100 lines (ideal)
- **Medium**: 100-200 lines (acceptable)
- **Large**: 200-300 lines (consider extraction)
- **Too Large**: > 300 lines (should refactor)

### Component Extraction Rules
Extract when:
- View exceeds 200 lines
- Code block is repeated 2+ times
- Section has clear single responsibility
- Component could be reused
- Testing would benefit from isolation

Don't extract when:
- Component used only once and tightly coupled
- Less than 20 lines
- Would require too many parameters (>5)
- Would reduce clarity

---

## ✨ SwiftUI Best Practices Checklist

For each view, verify:
- [ ] Clear MARK sections
- [ ] Business logic in ViewModel
- [ ] @State only for UI state
- [ ] Extracted view builders for complex sections
- [ ] No expensive operations in body
- [ ] Proper dependency injection
- [ ] Task modifiers for async work
- [ ] Accessibility labels on interactive elements
- [ ] Preview with realistic data
- [ ] File size reasonable (<200 lines ideal)

---

**Your SwiftUI code is already quite good!** These refactors will make it even better for long-term maintenance.
```

## Special Notes for Your Project

### Focus Areas:
1. StoneDetailView - likely your largest view file
2. Code duplication (colorForLevel - marked with TODO)
3. Business logic separation (already mostly good)

### Keep Doing:
- MVVM separation (excellent)
- @ViewBuilder usage (good patterns)
- ViewModel injection (proper approach)
- Component extraction (FilterChip, RemoteImage)

### Priority Order:
1. Fix duplicate code (quick win)
2. Extract large views if any
3. Cache filtered results for performance
4. Polish and consistency
