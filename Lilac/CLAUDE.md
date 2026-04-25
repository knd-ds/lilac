# Proyecto Lilac — Claude Code Context

## What this is

Lilac is a personal iOS app that opens social media platforms inside a browser container and enforces a daily time limit per platform. When the timer expires, the app locks that platform for the rest of the day. It resets automatically at midnight.

The goal is self-imposed social media reduction — not parental controls, not a productivity suite. One user, one iPhone.

---

## Validated technical foundation

**WKWebView + SwiftUI works.** Instagram was tested on a real device (iPhone, iOS 18.7.7) using `UIViewRepresentable` wrapping `WKWebView`. Login succeeded and the feed loaded correctly inside the app container. This is the confirmed approach.

**Do not switch to SFSafariViewController.** It cannot be controlled programmatically (no timer overlay, no lock screen). WKWebView is the correct choice.

---

## Tech stack

- **Language:** Swift
- **UI framework:** SwiftUI
- **Web rendering:** WKWebView via `UIViewRepresentable`
- **Persistence:** UserDefaults (simple key-value for time remaining and lock state per platform)
- **Deployment target:** iOS 18.0 (must match physical device)
- **Distribution:** Personal device only, via Xcode direct install. No App Store.

---

## MVP scope

### Platforms in MVP
- Instagram only (validated and working)
- Twitter/X and Reddit are planned but out of scope for MVP

### Core behavior

1. User opens the app and selects Instagram
2. Instagram loads inside WKWebView, full screen
3. A timer overlay is visible at the top of the screen showing remaining time (starting at 10:00)
4. Timer counts down only while the app is in the foreground and active
5. When timer reaches 0:00, the webview is replaced by a lock screen
6. The lock screen shows a message that the daily limit for Instagram has been reached
7. The app does not close itself — it shows the lock screen and stays open
8. If the user backgrounds the app and returns, the lock screen remains (platform is still locked)
9. At midnight, the lock state and remaining time reset automatically for all platforms

### What does NOT happen on timer expiry
- The app does not force-close (iOS doesn't allow this reliably)
- There is no warning countdown or color change before expiry (post-MVP)
- There is no way to manually reset or extend time (post-MVP)

---

## Timer behavior rules

| Scenario | Behavior |
|---|---|
| App is in foreground | Timer counts down |
| App goes to background | Timer pauses |
| User returns to app, time remaining | Timer resumes |
| User returns to app, time expired | Lock screen is shown |
| User reopens app after midnight | Timer and lock reset to 10:00 |
| User reopens app, same day, time expired | Lock screen shown immediately |

---

## Data model (simple, UserDefaults)

For each platform, store:
- `remainingSeconds: Int` — seconds left today (starts at 600)
- `isLocked: Bool` — whether the platform is locked today
- `lastResetDate: String` — date string (yyyy-MM-dd) of last reset

On every app launch and every time the platform is opened, check if `lastResetDate` is before today. If yes, reset `remainingSeconds` to 600 and `isLocked` to false.

---

## Screen architecture

### 1. Home screen
- Shows available platforms (MVP: Instagram only)
- Each platform shows as a card/button
- If platform is locked, card shows locked state with a lock icon and "Available tomorrow" label
- If platform has time remaining, card shows remaining time

### 2. Browser screen
- Full-screen WKWebView loading the platform URL
- Timer overlay pinned to the top (shows MM:SS, e.g. "08:42")
- Timer is always visible — do not let the webview render underneath or overlap it
- When timer hits 0, animate transition to lock screen

### 3. Lock screen
- Replaces webview when time expires
- Shows platform name, a message ("You've used your Instagram time for today"), and today's date
- No button to override or extend
- User can navigate back to home screen

---

## Key implementation notes

### Timer
- Use `Timer.scheduledTimer` with 1-second intervals
- Pause timer using `scenePhase` environment value (`.background` → pause, `.active` → resume)
- Save remaining seconds to UserDefaults every tick so state survives app restarts

### WKWebView user agent
- Instagram may serve a degraded mobile web experience. If the feed doesn't render correctly, set a custom user agent string to mimic Safari Mobile:
  ```swift
  webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
  ```

### Midnight reset
- Do not rely on background tasks or push notifications for the reset
- Check reset condition on every app launch and every time the home screen appears
- Compare `lastResetDate` with `Date()` formatted as `yyyy-MM-dd` in the device's local timezone

### Session persistence
- Remaining seconds must be saved to UserDefaults every second (or on background/terminate)
- On relaunch, read from UserDefaults — do not start fresh from 600 unless a reset is due

---

## Out of scope for MVP

- Twitter/X and Reddit integrations
- Warning UI before timer expires (color change, vibration, alert)
- Manual reset or time extension
- Settings screen (custom time limits)
- App Store distribution
- Multiple user profiles
- Notification when lock resets at midnight
- Analytics or usage history

---

## Post-MVP backlog (do not build now)

1. Add Twitter/X (validate login behavior separately before building)
2. Add Reddit
3. Warning at 60 seconds remaining (timer turns red)
4. Custom time limits per platform (settings screen)
5. Usage history screen (how much time used per day per platform)
6. Midnight reset push notification

---

## File structure (suggested)

```
Lilac/
├── LilacApp.swift
├── ContentView.swift         ← Home screen
├── BrowserView.swift         ← WKWebView + timer overlay
├── LockView.swift            ← Lock screen after timer expires
├── TimerManager.swift        ← Timer logic, UserDefaults persistence, reset logic
└── Platform.swift            ← Platform model (name, URL, color, icon)
```

---

## Platform definitions (MVP)

```swift
struct Platform {
    let name: String
    let url: String
    let color: Color
}

let instagram = Platform(
    name: "Instagram",
    url: "https://www.instagram.com",
    color: Color.purple
)
```

---

## Developer instructions

- Always test on a physical device. The simulator cannot validate WKWebView login behavior for Instagram.
- Deployment target must be set to iOS 18.0 or lower to match the test device.
- Do not add any third-party dependencies. Use only native iOS frameworks (SwiftUI, WebKit, Foundation).
- Keep all logic in Swift — no JavaScript injection into the webview unless strictly necessary.
- The app has one user. Do not over-engineer for multi-user or multi-device sync scenarios.
