import SwiftUI
import Combine

class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published private(set) var remainingSeconds: [String: Int] = [:]
    @Published private(set) var isLocked: [String: Bool] = [:]

    private let defaults = UserDefaults.standard
    private let dailyLimit = 600 // 10 minutes in seconds

    private init() {
        loadState()
        migrateOldLimits()
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

    private func loadState() {
        // Load all saved platform states
        // For now, just initialize with default values
        // Will be populated as platforms are accessed
    }

    private func migrateOldLimits() {
        // One-time migration: check if we need to migrate from old limit (3600) to new limit (600)
        let migrationKey = "didMigrateTo600Limit"

        if !defaults.bool(forKey: migrationKey) {
            // Reset all platforms to clear old limit values
            let platforms = [instagram, twitter]

            for platform in platforms {
                let key = "remainingSeconds_\(platform.name)"
                if let savedValue = defaults.object(forKey: key) as? Int, savedValue > dailyLimit {
                    // Old value detected, reset to new limit
                    defaults.set(dailyLimit, forKey: key)
                }
            }

            // Mark migration as complete
            defaults.set(true, forKey: migrationKey)
        }
    }

    private func saveRemainingSeconds(for platform: Platform) {
        let key = "remainingSeconds_\(platform.name)"
        defaults.set(remainingSeconds[platform.name] ?? dailyLimit, forKey: key)
    }

    private func loadRemainingSeconds(for platform: Platform) -> Int {
        let key = "remainingSeconds_\(platform.name)"
        if defaults.object(forKey: key) != nil {
            let savedValue = defaults.integer(forKey: key)
            // Migration: if saved value exceeds current daily limit, reset to daily limit
            if savedValue > dailyLimit {
                return dailyLimit
            }
            return savedValue
        }
        return dailyLimit
    }

    private func lockPlatform(_ platform: Platform) {
        isLocked[platform.name] = true
        let key = "isLocked_\(platform.name)"
        defaults.set(true, forKey: key)
    }

    private func loadLockState(for platform: Platform) -> Bool {
        let key = "isLocked_\(platform.name)"
        return defaults.bool(forKey: key)
    }

    private func resetAllPlatforms() {
        let platforms = [instagram, twitter]

        for platform in platforms {
            remainingSeconds[platform.name] = dailyLimit
            isLocked[platform.name] = false

            saveRemainingSeconds(for: platform)
            defaults.set(false, forKey: "isLocked_\(platform.name)")
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
