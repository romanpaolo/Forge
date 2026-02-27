 # ScopeSnap iOS MVP — Rewritten Architecture & Fastest PoC

## Core Promise (Unchanged)
**One job walk → zero typing → usable job data in Buildertrend.**

Replace: Meta Glasses → Otter.ai → ChatGPT → Buildertrend
With: Meta Glasses → ScopeSnap iOS → Buildertrend

---

## Tech Stack (Fastest PoC)

| Layer | Technology | Why |
|---|---|---|
| **UI** | SwiftUI (iOS 17+) | Native, fast iteration, declarative |
| **Glasses Integration** | [Meta Wearables DAT SDK](https://github.com/facebook/meta-wearables-dat-ios) (`MWDATCore` + `MWDATCamera`) | Official SDK, Swift Package Manager, camera + mic access from Ray-Ban Meta |
| **Transcription + AI Structuring** | [Claude API](https://docs.anthropic.com/en/docs) via [SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic) | Single API call handles audio transcription and scope extraction — no on-device ML model required |
| **Persistence** | SwiftData | Native Apple, zero config, project-based storage |
| **Export** | UIActivityViewController + PDF generation | Copy-to-clipboard, share sheet, PDF packet |
| **Package Management** | Swift Package Manager | All dependencies (Meta DAT, SwiftAnthropic) are SPM-native |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  Ray-Ban Meta Glasses                │
│            (camera + 5-mic array + speakers)         │
└──────────────────────┬──────────────────────────────┘
                       │ Bluetooth (via Meta AI app bridge)
                       ▼
┌─────────────────────────────────────────────────────┐
│              ScopeSnap iOS App                       │
│                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │  Capture     │  │  Process     │  │  Review &  │ │
│  │  Module      │  │  Module      │  │  Export    │ │
│  │             │  │              │  │            │ │
│  │ • Meta DAT  │  │ • Claude API │  │ • Edit UI  │ │
│  │   camera    │──▶│   transcribe │──▶│ • Approve  │ │
│  │ • BT audio  │  │   + structure│  │ • PDF gen  │ │
│  │ • iPhone    │  │   (one call) │  │ • Clipboard│ │
│  │   mic       │  │              │  │ • Email    │ │
│  │   fallback  │  │              │  │            │ │
│  └─────────────┘  └──────────────┘  └────────────┘ │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │              SwiftData Layer                  │   │
│  │  Project → Recording → Transcript → Packet   │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## Data Model (SwiftData)

```swift
@Model class Project {
    var name: String
    var address: String
    var createdAt: Date
    var recordings: [Recording]
    var packets: [ScopePacket]
}

@Model class Recording {
    var audioFileURL: URL
    var photos: [PhotoCapture]
    var transcript: String?
    var duration: TimeInterval
    var capturedAt: Date
}

@Model class PhotoCapture {
    var imageData: Data
    var voiceTag: String?        // "kitchen sink wall"
    var timestamp: TimeInterval  // offset in recording
}

@Model class ScopePacket {
    var scopeSummary: String     // Scope + Questions doc
    var tasksByTrade: [TradeTask]
    var status: PacketStatus     // .draft, .approved, .exported
    var generatedAt: Date
}

@Model class TradeTask {
    var trade: String            // "plumbing", "demo", "tile"
    var description: String
    var isQuestion: Bool         // flagged uncertainty
    var isApproved: Bool
}
```

---

## Module Breakdown

### 1. Capture Module

**Meta Glasses path (primary):**
```swift
import MWDATCore
import MWDATCamera

// Initialize on app launch
Wearables.configure()

// Register with Meta AI app
Wearables.shared.startRegistration()

// Start camera stream for photos
session.photoDataPublisher.listen { photoData in
    // Save photo with timestamp correlation to audio
}

// Capture voice-tagged photo
session.capturePhoto(format: .jpeg)
```

**iPhone fallback path:**
- `AVAudioEngine` for microphone recording
- Standard camera via `PhotosPicker` or `UIImagePickerController`

**Voice-tag detection** (runs during transcription):
- Pattern match on transcript for trigger phrases: "photo:", "measurement:", "note:"
- Associates nearest photo capture with the tag

### 2. Process Module

**Transcription + Structuring (Claude API, single call):**

Claude receives the audio file as base64 and returns a fully structured JSON response — no separate transcription step required.

```swift
import SwiftAnthropic

let service = AnthropicService(apiKey: keychainAPIKey)

// Load audio file as base64
let audioData = try Data(contentsOf: recording.audioFileURL)
let audioBase64 = audioData.base64EncodedString()

let systemPrompt = """
You are a construction scope analyst. Listen to this job-walk recording
and produce TWO outputs in JSON:

1. "transcript": Verbatim transcription of the audio.

2. "scope_summary": A one-page Scope + Questions document organized
   by area (kitchen, bathroom, exterior, etc.) with:
   - decisions_confirmed: [...]
   - open_questions: [...]
   - risks: [...]

3. "tasks_by_trade": Array of tasks organized by trade
   (demo, framing, plumbing, electrical, drywall, tile, paint, etc.)
   Each task has: trade, description, is_question (boolean).

CRITICAL: Never guess. If something is unclear, mark is_question: true.
"""

let message = try await service.createMessage(
    model: .claude_sonnet_4_5,
    messages: [
        .init(role: .user, content: [
            .init(type: .text, text: systemPrompt),
            .init(type: .document, source: .init(
                type: .base64,
                mediaType: "audio/mp4",
                data: audioBase64
            ))
        ])
    ],
    maxTokens: 4096
)
```

### 3. Review & Export Module

**Review UI:**
- SwiftUI `List` with sections by trade
- Swipe to delete tasks, tap to edit
- Questions highlighted in amber
- Toggle approval per item or approve all

**Export options:**
- **Copy to clipboard**: Formatted markdown of Scope + Questions
- **PDF packet**: Scope summary + task list + photos with tags
- **Share sheet**: Email to PM with PDF attached
- **Buildertrend-ready format**: Structured text matching BT's note/task fields

---

## Fastest PoC — What to Build First (Week 1–2)

Skip the Meta Glasses integration for the very first proof-of-concept. Here's the absolute fastest path to validating the core value prop:

### PoC Scope (2 weeks)
1. **iPhone-only recording** — `AVAudioEngine` captures job-walk audio
2. **Manual photo capture** — standard camera, manually tap to capture
3. **Claude API call** — send audio as base64, receive transcript + Scope + Questions + Tasks JSON in one response
4. **Basic review screen** — list of items, swipe to delete, tap to edit
5. **Copy to clipboard** — formatted output ready to paste into Buildertrend

### What this proves:
- Does the AI produce usable scope documents from real job-walk audio?
- Is the output quality better than your current Otter → ChatGPT flow?
- Do your PMs find the structured output useful?

### What this defers:
- Meta Glasses integration (add in Week 3–4)
- Voice-tagged photos (add in Week 3–4)
- PDF generation (add in Week 5–6)
- Buildertrend API integration (Phase 2)

---

## Revised 90-Day Roadmap

### Days 1–14: PoC (iPhone-only)
- SwiftUI app shell with project creation
- AVAudioEngine recording
- Claude API integration (audio → transcript + scope + tasks in one call)
- Claude prompt engineering for construction scope extraction
- Basic review/edit UI
- Copy-to-clipboard export
- **Test on 2–3 real job walks**

### Days 15–30: Add Meta Glasses
- Integrate Meta Wearables DAT SDK (MWDATCore + MWDATCamera)
- Camera photo capture from glasses
- Bluetooth audio recording path
- Voice-tag detection ("photo:", "measurement:")
- Photo ↔ transcript timestamp correlation
- **Test on 3 more job walks with glasses**

### Days 31–60: Polish & Templates
- PDF packet generation (Scope + Questions + photos)
- Trade-specific prompt templates (baths, kitchens, ADUs, decks, additions)
- PM handoff email/export feature
- Refine Claude prompts based on real job data
- SwiftData persistence and project history
- **Test on 5+ job walks, measure time savings**

### Days 61–90: Production & Buildertrend Prep
- Polish UI/UX for field use (large tap targets, one-hand operation)
- Offline queue for Claude API calls (transcribe offline, structure when online)
- Define Buildertrend data mappings
- Begin Buildertrend Marketplace partnership process
- App Store TestFlight distribution
- **Goal: 10+ completed job walks, 20+ min saved per walk**

---

## Dependencies & Costs

| Dependency | Cost | Notes |
|---|---|---|
| Apple Developer Account | $99/year | Required for TestFlight + device testing |
| Meta Developer Account | Free | Required for DAT SDK access |
| Ray-Ban Meta Glasses | ~$299 | You already have these |
| Claude API (Sonnet) | ~$3/1M input tokens | ~$0.05–0.10 per job walk (audio + text tokens) |
| SwiftAnthropic SDK | Free (MIT) | Community Swift wrapper |
| Meta Wearables DAT SDK | Free (preview) | Publishing limited to select partners during preview |

**Estimated API cost per job walk:** A 30-minute audio file processed via Claude's API (audio + structured output) runs roughly $0.05–0.10 per walk. Still negligible at field scale.

---

## Key Technical Notes

1. **Meta DAT SDK requires the Meta AI app** as a bridge between glasses and your app. Users must have it installed.
2. **Claude handles transcription and structuring in one call** — no on-device ML model, no CoreML dependency, no two-step pipeline.
3. **Internet required for processing** — audio is sent to Anthropic's API. An offline queue (Phase 4) buffers recordings and processes them when connectivity returns.
4. **Meta DAT camera streams at max 720p/30fps** over Bluetooth. Photos are 12MP. Both are sufficient for construction documentation.
5. **Mock Device Kit** lets you develop and test the glasses integration without physical hardware.
6. **Claude structured outputs** (JSON mode) ensure reliable parsing of scope documents and task lists.
7. **SwiftData** handles all local persistence with zero configuration — no Core Data boilerplate.

---

## Package.swift Dependencies

```swift
dependencies: [
    .package(url: "https://github.com/facebook/meta-wearables-dat-ios", from: "0.3.0"),
    .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "1.0.0"),
]
```

Both integrate cleanly via Swift Package Manager in a single Xcode project.
