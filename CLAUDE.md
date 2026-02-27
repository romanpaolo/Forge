# ScopeSnap — Claude Code Project Config

## What This Project Is

ScopeSnap is an iOS companion app for Ray-Ban Meta glasses that turns a job-walk recording into a structured scope document and trade task list — ready to export to Buildertrend. No typing required.

**Core loop:**
Ray-Ban Meta Glasses → ScopeSnap iOS → Buildertrend

The full product vision, architecture diagram, data model, and 90-day roadmap live in:
- `ScopeSnap_iOS_MVP_Architecture.md` — source of truth for all decisions
- `README.md` — tracks implementation status (update the Progress section whenever a feature is completed)

---

## Project Structure

```
Forge/                          ← repo root
├── CLAUDE.md                   ← you are here
├── README.md                   ← progress tracking lives here
├── ScopeSnap_iOS_MVP_Architecture.md
└── Forge/                      ← Xcode project root
    ├── Forge.xcodeproj/
    └── Forge/                  ← Swift source files
        ├── ForgeApp.swift      ← app entry point, Wearables.configure()
        ├── ContentView.swift   ← main UI
        ├── Persistence.swift   ← CoreData (will migrate to SwiftData)
        └── ...                 ← new files go here
```

---

## Build & Test Commands

**Build (simulator):**
```bash
xcodebuild \
  -project Forge/Forge.xcodeproj \
  -scheme Forge \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -20
```

**Run tests:**
```bash
xcodebuild \
  -project Forge/Forge.xcodeproj \
  -scheme Forge \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test 2>&1 | tail -30
```

**Clean build:**
```bash
xcodebuild \
  -project Forge/Forge.xcodeproj \
  -scheme Forge \
  clean 2>&1 | tail -5
```

Always run the build command after implementing a feature. If the build fails, fix the errors before marking the feature complete or moving on.

---

## Agentic Loop — The Ralph Wiggum Loop

This project follows a strict **Build → Test → Proceed** loop. Do not skip steps.

```
┌─────────────────────────────────────┐
│  1. READ next feature from README   │
│     (first unchecked item in        │
│      ## Implementation Progress)    │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  2. BUILD the feature               │
│     • Follow architecture doc       │
│     • Write clean, modular Swift    │
│     • No placeholders or stubs      │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  3. TEST the feature                │
│     • Run xcodebuild                │
│     • Fix any build errors          │
│     • Run unit tests if applicable  │
│     • Confirm expected behaviour    │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  4. UPDATE README.md                │
│     • Check off the completed item  │
│     • Add a one-line note if needed │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  5. COMMIT                          │
│     git add -A                      │
│     git commit -m "feat: <feature>" │
└──────────────────┬──────────────────┘
                   │
                   ▼
              LOOP BACK TO 1
```

Use `/loop` to start or resume this cycle.
Use `/feature-done` to mark the current feature complete and advance.

---

## Coding Standards

**Swift conventions:**
- SwiftUI for all UI — no UIKit unless the SDK forces it
- SwiftData for persistence — no Core Data boilerplate
- `async/await` for all async work — no completion handlers
- Group related code into clearly named files (e.g., `CaptureModule.swift`, `ProcessModule.swift`)
- Keep `ContentView.swift` as a thin coordinator — extract logic into dedicated types

**Architecture layers (from spec):**

| Layer | Responsibility |
|---|---|
| `CaptureModule` | Audio/video from glasses or iPhone fallback |
| `ProcessModule` | Claude API audio transcription + scope structuring (single call) |
| `ReviewView` | SwiftUI review/edit/approve UI |
| `ExportModule` | PDF, clipboard, share sheet |
| `SwiftData models` | Project, Recording, PhotoCapture, ScopePacket, TradeTask |

**Naming:**
- Files: `PascalCase.swift`
- Types: `PascalCase`
- Properties/functions: `camelCase`
- SwiftData models match the spec exactly (see `ScopeSnap_iOS_MVP_Architecture.md` § Data Model)

---

## Feature Order (from Architecture Doc)

Follow this order exactly. Do not jump ahead.

### Phase 1 — PoC, iPhone-only (Days 1–14)
1. Project creation UI (new project, name + address)
2. AVAudioEngine recording (start/stop, save audio file)
3. Claude audio transcription (send audio file as base64, receive transcript)
4. Claude API structuring (send transcript, parse JSON scope + tasks)
5. Review/edit UI (trade sections, swipe-to-delete, tap-to-edit)
6. Copy-to-clipboard export (formatted markdown output)

### Phase 2 — Meta Glasses (Days 15–30)
7. Meta Wearables DAT SDK integration (MWDATCore + MWDATCamera)
8. Photo capture from glasses camera stream
9. Bluetooth audio recording path
10. Voice-tag detection ("photo:", "measurement:", "note:")
11. Photo ↔ transcript timestamp correlation

### Phase 3 — Polish & Templates (Days 31–60)
12. PDF packet generation (scope + tasks + tagged photos)
13. Trade-specific Claude prompt templates
14. PM handoff email export
15. Prompt refinement pass (based on real job data)
16. SwiftData project history and persistence

### Phase 4 — Production (Days 61–90)
17. Field-use UI polish (large tap targets, one-hand operation)
18. Offline queue (transcribe offline, structure when online)
19. Buildertrend data field mappings
20. TestFlight distribution prep

---

## Key Technical Decisions

- **No Core Data** — migrate `Persistence.swift` to SwiftData as part of Feature 1
- **No WhisperKit** — Claude API handles both audio transcription and structuring in one call
- **Claude model**: `claude-sonnet-4-5` — send audio as base64, use JSON mode for structured output
- **Meta DAT SDK**: require the Meta AI app as bridge (document this clearly in onboarding)
- **API key storage**: Keychain only — never hardcode, never commit

---

## Dependencies

All via Swift Package Manager:

| Package | URL | Version |
|---|---|---|
| Meta Wearables DAT | `https://github.com/facebook/meta-wearables-dat-ios` | `>= 0.3.0` |
| SwiftAnthropic | `https://github.com/jamesrochabrun/SwiftAnthropic.git` | `>= 1.0.0` |

---

## Important Files to Read Before Touching Code

1. `ScopeSnap_iOS_MVP_Architecture.md` — before starting any feature
2. `README.md` — to find the current feature and update progress
3. The relevant existing Swift file(s) — before editing anything

Never modify a file without reading it first.
