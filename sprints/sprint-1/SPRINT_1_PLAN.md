# 🐝 BLEE — Sprint 1 Plan
### Core MVP: Auth · Onboarding · GPS Tracker · Run Receipt
**Weeks 9–12** · Based on [`BLEE_DEV_PLAN.md`](../../BLEE_DEV_PLAN.md) · [`MASTER_PLAN.md`](../MASTER_PLAN.md)

---

## 🎯 SPRINT GOAL

Deliver the **complete end-to-end solo runner loop**:

> Sign Up → Set Identity → Record Run (100% precision) → Post-Run RPE → Generate & Share Run Receipt

This sprint transforms the initialized Flutter scaffold into a fully functional, shippable product core that validates the fundamental value proposition: **Blee celebrates consistency and community over competitive PR pressure.**

---

## 🚦 HARD EXIT GATE — Sprint 1 Does NOT Close Until:

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| D7 Cohort Retention | **>= 45%** | PostHog cohort retention report on beta users |
| GPS Run Completion Rate | **>= 95%** | Crashlytics + run completion events / run start events |
| Run Receipt Share Rate | **>= 20%** | `receipt_shared` event / `run_completed` event in PostHog |
| Crashlytics Stability | **0 crashes / 48h** | Firebase Crashlytics real-time dashboard |

---

## 📦 PRE-CONDITIONS (Stage 0 Must Be Done)

- [ ] `flutter run` compiles cleanly on physical iOS + Android devices
- [ ] Firebase project `blee-prod` connected (`google-services.json` + `GoogleService-Info.plist`)
- [ ] Supabase `profiles` and `runs` tables deployed with RLS enforced
- [ ] Design system tokens live: `AppColors`, `AppSpacing`, `AppTypography`
- [ ] `go_router` scaffold with auth redirect guard in place

---

## 📅 WEEK-BY-WEEK BREAKDOWN

---

### Week 9 — Authentication & Profile Sync

**Theme:** Secure, frictionless account creation with automatic cloud profile hydration.

#### [SP1-01] Firebase Authentication Pipeline

**Files to create/modify:**
- `lib/features/auth/domain/auth_repository.dart` (abstract)
- `lib/features/auth/data/firebase_auth_repository.dart`
- `lib/features/auth/presentation/auth_notifier.dart` (Riverpod AsyncNotifier)
- `lib/features/auth/presentation/login_screen.dart`

**Tasks:**
- [ ] Implement Apple Sign-In (`sign_in_with_apple` package)
- [ ] Implement Google Sign-In (`google_sign_in` package)
- [ ] Implement Email/Password sign-in + registration
- [ ] Implement Phone OTP (Firebase Phone Auth)
- [ ] Implement `AuthNotifier` (Riverpod `AsyncNotifier<User?>`) that exposes `signInWithApple()`, `signInWithGoogle()`, `signInWithEmail()`, `signOut()`
- [ ] Wire `GoRouter` redirect guard: unauthenticated → `/login`; authenticated + no profile → `/onboarding`; authenticated + profile → `/home`

**Acceptance Criteria:**
- User can sign in, force-kill app, relaunch, and remain authenticated
- Auth state persists across cold starts via Firebase token refresh

---

#### [SP1-02] Supabase Profile Auto-Creation

**Files to create/modify:**
- `lib/features/auth/data/profile_repository.dart`
- `lib/features/auth/domain/profile_entity.dart` (freezed)

**Tasks:**
- [ ] On successful Firebase sign-in, check if `profiles` row exists for `auth.uid()`
- [ ] If missing, create default profile: `{ display_name: displayName, username: uid_first8, tier: 'pacer' }`
- [ ] Handle avatar upload to Supabase Storage with local compression (max 512x512px, JPEG 80%)
- [ ] Riverpod `profileProvider` that streams the current user's profile from Supabase

**Acceptance Criteria:**
- Profile created in Supabase < 2 seconds after first sign-in
- Avatar upload succeeds with compressed file < 100KB
- Profile hydrated from Supabase on cold restart without re-fetching from Firebase

---

### Week 10 — 7-Step Identity Onboarding Funnel

**Theme:** The psychological foundation. Each screen deepens identity commitment, not just data collection.

#### [SP1-03] Onboarding Flow UI

**Files to create:**
- `lib/features/onboarding/presentation/onboarding_screen.dart`
- `lib/features/onboarding/presentation/onboarding_notifier.dart`
- `lib/features/onboarding/domain/onboarding_state.dart` (freezed)
- Individual step widgets: `step_manifesto.dart`, `step_profile.dart`, `step_tier.dart`, `step_motivation.dart`, `step_rhythm.dart`, `step_permissions.dart`, `step_declaration.dart`

**The 7 Screens:**

| Step | Screen | Key UX Principle |
|------|--------|-----------------|
| 1 | **The Blee Manifesto** — "We don't run for numbers. We run for who we become." | Identity anchoring — Peak-End Rule: powerful opening |
| 2 | **First Name & Profile Photo** | Personalization + face-to-name trust |
| 3 | **Running Experience & Pace Tier** — Pacer (> 6:30), Strider (5:00–6:30), Elite (< 5:00) | Self-declaration, autonomy (SDT) |
| 4 | **Motivation Anchor** — Mental clarity · Health · Marathon prep · Community | SDT Relatedness + Competence |
| 5 | **Weekly Rhythm Commitment** — 2x / 3x / 4+x per week | Commitment & consistency hook |
| 6 | **Location & Notification Permission Primer** | Transparent "why" before OS dialog (improves grant rate) |
| 7 | **Identity Declaration Card** — "I am a Blee Runner" with haptic feedback | Peak-End Rule: memorable ending |

**Tasks:**
- [ ] Implement `PageView`-based multi-step flow with animated page transitions (200ms ease-out)
- [ ] Progress indicator bar (AppColors.primary accent on AppColors.surfaceBorder background)
- [ ] Screen 6: Show custom explanation screen *before* `Geolocator.requestPermission()` and `FirebaseMessaging.requestPermission()`
- [ ] Screen 7: Trigger `HapticFeedback.heavyImpact()` on identity card reveal
- [ ] Fire PostHog `onboarding_step_completed` event with `{ step: 1..7 }` on each screen completion
- [ ] Fire PostHog `onboarding_completed` on Screen 7 completion

**Acceptance Criteria:**
- >= 70% completion rate measured in beta (PostHog funnel)
- Screen 7 identity card render animates in < 300ms
- Back navigation works without data loss on all steps

---

### Week 11 — Real-Time In-Run GPS Tracking Screen

**Theme:** Zero-friction, glanceable, sweat-proof running HUD. Every millisecond of performance matters.

#### [SP1-04] Live Heads-Up Display (HUD)

**Files to create:**
- `lib/features/tracking/presentation/tracking_screen.dart`
- `lib/features/tracking/presentation/tracking_notifier.dart`
- `lib/features/tracking/domain/tracking_state.dart` (freezed)
- `lib/features/tracking/data/gps_repository.dart`
- `lib/features/tracking/data/local_run_db.dart` (SQLite)

**Tasks:**
- [ ] **HUD Typography (glanceable in direct sunlight):**
  - Elapsed time: 48pt, `AppTypography.displayLarge`, tabular figures
  - Distance (km): 42pt, `AppTypography.displayMedium`, tabular figures
  - Current pace (min/km): 36pt, `AppTypography.displaySmall`, tabular figures
- [ ] **Google Maps Live Polyline:**
  - Stream GPS points to `GoogleMap` via `Polyline` with `AppColors.primary` stroke
  - Custom user location marker (Blee bee icon, no default blue dot)
  - Camera follows user position with smooth animation (no jarring jumps)
- [ ] **Gesture Controls:**
  - Slide-to-pause: swipe up on pause button (prevents sweat mis-taps)
  - Hold-to-stop: 2-second press with circular countdown animation
  - Auto-pause: detect speed < 0.8 m/s for > 5 seconds, pause with toast notification
- [ ] **All 5 UI States on Tracking Screen:**
  1. **Ideal:** HUD running, map live, polyline growing
  2. **Loading/Acquiring:** "Acquiring GPS signal..." skeleton with pulsing accuracy ring
  3. **Error:** "Location permission denied" with Settings deep-link CTA
  4. **Warning:** "Weak satellite signal (accuracy: Xm)" amber banner — non-blocking
  5. **Recovery:** "Reconnected. Run resumed from saved state." after background kill recovery
- [ ] **SQLite Breadcrumb Storage:** Write each validated GPS point (accuracy <= 30m, speed <= 45 km/h) to `raw_breadcrumbs` table via `local_run_db.dart`
- [ ] **Background Foreground Service** (Android): Ongoing notification showing elapsed time + distance
- [ ] **iOS Background Modes**: `location` mode, `allowsBackgroundLocationUpdates = true`, `pausesLocationUpdatesAutomatically = false`

**Performance Rules:**
- Zero object allocations inside `LocationSettings` stream callback
- `RepaintBoundary` wrapping the HUD numbers widget and the map widget separately
- Map polyline updates debounced — batch updates every 2 seconds, not on every GPS point

**Acceptance Criteria:**
- Zero dropped frames during map panning (Flutter DevTools: 0 jank frames)
- HUD numbers legible in direct sunlight (tested physically)
- Location updates continue with screen locked for 60 consecutive minutes on both iOS + Android

---

### Week 12 — Post-Run Experience & Run Receipt Generator

**Theme:** The most important screen in the app. The Peak-End Rule demands perfection here. This IS the ending.

#### [SP1-05] Post-Run RPE Rating & Flow

**Files to create:**
- `lib/features/tracking/presentation/post_run_screen.dart`
- `lib/features/tracking/domain/run_summary_entity.dart` (freezed)

**Tasks:**
- [ ] **RPE Slider (Borg Scale 1–10):**
  - Tactile custom slider with haptic feedback at each integer step
  - Micro-copy labels at key points: "1 = Easy Recovery Walk" · "5 = Moderate Tempo" · "10 = Maximum All-Out Sprint"
  - Color gradient: AppColors.success (1) → AppColors.warning (5) → AppColors.danger (10)
- [ ] **Peak Kilometer Detection:**
  - Calculate fastest 1km segment from breadcrumb array
  - Display as "Peak KM: X.X km — X:XX min/km" with a trophy icon
- [ ] **Run Summary Stats:**
  - Total Distance (km) · Total Duration (HH:MM:SS) · Avg Pace (min/km) · Calories (est.) · RPE Badge

**Acceptance Criteria:**
- RPE value saved to Supabase `runs.rpe` on submission
- Peak KM calculated in `compute()` isolate (not main thread)
- Post-run screen reachable within 1 tap of "Stop Run"

---

#### [SP1-06] The Run Receipt Card Engine

**Files to create:**
- `lib/features/run_receipt/presentation/run_receipt_widget.dart`
- `lib/features/run_receipt/presentation/run_receipt_notifier.dart`
- `lib/features/run_receipt/domain/receipt_generator_service.dart`
- `lib/features/run_receipt/data/cloudflare_r2_repository.dart`

**The Run Receipt Layout (pixel-perfect):**

```
┌─────────────────────────────────┐
│  🐝  BLEE           BGC, Manila │  ← Header: Logo + City Badge
│  SAT, OCT 2 · 06:14 AM · ☀️    │  ← Date, Time, Weather
├─────────────────────────────────┤
│                                 │
│     [Route Mini-Map Silhouette] │  ← CustomPainter polyline render
│         (vector, no raster)     │
│                                 │
├─────────────────────────────────┤
│  DISTANCE      DURATION         │
│  10.2 km       58:32            │
│                                 │
│  AVG PACE      PEAK KM          │
│  5:44 /km      4:58 /km @ km 7  │
│                                 │
│  RPE EFFORT                     │
│  ████████░░  8 / 10             │
├─────────────────────────────────┤
│  Identity > Telemetry · blee.app│  ← Footer tagline
│  [■■■■ BARCODE ■■■■]           │  ← Unique receipt barcode graphic
└─────────────────────────────────┘
```

**Tasks:**
- [ ] Build `RunReceiptWidget` wrapped in `RepaintBoundary(key: _receiptKey)`
- [ ] Route silhouette rendered via `CustomPainter` — normalize coordinates to fit widget bounds, draw via `canvas.drawPath()`; executed in `compute()` isolate for coordinate transformation
- [ ] Receipt export: `RenderRepaintBoundary.toImage(pixelRatio: 3.0)` → PNG bytes (target: 1080x1920 Instagram Story ratio)
- [ ] Export performance: total < 400ms (measure with `Stopwatch`)
- [ ] Native share sheet via `share_plus`: pre-target Instagram Stories, WhatsApp, Camera Roll
- [ ] Async Cloudflare R2 upload (non-blocking): `PUT blee-run-receipts/{userId}/{runId}.png` with public CDN URL returned, saved to `runs.run_receipt_url`
- [ ] **Receipt Reveal Animation:** Scale from 0.8 → 1.0 with fade in, 280ms ease-out curve. This is the most important animation in the app — invest here.
- [ ] Fire PostHog `receipt_generated` and `receipt_shared` events

**Acceptance Criteria:**
- Export completes < 400ms on mid-tier Android (Pixel 6a)
- Output PNG is exactly 1080x1920 at 3x pixel ratio
- Upload to R2 does NOT block the share sheet — fires asynchronously
- Receipt share rate achieves >= 20% (tracked via PostHog)

---

## 🔗 FEATURE DEPENDENCY MAP

```
Week 9: Auth + Profile Sync
         ↓
Week 10: Onboarding (requires auth + profile)
         ↓
Week 11: GPS Tracker (requires auth; writes SQLite + Supabase)
         ↓
Week 12: Post-Run + Run Receipt (requires completed run data from Week 11)
```

---

## 🧪 TESTING STRATEGY

### Unit Tests (Domain Layer)
- [x] `AuthRepository` sign-in/sign-out state transitions
- [x] `GpsFilter` — accuracy filter, speed sanity, Haversine accumulation
- [x] `RunSummaryEntity` — peak km calculation from breadcrumb list
- [x] `ReceiptGeneratorService` — coordinate normalization for CustomPainter

### Widget Tests (Presentation Layer)
- [x] `LoginScreen` — renders all sign-in options; buttons disabled during loading state
- [x] `OnboardingScreen` — page navigation, back navigation, step event firing
- [x] `TrackingScreen` — all 5 UI states render correctly
- [x] `RunReceiptWidget` — renders with mock run data; share button triggers share intent

### Integration / Field Tests
- [ ] Cold start → sign in → complete onboarding < 3 minutes
- [ ] 5km run with screen locked on physical device (iOS + Android)
- [ ] Background kill + restore: run state recovered from SQLite
- [ ] Offline run completion → reconnect → Supabase sync (zero data loss)

---

## 📊 ANALYTICS EVENTS (PostHog)

| Event | Properties | Trigger |
|-------|-----------|---------|
| `onboarding_step_completed` | `{ step: 1..7 }` | Each onboarding screen completion |
| `onboarding_completed` | `{ tier, motivation, rhythm }` | Step 7 identity card confirmation |
| `run_started` | `{ user_id, timestamp }` | Tap "Start Run" |
| `run_paused` | `{ elapsed_seconds, distance_km }` | Slide-to-pause gesture |
| `run_completed` | `{ distance_km, duration_seconds, rpe, peak_km_pace }` | Hold-to-stop confirmed |
| `receipt_generated` | `{ run_id, distance_km }` | Receipt render completes |
| `receipt_shared` | `{ run_id, share_target }` | Share sheet item selected |

---

## 🚨 RISKS & MITIGATIONS

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| iOS background GPS killed by system | High | Critical | `pausesLocationUpdatesAutomatically = false` + foreground service simulation via significant location change API as fallback |
| Samsung / Xiaomi OEM battery killers | High | Critical | `BatteryOptimizationHelper.dart` — detect OEM, show interactive guide to disable optimization for Blee |
| Cloudflare R2 upload latency blocking UX | Medium | High | Upload is fully async; share sheet triggered immediately without waiting for R2 response |
| `RepaintBoundary.toImage()` OOM on low-RAM devices | Low | High | Cap `pixelRatio` at 2.5x on devices with < 3GB RAM detected via `deviceInfo_plus` |
| PostHog events lost offline | Low | Medium | PostHog SDK queues events locally and flushes on next connection |

---

## 📁 NEW FILES CHECKLIST — Sprint 1

```
lib/
├── core/
│   ├── router/
│   │   └── app_router.dart                          [x] Created
│   └── utils/
│       ├── result.dart                              [x] Created
│       └── geo_math.dart                           [x] Created
└── features/
    ├── auth/
    │   ├── domain/
    │   │   ├── auth_repository.dart                 [x] Created
    │   │   └── profile_entity.dart                  [x] Created
    │   ├── data/
    │   │   ├── firebase_auth_repository.dart        [x] Created
    │   │   └── profile_repository.dart              [x] Created
    │   └── presentation/
    │       ├── auth_notifier.dart                   [x] Created
    │       └── login_screen.dart                    [x] Updated
    ├── onboarding/
    │   ├── domain/
    │   │   └── onboarding_state.dart                [x] Created
    │   └── presentation/
    │       ├── onboarding_screen.dart               [x] Created
    │       ├── onboarding_notifier.dart             [x] Created
    │       └── steps/
    │           ├── step_manifesto.dart              [x] Created
    │           ├── step_profile.dart                [x] Created
    │           ├── step_tier.dart                   [x] Created
    │           ├── step_motivation.dart             [x] Created
    │           ├── step_rhythm.dart                 [x] Created
    │           ├── step_permissions.dart            [x] Created
    │           └── step_declaration.dart            [x] Created
    ├── tracking/
    │   ├── domain/
    │   │   ├── tracking_state.dart                  [x] Created
    │   │   └── run_summary_entity.dart              [x] Created
    │   ├── data/
    │   │   ├── gps_repository.dart                  [x] Created
    │   │   ├── gps_filter.dart                      [x] Created
    │   │   └── local_run_db.dart                    [x] Created (sqflite)
    │   └── presentation/
    │       ├── tracking_notifier.dart               [x] Created
    │       ├── tracking_screen.dart                 [x] Created
    │       └── post_run_screen.dart                 [x] Created
    └── run_receipt/
        ├── domain/
        │   └── receipt_generator_service.dart       [x] Created
        ├── data/
        │   └── cloudflare_r2_repository.dart        [x] Created
        └── presentation/
            ├── run_receipt_widget.dart              [x] Created
            └── run_receipt_notifier.dart            [x] Created
```

---

## ✅ SPRINT 1 DEFINITION OF DONE

Sprint 1 is complete when **all** of the following are true:

- [ ] All 4 hard exit gate metrics achieved (D7 >= 45%, GPS >= 95%, Share >= 20%, 0 crashes / 48h)
- [ ] `flutter analyze` passes with **0 errors, 0 warnings**
- [ ] All 7 Engineering DoD rules satisfied for every new file
- [ ] All 5 UI states implemented on: Login Screen, Onboarding Screen, Tracking Screen, Post-Run Screen, Run Receipt Screen
- [ ] GPS tracking verified on physical iOS + Android devices (background, 60 minutes)
- [ ] Run Receipt exports < 400ms and shares successfully via iOS + Android share sheets
- [ ] PostHog events flowing for all 7 defined analytics events
- [ ] Supabase `runs` table receiving synced runs from completed GPS sessions
- [ ] Zero empty `catch` blocks — all errors route to Crashlytics

---

*Sprint 1 Plan — Blee v4 · Weeks 9–12 · Last updated: 2026-10-02*
