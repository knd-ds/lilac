import SwiftUI

struct GoodChoiceView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Good call.")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Text("Use this time for something that matters.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Text("Swipe up to close the app")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    GoodChoiceView()
}
