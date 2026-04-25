import SwiftUI

struct Platform: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let color: Color
}

// MARK: - Platform Definitions

let instagram = Platform(
    name: "Instagram",
    url: "https://www.instagram.com",
    color: .purple
)

let twitter = Platform(
    name: "Twitter",
    url: "https://twitter.com",
    color: .purple
)

// Post-MVP platforms (not yet implemented):
// - Reddit
