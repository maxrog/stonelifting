# App Store Changelog Generator

Generate user-facing App Store release notes from git commits since the last release.

## Instructions

### 1. Find Release Range

Determine commits to include:

```bash
# Get last release tag
git describe --tags --abbrev=0

# If no tags exist, use initial commit
git log --reverse --pretty=format:"%H" | head -n 1

# Get all commits since last release
git log <last-tag>..HEAD --pretty=format:"%h - %s (%an, %ar)" --no-merges
```

### 2. Analyze & Categorize Commits

Group commits by theme:

**Categories:**
- ✨ **New Features** - New functionality users can see/use
- 🐛 **Bug Fixes** - Fixed issues that were broken
- ⚡ **Performance** - Speed improvements, optimizations
- 🎨 **UI/UX** - Visual changes, improved user experience
- 🔒 **Security** - Security enhancements, privacy improvements
- 📱 **Compatibility** - iOS version support, device support

**Translation Guidelines:**
```
Git commit → User-facing description

"feat: add AR stone measurement" → "Smart stone weight estimation using your camera"
"fix: location timeout in getCurrentLocation" → "Improved location accuracy when adding stones"
"refactor: parallel network requests" → "Faster loading of stone lists"
"perf: move base64 encoding off main thread" → "Smoother image uploads"
```

### 3. Write User-Friendly Copy

**Rules:**
- Use active voice: "Added" not "We added"
- Focus on benefits, not implementation
- Be specific: "2x faster loading" not "improved performance"
- Keep technical jargon out
- Start each item with a verb
- Avoid: "fixed bug", "refactored code", "updated dependencies"

**Good Examples:**
```
✅ "See multiple nearby stones grouped on the map"
✅ "Upload photos without any lag or stutter"
✅ "Find your heavy lifts (220+ lbs) with one tap"
✅ "Your location data now updates more accurately"

❌ "Added cluster view to MapView component"
❌ "Refactored image upload service"
❌ "Fixed issue #123"
❌ "Updated async/await patterns"
```

### 4. Format for App Store

**App Store Constraints:**
- Maximum 4000 characters
- No markdown (plain text only)
- Keep it scannable
- Lead with most exciting features
- Group similar items

**Template:**

```
What's New in Version X.X:

[Opening line - most exciting feature]

NEW FEATURES
• [Feature 1]
• [Feature 2]
• [Feature 3]

IMPROVEMENTS
• [Improvement 1]
• [Improvement 2]

BUG FIXES
• [Fix 1]
• [Fix 2]

[Optional closing line thanking users or teasing next release]
```

### 5. TestFlight vs App Store Notes

**TestFlight (more detailed):**
```
Beta Build 1.2 (42)

New in this build:
- AR measurement feature (test in good lighting)
- Map clustering (zoom out to see clusters)
- Parallel API requests (should feel faster)

Known issues:
- AR requires iPhone 12+ with LiDAR
- Clustering algorithm being tuned

Testing focus:
1. Try AR measurement on 5 different stones
2. Check map performance with 50+ stones
3. Test image upload on slow connection
```

**App Store (user-focused):**
```
What's New in Version 1.2:

Measure stone weight using your camera! Just point your iPhone at a stone and get an instant weight estimate using advanced AR technology.

NEW
• Smart weight estimation with AR
• See groups of nearby stones on the map
• Filter your collection by weight

IMPROVEMENTS
• 2x faster stone list loading
• Smoother photo uploads
• Better location accuracy

Thanks for using StoneLifting! Keep those stones moving 💪
```

## Output Format

```markdown
# 📱 App Store Release Notes

## Version X.X - [Release Date]

### 🎯 Headline Feature
[One sentence describing the most exciting new feature]

---

## TestFlight Notes (Beta Build XX)

**What's New:**
• [Feature 1 with technical context]
• [Feature 2 with implementation notes]
• [Performance improvement with metrics]

**Known Issues:**
• [Issue 1 - workaround if available]
• [Issue 2 - expected fix timeline]

**Testing Focus:**
1. [Specific test scenario 1]
2. [Specific test scenario 2]
3. [Specific test scenario 3]

**Performance Metrics:**
- Image upload: [before] → [after]
- List loading: [before] → [after]
- Memory usage: [before] → [after]

---

## App Store Release Notes (User-Facing)

```
What's New in Version X.X:

[Exciting opening line about headline feature]

NEW FEATURES
• [User benefit 1]
• [User benefit 2]
• [User benefit 3]

IMPROVEMENTS
• [Speed/UX improvement 1]
• [Speed/UX improvement 2]

BUG FIXES
• [Fixed issue in plain language]
• [Fixed issue in plain language]

[Optional: Thank you message or next feature tease]
```

**Character count**: XXX / 4000

---

## 📊 Commit Analysis

**Total commits since last release**: XX
**Breakdown**:
- Features: X commits
- Bug fixes: X commits
- Performance: X commits
- Refactoring: X commits (not in release notes)
- Dependencies: X commits (not in release notes)

**Notable commits**:
1. [commit hash] - [description] → [user-facing translation]
2. [commit hash] - [description] → [user-facing translation]

---

## ✅ Pre-Release Checklist

Before submitting to App Store:
- [ ] Version number incremented in Xcode
- [ ] Build number incremented
- [ ] All tests passing
- [ ] No critical TODOs in code
- [ ] Release notes reviewed for typos
- [ ] Screenshots updated if UI changed
- [ ] Privacy policy updated if needed
- [ ] Tested on multiple device sizes
- [ ] Tested on oldest supported iOS version

```

## Tips for Great Release Notes

### Do:
- Start with the most exciting feature
- Use bullet points for scannability
- Quantify improvements (2x faster, 50% smaller)
- Thank your users occasionally
- Show personality (but keep it professional)
- Preview next version if appropriate

### Don't:
- List internal refactorings
- Use developer jargon
- Write a novel (keep it under 500 words)
- Say "bug fixes and improvements" without specifics
- Mention removed features prominently
- Include commit hashes or issue numbers

### Examples from Great Apps

**Notion:**
```
What's New:

Create Notion AI-powered automations! Set up custom workflows that
trigger automatically based on database changes.

Also in this release:
• Faster page loading
• Improved offline support
• Better image compression

We're always improving Notion. Have feedback? Tap Settings > Help & Feedback
```

**Things:**
```
Things 3.19

• New Quick Entry on Mac - Add to-dos from anywhere with ⌘⌥Space
• Calendar improvements - See more events in your Today list
• Enhanced Share Extension - Faster capture from other apps

Plus lots of refinements and fixes.
```

## Special Considerations for StoneLifting

### Highlight Unique Features:
- AR/LiDAR technology (if applicable)
- Location-based features (privacy-conscious language)
- Photo uploads (compression improvements)
- Community features (public stones)

### Address Privacy:
If location or photo features added:
```
Your privacy matters: Location data is only used to tag stones you add,
and you control whether stones are public or private.
```

### Performance Claims:
Only include if you have metrics:
```
✅ "2x faster loading" (measured: 1000ms → 500ms)
✅ "Smoother uploads" (based on: moved encoding off main thread)
❌ "Way faster" (too vague)
❌ "Blazingly fast" (marketing fluff)
```

## Changelog vs Release Notes

**Keep Both:**

**CHANGELOG.md** (Developer-focused):
```markdown
## [1.2.0] - 2026-01-15

### Added
- AR-based stone weight estimation with LiDAR support
- Map clustering for nearby stones (StoneClusteringSystem)
- Parallel network requests in StoneListViewModel

### Fixed
- Base64 encoding blocking main thread in ImageUploadService
- Location timeout not being respected in LocationService

### Performance
- Image upload responsiveness improved by 20%
- Stone list refresh 2x faster with parallel fetching
```

**App Store Notes** (User-focused):
```
What's New in Version 1.2:

Point your camera at a stone and get an instant weight estimate!

NEW
• Smart weight estimation using AR
• See groups of nearby stones on the map

IMPROVEMENTS
• 2x faster loading
• Smoother photo uploads
```

---

**Remember**: Users care about what the app can DO, not how it does it. Focus on benefits and experiences, not implementation details.
