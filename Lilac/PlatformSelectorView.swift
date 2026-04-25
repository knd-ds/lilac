import SwiftUI

struct PlatformSelectorView: View {
    @State private var selectedPlatform: Platform?
    @State private var showBrowser = false

    @ObservedObject private var timerManager = TimerManager.shared

    private let platforms = [instagram, twitter]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Choose a platform")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 60)

                Spacer()

                VStack(spacing: 16) {
                    ForEach(platforms) { platform in
                        PlatformButton(platform: platform) {
                            selectedPlatform = platform
                            showBrowser = true
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationDestination(isPresented: $showBrowser) {
            if let platform = selectedPlatform {
                BrowserView(platform: platform)
            }
        }
        .onAppear {
            // Check for midnight reset
            timerManager.checkAndResetIfNeeded()
        }
    }
}

struct PlatformButton: View {
    let platform: Platform
    let action: () -> Void

    @ObservedObject private var timerManager = TimerManager.shared

    private var isLocked: Bool {
        timerManager.isLocked(for: platform)
    }

    private var remainingSeconds: Int {
        timerManager.getRemainingSeconds(for: platform)
    }

    var body: some View {
        Button(action: {
            if !isLocked {
                action()
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(platform.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)

                    if isLocked {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                            Text("Available tomorrow")
                                .font(.system(size: 14, weight: .regular))
                        }
                        .foregroundColor(.gray)
                    } else {
                        Text(timeString(from: remainingSeconds))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLocked ? Color.gray.opacity(0.2) : platform.color.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isLocked ? Color.gray.opacity(0.3) : platform.color, lineWidth: 2)
            )
        }
        .disabled(isLocked)
        .onAppear {
            timerManager.loadPlatformState(for: platform)
        }
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d remaining", minutes, secs)
    }
}

#Preview {
    NavigationStack {
        PlatformSelectorView()
    }
}
