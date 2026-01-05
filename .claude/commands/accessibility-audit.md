# Accessibility Auditor

Audit the iOS app for accessibility compliance, including VoiceOver support, Dynamic Type, color contrast, and touch target sizes.

## Instructions

Perform a comprehensive accessibility audit of the SwiftUI views and components to ensure the app is usable by everyone.

### 1. VoiceOver & Screen Reader Support

**Check for Accessibility Labels:**
Search for interactive elements missing `.accessibilityLabel()`:

- [ ] Buttons without labels (icon-only buttons)
- [ ] Images without descriptive labels
- [ ] Custom controls without labels
- [ ] Navigation elements
- [ ] Interactive gestures

**Patterns to Find:**
```swift
// Bad: No accessibility label
Button {
    action()
} label: {
    Image(systemName: "plus")  // Screen reader says "Image"
}

// Bad: Generic label
Image(systemName: "checkmark")
    .accessibilityLabel("checkmark")  // Not descriptive

// Good: Descriptive label
Button {
    addStone()
} label: {
    Image(systemName: "plus")
}
.accessibilityLabel("Add new stone")
```

**Search Commands:**
- Find buttons with only `Image`: `Button.*\{[^}]*Image\(systemName:`
- Find images without accessibility: `Image\(.*\)` not followed by `.accessibilityLabel`
- Find custom gestures: `.onTapGesture`, `.gesture(` without accessibility

**Check for Accessibility Hints:**
Non-obvious actions should have hints:

```swift
// Good: Hint explains what happens
Button("Details") {
    showDetails()
}
.accessibilityLabel("Stone details")
.accessibilityHint("Opens detailed information about this stone")
```

**Check for Accessibility Traits:**
Ensure elements have correct traits:

```swift
// Buttons should have .isButton trait (usually automatic)
// Headers should be marked
Text("Your Stones")
    .font(.title)
    .accessibilityAddTraits(.isHeader)

// Disabled elements
Button("Save") { }
    .disabled(true)
    .accessibilityAddTraits(.isButton)  // Already has it
    // .disabled() automatically adds proper state
```

**Check for Hidden Elements:**
Decorative elements should be hidden from VoiceOver:

```swift
// Good: Hide decorative images
Image("background-pattern")
    .accessibilityHidden(true)

// Good: Hide redundant elements
HStack {
    Image(systemName: "person")
        .accessibilityHidden(true)  // Icon is decorative
    Text("Profile")  // This has the real info
}
```

### 2. Dynamic Type Support

**Check Text Scaling:**
All text should support Dynamic Type (user font size preferences):

- [ ] Text uses standard font styles (`.title`, `.body`, etc.)
- [ ] Custom fonts use `.scaledValue()`
- [ ] Layouts adapt to larger text sizes
- [ ] No fixed heights that clip text
- [ ] ScrollViews used for content that might overflow

**Patterns to Find:**
```swift
// Bad: Fixed font size
Text("Username")
    .font(.system(size: 14))  // Won't scale

// Good: Dynamic font
Text("Username")
    .font(.body)  // Scales with user preference

// Bad: Fixed height
Text("Long description...")
    .frame(height: 40)  // Will clip with large text

// Good: Flexible height
Text("Long description...")
    .lineLimit(nil)  // Grows as needed
```

**Search Commands:**
- Find fixed fonts: `.font\(.system\(size:`
- Find fixed frames with text: `.frame\(height:`
- Find `lineLimit(1)` on important text

**Check for Minimum Sizes:**
Important text should have minimum scale factors:

```swift
// Allow some shrinking but not too much
Text("Important label")
    .minimumScaleFactor(0.8)  // Shrink max 20%
```

### 3. Color Contrast

**Check Color Combinations:**
Ensure sufficient contrast for readability (WCAG AA: 4.5:1 for normal text, 3:1 for large text):

- [ ] Text on backgrounds
- [ ] Button labels
- [ ] Link colors
- [ ] Icon colors
- [ ] Disabled state colors

**Patterns to Find:**
```swift
// Potential issues:
// - Light gray text on white background
// - Custom colors without checking contrast
// - Low opacity text

// Bad: Low contrast
Text("Subtitle")
    .foregroundColor(.gray)  // May be too light on white

// Good: Sufficient contrast
Text("Subtitle")
    .foregroundColor(.secondary)  // System color with proper contrast

// Bad: Custom color without thought
.foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9))  // Very light

// Check for opacity < 0.6 on text
Text("Warning")
    .opacity(0.5)  // May be too faint
```

**Search Commands:**
- Find low opacity: `.opacity\(0\.[0-5]`
- Find custom colors: `Color\(red:`
- Find `.gray` or `.secondary` on potentially light backgrounds

**High Contrast Mode:**
Support for high contrast accessibility setting:

```swift
@Environment(\.colorSchemeContrast) var contrast

var textColor: Color {
    contrast == .increased ? .primary : .secondary
}
```

### 4. Touch Target Sizes

**Minimum Size: 44x44 points (Apple HIG)**

Check for interactive elements smaller than 44x44:

- [ ] Buttons
- [ ] Toggle switches
- [ ] Segmented controls
- [ ] Links
- [ ] Interactive images

**Patterns to Find:**
```swift
// Bad: Too small
Button("X") {
    dismiss()
}
.frame(width: 24, height: 24)  // Only 24x24!

// Good: Minimum 44x44
Button("X") {
    dismiss()
}
.frame(width: 44, height: 44)  // Proper size

// Good: Use contentShape for hit area
Button {
    toggle()
} label: {
    Image(systemName: "checkmark")
        .frame(width: 20, height: 20)
}
.contentShape(Rectangle())
.frame(width: 44, height: 44)  // Full tap area
```

**Search Commands:**
- Find small frames: `.frame\(width: [0-3]\d, height: [0-3]\d\)`
- Find buttons with small images
- Find `.onTapGesture` on small views

### 5. Keyboard & Focus Management

**Check Focus Handling:**
Ensure keyboard navigation works properly:

- [ ] `@FocusState` used for form fields
- [ ] Tab order is logical
- [ ] Focus moves to next field on submit
- [ ] Focus visible indicators

**Patterns to Find:**
```swift
// Good: Focus management
@FocusState private var focusedField: Field?

TextField("Email", text: $email)
    .focused($focusedField, equals: .email)
    .onSubmit {
        focusedField = .password  // Move to next field
    }
```

**Search Commands:**
- Find TextFields: `TextField\(`
- Check for `@FocusState` usage
- Check `.onSubmit` handlers

### 6. Animation & Motion

**Check for Reduce Motion:**
Support for users who prefer reduced motion:

- [ ] Animations can be disabled
- [ ] No essential info conveyed only through motion
- [ ] Alternative feedback for animations

**Patterns to Find:**
```swift
// Good: Respect reduce motion
@Environment(\.accessibilityReduceMotion) var reduceMotion

var animation: Animation? {
    reduceMotion ? nil : .spring()
}

// Apply animation conditionally
.animation(animation, value: someValue)

// Or use built-in modifier
.animation(.default, value: someValue)  // Automatically respects setting
```

**Search Commands:**
- Find `.animation(` usages
- Check for `withAnimation` blocks
- Look for custom transitions

### 7. Semantic Content

**Check Grouping:**
Related content should be grouped for VoiceOver:

```swift
// Bad: Individual elements announced separately
HStack {
    Image(systemName: "mappin")
    Text("Location: ")
    Text(locationName)
}

// Good: Grouped as single element
HStack {
    Image(systemName: "mappin")
    Text("Location: ")
    Text(locationName)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Location: \(locationName)")
```

**Check Reading Order:**
Ensure VoiceOver reads in logical order:

```swift
// Good: Explicit sort priority
VStack {
    Text("Title")
        .accessibilitySortPriority(2)

    Image("photo")
        .accessibilitySortPriority(1)  // Read after title
}
```

### 8. Forms & Input Validation

**Check Error Announcements:**
Errors should be announced to screen readers:

- [ ] Validation errors have accessibility labels
- [ ] Error state is announced
- [ ] Required fields are marked

**Patterns to Find:**
```swift
// Bad: Visual-only error
if !isValid {
    Text("Invalid email")
        .foregroundColor(.red)  // Only visual
}

// Good: Announced error
TextField("Email", text: $email)
    .accessibilityLabel("Email address")
    .accessibilityValue(isValid ? email : "Invalid email: \(email)")

// Or use accessibility notification
if !isValid {
    AccessibilityNotification.Announcement("Invalid email entered")
        .post()
}
```

**Required Fields:**
```swift
TextField("Email", text: $email)
    .accessibilityLabel("Email address, required")
```

### 9. Images & Visual Content

**Check Alternative Text:**
All informative images need descriptions:

- [ ] Photos have meaningful descriptions
- [ ] Charts/graphs have text alternatives
- [ ] Icons convey information (not just decoration)

**Patterns to Find:**
```swift
// Bad: No description
AsyncImage(url: stoneImageURL)

// Good: Descriptive label
AsyncImage(url: stoneImageURL)
    .accessibilityLabel("Granite stone weighing 150 pounds, lifted to chest level")

// Decorative image (no info)
Image("background")
    .accessibilityHidden(true)
```

### 10. Common iOS Accessibility Issues

**Navigation:**
- [ ] Tab bar items have labels
- [ ] Navigation buttons are labeled
- [ ] Back buttons are properly labeled
- [ ] Modal dismissal is accessible

**Lists:**
- [ ] List items are accessible
- [ ] Swipe actions have labels
- [ ] Delete confirmations are accessible

**Alerts:**
- [ ] Alert titles and messages are accessible
- [ ] Alert buttons have clear labels
- [ ] Dismissal methods are accessible

**Custom Controls:**
- [ ] Custom sliders have value labels
- [ ] Custom pickers are accessible
- [ ] Star ratings announce current value
- [ ] Custom gestures have alternatives

## Output Format

```markdown
## ♿ Accessibility Audit Report
**Audit Date**: YYYY-MM-DD
**Views Analyzed**: X SwiftUI files
**Issues Found**: Y issues (Z critical)
**Accessibility Score**: B (estimated)

---

## 🚨 CRITICAL Issues (Block Release)

### Missing VoiceOver Labels
**Impact**: Critical - App unusable with VoiceOver

1. **File**: Views/Stones/AddStoneView.swift:123
   - **Issue**: Button with icon only, no accessibility label
   - **Code**: `Button { addStone() } label: { Image(systemName: "plus") }`
   - **Current Announcement**: "Image" (not helpful)
   - **Fix**: `.accessibilityLabel("Add new stone")`
   - **Priority**: 🔴 Critical

2. **File**: Views/Profile/ProfileView.swift:89
   - **Issue**: Custom gesture with no accessibility alternative
   - **Code**: `.onTapGesture { showDetail() }`
   - **Current State**: Not accessible to VoiceOver users
   - **Fix**: Add `.accessibilityAction` or make it a Button
   - **Priority**: 🔴 Critical

### Touch Target Too Small
**Impact**: High - Difficult to tap for motor impaired users

1. **File**: Views/Components/CloseButton.swift:34
   - **Issue**: Button only 24x24 points (minimum is 44x44)
   - **Code**: `.frame(width: 24, height: 24)`
   - **Impact**: Hard to tap, especially for users with motor difficulties
   - **Fix**: Increase to 44x44 or use larger contentShape
   - **Priority**: 🔴 Critical

---

## ⚠️ HIGH PRIORITY Issues

### Color Contrast
**Impact**: High - Text hard to read

1. **File**: Views/Stones/StoneListView.swift:156
   - **Issue**: Light gray text on white background (insufficient contrast)
   - **Code**: `.foregroundColor(Color(white: 0.85))`
   - **Contrast Ratio**: ~2:1 (needs 4.5:1 for normal text)
   - **Fix**: Use `.secondary` or darker color: `Color(white: 0.6)`
   - **Priority**: 🟠 High

### Dynamic Type Not Supported
**Impact**: High - Breaks for users with large text

1. **File**: Views/Authentication/LoginView.swift:78
   - **Issue**: Fixed font size won't scale
   - **Code**: `.font(.system(size: 16))`
   - **Impact**: Text too small for users with vision impairments
   - **Fix**: Use `.font(.body)` or `.font(.custom("Font", size: 16, relativeTo: .body))`
   - **Priority**: 🟠 High

### Missing Accessibility Hints
**Impact**: Medium-High - Non-obvious functionality

1. **File**: Views/Map/MapView.swift:234
   - **Issue**: Button action not clear from label alone
   - **Code**: Button with label "Details" but unclear what happens
   - **Fix**: `.accessibilityHint("Opens detailed map view with stone locations")`
   - **Priority**: 🟠 High

---

## ℹ️ MEDIUM PRIORITY Issues

### Decorative Images Not Hidden
**Impact**: Medium - Clutters VoiceOver navigation

1. **File**: Views/Components/Background.swift:45
   - **Issue**: Decorative image announced by VoiceOver
   - **Code**: `Image("background-pattern")`
   - **Impact**: Users hear "Image" with no useful info
   - **Fix**: `.accessibilityHidden(true)`
   - **Priority**: 🟡 Medium

### Animations Without Reduce Motion
**Impact**: Medium - May cause motion sickness

1. **File**: Views/Stones/StoneDetailView.swift:189
   - **Issue**: Animation doesn't respect reduce motion setting
   - **Code**: `.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)`
   - **Fix**: Check `@Environment(\.accessibilityReduceMotion)` and disable if needed
   - **Priority**: 🟡 Medium

### Form Errors Not Announced
**Impact**: Medium - Validation failures silent to screen readers

1. **File**: Views/Authentication/RegisterView.swift:267
   - **Issue**: Error text shown visually but not announced
   - **Code**: `if !isValid { Text("Invalid username").foregroundColor(.red) }`
   - **Fix**: Add `.accessibilityValue("Invalid username")` to TextField or post notification
   - **Priority**: 🟡 Medium

---

## ✅ Accessibility Strengths

Great work in these areas:

- ✅ Most buttons use standard SwiftUI components (automatically accessible)
- ✅ Text uses system fonts in many places (Dynamic Type support)
- ✅ Navigation structure is clear and logical
- ✅ Forms use standard TextField components
- ✅ Good use of semantic colors (`.primary`, `.secondary`)

---

## 📊 Accessibility Metrics

### By Category
| Category | Issues | Critical | High | Medium |
|----------|--------|----------|------|--------|
| VoiceOver | 8 | 2 | 3 | 3 |
| Touch Targets | 3 | 1 | 2 | 0 |
| Color Contrast | 4 | 0 | 2 | 2 |
| Dynamic Type | 5 | 0 | 3 | 2 |
| Motion | 2 | 0 | 0 | 2 |
| Forms | 3 | 0 | 1 | 2 |

### By View
**Views Needing Most Attention**:
1. `AddStoneView.swift` - 6 issues
2. `StoneListView.swift` - 5 issues
3. `RegisterView.swift` - 4 issues
4. `MapView.swift` - 3 issues
5. `ProfileView.swift` - 3 issues

### Compliance Score
- **VoiceOver Support**: 70% (needs improvement)
- **Dynamic Type**: 65% (needs improvement)
- **Color Contrast**: 80% (good)
- **Touch Targets**: 85% (good)
- **Keyboard Navigation**: 75% (good)
- **Overall Score**: B- (73%)

**Target for Release**: A- (90%+)

---

## 🎯 Recommended Action Plan

### Week 1: Critical Fixes (Required for Release)
**Priority**: Make app usable with VoiceOver

1. **Add accessibility labels** to all icon buttons (8 locations)
   - Estimated time: 2 hours
   - Impact: VoiceOver users can navigate

2. **Fix touch target sizes** (3 locations)
   - Increase to 44x44 minimum
   - Estimated time: 1 hour
   - Impact: Easier tapping for all users

3. **Add accessibility alternatives** to custom gestures (2 locations)
   - Convert to buttons or add accessibilityActions
   - Estimated time: 1 hour
   - Impact: Critical features accessible

**Expected Score After Week 1**: 80% (B)

### Week 2: High Priority (Better Accessibility)
**Priority**: Support vision and motor impairments

1. **Fix color contrast issues** (2 high priority items)
   - Use darker grays, system colors
   - Estimated time: 1 hour
   - Impact: Readable for low vision users

2. **Add Dynamic Type support** to fixed fonts (3 locations)
   - Replace `.system(size:)` with text styles
   - Estimated time: 2 hours
   - Impact: Supports user font preferences

3. **Add accessibility hints** to non-obvious actions (3 locations)
   - Explain what buttons do
   - Estimated time: 1 hour
   - Impact: Better UX for all users

**Expected Score After Week 2**: 87% (B+)

### Week 3: Polish (Excellent Accessibility)
**Priority**: Best-in-class accessibility

1. **Hide decorative images** from VoiceOver (5 locations)
2. **Add reduce motion support** (2 locations)
3. **Improve form error announcements** (3 locations)
4. **Add semantic grouping** where appropriate (4 locations)

**Expected Score After Week 3**: 93% (A-)

---

## 🛠️ Quick Fixes (Copy-Paste Solutions)

### Icon Button Fix
```swift
// Before:
Button {
    addStone()
} label: {
    Image(systemName: "plus")
}

// After:
Button {
    addStone()
} label: {
    Image(systemName: "plus")
}
.accessibilityLabel("Add new stone")
```

### Touch Target Fix
```swift
// Before:
Button("X") { dismiss() }
    .frame(width: 24, height: 24)

// After:
Button("X") { dismiss() }
    .frame(width: 44, height: 44)  // Minimum size
```

### Dynamic Type Fix
```swift
// Before:
Text("Title")
    .font(.system(size: 20))

// After:
Text("Title")
    .font(.title3)  // Scales automatically
```

### Color Contrast Fix
```swift
// Before:
Text("Subtitle")
    .foregroundColor(.gray)

// After:
Text("Subtitle")
    .foregroundColor(.secondary)  // System color with proper contrast
```

### Decorative Image Fix
```swift
// Before:
Image("background-pattern")

// After:
Image("background-pattern")
    .accessibilityHidden(true)
```

### Reduce Motion Fix
```swift
// Before:
.animation(.spring(), value: isExpanded)

// After:
@Environment(\.accessibilityReduceMotion) var reduceMotion

.animation(reduceMotion ? nil : .spring(), value: isExpanded)
```

### Form Error Fix
```swift
// Before:
TextField("Email", text: $email)
if !isValidEmail {
    Text("Invalid email").foregroundColor(.red)
}

// After:
TextField("Email", text: $email)
    .accessibilityLabel("Email address")
    .accessibilityValue(isValidEmail ? "" : "Invalid email format")
if !isValidEmail {
    Text("Invalid email").foregroundColor(.red)
}
```

---

## 🧪 Testing Recommendations

### Manual Testing Checklist

**VoiceOver Testing** (Most Important):
1. Enable VoiceOver: Settings → Accessibility → VoiceOver
2. Navigate through each screen with VoiceOver
3. Verify all buttons announce their purpose
4. Check form field labels are descriptive
5. Ensure all interactive elements are reachable
6. Test core user flows (login, add stone, view list)

**Dynamic Type Testing**:
1. Settings → Display & Brightness → Text Size
2. Set to largest size
3. Verify all text is readable
4. Check layouts don't break
5. Ensure scroll works where needed

**Voice Control Testing**:
1. Settings → Accessibility → Voice Control
2. Try "Tap [button name]" commands
3. Verify all buttons are reachable by voice

**Reduce Motion Testing**:
1. Settings → Accessibility → Motion → Reduce Motion
2. Check animations are reduced/removed
3. Ensure essential info isn't lost

**High Contrast Testing**:
1. Settings → Accessibility → Display → Increase Contrast
2. Verify colors still work
3. Check contrast is even better

### Automated Testing

Add accessibility tests to your test suite:

```swift
func testButtonAccessibility() {
    let app = XCUIApplication()
    app.launch()

    let addButton = app.buttons["Add new stone"]
    XCTAssertTrue(addButton.exists)
    XCTAssertTrue(addButton.isHittable)
}

func testDynamicType() {
    // Test with different text sizes
    XCUIDevice.shared.dynamicTypeSize = .accessibility3
    // Verify layout doesn't break
}
```

### Third-Party Tools

Consider using:
- **Xcode Accessibility Inspector**: Built-in tool for checking issues
- **Accessibility Snapshot Testing**: Automated accessibility checks
- **Stark Plugin**: Color contrast checking

---

## 📚 Resources

- [Apple Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [iOS VoiceOver Guide](https://developer.apple.com/documentation/accessibility/voiceover)
- [SwiftUI Accessibility](https://developer.apple.com/documentation/swiftui/view-accessibility)

---

## 💡 Accessibility Best Practices for This App

### For Stone Listing Views
```swift
// Describe stone with full context
HStack {
    AsyncImage(url: stone.imageUrl)
        .accessibilityLabel("Photo of \(stone.name ?? "stone")")

    VStack {
        Text(stone.name ?? "Unnamed")
        Text("\(stone.weight ?? 0) lbs")
    }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(stone.name ?? "Stone"), \(stone.weight ?? 0) pounds, lifted to \(stone.liftingLevel.displayName)")
```

### For Map Views
```swift
// Make map annotations accessible
MapAnnotation(coordinate: stone.coordinate) {
    Image(systemName: "mappin")
}
.accessibilityLabel("Stone at \(stone.locationName ?? "unknown location")")
.accessibilityAddTraits(.isButton)
.accessibilityHint("Double tap to view stone details")
```

### For Camera/AR Features
```swift
// Provide alternative for visual-only features
if !UIAccessibility.isVoiceOverRunning {
    ARCameraView()
} else {
    // Alternative input for VoiceOver users
    ManualWeightEntryView()
}
```

---

**Remember**: Accessibility isn't optional—it's required by law in many countries and makes your app better for everyone. 20% of users benefit from accessibility features!
```

## Testing Your Fixes

After making changes:

1. **Turn on VoiceOver** and navigate the app
2. **Adjust text size** to largest and verify layouts
3. **Enable high contrast** and check colors
4. **Use Voice Control** to test tap targets
5. **Run Xcode Accessibility Inspector** on each view

Good accessibility is good UX for everyone! 🌟
