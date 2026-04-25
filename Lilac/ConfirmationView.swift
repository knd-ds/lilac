import SwiftUI

struct ConfirmationView: View {
    @State private var showPlatformSelector = false
    @State private var showGoodChoice = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    Text("Do you really want to open social media right now?")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()

                    VStack(spacing: 20) {
                        Button(action: {
                            showPlatformSelector = true
                        }) {
                            Text("Yes, open it")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.purple)
                                .cornerRadius(12)
                        }

                        Button(action: {
                            showGoodChoice = true
                        }) {
                            Text("No, not now")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }
            }
            .navigationDestination(isPresented: $showPlatformSelector) {
                PlatformSelectorView()
            }
            .navigationDestination(isPresented: $showGoodChoice) {
                GoodChoiceView()
            }
        }
    }
}

#Preview {
    ConfirmationView()
}
