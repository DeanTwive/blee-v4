# 🐝 BLEE — Master Plan Overview
### *The Running Community That Moves You* · v4.0 Reference

> **Source of Truth:** [`BLEE_MASTER_PLAN.md`](../BLEE_MASTER_PLAN.md) · [`BLEE_DEV_PLAN.md`](../BLEE_DEV_PLAN.md)  
> **Philosophy:** Evidence-Gated Development. GPS Reliability First. Community Second. Monetization Third.  
> Never advance to the next sprint until the current gate passes.

---

## 🧭 PRODUCT NORTH STAR

**North Star Metric:** Weekly Active Runners (WAR) — logged 1+ run AND had 1+ social interaction within 7 days.

**The Three Gaps Blee Closes:**

| Gap | Root Cause | How Blee Closes It |
|-----|-----------|-------------------|
| Identity Gap | 80% quit because they never felt they belonged | Effort-first culture, non-hierarchical tiers |
| Community Gap | Strava is competitive, not welcoming | Local groups, group runs, buddy matching |
| Knowledge Gap | Injury from over-training, jargon barriers | RPE plans, Run Science Hub, cadence coaching |

**Counter-Positioning:**

| Competitor | Weakness | Blee Wedge |
|-----------|---------|-----------|
| Strava | Pace-bragging culture intimidates 80% | "Where effort matters more than speed" |
| Nike Run Club | Zero real community utility | "Your data. Your tribe. Your plan." |
| Garmin | Cold clinical UX, zero social | "Run science with a human heartbeat" |

---

## 🗺️ FULL SPRINT ROADMAP & HARD EXIT GATES

| Phase | Timeline | Primary Objective | Hard Exit Gate |
|---|---|---|---|
| **Stage 0: Foundation** | Weeks 1–2 | Cloud infra, SQL schema, Flutter init, design system | `flutter run` compiles on iOS + Android; Supabase schema + RLS live |
| **Validate: Zero Code** | Weeks 1–4 (Parallel) | Club outreach, runner interviews, waitlist | All 4 community validation gates documented |
| **GPS POC** | Weeks 5–8 | Background GPS engine, SQLite pipeline, PostGIS sync | >= 99% point retention, < 6% battery/hr, 100% sync idempotency |
| **Sprint 1: Core MVP** | Weeks 9–12 | Auth, 7-Step Onboarding, GPS Tracker, Run Receipt | D7 retention >= 45%; GPS success >= 95%; Receipt share >= 20% |
| **Sprint 2: Community** | Weeks 13–16 | Groups, RSVP, Live Beacon, Feed, Moderation | Zero P0/P1 bugs; Beacon validated by 20 emergency contacts |
| **Sprint 3: Hardening** | Weeks 17–20 | A11y WCAG AA, 60fps profiling, Store submissions | 0 crashes / 72h; App Store + Play Store approved |
| **Launch: BGC 6AM** | Month 5 | Hyper-local BGC Saturday community run launch | D30 retention >= 25%; WAR/MAU >= 40%; 500+ active BGC runners |
| **Monetize** | Month 8+ | Blee Pro (RevenueCat) + Blee Pack (B2B Stripe) | Monthly paid churn < 6%; CAC payback < 3 months; 5+ paid clubs |

---

## 🏛️ TECHNICAL STACK

| Layer | Technology |
|-------|-----------|
| **Mobile** | Flutter 3.x (Dart 3) |
| **Auth** | Firebase Authentication (Apple, Google, Email, Phone OTP) |
| **Analytics / Crash** | Firebase Analytics · Firebase Crashlytics · PostHog |
| **Push** | Firebase Cloud Messaging (FCM) |
| **Database (Remote)** | Supabase PostgreSQL + PostGIS (`ap-southeast-1`) |
| **Database (Local)** | SQLite via `sqflite` |
| **Maps** | Google Maps SDK for iOS + Android |
| **State Management** | `flutter_riverpod` v2.5+ with `riverpod_generator` |
| **Routing** | `go_router` with auth redirect guards |
| **Models** | `freezed` + `json_serializable` (immutable) |
| **Media Storage** | Cloudflare R2 (`blee-run-receipts`) |
| **Subscriptions** | RevenueCat (`purchases_flutter`) |
| **B2B Payments** | Stripe Web Checkout (Cloudflare Workers / Supabase Edge Functions) |

---

## 🏗️ CLEAN ARCHITECTURE — FEATURE-DRIVEN STRUCTURE

```
lib/
├── app.dart                          # MaterialApp.router, AppTheme, Global Providers
├── main.dart                         # Entry point, Firebase.initializeApp, Supabase.initialize
├── core/
│   ├── constants/                    # app_colors.dart, app_spacing.dart, app_typography.dart
│   ├── network/                      # connectivity_service.dart, error_interceptor.dart
│   ├── router/                       # app_router.dart (GoRouter with redirect guards)
│   ├── theme/                        # app_theme.dart (Dark elevated slates)
│   └── utils/                        # geo_math.dart, polyline_filter.dart, result.dart
└── features/
    ├── auth/                         # [data, domain, presentation]
    ├── onboarding/                   # [data, domain, presentation]
    ├── tracking/                     # [data, domain, presentation]
    ├── run_receipt/                  # [data, domain, presentation]
    ├── groups/                       # [data, domain, presentation]
    ├── safety/                       # [data, domain, presentation]
    ├── feed/                         # [data, domain, presentation]
    └── profile/                      # [data, domain, presentation]
```

**Layer Contract (Non-negotiable):**
- **Presentation** — renders state, dispatches user intents only. Zero direct DB/HTTP calls.
- **Domain (Notifiers/UseCases)** — business logic, validation, state orchestration. Framework-agnostic.
- **Data (Repositories)** — maps external DTOs <-> domain entities. Abstracts Supabase, SQLite, Firebase.

---

## 🎨 DESIGN SYSTEM TOKENS

### Color Palette
| Token | Hex | Usage |
|-------|-----|-------|
| `surface` | `#121417` | Base background |
| `surfaceElevated` | `#1E2228` | Cards, sheets |
| `surfaceBorder` | `#2A303C` | Dividers, borders |
| `primary` | `#E5F925` | CTA, brand accent (Electric Cyber Lime) |
| `onPrimary` | `#000000` | Text on primary |
| `electricCobalt` | `#2B66FF` | Secondary actions |
| `safetyOrange` | `#FF5500` | Live Beacon, urgent |
| `success` | `#00E676` | Confirmation, sync done |
| `danger` | `#FF3B30` | Error, destructive |
| `warning` | `#FFCC00` | Caution states |

### Spacing Scale (8pt / 4pt Grid)
`4px · 8px · 12px · 16px · 20px · 24px · 32px · 40px · 48px · 64px`
> Zero arbitrary magic numbers anywhere in presentation code.

### Typography
- **Font:** Inter / Plus Jakarta Sans — tabular figures (`FontFeature.tabularFigures()`) for running telemetry.
- **Tracking HUD:** 48pt time · 42pt distance · 36pt pace (glanceable in direct sunlight).

---

## 📋 ENGINEERING DEFINITION OF DONE (DoD)

Every pull request merged into `main` **must** satisfy all 7 Blee Engineering Contract rules:

1. **Zero Lint Errors** — `flutter analyze` passes with 0 errors, 0 warnings.
2. **Deterministic Disposal** — Every `AnimationController`, `TextEditingController`, `StreamSubscription` has a matching `.dispose()` / `ref.onDispose()`.
3. **Architecture Boundary** — No widget makes direct DB or HTTP calls. All calls route through Riverpod notifiers and abstract repositories.
4. **5 UI States** — Every data-driven screen implements: Ideal · Loading Skeleton · Empty · Error + Retry · Offline/Cached.
5. **No Magic Values** — All margins, colors, fonts reference `AppSpacing`, `AppColors`, `AppTypography` tokens only.
6. **Error Logging** — Every `try-catch` routes unexpected errors to `FirebaseCrashlytics.instance.recordError()`. No empty catch blocks.
7. **GPS Data Integrity** — Every coordinate validated: `-90 <= lat <= 90`, `-180 <= lng <= 180`, `accuracy <= 30m`.

---

## 📊 SUPABASE DATABASE SCHEMA (Core Tables)

| Table | Key Columns | Notes |
|-------|-------------|-------|
| `profiles` | `id (UUID = Firebase UID)`, `username`, `tier`, `rhythm_weeks` | Mirrors Firebase Auth UID |
| `runs` | `user_id`, `started_at`, `route GEOMETRY(LINESTRING,4326)` | PostGIS spatial index; unique `(user_id, started_at)` for idempotency |
| `groups` | `admin_id`, `city`, `neighborhood`, `is_public` | BGC-first, expandable |
| `group_members` | `(group_id, user_id)` PK | Roles: admin · organizer · member |
| `group_runs` | `scheduled_at`, `meetup_lat/lng`, `target_pace_bracket` | RSVP-linked events |
| `group_run_rsvps` | `(run_id, user_id)` PK | Status: going · maybe · not_going |
| `live_beacons` | `token (256-bit)`, `expires_at`, `last_lat/lng` | Token-based, no auth required for read |
| `user_blocks` | `(blocker_id, blocked_id)` | Bidirectional content hide |
| `content_reports` | `reporter_id`, `reported_user_id`, `reason`, `status` | Status: pending · reviewed · actioned |

---

## 🔬 THE 5 ESSENTIAL UI STATES CONTRACT

Every data-driven screen/component **must** implement all 5:

| State | Implementation Standard |
|-------|------------------------|
| **1. Ideal** | High-contrast, scannable data. 8pt grid. Tabular numbers for telemetry. |
| **2. Loading** | Content-matched shimmer/skeleton (`shimmer` package). Never a generic center spinner. |
| **3. Empty** | Reassuring illustration, empathetic copy, one clear primary CTA. |
| **4. Error** | Human-readable message, error code, actionable "Try Again" callback. |
| **5. Offline** | Cached data banner ("Showing cached run from SQLite"), seamless fallback. |

---

## ⚡ PERFORMANCE GUARDRAILS

| Rule | Standard |
|------|----------|
| **Frame Budget** | 16ms (60 FPS) / 8ms (120 FPS) on tracking HUD |
| **Heavy Work** | Polyline filtering + image rendering — `compute()` Flutter Isolates |
| **GPS Callbacks** | Zero new object allocations in stream callbacks (tight loop) |
| **Memory** | App heap < 120MB after 60min active GPS recording |
| **Image Rendering** | `ResizeImage(cacheWidth, cacheHeight)` on all `CachedNetworkImage` |
| **Lists** | `ListView.builder` / `GridView.builder` with explicit `itemCount` always |

---

## 💰 MONETIZATION ARCHITECTURE

### Blee Pro — Consumer IAP (RevenueCat)
- **Price:** $4.99/month · $39.99/year (14-day free trial)
- **Paywall trigger:** After 5th completed run, on custom receipt styling screen
- **Graceful downgrade:** Core GPS tracking + historical data retained forever on cancellation

### Blee Pack — B2B Club Portal (Stripe Web)
- **Price:** $29/month per club (bypasses 30% platform cut)
- **Target:** BGC running clubs, corporate wellness, boutique fitness studios
- **Stack:** Next.js + Supabase Auth dashboard · Stripe Customer Portal · Cloudflare Workers webhooks

---

*BLEE Master Plan v4.0 — GPS Reliability First · Community Second · Monetization Third.*  
*Last updated: 2026-10-02*
