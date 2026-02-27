Mark the current feature as complete and advance to the next one.

Steps:

1. Confirm the build is passing:
   ```
   xcodebuild -project Forge/Forge.xcodeproj -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -10
   ```
   If the build is broken, stop and fix it before marking anything complete.

2. Check off the current feature in `README.md` under `## Implementation Progress`.

3. Commit the completed feature:
   ```
   git add -A
   git commit -m "feat: <feature name> — complete"
   ```

4. Read `README.md` and identify the **next unchecked feature**.

5. Print a summary:
   - ✅ What was just completed
   - 🔜 What comes next
   - 📋 Remaining feature count

6. Ask: "Start building the next feature now?" and wait for the go-ahead.
