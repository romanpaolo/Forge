  To run it right now (free)

  Just open Xcode and hit Run on the simulator — everything builds. No
  accounts needed. The glasses features won't work but you can test the
  full iPhone-only flow.

  ---
  To run on your actual iPhone

  1. Apple Developer account — $99/year at https://developer.apple.com.
  Required for device testing.
  2. Set your signing team in Xcode — open Forge.xcodeproj, go to the
  Forge target → Signing & Capabilities → select your team. Xcode handles
  the rest.
  3. Add your Claude API key — once the app is on your phone, tap the gear
   icon and paste your key from https://console.anthropic.com.

  ---
  To use the Ray-Ban Meta glasses

  4. Meta Developer account (free) — register at
  https://developers.facebook.com, create an app, and get your real App
  ID.
  5. Replace the placeholder App ID — Forge/Info.plist line 38 currently
  has MetaAppID: 0. Swap in your real ID.
  6. Install the Meta AI app on your iPhone and pair your glasses to it.
  ScopeSnap bridges through it.

  ---
  To ship on TestFlight

  7. App Store Connect — comes with the Apple Developer account. Create a
  new app record with a unique bundle ID (change it from whatever it
  currently is in Xcode).
  8. Archive and upload — in Xcode: Product → Archive → Distribute →
  TestFlight. Takes ~10 min.
  9. Invite testers — in App Store Connect, add emails to your TestFlight
  group.

  ---
  Checklist summary

  ┌───────────────────────┬────────────────────────┬──────────────────┐
  │        Action         │          Cost          │  Blocking what   │
  ├───────────────────────┼────────────────────────┼──────────────────┤
  │ Open in Xcode, run    │ Free                   │ Nothing          │
  │ simulator             │                        │                  │
  ├───────────────────────┼────────────────────────┼──────────────────┤
  │ Apple Developer       │ $99/yr                 │ Device +         │
  │ Program               │                        │ TestFlight       │
  ├───────────────────────┼────────────────────────┼──────────────────┤
  │ Claude API key        │ Pay-per-use            │ Core app         │
  │                       │ (~$0.05–0.10/walk)     │ functionality    │
  ├───────────────────────┼────────────────────────┼──────────────────┤
  │ Meta Developer        │ Free                   │ Glasses features │
  │ account + App ID      │                        │                  │
  ├───────────────────────┼────────────────────────┼──────────────────┤
  │ Meta AI app on iPhone │ ~$299 glasses          │ Glasses features │
  │  + paired glasses     │                        │                  │
  ├───────────────────────┼────────────────────────┼──────────────────┤
  │ Unique bundle ID +    │ Free (with Dev         │                  │
  │ App Store Connect app │ account)               │ TestFlight       │
  │  record               │                        │                  │
  └───────────────────────┴────────────────────────┴──────────────────┘

  The fastest path to a real field test is: Apple Developer account → sign
   the app → add your Claude key → run on iPhone. That gives you the full
  iPhone-only flow (record, transcribe, structure, export) without needing
   the glasses at all.

