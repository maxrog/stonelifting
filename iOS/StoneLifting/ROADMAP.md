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
- [ ] Stone type selection (granite, limestone, etc.)
- [ ] Accuracy tracking (predicted vs actual)
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
- [ ] Badges (half/full sterker)
- [ ] User profiles
- [ ] Leaderboards

---

## Platform & Infrastructure

### Authentication & Backend
- [ ] Password Reset
- [ ] Apple/Google/Phone Sign In
- [ ] Database indexes
- [ ] Sentry error tracking
- [ ] Rate limiting
- [ ] Custom domain

### App Quality
- [ ] CI/CD pipeline
- [ ] Localization
- [ ] Theming support
- [ ] Accessibility
- [ ] Performance profiling
- [ ] Unit/UI tests

### Extensions
- [ ] Widgets
- [ ] Push notifications

---

## Device Support

**LiDAR Devices** (iPhone 12 Pro+, iPad Pro 2020+): Full features
**Non-LiDAR Devices**: Plane detection only, reduced accuracy
