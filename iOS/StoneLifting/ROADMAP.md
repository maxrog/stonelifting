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
- [ ] Nearby stones discovery
  - Fetch stones within visible map region
  - "Nearby" filter on map (separate from user/public stones)
  - Cache discovered areas for offline camping trips
  - Auto-refresh when panning map to new areas

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
- [ ] Phone Number Sign In (low priority - OAuth already includes phone verification)

### Security & Anti-Spam (PRE-LAUNCH CRITICAL)
- [ ] Fix report system - Unique reporter tracking (CRITICAL BUG - 3-4 hours)
- [ ] Rate limiting - Stone creation (10/day new users, 50/day established - 2 hours)
- [ ] Rate limiting - API endpoints (prevent abuse/scrapers - 3-4 hours)
- [ ] Rate limiting - OAuth endpoints (prevent token injection - 1 hour)
- [ ] New account restrictions (<7 days = reduced limits - 1-2 hours)
- [ ] Duplicate stone detection (same image/location - Phase 2)
- [ ] Location validation (GPS spoofing detection - Phase 2)
- [ ] Admin moderation dashboard (Phase 3)

**Total Pre-Launch: ~9-11 hours** | See `/SECURITY_ANTI_SPAM.md` for implementation guide

### Infrastructure
- [ ] Associated Domains (password autofill, universal links, handoff - requires web interface first)
- [ ] Database indexes
- [ ] Sentry error tracking
- [ ] Rate limiting
- [ ] Custom domain
- [ ] Switch DATABASE_PUBLIC_URL to RAILWAY_PRIVATE_DOMAIN to avoid egress fees (Currently using DATABASE_PUBLIC_URL -> RAILWAY_TCP_PROXY_DOMAIN)
- [ ] Upgrade OpenAI Moderation to paid tier for production (~$0.01/1000 stones, removes rate limits, currently using free tier with retry logic)

### App Quality
- [ ] CI/CD pipeline
- [ ] Localization
- [ ] Theming support
- [ ] Settings (lb vs kg etc)
- [ ] Accessibility
- [ ] Performance profiling
- [ ] Unit/UI tests

### Performance & Caching
- [ ] Stale-While-Revalidate pattern
  - Load SwiftData cache FIRST on app launch (instant UI)
  - Fetch fresh data in background and update silently
  - Increase background refresh throttle to 15-30 min (stones rarely change)
  - Consider HTTP cache headers (ETag/Cache-Control) for bandwidth savings
  - Current: Show spinner → fetch → cache → show data
  - Goal: Show cache → silent refresh → update if changed

- [ ] CDN Integration
  - **Goal**: Reduce API latency by serving backend from edge locations closer to users
  - **Options**:
    - Cloudflare CDN: Put Vapor backend behind Cloudflare (~$20/month, automatic global edge caching, DDoS protection)
    - AWS CloudFront: Native integration with Railway (multiple edge locations, more control over caching, pay per use)
    - Fastly: Real-time caching and purging, excellent for dynamic content (higher cost but better performance)
  - **Benefits**:
    - API calls: 200-300ms → 20-50ms (10x faster)
    - Image loading: Faster with CDN caching
    - Better user experience worldwide
    - Reduced backend load
  - **Implementation**:
    1. Set up CDN provider
    2. Configure edge caching rules (cache GET, bypass POST/PUT/DELETE)
    3. Update DNS/Railway config
    4. Test from multiple regions
    5. Monitor performance improvement
  - **Priority**: Medium (after core features stable)
  - **Estimated effort**: 4-8 hours
  - **Cost**: $20-50/month depending on usage

### UI/UX Design
- [ ] Rework add stone form (currently feels cluttered)
- [ ] Update app icon: SF Symbol circle.dotted.and.circle (rotated, wiggle animation) - icons 8
- [ ] Make UI less AI-ish (reduce generic AI patterns)
- [ ] Consider sparkle effect for weight estimation feature

### Code Quality & Technical Debt
- []

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

### Marketing & Web Presence
- [ ] Landing Website
  - Responsive design showcasing app features
  - Smart platform detection (iOS/Android/Desktop)
  - Direct App Store links for mobile users
  - Email signup for Android waitlist / updates
  - Screenshots and demo videos
  - SEO optimization for discoverability
  - Universal links integration (deeplink to app if installed)
  - Prerequisites: Custom domain, Associated Domains configured
  - Enables: Password autofill, universal links, handoff features

---

## Device Support

**LiDAR Devices** (iPhone 12 Pro+, iPad Pro 2020+): Full features
**Non-LiDAR Devices**: Plane detection only, reduced accuracy
