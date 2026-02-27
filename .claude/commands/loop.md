Start or resume the Ralph Wiggum Agentic Loop for ScopeSnap.

Follow these steps exactly, in order, without skipping:

1. Read `README.md` and find the **first unchecked item** under `## Implementation Progress`. That is the current feature.

2. Read `ScopeSnap_iOS_MVP_Architecture.md` for the full spec of that feature.

3. Read every existing Swift source file that is relevant to the feature before writing any code.

4. **Build the feature** — write clean, production-quality Swift. No stubs, no TODOs, no placeholder logic. Follow the architecture doc exactly.

5. **Test the feature** — run:
   ```
   xcodebuild -project Forge/Forge.xcodeproj -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -20
   ```
   If the build fails, fix all errors before continuing. Do not proceed with a broken build.

6. If the project has unit tests relevant to the feature, run them:
   ```
   xcodebuild -project Forge/Forge.xcodeproj -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test 2>&1 | tail -30
   ```

7. **Update `README.md`** — check off the completed feature in `## Implementation Progress` and add a short note if useful.

8. **Commit**:
   ```
   git add -A
   git commit -m "feat: <feature name>"
   ```

9. Report what was built, what was tested, and what the next feature in the queue is.

10. Ask: "Ready to continue to the next feature?" — then wait for confirmation before looping.
