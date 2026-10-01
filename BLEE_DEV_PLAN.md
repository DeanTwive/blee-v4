# 🐝 BLEE — Agile Development & Sprint Execution Roadmap
### Based on BLEE_MASTER_PLAN.md v4.0 · Flutter & Firebase/Supabase Architecture

> **Stack:** Flutter 3.x (Dart 3) · Firebase (Auth, Analytics, Crashlytics, FCM) · Supabase (PostgreSQL + PostGIS) · SQLite (`sqflite`) · Google Maps SDK · RevenueCat · Cloudflare R2 · Stripe (Web)  
> **Philosophy:** Evidence-Gated Development. GPS Reliability First. Community Second. Monetization Third. Never advance to the next sprint until the current gate passes.

---

## 🗺️ MASTER SPRINT PROGRESSION & GATES OVERVIEW

| Phase / Sprint | Timeline | Primary Objective | Hard Exit Gate |
|---|---|---|---|
| **Stage 0: Foundation** | Weeks 1–2 | Accounts, Cloud Infra, SQL Schema, Flutter Project Init | `flutter run` compiles on iOS/Android; Supabase schema + RLS verified live |
| **Validate: Zero Code** | Weeks 1–4 (Parallel) | Community outreach, club leader alignment, runner interviews | All 4 community validation gates pass with documented evidence |
| **GPS POC** | Weeks 5–8 | Background GPS service, SQLite storage, Supabase PostGIS sync | All 3 POC technical gates pass across 10-device test matrix |
| **Sprint 1: Core MVP** | Weeks 9–12 | Auth, 7-Step Onboarding, GPS Run Tracker, Run Receipt Generator | D7 retention ≥ 45%; GPS run success rate ≥ 95%; Receipt share rate ≥ 20% |
| **Sprint 2: Community** | Weeks 13–16 | Groups, Group Runs & RSVP, Live Beacon Safety, Feed, Report/Block | Zero P0/P1 bugs in field beta; Live Beacon validated by 20 contacts |
| **Sprint 3: Hardening** | Weeks 17–20 | Accessibility (WCAG AA), 60fps Profiling, Store Submissions | Crashlytics 0 crashes for 72 consecutive hours; App Store / Play Store approved |
| **Launch: BGC 6AM** | Month 5 | Hyper-local launch at Bonifacio Global City Saturday community run | D30 retention ≥ 25%; Weekly Active Runners / MAU ≥ 40%; 500+ active BGC runners |
| **Monetize** | Month 8+ | Blee Pro (RevenueCat IAP) & Blee Pack (B2B Web Stripe Portal) | Monthly paid churn < 6%; CAC payback period < 3 months; 5+ paid clubs |

---

## 🏛️ CORE TECHNICAL ARCHITECTURE & STANDARDS

### 1. Layered Architecture (Clean Architecture + Feature-Driven)
Code is partitioned by feature module with strict unidirectional dependency flow:
```
lib/
├── app.dart                          # MaterialApp.router, AppTheme, Global Providers
├── main.dart                         # Entry point, Firebase.initializeApp, Supabase.initialize
├── core/
│   ├── constants/                    # app_colors.dart, app_spacing.dart, app_typography.dart
│   ├── network/                      # connectivity_service.dart, error_interceptor.dart
│   ├── router/                       # app_router.dart (GoRouter with redirect guards)
│   ├── theme/                        # app_theme.dart (Light + Dark elevated slates)
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

### 2. State Management & Data Flow
- **Framework:** `flutter_riverpod` (v2.5+) with code generation (`riverpod_generator`).
- **Immutability:** `freezed` & `json_serializable` for all domain entities and state objects.
- **Unidirectional Data Flow:** Presentation dispatches intents to `Notifier` / `AsyncNotifier`. State streams down. No direct repository calls from UI widgets.

### 3. The 5 Essential UI States Contract
Every data-driven UI screen must explicitly implement all five UI states:
1. **Ideal State:** High-contrast, scannable data visualization using the 8pt grid.
2. **Loading State:** Content-matched shimmer/skeleton loaders (`shimmer` package), never generic center spinners.
3. **Empty State:** Reassuring illustration/icon, empathetic copy, clear single primary CTA.
4. **Error State:** Human-readable explanation, error code, and actionable "Try Again" retry callback.
5. **Partial / Offline State:** Graceful cached banner ("Showing cached run from SQLite"), seamless offline fallback.

### 4. Golden Rules of Performance & Battery
- **Frame Budget:** 16ms (60 FPS) / 8ms (120 FPS). Heavy polyline filtering and image rendering executed in Flutter Isolates via `compute()`.
- **Garbage Collection:** Zero allocations in tight loops (GPS stream callbacks, paint methods).
- **Deterministic Teardown:** Every `AnimationController`, `TextEditingController`, and `StreamSubscription` disposed in `dispose()` or Riverpod `ref.onDispose()`.

---

## 🚀 STAGE 0: WEEKS 1–2 — FOUNDATION, ACCOUNTS, SCHEMA & INIT

**Primary Goal:** Establish all cloud, database, analytics, and mobile project scaffolding before writing feature logic.  
**Hard Exit Gate:** `flutter run` boots cleanly on physical iOS and Android devices; Supabase PostGIS schema deployed with active RLS; Firebase project connected.

### Sprint Backlog: Week 1 — Cloud & Infrastructure Setup

#### [ST0-01] External Services & Developer Accounts Provisioning
- **Type:** DevOps / Setup
- **Tasks:**
  - [ ] Enroll in Apple Developer Program ($99/year) & Google Play Console ($25 one-time).
  - [ ] Provision Firebase project `blee-prod` (Region: `asia-east1`).
  - [ ] Provision Supabase project `blee-prod` (Region: `ap-southeast-1` Singapore).
  - [ ] Create Cloudflare R2 bucket `blee-run-receipts` and configure CORS for mobile upload.
  - [ ] Create RevenueCat project `Blee` and configure iOS/Android bundle identifiers (`com.blee.app`).
  - [ ] Configure PostHog Cloud EU/US instance and obtain client API key.
  - [ ] Create Google Cloud Console project, enable Maps SDK for Android, Maps SDK for iOS, and Places API.
- **Acceptance Criteria:** All credentials and API keys stored securely in `.env.development` and CI secrets vault (never committed to Git).

#### [ST0-02] Supabase PostgreSQL + PostGIS Schema Deployment
- **Type:** Backend / Database
- **Tasks:** Deploy database schema via Supabase SQL Editor:
  ```sql
  -- Extensions
  CREATE EXTENSION IF NOT EXISTS postgis;
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

  -- Profiles (Mirroring Firebase Auth UID)
  CREATE TABLE public.profiles (
    id UUID PRIMARY KEY, -- matches auth.uid
    display_name TEXT NOT NULL,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    tier TEXT NOT NULL DEFAULT 'pacer' CHECK (tier IN ('pacer', 'strider', 'elite')),
    identity_goal TEXT,
    avatar_url TEXT,
    city TEXT DEFAULT 'Taguig (BGC)',
    rhythm_weeks INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );

  -- Runs (PostGIS LINESTRING for routes)
  CREATE TABLE public.runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    distance_meters DOUBLE PRECISION NOT NULL,
    duration_seconds INTEGER NOT NULL,
    rpe INTEGER CHECK (rpe BETWEEN 1 AND 10),
    avg_cadence INTEGER,
    route GEOMETRY(LINESTRING, 4326),
    city TEXT DEFAULT 'BGC',
    run_receipt_url TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    privacy_zone_applied BOOLEAN DEFAULT FALSE,
    peak_km_index INTEGER,
    peak_km_pace_seconds INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, started_at) -- Idempotency guarantee
  );

  -- Groups
  CREATE TABLE public.groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    city TEXT NOT NULL,
    neighborhood TEXT,
    admin_id UUID NOT NULL REFERENCES public.profiles(id),
    is_public BOOLEAN DEFAULT TRUE,
    member_count INTEGER DEFAULT 1,
    cover_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );

  -- Group Members
  CREATE TABLE public.group_members (
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'organizer', 'member')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id)
  );

  -- Group Runs (Schedules)
  CREATE TABLE public.group_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    created_by UUID REFERENCES public.profiles(id),
    title TEXT NOT NULL,
    description TEXT,
    scheduled_at TIMESTAMPTZ NOT NULL,
    meetup_lat DOUBLE PRECISION NOT NULL,
    meetup_lng DOUBLE PRECISION NOT NULL,
    meetup_address TEXT NOT NULL,
    target_pace_bracket TEXT,
    target_distance_km DOUBLE PRECISION,
    max_attendees INTEGER DEFAULT 50,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );

  -- RSVPs
  CREATE TABLE public.group_run_rsvps (
    run_id UUID REFERENCES public.group_runs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'going' CHECK (status IN ('going', 'maybe', 'not_going')),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (run_id, user_id)
  );

  -- Safety Live Beacons
  CREATE TABLE public.live_beacons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    run_id UUID REFERENCES public.runs(id),
    token TEXT UNIQUE NOT NULL, -- 256-bit cryptographically secure token
    last_lat DOUBLE PRECISION,
    last_lng DOUBLE PRECISION,
    last_battery_pct INTEGER,
    last_updated TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );

  -- Moderation & Safety Blocks
  CREATE TABLE public.user_blocks (
    blocker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id)
  );

  CREATE TABLE public.content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id),
    reported_user_id UUID NOT NULL REFERENCES public.profiles(id),
    content_type TEXT NOT NULL CHECK (content_type IN ('run', 'profile', 'group', 'comment')),
    content_id UUID NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'actioned')),
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
  ```
- **Acceptance Criteria:** Tables created in Supabase with PostGIS spatial indices on `runs.route`.

#### [ST0-03] Row Level Security (RLS) Policies Deployment
- **Type:** Backend / Security
- **Tasks:**
  - [ ] Enforce RLS on all tables (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`).
  - [ ] Configure policies allowing public read of verified profiles, private update by `auth.uid()`.
  - [ ] Secure `runs` table: users can only insert, update, or delete their own runs. Public runs readable by authenticated users (excluding blocked users).
  - [ ] Secure `live_beacons`: Token-based read policy (`is_active = true AND expires_at > NOW()`), runner updates own beacon.
- **Acceptance Criteria:** Unit tests in Supabase SQL verify unauthorized updates are rejected.

---

### Sprint Backlog: Week 2 — Flutter Project Scaffolding & Core Architecture

#### [ST0-04] Flutter 3.x Project Initialization & Dependencies
- **Type:** Mobile / Setup
- **Tasks:**
  - [ ] Initialize Flutter project: `flutter create --org com.blee --project-name blee blee_app`.
  - [ ] Add production dependencies to `pubspec.yaml`:
    - `firebase_core`, `firebase_auth`, `firebase_crashlytics`, `firebase_analytics`, `firebase_messaging`
    - `supabase_flutter`
    - `geolocator`, `flutter_background_service`, `sqflite`, `path_provider`
    - `google_maps_flutter`
    - `screenshot`, `share_plus`, `image_picker`, `cached_network_image`
    - `flutter_riverpod`, `riverpod_annotation`
    - `go_router`
    - `freezed_annotation`, `json_annotation`
    - `intl`, `uuid`, `crypto`
    - `posthog_flutter`, `purchases_flutter`
  - [ ] Configure dev dependencies: `build_runner`, `freezed`, `json_serializable`, `riverpod_generator`, `flutter_lints`.
  - [ ] Integrate Firebase configuration: `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
- **Acceptance Criteria:** `flutter pub get` succeeds without version conflicts; Android Gradle and iOS CocoaPods build without errors.

#### [ST0-05] Design System & Tokenization Implementation
- **Type:** UI Architecture
- **Tasks:**
  - [ ] Implement `lib/core/constants/app_colors.dart`:
    - Pure Dark & Elevated Slates: `surface = #121417`, `surfaceElevated = #1E2228`, `surfaceBorder = #2A303C`
    - Brand Colors: `primary = #E5F925` (Electric Cyber Lime / Hi-Vis Amber), `onPrimary = #000000`
    - Secondary: `electricCobalt = #2B66FF`, `safetyOrange = #FF5500`
    - Status: `success = #00E676`, `danger = #FF3B30`, `warning = #FFCC00`
  - [ ] Implement `lib/core/constants/app_spacing.dart`: Strict 8pt/4pt grid (4, 8, 12, 16, 20, 24, 32, 40, 48, 64px).
  - [ ] Implement `lib/core/constants/app_typography.dart`: Clean, athletic modern type scale (Inter/Plus Jakarta Sans) with tabular numbers for running telemetry (`FontFeature.tabularFigures()`).
- **Acceptance Criteria:** No raw hex codes or magic number margins anywhere in presentation code.

---

## 👥 VALIDATE: WEEKS 1–4 (PARALLEL) — COMMUNITY & ZERO-CODE DISCOVERY

**Primary Goal:** Validate product-market need, user identity resonance, and hyper-local BGC club willingness with zero engineering waste.  
**Hard Exit Gate:** All 4 validation gates passed with signed club agreements, 50+ recorded interviews, and 100+ beta commitments.

### Week-by-Week Operational Execution

#### Week 1: Club Outreach & Leader Interviews (Gate 1)
- [ ] Contact 5 prominent BGC/Manila running clubs (e.g., BGC Run Club, Runtopia, Ayala Tri).
- [ ] Conduct 30-minute structured interviews with 3+ club captains.
- [ ] Discover current pain points: WhatsApp RSVP drop-off, Strava segment toxicity, roll-call manual tracking.
- **Exit Gate 1:** At least 3 club leaders agree to pilot Blee for Saturday group runs.

#### Week 2: Ground Truth Runner Interviews at BGC High Street (Gate 2)
- [ ] Attend Saturday 5:30 AM – 7:30 AM runs along 9th Avenue & Bonifacio High Street.
- [ ] Conduct 50 on-the-spot 3-minute interviews across 3 tiers (20 Pacers, 20 Striders, 10 Elites).
- [ ] Test the core value proposition: "A running app that celebrates consistency and community over competitive PR pressure."
- **Exit Gate 2:** ≥ 75% (38/50) runners express dissatisfaction with Strava's intimidation factor or NRC's lack of local community.

#### Week 3: Run Receipt Prototype Testing (Gate 3)
- [ ] Generate 5 visual variants of the "Run Receipt" (black receipt theme, card gradient, typographic poster, minimalist split card).
- [ ] Present prototypes to 30 runners via smartphone mockups.
- [ ] Measure organic sharing impulse: "Would you share this to your Instagram Story right now?"
- **Exit Gate 3:** ≥ 65% of surveyed runners pick the "Run Receipt" over standard Strava orange route screenshots.

#### Week 4: Waitlist & Seed Community Formation (Gate 4)
- [ ] Launch simple landing page with BGC club branding and WhatsApp VIP beta group.
- [ ] Acquire 100 organic runner waitlist signups committing to test the GPS POC.
- **Exit Gate 4:** 100 verified runners joined waitlist with phone number and pace tier declared.

---

## 🛰️ GPS POC: WEEKS 5–8 — BACKGROUND GPS ENGINE, SQLITE & SYNC

**Primary Goal:** Build a rock-solid, production-grade background GPS recording engine that does not drop points in background or get killed by aggressive OS battery managers.  
**Hard Exit Gate:** All 3 POC technical gates pass:
1. **Point Retention Gate:** ≥ 99.0% GPS point capture over a 10km run in background with screen locked.
2. **Battery Gate:** Battery drain < 6% per hour of continuous background recording.
3. **Sync Idempotency Gate:** 100% successful offline-to-online sync with zero duplicate database entries.

### Sprint Backlog: Week 5 — Foreground & Background Location Architecture

#### [GPS-01] Flutter Background Service & Geolocation Engine
- **Type:** Mobile / Core GPS
- **Tasks:**
  - [ ] Implement `flutter_background_service` with Android Foreground Service notification:
    - Ongoing notification with channel ID `blee_tracking_channel`.
    - Real-time notification updates displaying current elapsed time, distance (km), and pace (min/km).
  - [ ] Configure iOS Background Modes in `Info.plist`:
    - `location` (Background location updates)
    - `processing` (Background task completion)
    - Set `allowsBackgroundLocationUpdates = true` and `pausesLocationUpdatesAutomatically = false`.
  - [ ] Implement `geolocator` stream settings:
    - Android: `AndroidSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 3, intervalDuration: Duration(seconds: 1), foregroundNotificationConfig: ...)`
    - iOS: `AppleSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 3, activityType: ActivityType.fitness, showBackgroundLocationIndicator: true)`
- **Acceptance Criteria:** Location updates continue streaming when the app is minimized and device screen is locked for 60 consecutive minutes.

---

### Sprint Backlog: Week 6 — High-Throughput SQLite Local Pipeline

#### [GPS-02] Local SQLite High-Throughput Storage & Filter Pipeline
- **Type:** Mobile / Database / Math
- **Tasks:**
  - [ ] Create `lib/features/tracking/data/local_run_db.dart` using `sqflite`:
    ```sql
    CREATE TABLE raw_breadcrumbs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      run_id TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      altitude REAL,
      accuracy REAL NOT NULL,
      speed REAL,
      timestamp INTEGER NOT NULL,
      is_synced INTEGER DEFAULT 0
    );
    CREATE INDEX idx_run_timestamp ON raw_breadcrumbs(run_id, timestamp);
    ```
  - [ ] Implement Point Sanitization Filter (`gps_filter.dart`):
    - **Accuracy Filter:** Discard points where `accuracy > 30.0` meters.
    - **Speed Sanity:** Discard points where calculated delta speed exceeds 45 km/h (eliminates GPS teleportation glitches).
    - **Haversine Distance Accumulation:** Accumulate distance only when delta distance exceeds minimum distance threshold (2.5 meters).
  - [ ] Implement Polyline Simplification in isolate via `compute()`: Ramer-Douglas-Peucker (RDP) algorithm with epsilon = 0.00005 (~5m) to compress 3,600 points down to ~400 high-fidelity vertices for PostGIS upload.
- **Acceptance Criteria:** SQLite write operations average < 3ms per point; zero UI thread jank during active recording.

---

### Sprint Backlog: Week 7 — Supabase PostGIS Sync Engine

#### [GPS-03] Idempotent Offline-to-Online PostGIS Sync Worker
- **Type:** Backend Integration / Data Layer
- **Tasks:**
  - [ ] Implement `GpsRepository.syncRunToSupabase()`:
    - Reads all unsynced points for completed `run_id` from local SQLite.
    - Constructs WKT (Well-Known Text) `LINESTRING(lng1 lat1, lng2 lat2, ...)` or GeoJSON coordinates array.
    - Executes idempotent upsert into Supabase `runs` table:
      ```dart
      try {
        final lineString = 'SRID=4326;LINESTRING(${points.map((p) => '${p.longitude} ${p.latitude}').join(',')})';
        await supabase.from('runs').insert({
          'user_id': userId,
          'started_at': startedAt.toIso8601String(),
          'ended_at': endedAt.toIso8601String(),
          'distance_meters': distanceMeters,
          'duration_seconds': durationSeconds,
          'rpe': rpeScore,
          'route': lineString,
          'city': 'BGC',
        });
        await localDb.markRunAsSynced(runId);
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          // Unique constraint violation (user_id, started_at) -> already synced!
          await localDb.markRunAsSynced(runId);
        } else {
          rethrow;
        }
      }
      ```
  - [ ] Implement background connectivity listener (`connectivity_plus`) that triggers pending sync queue automatically when network returns.
- **Acceptance Criteria:** Simulating airplane mode during run completion retains local data; reconnecting immediately uploads route with zero data loss and zero duplicates.

---

### Sprint Backlog: Week 8 — The 10-Device Matrix Stress Test

#### [GPS-04] Extreme Device & Urban Canyon Field Matrix
- **Type:** QA / Field Testing
- **Tasks:**
  - [ ] Test matrix across 10 real physical hardware units:
    1. Samsung Galaxy S23 (OneUI aggressive sleeping)
    2. Samsung Galaxy A54 (mid-tier Exynos)
    3. Xiaomi Redmi Note 12 (MIUI battery-killer)
    4. Xiaomi 13 Pro (HyperOS)
    5. Google Pixel 7 (Stock Android)
    6. Google Pixel 6a (Doze mode validation)
    7. iPhone 15 Pro (iOS 17 Standby & Dynamic Island)
    8. iPhone 13 (iOS 17 standard)
    9. iPhone 11 (Legacy iOS battery throttling)
    10. Huawei P30 / Honor (EMUI aggressive app killer)
  - [ ] Execute two standardized 10km runs:
    - Test A: Open sky flat loop (BGC Greenway Park).
    - Test B: High-density urban canyon (Bonifacio High Street tall concrete glass towers).
  - [ ] Implement `BatteryOptimizationHelper.dart`: Detect OEM manufacturer and show polite interactive guide directing runner to disable OEM battery optimization for Blee.
- **Acceptance Criteria:** All 10 devices pass the 3 technical gates (≥ 99% points preserved, < 6% battery/hr, 100% sync success).

---

## 📱 SPRINT 1: WEEKS 9–12 — CORE MVP: AUTH, ONBOARDING, TRACKER & RECEIPT

**Primary Goal:** Deliver the end-to-end solo runner loop: Sign up -> Set identity -> Record run with 100% precision -> Post-run RPE -> Generate & share Run Receipt.  
**Hard Exit Gate:**
- D7 Cohort Retention ≥ 45% on beta.
- GPS run completion reliability ≥ 95%.
- Run Receipt share rate ≥ 20% of completed runs.
- Crashlytics zero crashes for 48 consecutive hours.

### Week-by-Week Backlog

#### Week 9: Authentication & Profile Sync
- **[SP1-01] Firebase Authentication Pipeline:**
  - Implement Apple Sign-In (`sign_in_with_apple`), Google Sign-In, Email/Password, and Phone OTP.
  - Implement Auth State Riverpod Provider (`auth_notifier.dart`).
- **[SP1-02] Supabase Profile Auto-Creation Trigger:**
  - Upon successful Firebase Auth sign-in, check if profile exists in Supabase `profiles`. If not, create default profile record using JWT/UID.
  - Handle profile avatar upload to Supabase Storage with local compression.
- **Acceptance Criteria:** User can sign in, kill app, relaunch, and remain authenticated with profile hydrated from Supabase.

#### Week 10: The 7-Step Identity Onboarding Funnel
- **[SP1-03] Onboarding Flow UI (8pt Grid, Animated Transitions):**
  - Screen 1: The Blee Manifesto ("We don't run for numbers. We run for who we become.").
  - Screen 2: First Name & Profile Photo.
  - Screen 3: Running Experience & Pace Tier (Pacer: > 6:30 min/km, Strider: 5:00–6:30 min/km, Elite: < 5:00 min/km).
  - Screen 4: Motivation Anchor (Mental clarity, health, marathon prep, community).
  - Screen 5: Weekly Rhythm Commitment (2 runs/wk, 3 runs/wk, 4+ runs/wk).
  - Screen 6: Location & Notification Permission Primer (Transparent explanation of *why* background location is mandatory before showing OS dialog).
  - Screen 7: Identity Declaration Card ("I am a Blee Runner") with tactile haptic feedback.
- **Acceptance Criteria:** Funnel analytics hooked to PostHog; ≥ 70% completion rate in beta.

#### Week 11: Real-Time In-Run Tracking Screen
- **[SP1-04] Live Heads-Up Display (HUD):**
  - Glanceable typography: 48pt elapsed time, 42pt distance (km), 36pt current pace (min/km). Tabular numeric layout to eliminate visual jitter.
  - Google Maps live polyline stream overlay with custom user location marker.
  - Slide-to-pause / hold-to-stop gesture to prevent accidental sweat touches.
  - Auto-pause toggle option (detects speed < 0.8 m/s for > 5 seconds).
  - Implement all 5 UI states (ideal tracking, acquiring GPS signal skeleton, GPS permission denied error, weak satellite warning, background recovery state).
- **Acceptance Criteria:** Zero dropped frames during map panning; legible in direct sunlight.

#### Week 12: Post-Run Experience & Run Receipt Generator
- **[SP1-05] Post-Run RPE Rating & Flow:**
  - Borg Rating of Perceived Exertion (RPE) 1–10 tactile slider with micro-copy ("1 = Easy Recovery Walk", "5 = Moderate Tempo", "10 = Maximum All-Out Sprint").
  - Peak Kilometer Pace calculation and highlight.
- **[SP1-06] The Run Receipt Card Engine:**
  - Pixel-perfect, high-aesthetic digital receipt widget wrapped in `RepaintBoundary`:
    - Header: Blee Bee logo, date, time, weather icon, city badge ("BGC, Manila").
    - Body: Total Distance, Duration, Avg Pace, Peak KM Pace, RPE Score badge.
    - Graphic: Route mini-map vector silhouette rendered via `CustomPainter`.
    - Footer: "Identity > Telemetry · blee.app" + unique receipt barcode graphic.
  - Convert `RepaintBoundary` to high-resolution PNG (3x device pixel ratio) in memory.
  - Native Share Sheet integration (`share_plus`) targeting Instagram Stories, WhatsApp, and Camera Roll save.
  - Async upload of generated image to Cloudflare R2 bucket (`blee-run-receipts`) for permanent cloud URL.
- **Acceptance Criteria:** Export takes < 400ms; produces clean 1080x1920 Instagram Story format; zero server rendering cost.

---

## 🤝 SPRINT 2: WEEKS 13–16 — COMMUNITY CORE: GROUPS, RSVPS, LIVE BEACON & TRUST

**Primary Goal:** Transform Blee from a solo utility into a hyper-local running community platform with group runs and live safety tracking.  
**Hard Exit Gate:** Zero P0/P1 bugs in field beta; ≥ 70% RSVP attendance rate; Live Beacon successfully tested by 20 runner emergency contacts.

### Week-by-Week Backlog

#### Week 13: Local Running Groups Directory & Detail View
- **[SP2-01] Groups Architecture:**
  - Group discovery list filtered by city and neighborhood (default: BGC, Taguig).
  - Search bar with 300ms debounce.
  - Group Detail view: Cover photo, description, admin badge, member count, upcoming scheduled runs.
  - Join / Leave group state machine with optimistic UI updates.
  - Implement all 5 UI states (Ideal group feed, shimmer list skeletons, empty "No groups in your neighborhood yet", error with retry, offline cached groups).
- **Acceptance Criteria:** Member list displays accurate counts; admins can edit group metadata.

#### Week 14: Group Runs Scheduling & RSVP Engine
- **[SP2-02] Group Run Event Management:**
  - Admins can create scheduled runs: Title, date/time, meetup location pin on Google Maps, target distance, pace brackets, and max attendee cap.
  - RSVP system: Runners mark "Going", "Maybe", or "Can't Go".
  - One-tap "Add to Calendar" (.ics export via `add_2_calendar`).
  - Google Maps deep-link ("Directions to Meetup Point" opening Apple Maps / Google Maps).
  - Push notification reminder via FCM sent 2 hours before scheduled meetup.
- **Acceptance Criteria:** Over-capacity RSVPs automatically disabled; RSVP status reflected in real-time.

#### Week 15: Safety Live Beacon Engine
- **[SP2-03] Cryptographic Live Beacon Generation & Streaming:**
  - Runner toggles "Share Live Beacon" before starting a run.
  - App generates 256-bit cryptographically secure token using `Random.secure()` (base64url 32 characters).
  - Inserts beacon into Supabase `live_beacons` with `expires_at = NOW() + INTERVAL '3 hours'`.
  - Background service pushes `(last_lat, last_lng, battery_pct)` to Supabase every 15 seconds.
  - Generates shareable URL: `https://blee.app/live/{token}`.
- **[SP2-04] Lightweight Public Web Viewer & WAF Rate Limiting:**
  - Static HTML5/Leaflet or Mapbox web viewer hosted on Cloudflare Pages.
  - Reads beacon coordinates without requiring login (contacts do not need a Blee account).
  - Cloudflare WAF rate limiting rule: max 10 requests/minute per IP on `/live/*` to block scrapers.
  - Auto-terminates when runner taps "Stop Run" or token expires.
- **Acceptance Criteria:** Emergency contact can open link on any mobile browser and track runner live; link dead after 3 hours.

#### Week 16: Activity Feed, Privacy Zones & Moderation
- **[SP2-05] Community Activity Feed:**
  - Chronological feed of runs completed by club members and mutual runners.
  - "Cheer" interaction (anti-toxic kudos with no public dislike or vanity counters).
  - Virtualized list rendering via `ListView.builder` with `RepaintBoundary` on feed cards.
- **[SP2-06] Privacy Zones & User Moderation:**
  - **Privacy Zone:** Runner can set home/work address; Blee trims first and last 500 meters of any route starting or ending inside this circle.
  - **Block & Report:** User can block any profile (instantly hides all content, runs, and comments bidirectionally).
  - **Report Engine:** Form submission to `content_reports` with screenshot and reason.
- **Acceptance Criteria:** Blocked user completely disappears from all queries; privacy zone masks GPS coordinates before saving to public runs table.

---

## 🛡️ SPRINT 3: WEEKS 17–20 — PRODUCTION HARDENING, A11Y & APP STORE

**Primary Goal:** Eliminate technical debt, optimize performance to consistent 60/120 FPS, achieve WCAG 2.1 AA accessibility compliance, and pass App Store / Google Play reviews.  
**Hard Exit Gate:** Crashlytics zero crashes for 72 consecutive hours on 50-person TestFlight/Internal Track; App Store and Play Store approved for release.

### Week-by-Week Backlog

#### Week 17: Accessibility (A11y) & Dark Mode Theming Audit
- **[SP3-01] WCAG 2.1 AA Accessibility Hardening:**
  - Audit all text elements with Color Contrast Analyzer: minimum 4.5:1 for body text, 3:1 for large telemetry numbers.
  - Wrap all interactive widgets with explicit `Semantics(button: true, label: "...")` for VoiceOver & TalkBack.
  - Ensure all touch targets meet minimum 48x48 dp bounding boxes.
  - Dynamic Font Scaling: Test under 200% system font scaling; resolve all RenderFlex overflow errors using `Flexible`, `Expanded`, and `FittedBox`.
- **Acceptance Criteria:** Screen reader can complete an entire run flow without visual feedback; zero layout overflows.

#### Week 18: Performance Profiling & Memory Leak Sweep
- **[SP3-02] DevTools Profiling & Leak Elimination:**
  - Run Flutter DevTools Memory Profiler: verify zero memory leaks across 20 screen transitions.
  - Ensure all `StreamSubscription`, `TextEditingController`, and `MapController` instances are deterministically closed.
  - Image caching: Constrain memory footprint using `ResizeImage` with `cacheWidth` and `cacheHeight` on `CachedNetworkImage`.
  - Frame budget verification: GPS tracking HUD maintains solid 60fps / 120fps with zero frame drops during active route rendering.
- **Acceptance Criteria:** App heap memory remains under 120MB after 60 minutes of active GPS recording.

#### Week 19: Offline Resilience & Edge Case Chaos Testing
- **[SP3-03] Chaos Engineering Suite:**
  - Simulate complete GPS signal loss (tunnel test): verify dead reckoning / polite indicator UI.
  - Force app kill by OS in background: verify recovery service resurrects active run state from SQLite.
  - Test run completion with zero network: verify run marked local and syncs silently once Wi-Fi reconnects.
  - Low-battery mode test: verify location updates do not crash when Android enters aggressive battery-saver mode.
- **Acceptance Criteria:** Zero lost runs across 50 simulated chaos scenarios.

#### Week 20: Store Assets, Privacy Compliance & App Submission
- **[SP3-04] App Store & Google Play Submission:**
  - Prepare high-resolution App Store screenshots for 6.7", 6.5", and 5.5" iPhone displays, plus Android phone/tablet specs.
  - Draft App Store Privacy Nutrition Labels: declare Location (Tracking), Contact Info (Account), Diagnostics (Crashlytics).
  - Configure iOS `NSLocationAlwaysAndWhenInUseUsageDescription` with clear, compliant copy explaining background safety and distance tracking.
  - Submit build to TestFlight External Review and Google Play Closed Testing.
- **Acceptance Criteria:** Both Apple App Review and Google Play Review approve build with zero rejections.

---

## 🏁 LAUNCH: MONTH 5 — THE BGC SATURDAY 6:00 AM PLAYBOOK

**Primary Goal:** Execute a concentrated, hyper-local launch event in Bonifacio Global City to establish network density and organic viral momentum.  
**Hard Exit Gate:** D30 retention ≥ 25%; Weekly Active Runners / MAU ≥ 40%; 500+ active runners in BGC cluster.

### Launch Operational & Technical Plan

#### T-Minus 7 Days: Pre-Launch Readiness
- [ ] Deploy v1.0.0 production builds to App Store and Google Play phased release.
- [ ] Confirm Supabase connection pooler (`PgBouncer`) configured for 500+ concurrent connections.
- [ ] Pre-populate BGC Running Club and 3 partnered groups with official Saturday 6:00 AM launch run.
- [ ] Configure PostHog live dashboard for real-time onboarding funnel, run starts, and receipt shares.

#### Launch Day: Saturday 5:30 AM – 8:30 AM (BGC High Street)
- [ ] **On-Ground Presence:** Booth setup at Bonifacio High Street Amphitheater.
- [ ] **Physical Run Receipt Wall:** Runners who complete the 5km/10km community run show their digital Run Receipt on Blee and receive a printed physical vinyl sticker badge.
- [ ] **Live Operations War Room:** Engineering team monitors Firebase Crashlytics real-time logs, PostHog event streams, and Supabase database latency.
- [ ] **Pacing Groups:** Designated Blee pacers lead 5:00, 5:30, 6:00, 6:30, and 7:00 min/km pace groups with Blee Live Beacons active.

#### Post-Launch Weeks 1–4: Retention & Optimization
- [ ] Monitor D1, D7, and D30 retention cohorts in PostHog.
- [ ] Daily triage of user feedback, GPS reports, and edge-case device issues.
- [ ] Celebrate Blee Rhythm milestones (rewarding runners who hit 2+ runs/week for 4 consecutive weeks).

---

## 💰 MONETIZE: MONTH 8+ — BLEE PRO & BLEE PACK WEB

**Primary Goal:** Launch sustainable, high-margin revenue streams through consumer subscriptions (Blee Pro) and B2B running club software (Blee Pack).  
**Hard Exit Gate:** Monthly paid churn < 6%; CAC payback period < 3 months; at least 5 paying B2B running club accounts.

### 1. Blee Pro (In-App Subscriptions via RevenueCat)
- **Pricing:** $4.99/month or $39.99/year (with 14-day free trial).
- **Features Included:**
  - Advanced Cadence Coach & phone accelerometer analytics.
  - Unlimited custom Run Receipt themes (Dark Mode Carbon, Vintage Tokyo, Minimalist Line).
  - Unlimited Group creation and leadership tools.
  - Blee Rhythm Protection: 2 automatic "Grace Weeks" per quarter to preserve identity streak during injury or illness.
- **Implementation:**
  - `purchases_flutter` SDK integration.
  - Paywall presented contextually: after 5th completed run and on custom receipt styling screens.
  - Graceful downgrade: runners who cancel retain all historical data and core GPS tracking forever.

### 2. Blee Pack (B2B Club Web Portal via Stripe)
- **Pricing:** $29/month per club (bypasses 30% Apple/Google cut via Web Checkout).
- **Target:** Independent running clubs, corporate wellness teams, and boutique fitness studios.
- **Features Included:**
  - Web dashboard (Next.js + Supabase Auth) for club captains.
  - Aggregate club attendance analytics, heatmaps, and RSVP export (.csv).
  - Co-branded club Run Receipts (Club logo automatically watermarked on members' shared receipts).
  - Priority member announcement broadcasts.
- **Implementation:**
  - Stripe Customer Portal & Subscription Webhook worker on Cloudflare Workers / Supabase Edge Functions.

---

## 📋 ENGINEERING GUARDRAILS & DEFINITION OF DONE (DoD)

Before any pull request is merged into `main`, it must satisfy the **Blee Engineering Contract**:

1. **Zero Lint Errors:** `flutter analyze` passes with zero errors and zero warnings.
2. **Deterministic Disposal:** All controllers, animations, text fields, and streams have matching `.dispose()` calls.
3. **Architecture Boundary:** No presentation widget makes direct database or HTTP calls. Everything routes through Riverpod notifiers and abstract repositories.
4. **5 UI States Handled:** Widget code handles Ideal, Loading Skeleton, Empty, Error with Retry, and Offline States.
5. **No Magic Values:** Margins, paddings, colors, and font styles strictly reference `AppSpacing`, `AppColors`, and `AppTypography`.
6. **Error Logging:** Every `try-catch` block routes unexpected errors to `FirebaseCrashlytics.instance.recordError()`. Never leave empty catch blocks.
7. **GPS Data Integrity:** Every coordinate point validated (`-90 <= lat <= 90`, `-180 <= lng <= 180`, `accuracy <= 30m`).

---
*Blee Dev Plan v2.0 — Engineered for 100% Reliability, Zero GPS Loss, and Thriving Community.*
