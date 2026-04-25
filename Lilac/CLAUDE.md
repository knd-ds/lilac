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

## Core behavior

1. User opens the app — prompted "Do you really want to open social media right now?"
2. If yes, selects a platform (Instagram or Twitter/X)
3. Platform loads inside WKWebView, full screen
4. A timer overlay is visible at the top of the screen showing remaining time (starting at 10:00)
5. Timer counts down only while the app is in the foreground and active
6. When timer reaches 0:00, the webview is replaced by a lock screen (in the same tick — no delay)
7. The lock screen shows a message that the daily limit for that platform has been reached
8. The app does not close itself — it shows the lock screen and stays open
9. If the user backgrounds the app and returns, the lock screen is shown immediately if the platform is locked
10. At midnight, the lock state and remaining time reset automatically for all platforms

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
| User returns to app, time remaining | Timer resumes (after midnight check) |
| User returns to app, time expired | Lock screen shown immediately |
| Midnight passes while app is backgrounded | Reset applied on next foreground |
| User reopens app after midnight | Timer and lock reset to 10:00 |
| User reopens app, same day, time expired | Lock screen shown immediately |

---

## Data model (UserDefaults)

For each platform, store:
- `remainingSeconds_<PlatformName>: Int` — seconds left today (starts at 600)
- `isLocked_<PlatformName>: Bool` — whether the platform is locked today
- `lastResetDate: String` — date string (yyyy-MM-dd) of last reset

On every app launch, every platform open, and every foreground return, check if `lastResetDate` is before today. If yes, reset `remainingSeconds` to 600 and `isLocked` to false for all platforms.

---

## Screen architecture

### 1. ConfirmationView (entry point)
- Full-screen prompt: "Do you really want to open social media right now?"
- "Yes, open it" → PlatformSelectorView
- "No, not now" → GoodChoiceView

### 2. GoodChoiceView
- Encouraging message, no forward navigation
- Hint to swipe up to close

### 3. PlatformSelectorView
- Shows available platforms as cards
- Each card displays: platform name, remaining time or lock state
- Locked platforms show lock icon + "Available tomorrow"
- Tapping unlocked platform opens BrowserView

### 4. BrowserView
- VStack layout: Timer bar (top) → WKWebView (fills remaining space)
- Timer respects safe area, doesn't cover platform controls
- Navigates to LockView when timer expires

### 5. LockView
- Shows platform name, lock message, today's date
- No override or extension options
- User can navigate back to home

---

## Key implementation notes

### Timer
- `Timer.scheduledTimer` with 1-second intervals, running on the main run loop
- Pause via `scenePhase` (`.background`/`.inactive` → pause, `.active` → resume)
- On `.active` foreground return: run `checkAndResetIfNeeded()` first, then check lock state, then start timer
- Save remaining seconds to UserDefaults every tick
- Lock screen appears in the same timer tick that causes the lock (no 1-second display of "0:00")

### WKWebView user agent
Set a custom user agent string to mimic Safari Mobile:
```swift
webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
```

### Midnight reset
- Do not rely on background tasks or push notifications for the reset
- Check reset condition on every app launch, every platform open, and every foreground return
- Compare `lastResetDate` with `Date()` formatted as `yyyy-MM-dd` in the device's local timezone
- `checkAndResetIfNeeded()` is idempotent — safe to call multiple times

### Session persistence
- Remaining seconds saved to UserDefaults every second
- On relaunch, read from UserDefaults — do not start fresh from 600 unless a reset is due

### Changing the daily limit
If `dailyLimit` needs to change again:
1. Change the constant in `TimerManager`
2. The safety cap in `loadRemainingSeconds` (`if savedValue > dailyLimit { return dailyLimit }`) ensures old UserDefaults values are capped automatically — no separate migration function needed

---

## File structure

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
├── Platform.swift                 ← Platform model, instances, allPlatforms
└── CLAUDE.md                      ← This file
```

---

## Platform definitions

```swift
struct Platform: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let color: Color
    let allowedDomains: [String]
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

let allPlatforms: [Platform] = [instagram, twitter]
```

**`allPlatforms` is the single source of truth** for the platform list. Both `PlatformSelectorView` and `TimerManager.resetAllPlatforms()` use it. When adding a new platform, add the instance and add it to `allPlatforms` — that is the only required change to propagate it through the app.

**Why `allowedDomains` exists:**
- Instagram redirects to `facebook.com` for login sync
- Twitter redirects to `x.com` (new brand domain)
- Platforms need multiple domains to function correctly

---

## External link handling architecture

### Problem statement
Instagram Stories links ("Visitar enlace") were completely non-functional. Root cause: no `WKUIDelegate` assigned, so `window.open()` calls were silently blocked.

### Solution: WKUIDelegate + WKNavigationDelegate

```swift
class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
    let allowedDomains: [String]

    // WKUIDelegate - handles window.open() (Instagram Stories)
    func webView(..., createWebViewWith...) -> WKWebView? {
        // If external URL: open in default browser
        // Always return nil — never create a new WKWebView
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

### Navigation type distinction (critical — do not change)

| Navigation Type | Example | Behavior |
|---|---|---|
| `.linkActivated` | User taps link in Instagram Story | Open in Chrome, cancel in WKWebView |
| `.other` (redirect) | `twitter.com` → `x.com` | Allow in WKWebView |
| `.other` (redirect) | `instagram.com` → `facebook.com/login_sync` | Allow in WKWebView |

Without this distinction, automatic redirects open in Chrome, breaking login flows.

### Domain matching logic (do not change)

```swift
private func isExternalURL(_ url: URL) -> Bool {
    guard let host = url.host else { return false }
    for domain in allowedDomains {
        if host.contains(domain) {
            return false // Internal
        }
    }
    return true // External
}
```

**Examples with `allowedDomains = ["instagram.com", "facebook.com", "fbcdn.net"]`:**
- `www.instagram.com` → internal ✓
- `facebook.com` → internal ✓ (login sync redirect stays in WKWebView)
- `l.instagram.com` → internal (contains `instagram.com`) — Stories wrapper links use `.linkActivated` navigation type, so they are still opened externally via the `decidePolicyFor` branch
- `x.com` with `allowedDomains = ["twitter.com", "x.com"]` → internal ✓

---

## TimerManager implementation details

### Key features
- Singleton pattern (`TimerManager.shared`)
- `@Published` `remainingSeconds: [String: Int]` and `isLocked: [String: Bool]` — keyed by platform name
- Saves to UserDefaults every second
- Automatic midnight reset via date comparison
- All mutations happen on the main thread (timer runs on main run loop) — no race conditions

### UserDefaults key helpers
Keys are generated by private functions, not repeated as raw strings:
```swift
private func remainingSecondsKey(for platform: Platform) -> String {
    "remainingSeconds_\(platform.name)"
}
private func isLockedKey(for platform: Platform) -> String {
    "isLocked_\(platform.name)"
}
```
This ensures a key format change is a one-line edit, not a search across multiple methods.

### Limit safety cap
`loadRemainingSeconds(for:)` always caps the returned value at `dailyLimit`. This means stale UserDefaults values from a previous (higher) limit are corrected automatically on load, with no migration function required.

---

## WKWebView anti-detection measures

Twitter/X actively detects WKWebView and blocks authentication flows. Current mitigations:

1. **Custom user agent** — mimics Safari Mobile (see above)

2. **JavaScript injection at `atDocumentStart`**
```javascript
delete window.webkit;
Object.defineProperty(navigator, 'standalone', { value: false, writable: false });
```

3. **Configuration**
```swift
configuration.allowsInlineMediaPlayback = true
configuration.websiteDataStore = .default()
webView.allowsBackForwardNavigationGestures = true
webView.allowsLinkPreview = true
```

These measures are platform-agnostic. Do not remove any of them without retesting Twitter login.

---

## Layout architecture (BrowserView)

VStack layout — do not change to ZStack:

```swift
VStack(spacing: 0) {
    TimerOverlay(...)     // Respects safe area top, occupies its own space
        .background(Color.black)

    WebViewContainer(...) // Fills remaining space
        .ignoresSafeArea(.container, edges: .bottom)
}
```

**Layout stack:** `[Status bar] → [Timer bar] → [WKWebView content] → [Home indicator]`

ZStack was the original approach and caused the timer to float over Twitter's navigation bar, making the back button and account menu inaccessible.

---

## Bugs found and fixed

### Bug #1: Instagram login redirect opens in Chrome
Instagram automatically redirects to `facebook.com` for login sync. Fix: added `facebook.com` and `fbcdn.net` to Instagram's `allowedDomains`. Automatic redirects (not user taps) stay in WKWebView.

### Bug #2: Twitter opens directly in Chrome
Twitter automatically redirects `twitter.com` → `x.com`. Fix: added `x.com` and `t.co` to Twitter's `allowedDomains`.

### Bug #3: Timer limit not updating from 60min to 10min
Old UserDefaults values (3600s) persisted after changing `dailyLimit` to 600. Fix: added safety cap in `loadRemainingSeconds` (`if savedValue > dailyLimit { return dailyLimit }`). The one-time migration function (`migrateOldLimits`) that was also added has since been removed — the safety cap alone is sufficient and runs on every load.

### Bug #4: Midnight reset skipped when app is backgrounded on BrowserView
If midnight passed while the app was backgrounded with BrowserView open, returning to the app resumed the old timer without resetting. Fix: `checkAndResetIfNeeded()` is now called in the `.active` case of `scenePhase`, before the timer restarts.

### Bug #5: Lock screen not shown on foreground return after lock
If the timer reached 0 and `isLocked` became true while the app was being backgrounded, returning to the foreground would not show the lock screen (`showLockScreen` remained false). Fix: the `.active` scenePhase handler now checks `isLocked` and sets `showLockScreen = true` if needed.

### Bug #6: Lock screen appeared one second late
The timer callback checked `if remainingSeconds > 0` before calling `decrementTime`. When `remainingSeconds` hit 0, the lock screen wasn't shown until the next timer tick — a 1-second gap where "0:00" was visible but the lock screen hadn't appeared. Fix: removed the redundant guard; the callback now calls `decrementTime` unconditionally and checks `isLocked` immediately after, in the same tick.

---

## Known limitations

### Sign in with Apple creates new accounts
WKWebView is treated as a different context than Safari or the native app. "Sign in with Apple" generates a new identifier and creates a new account instead of accessing the existing one.

**Workaround:** Use traditional email/password login.

**Potential fix (not implemented):** Use `ASWebAuthenticationSession` for OAuth flows.

---

## Post-MVP backlog (do not build now)

1. Add Reddit (validate login behavior separately before building)
2. Warning at 60 seconds remaining (timer turns red)
3. Custom time limits per platform (settings screen)
4. Usage history screen (how much time used per day per platform)
5. Midnight reset push notification

---

## Testing checklist (physical device only)

Before considering a session complete, verify:

- [ ] Instagram loads correctly without opening Chrome
- [ ] Instagram can navigate to DMs, Explore, Profile without issues
- [ ] Instagram Stories "Visitar enlace" opens external links in Chrome
- [ ] Twitter loads and redirects to x.com inside the app
- [ ] Twitter feed navigation stays in Lilac
- [ ] Timer counts down correctly (test with short limit)
- [ ] Timer pauses when app goes to background
- [ ] Timer resumes when app returns to foreground
- [ ] Lock screen appears when timer reaches 0:00 (same tick, no delay)
- [ ] Backgrounding after lock and returning shows lock screen immediately
- [ ] Locked platform shows "Available tomorrow" in selector
- [ ] Midnight reset works (change device date to test; verify reset applies even if BrowserView was open when date changed)
- [ ] ConfirmationView → "No, not now" → GoodChoiceView flow
- [ ] ConfirmationView → "Yes, open it" → PlatformSelectorView flow

---

## Important notes for future sessions

1. **Never remove `allowedDomains`** — platforms depend on this for cross-domain authentication flows

2. **Never remove the navigation type check** — `.linkActivated` vs `.other` distinction is critical for correct link handling

3. **Never remove WKUIDelegate or WKNavigationDelegate** — both are required; removing either breaks external link handling

4. **`allPlatforms` is the only place to add a new platform** — `PlatformSelectorView` and `TimerManager.resetAllPlatforms()` both use it; adding a platform only to one of them will cause the other to miss it

5. **To change the daily limit:** change `dailyLimit` in TimerManager. The safety cap in `loadRemainingSeconds` handles old UserDefaults values automatically. No migration function needed.

6. **Testing timer limits** — change `dailyLimit` temporarily; revert before shipping. UserDefaults values from a higher limit are capped automatically on load.

7. **Current daily limit is 600 seconds (10 minutes)** — this is the production value

8. **Xcode project uses File System Synchronized Groups** — new Swift files are automatically included, no need to manually add to project.pbxproj
