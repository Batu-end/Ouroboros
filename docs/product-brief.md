# Ouroboros — product brief

Source material for writing a README, landing page, or launch post. Everything here is factual; nothing has been marketed yet.

Repo: https://github.com/Batu-end/Ouroboros (public) · macOS 14+ · Swift 6 / SwiftUI · ~1,440 lines · no dependencies

---

## What it is

A macOS menu bar focus timer that **earns** breaks instead of scheduling them. You work as long as your focus holds; when it breaks, you press one button and the app pays you back a percentage of the time you actually worked.

No Dock icon, no windows, no account, no sync. The status bar item and a popover are the entire app.

## The core mechanic

```
EarnedBreak = WorkedSeconds × ratio      (floor: 60 seconds)
```

Default ratio is **15%** — one hour of work earns nine minutes of break. Selectable: Low 12%, Standard 15%, High 25%.

The 60-second floor matters: a two-minute work block still buys a real minute off, so there is never a reason to push through.

## The four states

| State | Menu bar | What's counting |
| --- | --- | --- |
| Idle | `infinity` | nothing |
| Working | `infinity.circle.fill` + time counting **up**, teal | work |
| On break | `cup.and.saucer.fill` + time counting **down**, amber | break |
| Waiting | `hourglass` + how long it has waited, violet | **nothing** |

The loop: Working → (you press "I'm Distracted — Take Break") → On break → (countdown ends) → Waiting → (you click) → Working.

## Who it's for

Built by and for someone with ADHD. The design target is the specific failure mode where a timer makes things worse: you can't start on command, you can't stop on command, and a rigid 25/5 split punishes you for both.

Not positioned as a medical or clinical tool. It's a timer with different assumptions.

## How it differs from Pomodoro

| Pomodoro | Ouroboros |
| --- | --- |
| Fixed 25 minutes of work | Work as long as focus holds — open-ended |
| Breaks are scheduled | Breaks are earned, proportional to real work |
| Stopping early = failure, broken streak | Stopping early is the main button, and it pays you |
| Progress bar toward a deadline | No invented deadline; the ring sweeps once a minute |
| Streaks, scores, gamification | None. No streaks to lose |

The reframe worth leading with: **the "I give up" button is the primary action, and pressing it is rewarded.** Most timers make quitting feel like failing. Here it's the mechanism.

## Design decisions worth naming (each has a reason)

- **The primary button is the exit, not the start.** Biggest, most visible control in the app is "I'm Distracted — Take Break."
- **Work has no progress bar.** Work is open-ended, so a bar filling toward an invented target would be a lie. The ring sweeps once per minute for motion; the caption shows the honest number — how much break you've banked so far.
- **Break ring depletes across the whole break**, one full circle, so "how much is left" is readable at a glance.
- **Colour marks the psychological boundary**: teal (work) → amber (rest) → violet (waiting). The whole popover carries a wash of the phase colour, so the mode registers before you read anything.
- **The app never invents time.** After a break ends, it waits — counting nothing — until you click. If the break ran out while you were away from the desk, that time lands in no column. The log stays true at the cost of a gap when you walk away.
- **Crashes don't cost you an hour.** State is written on every transition with a 15-second heartbeat. Relaunch within 90 seconds and the timer picks up exactly where it was; after a reboot the block is closed at the last heartbeat — dead time is neither counted as work nor silently discarded.
- **A pulse every 10 minutes** of work. Small, cheap acknowledgement during long stretches.
- **Starting a break is silent**; ending one plays a soft chime (`Purr`) plus a time-sensitive banner and a panel that stays on screen until answered. Stopping work should feel like relief, not an event that announces itself.

## Technical facts (credible, verifiable claims)

- Pure SwiftUI + Combine + UserNotifications. **Zero third-party dependencies.**
- Measured **0.0% CPU idle, ~1.3% with a timer running** and the popover closed.
  - Worth a line on its own: `MenuBarExtra` keeps its popover content alive after closing, so an animated `TimelineView` inside it redraws at display rate forever — this cost 50% of a core until it was gated on actual window visibility. Most menu bar apps with animation have some version of this bug.
- Timer uses absolute date anchors, not counters, so sleep/wake and dropped ticks can't make it drift. It resyncs on wake.
- 39 tests, including rendering the ring to pixels and asserting on them.
- `LSUIElement` agent app: verified no Dock tile, no app switcher entry.
- Session history in `UserDefaults`, 60-day rolling window. **Nothing leaves the machine.** No network code at all.

## What's in the UI

Popover (~300pt wide, native materials): phase badge, timer ring with readout, one large primary action, quiet secondary actions (Skip Break / End Session), and today's log — every closed cycle (a work block plus the break that followed it) with work time, break time, daily totals and the break ratio you actually realized.

Settings are one gear with one choice: break generosity.

## Current state — be honest about this

- **Not signed or notarized.** Users build it from source (`./build.sh --run`) or get a Gatekeeper warning. No installer, no Homebrew cask, no release binary yet.
- **No LICENSE file.** Needs one before promoting it.
- **The app icon is derived from an engraving found on a blog**; the rights holder is unverified. Should be replaced before any public push.
- No sync, no iOS app, no export, no reports beyond today, no custom ratio number (three levels only), no idle detection, no app/website blocking.
- Untested beyond the author's own machine (Apple silicon, macOS 26).

## Tone notes

The app's own voice is plain, unsentimental, slightly dry: "nothing is counting", "break over", "banked 2:10 break". No exclamation marks, no coaching, no "You've got this!". Marketing copy that's hype-heavy would clash with the product.

The name is the mechanic: work feeds break feeds work, a loop that closes on itself.

## Open questions for positioning

1. Lead with the ADHD angle, or with "Pomodoro is wrong for open-ended work" (wider audience, same product)?
2. Free open-source project, or a paid Mac app with a signed build?
3. Is "earned breaks" or "the quit button that pays you" the stronger hook?
