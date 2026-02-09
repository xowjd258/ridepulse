import SwiftUI

// MARK: - Toss-style Color System
extension Color {
    // Primary
    static let tossPrimary = Color(hex: "3182F6")
    static let tossSecondary = Color(hex: "4E5968")
    
    // Background
    static let tossBg = Color(hex: "F4F5F7")
    static let tossCardBg = Color.white
    static let tossDarkBg = Color(hex: "191F28")
    
    // Text
    static let tossTextPrimary = Color(hex: "191F28")
    static let tossTextSecondary = Color(hex: "8B95A1")
    static let tossTextTertiary = Color(hex: "B0B8C1")
    
    // Status
    static let tossGreen = Color(hex: "2AD062")
    static let tossRed = Color(hex: "F04452")
    static let tossOrange = Color(hex: "F59E0B")
    static let tossYellow = Color(hex: "FCD535")
    
    // Gradient
    static let tossGradientStart = Color(hex: "3182F6")
    static let tossGradientEnd = Color(hex: "6DB5F5")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Toss-style Font System
extension Font {
    static func tossTitle() -> Font {
        .system(size: 22, weight: .bold)
    }
    static func tossHeadline() -> Font {
        .system(size: 17, weight: .semibold)
    }
    static func tossBody() -> Font {
        .system(size: 15, weight: .regular)
    }
    static func tossCaption() -> Font {
        .system(size: 13, weight: .regular)
    }
    static func tossMetric() -> Font {
        .system(size: 48, weight: .bold, design: .rounded)
    }
    static func tossMetricMedium() -> Font {
        .system(size: 32, weight: .bold, design: .rounded)
    }
    static func tossMetricSmall() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }
}

// MARK: - View Modifiers
struct TossCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.tossCardBg)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct TossPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tossHeadline())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? Color.tossPrimary : Color.tossTextTertiary)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct TossSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tossHeadline())
            .foregroundColor(.tossPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tossPrimary.opacity(0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func tossCard() -> some View {
        modifier(TossCardModifier())
    }
}
