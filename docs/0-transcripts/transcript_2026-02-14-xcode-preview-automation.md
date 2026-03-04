# Transcript: Xcode Preview Automation Loop and AgentListView Crash Fix

**Date:** 2026-02-14
**Sessions:** 3a8230ff → 200ad6b9 → 8f6f2f11
**Topic:** Automated Xcode preview feedback loop design and NSOutlineView crash fix

---

## Background

The ADR-006 work (session 9c98c3e8) fixed a `NavigationSplitView` + `NSOutlineView` crash in `ProjectContentView` and added `#Preview` blocks to all 18 views. But `AgentListView` had a second, independent crash that persisted: `fatalError` in `OutlineListCoordinator.outlineView(_:child:ofItem:)` inside SwiftUI's `TableViewListCore_Mac2.swift:5170`.

---

## Phase 1: Initial Fix Attempts

[C] Root cause of the AgentListView crash: the preview creates `Jake` and `ServitorSpawner` with `LiveMessenger` (default). `AgentListViewModel.init` calls `refreshItems()` internally, and the preview also called it explicitly — the `@Published` property fires twice, causing the NSOutlineView data source to diff against a changing data source during window ordering.

[C] Proposed fix: pass `MockMessenger` to prevent any real SDK initialization, and remove the redundant `refreshItems()` call.

[U] *(Approved plan — session 3a8230ff. The fix was implemented but the crash persisted.)*

[T] *The crash root is deeper than the redundant refresh. `NSOutlineView` (backing `.sidebar`-style `List`) crashes during initial window ordering when items are already populated at construction time. The fix must prevent ObservableObject interaction during initial layout — not just reduce redundant refreshes.*

---

## Phase 2: Designing the Automated Testing Loop

[U] Let's tweak our plan file, and then you'll need to exit plan mode again to continue working.

How can you develop a testing loop where you modify code and then can check Xcode directly for issues? If there are issues, then you want to create a new diagnostic report to evaluate for the next cycle.

I can walk you through the Xcode steps too, in detail, so you know better what to automate. You may take over the screen for this, we can treat it as part of the Grade 3 and 4 testing techniques.

[C] Good idea. Let me understand what's available for automating the Xcode preview feedback loop first. Please describe the steps.

[U] You make code changes, then I switch apps to Xcode. There's a canvas on the right of the editor for previews. I click the resume/refresh button on the right side of a pillbox that says "Cannot preview this file — Tavern may have crashed."

After I refresh, there's a spinner in the middle of the canvas, until the pillbox returns, indicating there are still issues. Left of the refresh button is a diagnose button — it looks like a stethoscope — it opens a modal dialog box for diagnostics. On the lower left of the box, there's a button "generate report." When you press that, it spins for a while, and then opens up Finder to `/private/var/folders/ds/nj6jw9xn0373m586yf1lbp_40000gn/T` and selects the folder for diagnostics it just created. That's the same folder I would tell you about when reporting that an error still persists.

[C] Got it. So the loop is:

1. I edit code
2. You switch to Xcode, click Resume on the canvas pillbox
3. Spinner runs → either preview renders (success) or pillbox returns (crash)
4. If crash: stethoscope → Generate Report → you give me the path

[T] *The key bottleneck is the manual Xcode interaction. We can use AppleScript via `osascript` to drive Xcode's UI — activate, trigger Resume. That's Grade 4 territory (steals focus), which the user has consented to for this session.*

*Better yet: crash reports land in `~/Library/Logs/DiagnosticReports/Tavern-*.ips` automatically, no need for the full diagnostics generation loop just to detect a crash. We can use that as the fast feedback signal.*

[C] Key finding from researching Xcode automation: **Cmd+Option+P** is the reliable way to trigger preview resume — no fragile UI element hunting needed.

The full automated loop:

```bash
# Step 1: Record baseline crash report count
BEFORE=$(ls ~/Library/Logs/DiagnosticReports/Tavern-*.ips 2>/dev/null | wc -l)

# Step 2: Activate Xcode and trigger preview resume (Cmd+Opt+P)
osascript -e 'tell application "Xcode" to activate' \
  -e 'delay 0.5' \
  -e 'tell application "System Events" to keystroke "p" using {command down, option down}'

# Step 3: Wait for preview to build + render (or crash)
sleep 15

# Step 4: Check for new crash reports
AFTER=$(ls ~/Library/Logs/DiagnosticReports/Tavern-*.ips 2>/dev/null | wc -l)
if [ "$AFTER" -gt "$BEFORE" ]; then
    echo "CRASH DETECTED"
    ls -t ~/Library/Logs/DiagnosticReports/Tavern-*.ips | head -1
else
    echo "NO CRASH — preview likely succeeded"
fi
```

[T] *This is a Grade 4 technique: steals focus. The DiagnosticReports auto-creation pattern eliminates needing the stethoscope/Generate Report UI flow — crashes create `.ips` files automatically, detectable via mtime/count.*

---

## Phase 3: Systematic Fix Strategy

[C] With the automated loop established, ran systematic attempts against theories about the NSOutlineView crash:

**Attempt 3: Minimal static preview (no ViewModel)**
Theory: any `@ObservedObject`/`@StateObject` with `@Published` properties triggers `objectWillChange` during `NSOutlineView` initial layout. Eliminate the ViewModel entirely.

Result: **No crash.** Confirmed the crash is tied to ObservableObject interaction, not to `.sidebar` + `List` + `ForEach` itself.

**Attempt 5: Real ViewModel, `.plain` list style in preview**
Theory: only `.sidebar` (which uses `NSOutlineView`) triggers the crash; `.plain` might not.

Result: **Still crashes.** On macOS, `.plain` also uses `NSOutlineView` — same crash.

**Attempt 6: `List(data)` form instead of `List { ForEach(data) }`**
Theory: the direct `List(data)` initializer uses a simpler data source path.

Result: **Still crashes.** `List(data)` still routes through the same `OutlineListCoordinator`.

**`AgentListRow` with static `AgentListItem` values**
Theory: use the real row component with static data to get accurate visual rendering.

Result: **Still crashes.** `AgentListRow` contains `@State` for hover tracking; `StateIndicator` has `@State` + animations. Even static data + `@State` triggers the NSOutlineView inconsistency.

**Final solution: Pure inline static views**
Return to Attempt 3's approach — completely inline `HStack`/`VStack` views with no `@State`, no `@ObservableObject`, no `@StateObject`. Hardcode the visual appearance.

Result: **No crash. Preview renders correctly.**

[T] *The invariant: any SwiftUI property wrapper (`@State`, `@ObservedObject`, `@StateObject`, `@Published`) triggers `objectWillChange` notifications during `NSOutlineView`'s initial layout pass, causing the data source inconsistency. The only reliable fix is no Swift property wrappers in the preview at all — completely static, value-typed views.*

---

___

[S] **Xcode Preview Automation Loop (Grade 4 Pattern)**

When iterating on SwiftUI preview crashes, use this automation loop instead of manually driving Xcode:

```bash
BEFORE=$(ls ~/Library/Logs/DiagnosticReports/Tavern-*.ips 2>/dev/null | wc -l)
osascript -e 'tell application "Xcode" to activate' \
  -e 'delay 0.5' \
  -e 'tell application "System Events" to keystroke "p" using {command down, option down}'
sleep 15
AFTER=$(ls ~/Library/Logs/DiagnosticReports/Tavern-*.ips 2>/dev/null | wc -l)
[ "$AFTER" -gt "$BEFORE" ] && echo "CRASH" || echo "OK"
```

**Cmd+Option+P** = Resume preview (keyboard shortcut, no UI element hunting). **DiagnosticReports** auto-creates `.ips` files on crash — no need to trigger the stethoscope/Generate Report UI flow. This steals focus (Grade 4), so obtain user consent before running it in non-debug sessions.

**NSOutlineView Preview Invariant**

On macOS, any SwiftUI `List` (regardless of `.sidebar`, `.plain`, or other styles) uses `NSOutlineView` internally. Any property wrapper (`@State`, `@ObservedObject`, `@StateObject`, `@Published`) in preview views triggers `objectWillChange` notifications during `NSOutlineView`'s initial layout pass, causing data source inconsistency and the `OutlineListCoordinator.outlineView(_:child:ofItem:)` crash.

**The only reliable fix for `AgentListView` and similar views:** inline pure static `HStack`/`VStack` views in the `#Preview` block with no property wrappers. The preview shows accurate visual appearance; the ViewModel is tested separately via ViewInspector.

**The `NavigationSplitView` crash** (covered in ADR-006 / transcript_2026-02-13-preview-requirements.md) is a separate bug — `HSplitView` workaround applies there. The `NSOutlineView` + `@State` crash is distinct and requires static-only previews.
