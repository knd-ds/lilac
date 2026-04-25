import SwiftUI

struct LockView: View {
    let platform: Platform

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 80, weight: .regular))
                    .foregroundColor(platform.color)

                VStack(spacing: 16) {
                    // Platform name
                    Text(platform.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    // Message
                    Text("You've used your \(platform.name) time for today")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // Today's date
                    Text(todayString)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }

                Spacer()

                // Subtle hint to navigate back
                Text("Tap the back button to return home")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(false)
    }
}

#Preview {
    NavigationStack {
        LockView(platform: instagram)
    }
}
