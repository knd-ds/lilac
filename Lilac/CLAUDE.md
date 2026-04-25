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

---

## Current Implementation Status (Updated 2026-04-25)

### Git Branch
Currently on: **`refactor25abr`**

### Completed Features

#### 1. Full App Flow (Beyond MVP)
The app now has a complete multi-screen flow:

**ConfirmationView** (Launch screen)
- Full-screen prompt: "Do you really want to open social media right now?"
- Two buttons: "Yes, open it" → PlatformSelectorView | "No, not now" → GoodChoiceView

**GoodChoiceView**
- Encouraging message: "Good call. Use this time for something that matters."
- No forward navigation, subtle hint to swipe up to close app

**PlatformSelectorView**
- Shows available platforms as cards
- Each card displays: platform name, remaining time or lock state
- Locked platforms show lock icon + "Available tomorrow"
- Tapping unlocked platform opens BrowserView

**BrowserView**
- VStack layout: Timer bar (top) → WKWebView (fills remaining space)
- Timer respects safe area, doesn't cover platform controls
- Navigates to LockView when timer expires

**LockView**
- Shows platform name, lock message, today's date
- No override or extension options
- User can navigate back to home

#### 2. Platforms Implemented
- **Instagram** (validated and working)
- **Twitter/X** (validated and working)

Both platforms have:
- Independent 10-minute daily timers
- Independent lock states
- Automatic midnight reset
- External link handling

#### 3. Platform Model Evolution

```swift
struct Platform: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let color: Color
    let allowedDomains: [String]  // NEW: Multi-domain support
}

let instagram = Platform(
    name: "Instagram",
    url: "https://www.instagram.com",
    color: .purple,
    allowedDomains: ["instagram.com", "facebook.com", "fbcdn.net"]
)

let twitter = Platform(
    name: "Twitter",
    url: "https://twitter.com",
    color: .purple,
    allowedDomains: ["twitter.com", "x.com", "t.co"]
)
```

**Why `allowedDomains` exists:**
- Instagram redirects to `facebook.com` for login sync
- Twitter redirects to `x.com` (new brand domain)
- Platforms need multiple domains to function correctly

---

## External Link Handling Architecture

### Problem Statement
Instagram Stories links ("Visitar enlace") were completely non-functional. Tapping them did nothing. Root cause: no `WKUIDelegate` assigned, so `window.open()` calls were silently blocked.

### Solution: WKUIDelegate + WKNavigationDelegate

**Implementation in BrowserView.swift:**

```swift
class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
    let allowedDomains: [String]

    // WKUIDelegate - handles window.open() (Instagram Stories)
    func webView(..., createWebViewWith...) -> WKWebView? {
        // Extract URL, check if external, open in default browser
        // Always return nil (never create new WKWebView)
    }

    // WKNavigationDelegate - handles standard navigation
    func webView(..., decidePolicyFor...) {
        if isExternalURL(url) {
            if navigationAction.navigationType == .linkActivated {
                // User tapped a link → open in external browser
                openInExternalBrowser(url)
                decisionHandler(.cancel)
            } else {
                // Automatic redirect → allow in WKWebView
                decisionHandler(.allow)
            }
        } else {
            // Internal navigation → allow normally
            decisionHandler(.allow)
        }
    }
}
```

### Navigation Type Distinction (Critical)

| Navigation Type | Example | Behavior |
|---|---|---|
| `.linkActivated` | User taps link in Instagram Story | Open in Chrome, cancel in WKWebView |
| `.other` (redirect) | `twitter.com` → `x.com` | Allow in WKWebView |
| `.other` (redirect) | `instagram.com` → `facebook.com/login_sync` | Allow in WKWebView |

**Why this matters:**
- Without this distinction, automatic redirects open in Chrome, breaking login flows
- With this distinction, user taps go to Chrome, but platform redirects stay internal

### Domain Matching Logic

```swift
private func isExternalURL(_ url: URL) -> Bool {
    guard let host = url.host else { return false }

    // Check against all allowed domains
    for domain in allowedDomains {
        if host.contains(domain) {
            return false // Internal
        }
    }
    return true // External
}
```

**Examples:**
- `instagram.com` with allowedDomains `["instagram.com", "facebook.com"]` → internal
- `facebook.com` with same list → internal ✓
- `l.instagram.com` → external (wrapper link) ✓
- `x.com` with allowedDomains `["twitter.com", "x.com"]` → internal ✓

---

## Bugs Found and Fixed

### Bug #1: Instagram Login Redirect Opens in Chrome
**Symptom:** Opening Instagram from Lilac immediately opens Chrome with `facebook.com/instagram/login_sync`

**Root cause:**
- Instagram automatically redirects to Facebook for login sync
- Original code only allowed `instagram.com`
- `facebook.com` was treated as external → opened in Chrome
- Login flow broken

**Fix:**
- Added `allowedDomains: [String]` to Platform model
- Instagram now allows: `["instagram.com", "facebook.com", "fbcdn.net"]`
- Automatic redirects (not user taps) allowed in WKWebView

### Bug #2: Twitter Opens Directly in Chrome
**Symptom:** Tapping Twitter in PlatformSelectorView immediately opens Chrome, never loads in Lilac

**Root cause:**
- Twitter automatically redirects `twitter.com` → `x.com`
- Original code only allowed `twitter.com`
- Redirect to `x.com` treated as external → opened in Chrome immediately

**Fix:**
- Twitter now allows: `["twitter.com", "x.com", "t.co"]`
- Redirect happens in WKWebView, user stays in app

### Bug #3: Timer Limit Not Updating from 60min to 10min
**Symptom:** After changing `dailyLimit` from 3600 to 600, app still showed 60 minutes

**Root cause:**
- Old values (3600) saved in UserDefaults on device
- `loadRemainingSeconds()` read cached values, didn't check against new limit

**Fix:**
- Added `migrateOldLimits()` function (runs once on app launch)
- Detects values > 600, resets them to 600
- Added safety check in `loadRemainingSeconds()` to cap at `dailyLimit`

---

## WKWebView Anti-Detection Measures

### Problem: Twitter Blocks Login in Embedded WKWebView
Twitter/X actively detects WKWebView and blocks authentication flows.

### Current Mitigations (BrowserView.swift)

1. **Custom User Agent**
```swift
webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
```

2. **JavaScript Injection (atDocumentStart)**
```javascript
delete window.webkit;
Object.defineProperty(navigator, 'standalone', { value: false, writable: false });
```

3. **Configuration Settings**
```swift
configuration.allowsInlineMediaPlayback = true
configuration.websiteDataStore = .default() // Proper cookie handling
webView.allowsBackForwardNavigationGestures = true
webView.allowsLinkPreview = true
```

**Note:** These measures are platform-agnostic. They work for both Instagram and Twitter.

---

## Layout Architecture (BrowserView)

### Problem: Timer Overlay Covering Platform Controls
Original implementation used `ZStack` with `.ignoresSafeArea()`, causing:
- Timer floating over Twitter's navigation bar
- "Back" button in Twitter inaccessible
- Account/settings menu covered

### Solution: VStack with Proper Safe Area Handling

```swift
VStack(spacing: 0) {
    // Timer bar - respects safe area top
    TimerOverlay(...)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.black)

    // WKWebView - fills remaining space
    WebViewContainer(...)
        .ignoresSafeArea(.container, edges: .bottom) // Only bottom
}
```

**Layout stack:** `[Status bar] → [Timer bar] → [WKWebView content] → [Home indicator]`

All platform controls are now touchable. Timer occupies its own space instead of floating.

---

## TimerManager Implementation Details

### Key Features
- Singleton pattern (`TimerManager.shared`)
- Observable object publishing `remainingSeconds` and `isLocked` per platform
- Saves to UserDefaults every second
- Automatic midnight reset via date comparison

### Migration System
When app limit changes, old UserDefaults values persist. Migration handles this:

```swift
private func migrateOldLimits() {
    let migrationKey = "didMigrateTo600Limit"
    if !defaults.bool(forKey: migrationKey) {
        // Reset values exceeding new limit
        for platform in platforms {
            if savedValue > dailyLimit {
                defaults.set(dailyLimit, forKey: key)
            }
        }
        defaults.set(true, forKey: migrationKey)
    }
}
```

Only runs once. Future limit changes need new migration keys.

---

## File Structure (Actual)

```
Lilac/
├── LilacApp.swift
├── ContentView.swift              ← Entry point, shows ConfirmationView
├── ConfirmationView.swift         ← "Do you really want to open?" prompt
├── GoodChoiceView.swift           ← "Good call" encouragement screen
├── PlatformSelectorView.swift     ← Platform cards with timer/lock state
├── BrowserView.swift              ← WKWebView + timer + delegates
├── LockView.swift                 ← Lock screen after timer expires
├── TimerManager.swift             ← Timer logic, persistence, reset
├── Platform.swift                 ← Platform model with allowedDomains
└── CLAUDE.md                      ← This file
```

---

## Known Limitations

### Sign in with Apple Creates New Accounts
When using "Sign in with Apple" inside WKWebView (e.g., for Twitter login), Apple generates a **unique identifier per app context**. WKWebView is treated as a different context than Safari or the native Twitter app, so it creates a new account instead of accessing the existing one.

**Workaround:** Use traditional email/password login instead of "Sign in with Apple" for testing.

**Potential fix (not implemented):** Use `ASWebAuthenticationSession` for OAuth flows, but this is more complex and not required for MVP.

---

## Testing Checklist (Physical Device Only)

Before considering a session complete, verify:

- [ ] Instagram loads correctly without opening Chrome
- [ ] Instagram can navigate to DMs, Explore, Profile without issues
- [ ] Instagram Stories "Visitar enlace" opens external links in Chrome
- [ ] Twitter loads and redirects to x.com inside the app
- [ ] Twitter feed navigation stays in Lilac
- [ ] Timer counts down correctly (test with short limit)
- [ ] Timer pauses when app goes to background
- [ ] Timer resumes when app returns to foreground
- [ ] Lock screen appears when timer reaches 0:00
- [ ] Locked platform shows "Available tomorrow" in selector
- [ ] Midnight reset works (change device date to test)
- [ ] ConfirmationView → "No, not now" → GoodChoiceView flow
- [ ] ConfirmationView → "Yes, open it" → PlatformSelectorView flow

---

## Important Notes for Future Sessions

1. **Never remove `allowedDomains`** — platforms depend on this for cross-domain authentication flows

2. **Never remove navigation type check** — `.linkActivated` vs `.other` distinction is critical for correct link handling

3. **Testing timer limits** — if you need to test with longer limits, remember to:
   - Change `dailyLimit` in TimerManager
   - Add a new migration key (don't reuse `didMigrateTo600Limit`)
   - Test on device (UserDefaults is per-device)

4. **Adding new platforms** — must include `allowedDomains` array with all domains the platform might redirect to

5. **WKWebView delegates are mandatory** — removing `WKUIDelegate` or `WKNavigationDelegate` breaks external link handling

6. **Xcode project uses File System Synchronized Groups** — new Swift files are automatically included, no need to manually add to project.pbxproj

7. **Current daily limit is 600 seconds (10 minutes)** — this is production value, not testing value
