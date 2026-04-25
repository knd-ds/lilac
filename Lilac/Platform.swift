import SwiftUI

struct Platform: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let color: Color
    let allowedDomains: [String]
}

// MARK: - Platform Definitions

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

// Post-MVP platforms:
// - Reddit
