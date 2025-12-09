import SwiftUI

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(HeirloomColors.tomato)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(HeirloomColors.tomato)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HeirloomColors.tomato, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(HeirloomColors.cream)
                            .opacity(configuration.isPressed ? 0.5 : 0)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(HeirloomColors.tomato)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Text Button Style
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(HeirloomColors.tomato)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style
struct DestructiveButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style
struct IconButtonStyle: ButtonStyle {
    var backgroundColor: Color = HeirloomColors.cream
    var foregroundColor: Color = HeirloomColors.charcoal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20))
            .foregroundStyle(foregroundColor)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(backgroundColor)
                    .opacity(configuration.isPressed ? 0.6 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions
extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(isLoading: Bool) -> PrimaryButtonStyle {
        PrimaryButtonStyle(isLoading: isLoading)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func secondary(isLoading: Bool) -> SecondaryButtonStyle {
        SecondaryButtonStyle(isLoading: isLoading)
    }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
    static func destructive(isLoading: Bool) -> DestructiveButtonStyle {
        DestructiveButtonStyle(isLoading: isLoading)
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
    static func icon(backgroundColor: Color, foregroundColor: Color) -> IconButtonStyle {
        IconButtonStyle(backgroundColor: backgroundColor, foregroundColor: foregroundColor)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: HeirloomSpacing.lg) {
        Button("Primary Button") {}
            .buttonStyle(.primary)

        Button("Primary Loading") {}
            .buttonStyle(.primary(isLoading: true))
            .disabled(true)

        Button("Secondary Button") {}
            .buttonStyle(.secondary)

        Button("Text Button") {}
            .buttonStyle(.text)

        Button("Destructive Button") {}
            .buttonStyle(.destructive)

        HStack(spacing: HeirloomSpacing.md) {
            Button {
            } label: {
                Image(systemName: "heart")
            }
            .buttonStyle(.icon)

            Button {
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.icon(backgroundColor: HeirloomColors.tomato, foregroundColor: .white))
        }
    }
    .padding()
    .background(Color.white)
}
