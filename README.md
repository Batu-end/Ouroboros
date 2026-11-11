<p align="center">
  <img src="Resources/AppIcon-preview.png" width="160" alt="Ouroboros app icon">
</p>

# Ouroboros

A macOS menu bar focus timer that earns your breaks instead of scheduling them.

Pomodoro assumes you can start and stop on command. Ouroboros assumes you can't. You work as
long as the focus holds; the moment it breaks you hit one button, and the app pays you back
**15% of the time you actually worked** as break time. Work feeds break feeds work — a loop that
closes on itself. No Dock icon, no windows, no streaks to lose.

## The loop

| Phase | Menu bar | Primary button |
| --- | --- | --- |
| Idle | `⟳` | Start Working |
| Working | `💼 14:25` (counting up) | **I'm Distracted — Take Break** |
| On break | `☕ 02:45` (counting down) | Resume Work Early |

- `EarnedBreak = WorkedSeconds × 0.15`, with a hard floor of **60 seconds** — a two-minute work
  block still buys a real minute off, so there is never a reason to push through.
- When the countdown hits zero you get a soft chime and a banner, and the app drops you straight
  back into Working. The loop never leaves you stranded at a dead stop.
- Today's loops are logged with totals and the break ratio you actually realized.

## Build and run

```bash
./build.sh --run
```

That compiles in release mode, assembles `Ouroboros.app` next to the sources, ad-hoc signs it, and
launches it. Look at the right side of your menu bar — there is deliberately no Dock icon and no
window.

To keep it:

```bash
mv Ouroboros.app /Applications/
```

Then add it under **System Settings → General → Login Items & Extensions → Open at Login** if you
want it on every boot.

Tests:

```bash
swift test
```

Covers the 15% math, the 60-second floor, clock formatting, every phase transition, and a full
work → break-expiry → work loop (driven at 600× speed).

### Fast mode

```bash
OUROBOROS_FAST=1 ./Ouroboros.app/Contents/MacOS/Ouroboros
```

One real second counts as a minute, so you can watch an entire loop — including the break-over
chime — in a few seconds.

## No Dock icon: the `LSUIElement` key

This is the one setting that turns a normal app into a menu bar app. `build.sh` writes it from
[`Resources/Info.plist`](Resources/Info.plist):

```xml
<key>LSUIElement</key>
<true/>
```

**If you build this in Xcode instead** (File → New → Project → macOS → App, SwiftUI lifecycle,
then drop `Sources/` in):

1. Select the project in the navigator, pick the app **target**, open the **Info** tab.
2. Hover any row, click **+**, and start typing `Application is agent` — Xcode autocompletes to
   the key `LSUIElement`.
3. Set its value to **YES**.

Equivalent route if your target has no Info tab: **Build Settings → Info.plist Values →
"Application is agent (UIElement)" → Yes**, or add `INFOPLIST_KEY_LSUIElement = YES` to the target's
build settings.

Verify it took effect — with the app running:

```bash
lsappinfo info -only ApplicationType "$(pgrep -x Ouroboros)"
```

`"ApplicationType"="UIElement"` means it is a true agent: menu bar only, no Dock tile, no app menu
(quit from the ⏻ button inside the popover, or ⌘Q while it's open).

## Architecture

```
Sources/OuroborosKit/
  Core/BreakMath.swift          pure rules: 15% ratio, 60s floor, formatting  (unit tested)
  Core/AppPhase.swift           idle / working(since:) / onBreak(start:duration:worked:)
  Core/TimerEngine.swift        the only mutable state: phase machine + 5Hz tick + log
  Core/SessionStore.swift       Codable sessions in UserDefaults, 60-day window
  Core/NotificationManager.swift best-effort banner, always-on chime
  UI/…                          popover dashboard, ring, buttons, log
Sources/Ouroboros/main.swift    entry point
```

Two deliberate choices:

- **Absolute time anchors, never counters.** Each phase stores a `Date`; elapsed and remaining are
  recomputed from the clock on every tick. Sleep the lid, drop a timer tick, change nothing — the
  numbers stay honest.
- **The working ring sweeps once a minute** rather than filling toward a target. Work here is
  open-ended; a progress bar toward an invented deadline would be a lie. The caption shows what
  matters instead: how much break you have banked so far.

Pure SwiftUI + Combine + UserNotifications. No dependencies. macOS 14+.

## Icon

`Resources/AppIcon.icns` is generated, not hand-drawn:

```bash
swift Tools/MakeIcon.swift path/to/line-art.jpg
```

[`Tools/MakeIcon.swift`](Tools/MakeIcon.swift) keys the flat background out of a piece of dark
linework by luminance, crops to the ink, recolors it, and composites it onto a dark rounded-square
plate with a teal halo — then emits every size from 16px to 1024px via `iconutil`. Point it at any
other line drawing to reskin the app.

Since the app is an agent (`LSUIElement`), this icon never appears in the Dock; it shows up in
Finder, Spotlight and notification banners.

> **Attribution:** the ouroboros engraving this icon is derived from came from a blog post and its
> rights holder is unverified. Swap in your own artwork before using this anywhere public.
