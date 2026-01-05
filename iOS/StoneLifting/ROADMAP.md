# StoneLifting App Roadmap

## Core Features

### Stone Management
- [ ] Multi-angle photos
- [ ] Multiple ticks of same stone"
- [ ] Location history/map
- [ ] Search and filtering
- [ ] Data export (CSV/JSON)
- [ ] Statistics dashboard
- [ ] Log completions of other users' stones

### Weight Estimation Improvements
- [ ] Stone type AI detection (use branded colors)
- [ ] Confidence intervals
- [ ] Reference object calibration

### Camera Tech 
### Phase 1: Mesh Visualization
- Visualize LiDAR mesh overlay
- Tap/circle region to select stone
- Auto-calculate bounding box volume
- Reduce from 6 taps to 1 tap

### Phase 2: Mesh Segmentation
- One-tap object detection
- Auto-separate stone from background
- Calculate actual mesh volume
- Handle irregular shapes

### Phase 3: Direct Depth Access
- Access raw depth buffer
- Faster measurements
- Work without plane detection

### Phase 4: 3D Object Scanning (Future)
- Walk around stone to scan all angles
- Build complete 3D model
- Export capability

### Phase 5: ML Auto-Detection (Future)
- Point → instant weight
- No user interaction needed
- CoreML-powered segmentation

---

### Social & Gamification
- [ ] User profiles
- [ ] Leaderboards

---

## Platform & Infrastructure

### Authentication & Backend
- [ ] Password Reset
- [ ] Apple/Google/Phone Sign In
- [ ] Fix Associated Domains for AutoFill Passwords (bundleID: com.marfodub.StoneLifting)
- [ ] Database indexes
- [ ] Sentry error tracking
- [ ] Rate limiting
- [ ] Custom domain
- [ ] Switch DATABASE_PUBLIC_URL to RAILWAY_PRIVATE_DOMAIN to avoid egress fees (Currently using DATABASE_PUBLIC_URL -> RAILWAY_TCP_PROXY_DOMAIN)

### App Quality
- [ ] CI/CD pipeline
- [ ] Localization
- [ ] Theming support
- [ ] Settings (lb vs kg etc)
- [ ] Accessibility
- [ ] Performance profiling
- [ ] Unit/UI tests

### UI/UX Design
- [ ] Rework add stone form (currently feels cluttered)
- [ ] Update app icon: SF Symbol circle.dotted.and.circle (rotated, wiggle animation) - icons 8
- [ ] Make UI less AI-ish (reduce generic AI patterns)
- [ ] Consider sparkle effect for weight estimation feature

### Code Quality & Technical Debt
- [ ] Address DRY violations (StoneListView:242, StoneDetailView:407, StoneDetailsFormView:19)
- [ ] Finalize image compression settings for production (ImageUploadService:100,120,124)
- [ ] Implement offline stone saving (AddStoneView)
- [ ] Improve form validation UX feedback (AddStoneView:12 - clarify required fields)
- [ ] Add user avatar placeholder (StoneDetailView:362)
- [ ] Refactor loading view (RootView:64 - use splash screen / extract views)

### Development Automation Tools


**Planned**

- [ ] GitHub Actions + Claude API Integration
  - Automated code review on every PR (using `/review-staged` logic)
  - Security scanning on PR creation and scheduled runs
  - Performance regression detection on commits
  - Accessibility compliance checks in CI
  - Auto-generate test suggestions for new code
  - Post results as PR comments with actionable feedback
  - Fail builds on critical security/accessibility issues

- [ ] ML Training Assistant - Help train and improve stone weight estimation model
  - Generate training data from labeled photos
  - Validate model accuracy and identify edge cases
  - Optimize model parameters for deployment
  - Export CoreML models for iOS

- [ ] `/pr-gen` - PR Description Generator
  - Analyze branch changes and generate comprehensive PR descriptions
  - Auto-detect breaking changes and migrations needed
  - Format according to team conventions

- [ ] `/optimize-images` - Image Optimization Agent
  - Scan for large/unoptimized images in the project
  - Compress and resize images automatically
  - Generate @2x/@3x variants
  - Report space savings

- [ ] `/review-deps` - Dependency Update Reviewer
  - Check for outdated Swift packages and pods
  - Analyze changelogs for breaking changes
  - Suggest safe update paths
  - Flag security vulnerabilities

### Extensions
- [ ] Widgets
- [ ] Push notifications

---

## Device Support

**LiDAR Devices** (iPhone 12 Pro+, iPad Pro 2020+): Full features
**Non-LiDAR Devices**: Plane detection only, reduced accuracy
