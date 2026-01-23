import SwiftUI

// MARK: - Colors
extension Color {
    // Primary colors
    static let appBackground = Color(hex: "#111111")
    static let cardBackground = Color(hex: "#1E1E1E")
    static let navBackground = Color(hex: "#1A1A1A")
    static let accentOrange = Color(hex: "#FF8400")

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#999999")
    static let textMuted = Color(hex: "#666666")

    // Status colors
    static let success = Color(hex: "#00CC66")
    static let error = Color(hex: "#D93C15")
    static let standing = Color(hex: "#FF8400")
    static let sitting = Color(hex: "#6666FF")

    // Border colors
    static let borderLight = Color(hex: "#333333")
    static let borderMedium = Color(hex: "#2E2E2E")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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

// MARK: - Typography
struct AppFont {
    static let largeTitle = Font.system(size: 72, weight: .bold, design: .rounded)
    static let title = Font.system(size: 24, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 14, weight: .medium, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let small = Font.system(size: 10, weight: .semibold, design: .rounded)
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Color.accentOrange : Color.textMuted)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .foregroundColor(.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.error, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CircleButtonStyle: ButtonStyle {
    var background: Color = .cardBackground
    var foreground: Color = .white
    var size: CGFloat = 100

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Card View
struct CardView<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16

    init(padding: CGFloat = 16, cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
    }
}

// MARK: - Icon Background
struct IconBackground: View {
    let icon: String
    var color: Color = .accentOrange
    var size: CGFloat = 48
    var iconSize: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(color)
        }
    }
}
