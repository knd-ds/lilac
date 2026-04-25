import SwiftUI
import Combine

class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published private(set) var remainingSeconds: [String: Int] = [:]
    @Published private(set) var isLocked: [String: Bool] = [:]

    private let defaults = UserDefaults.standard
    private let dailyLimit = 600 // 10 minutes in seconds

    private init() {
        checkAndResetIfNeeded()
    }

    // MARK: - Public API

    func getRemainingSeconds(for platform: Platform) -> Int {
        return remainingSeconds[platform.name] ?? dailyLimit
    }

    func isLocked(for platform: Platform) -> Bool {
        return isLocked[platform.name] ?? false
    }

    func decrementTime(for platform: Platform) {
        let remaining = getRemainingSeconds(for: platform)

        if remaining > 0 {
            remainingSeconds[platform.name] = remaining - 1
            saveRemainingSeconds(for: platform)

            // Lock if timer reaches zero
            if remaining - 1 <= 0 {
                lockPlatform(platform)
            }
        }
    }

    func checkAndResetIfNeeded() {
        let today = getTodayString()
        let lastResetDate = defaults.string(forKey: "lastResetDate") ?? ""

        if lastResetDate != today {
            // New day - reset all platforms
            resetAllPlatforms()
            defaults.set(today, forKey: "lastResetDate")
        }
    }

    // MARK: - Private Helpers

    private func remainingSecondsKey(for platform: Platform) -> String {
        "remainingSeconds_\(platform.name)"
    }

    private func isLockedKey(for platform: Platform) -> String {
        "isLocked_\(platform.name)"
    }

    private func saveRemainingSeconds(for platform: Platform) {
        defaults.set(remainingSeconds[platform.name] ?? dailyLimit, forKey: remainingSecondsKey(for: platform))
    }

    private func loadRemainingSeconds(for platform: Platform) -> Int {
        let key = remainingSecondsKey(for: platform)
        if defaults.object(forKey: key) != nil {
            let savedValue = defaults.integer(forKey: key)
            if savedValue > dailyLimit {
                return dailyLimit
            }
            return savedValue
        }
        return dailyLimit
    }

    private func lockPlatform(_ platform: Platform) {
        isLocked[platform.name] = true
        defaults.set(true, forKey: isLockedKey(for: platform))
    }

    private func loadLockState(for platform: Platform) -> Bool {
        defaults.bool(forKey: isLockedKey(for: platform))
    }

    private func resetAllPlatforms() {
        for platform in allPlatforms {
            remainingSeconds[platform.name] = dailyLimit
            isLocked[platform.name] = false

            saveRemainingSeconds(for: platform)
            defaults.set(false, forKey: isLockedKey(for: platform))
        }
    }

    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    // MARK: - Platform Loading

    func loadPlatformState(for platform: Platform) {
        checkAndResetIfNeeded()

        if remainingSeconds[platform.name] == nil {
            remainingSeconds[platform.name] = loadRemainingSeconds(for: platform)
        }

        if isLocked[platform.name] == nil {
            isLocked[platform.name] = loadLockState(for: platform)
        }
    }
}
