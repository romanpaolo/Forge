# ScopeSnap

**One job walk → zero typing → usable job data in Buildertrend.**

ScopeSnap is an iOS companion app for Ray-Ban Meta glasses that replaces the fragmented workflow of Meta Glasses → Otter.ai → ChatGPT → Buildertrend with a single, seamless pipeline: record a job walk, send the audio to Claude, get back a structured scope document and trade task list — ready to export.

---

## Implementation Progress

> Claude Code updates this section automatically via the Ralph Wiggum Loop (`/loop`).
> Check off items here as each feature is built and tested.

### Phase 1 — PoC, iPhone-only (Days 1–14)
- [x] Project creation UI (new project, name + address) — SwiftData models, ProjectListView, NewProjectView, ProjectDetailView
- [x] AVAudioEngine recording (start/stop, save audio file to disk) — CaptureModule (@Observable), AAC .m4a to Documents/Recordings/, mic permission in Info.plist
- [x] Claude audio transcription (send audio file, receive transcript) — ProcessModule (URLSession, base64 AAC → Claude Sonnet), KeychainHelper, APIKeySettingsView, per-recording Transcribe button
- [x] Claude API structuring (send transcript, parse JSON scope + tasks) — ProcessModule.structure(), StructuredScope value type, scopeSection in ProjectDetailView, PacketRow with status badge
- [x] Review/edit UI (trade sections, swipe-to-delete, tap-to-edit, amber questions) — ScopeReviewView, TaskRow, EditTaskSheet, per-item + bulk approval, status badge
- [x] Copy-to-clipboard export (formatted markdown output) — ExportModule, share sheet via UIActivityViewController

### Phase 2 — Meta Glasses (Days 15–30)
- [x] Meta Wearables DAT SDK integration (MWDATCore + MWDATCamera) — WearablesManager (@Observable), registration flow, device discovery, GlassesSetupView, status icon in ProjectListView
- [x] Photo capture from glasses camera stream — StreamSession + AutoDeviceSelector, photoDataPublisher, capturePhoto() button during recording, photo thumbnails in RecordingRow
- [x] Bluetooth audio recording path — AVAudioSession .playAndRecord + .allowBluetooth in CaptureModule
- [x] Voice-tag detection ("photo:", "measurement:", "note:") — VoiceTagDetector.detect(in:), parses trigger phrases with content extraction
- [x] Photo ↔ transcript timestamp correlation — VoiceTagDetector.correlate(), sequential matching after transcription

### Phase 3 — Polish & Templates (Days 31–60)
- [x] PDF packet generation (scope + tasks + tagged photos) — PDFGenerator using UIGraphicsPDFRenderer, letter-size with selectable text, export via share sheet in ScopeReviewView
- [x] Trade-specific Claude prompt templates (baths, kitchens, ADUs, decks, additions) — ProjectType enum on Project model, per-type guidance injected into structuring prompt, type picker in NewProjectView
- [x] PM handoff email export — ScopeReviewView "Share as Markdown" + "Export as PDF" menu items feed UIActivityViewController (Mail, AirDrop, etc.)
- [x] Prompt refinement pass (based on real job data) — improved transcription and structuring prompts; model updated to claude-sonnet-4-6; task descriptions now must be bid-ready
- [x] SwiftData project history and persistence — ProjectListView shows recording count, packet count, and project type icon per project

### Phase 4 — Production (Days 61–90)
- [ ] Field-use UI polish (large tap targets, one-hand operation)
- [ ] Offline queue (record without connectivity, process when online)
- [ ] Buildertrend data field mappings
- [ ] TestFlight distribution prep

---

## Why ScopeSnap

Field estimators and PMs currently piece together job-walk notes across multiple tools. ScopeSnap collapses that into one app: walk a job, talk through what you see, and come out with an AI-structured scope document organized by area and trade — without typing a single word.

---

## Architecture

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
│  │  Capture    │  │  Process     │  │  Review &  │ │
│  │  Module     │  │  Module      │  │  Export    │ │
│  │             │  │              │  │            │ │
│  │ • Meta DAT  │  │ • Claude API │  │ • Edit UI  │ │
│  │   camera    │──▶│   transcribe │──▶│ • Approve  │ │
│  │ • BT audio  │  │   + structure│  │ • PDF gen  │ │
│  │ • iPhone    │  │   (one call) │  │ • Clipboard│ │
│  │   fallback  │  │              │  │ • Email    │ │
│  └─────────────┘  └──────────────┘  └────────────┘ │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │              SwiftData Layer                  │   │
│  │  Project → Recording → Transcript → Packet   │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| **UI** | SwiftUI (iOS 17+) | Native, declarative, fast iteration |
| **Glasses Integration** | Meta Wearables DAT SDK (`MWDATCore` + `MWDATCamera`) | Official SDK via SPM — camera + mic access from Ray-Ban Meta |
| **Transcription + AI Structuring** | Claude API via SwiftAnthropic | Single API call handles both transcription and scope extraction — simpler stack, no on-device ML model |
| **Persistence** | SwiftData | Native Apple, zero config, project-based storage |
| **Export** | UIActivityViewController + PDF generation | Clipboard copy, share sheet, PDF packet |
| **Package Management** | Swift Package Manager | All dependencies are SPM-native |

---

## How the Process Module Works

Rather than running a separate on-device transcription model, ScopeSnap sends the recorded audio file directly to Claude. Claude handles both transcription and structuring in a single API call, returning a JSON response with the scope summary and trade task list.

```swift
// One Claude call — audio in, structured scope out
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

This removes the WhisperKit dependency entirely — no CoreML model to download, no Neural Engine requirement, and no two-step pipeline to maintain.

**Tradeoff:** Audio is sent to Anthropic's API rather than staying on-device. For a construction scope app this is an acceptable tradeoff; for stricter privacy requirements, on-device transcription could be reintroduced later.

---

## Features

**Capture**
- Stream live video and capture photos from Ray-Ban Meta glasses via the Meta Wearables DAT SDK
- Record job-walk audio over Bluetooth from the glasses' 5-mic array
- Voice-tag detection — say "photo:", "measurement:", or "note:" to auto-associate the nearest photo capture with a transcript segment
- iPhone fallback path (`AVAudioEngine` + standard camera) for use without glasses

**Process**
- Audio sent to Claude API — transcription and scope structuring happen in a single call
- Claude returns a Scope + Questions document (organized by area) and a trade task list (organized by trade)
- Questions and uncertainties are automatically flagged — Claude is instructed never to guess

**Review & Export**
- SwiftUI review screen with sections by trade; swipe to delete, tap to edit
- Amber highlighting for flagged questions
- Per-item or bulk approval
- Export as: formatted clipboard text, PDF packet (scope + tasks + tagged photos), or email to PM

---

## Data Model

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
    var voiceTag: String?        // e.g. "kitchen sink wall"
    var timestamp: TimeInterval  // offset within recording
}

@Model class ScopePacket {
    var scopeSummary: String     // Scope + Questions doc
    var tasksByTrade: [TradeTask]
    var status: PacketStatus     // .draft, .approved, .exported
    var generatedAt: Date
}

@Model class TradeTask {
    var trade: String            // "plumbing", "demo", "tile", etc.
    var description: String
    var isQuestion: Bool         // flagged uncertainty
    var isApproved: Bool
}
```

---

## Getting Started

### Requirements

- Xcode 16+
- iOS 17+ device
- [Meta AI app](https://ai.meta.com/) installed on the same device (required bridge for glasses)
- Ray-Ban Meta glasses (optional for PoC — iPhone fallback available)
- Claude API key ([get one at console.anthropic.com](https://console.anthropic.com))
- Apple Developer account ($99/year) for device testing and TestFlight

### Installation

1. Clone the repo:
   ```bash
   git clone https://github.com/your-org/scopesnap.git
   cd scopesnap
   ```

2. Open the project in Xcode:
   ```bash
   open Forge/Forge.xcodeproj
   ```

3. Swift Package Manager will resolve dependencies on first open:
   - `meta-wearables-dat-ios` — Meta glasses SDK
   - `SwiftAnthropic` — Claude API Swift wrapper

4. Add your Claude API key. Store it in the Keychain and surface it via a settings screen — never hardcode it or commit it to source control.

5. Select your target device and run.

### Meta Glasses Setup

1. Install the Meta AI app and pair your Ray-Ban Meta glasses.
2. On first launch, ScopeSnap will prompt you to register via the Meta AI bridge. Tap **Register** and follow the OAuth flow.
3. Once registered, the app will discover your glasses automatically when they are nearby.

> The **Mock Device Kit** bundled in the Meta DAT SDK lets you develop and test the glasses integration without physical hardware.

---

## Dependencies & Costs

| Dependency | Cost | Notes |
|---|---|---|
| Apple Developer Account | $99/year | Required for TestFlight + device testing |
| Meta Developer Account | Free | Required for DAT SDK access |
| Ray-Ban Meta Glasses | ~$299 | |
| Claude API (Sonnet) | ~$3/1M input tokens | ~$0.05–0.10 per job walk (audio + text tokens) |
| SwiftAnthropic SDK | Free (MIT) | Community Swift wrapper |
| Meta Wearables DAT SDK | Free (preview) | Publishing limited to select partners during preview |

**Estimated API cost per job walk:** A 30-minute recording processed via Claude's audio API runs roughly $0.05–$0.10 per walk — still negligible at field scale.

---

## Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/facebook/meta-wearables-dat-ios", from: "0.3.0"),
    .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "1.0.0"),
]
```

---

## Roadmap

### Days 1–14 — PoC (iPhone-only)
Validate the core value prop without glasses complexity.

- SwiftUI app shell with project creation
- `AVAudioEngine` recording + standard camera capture
- Claude API for audio transcription + scope structuring (single call)
- Basic review/edit UI with trade sections
- Copy-to-clipboard export
- **Goal: test on 2–3 real job walks**

### Days 15–30 — Add Meta Glasses
- Integrate Meta Wearables DAT SDK (`MWDATCore` + `MWDATCamera`)
- Photo capture from glasses camera stream
- Bluetooth audio recording path
- Voice-tag detection and photo ↔ transcript timestamp correlation
- **Goal: test on 3 more job walks with glasses**

### Days 31–60 — Polish & Templates
- PDF packet generation (scope + tasks + tagged photos)
- Trade-specific Claude prompt templates (bathrooms, kitchens, ADUs, decks, additions)
- PM handoff email/export
- Prompt refinement based on real job data
- SwiftData project history and persistence
- **Goal: 5+ job walks, measure time savings**

### Days 61–90 — Production & Buildertrend Prep
- UI/UX polish for field use (large tap targets, one-hand operation)
- Offline queue — record without connectivity, process when back online
- Buildertrend data field mappings
- Begin Buildertrend Marketplace partnership process
- TestFlight distribution
- **Goal: 10+ completed job walks, 20+ min saved per walk**

---

## Technical Notes

- **Meta DAT SDK requires the Meta AI app** as a bridge. Users must have it installed and their glasses paired before launching ScopeSnap.
- **Claude handles both transcription and structuring** in a single API call — no on-device ML model required, no two-step pipeline.
- **Meta DAT camera** streams at up to 720p/30fps over Bluetooth; still photos are 12MP — both sufficient for construction documentation.
- **Claude JSON mode** is used for all structuring requests to ensure reliable parsing of scope documents and task lists.
- **SwiftData** handles all local persistence with no Core Data boilerplate.
- **Internet required for processing** — audio is sent to Anthropic's API. An offline queue (Phase 4) will buffer recordings for processing when connectivity returns.

---

## License

MIT
