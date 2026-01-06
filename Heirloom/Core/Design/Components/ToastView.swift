import SwiftUI

// MARK: - Toast Type
enum ToastType {
    case success
    case error
    case info
    case warning

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

// MARK: - Toast Model
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String?
    let duration: TimeInterval

    init(type: ToastType, title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast View
struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 24))
                .foregroundStyle(toast.type.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(toast.title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.charcoal)

                if let message = toast.message {
                    Text(message)
                        .font(HeirloomFonts.callout)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                dismissToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(
                    color: HeirloomColors.cardShadow,
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, HeirloomSpacing.md)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            showToast()
        }
    }

    private func showToast() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            offset = 0
            opacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
            dismissToast()
        }
    }

    private func dismissToast() {
        withAnimation(.easeInOut(duration: 0.3)) {
            offset = -100
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Toast Manager
@MainActor
@Observable
class ToastManager {
    private(set) var currentToast: Toast?

    init() {}

    func show(_ toast: Toast) {
        currentToast = toast
    }

    func show(type: ToastType, title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        show(Toast(type: type, title: title, message: message, duration: duration))
    }

    func dismiss() {
        currentToast = nil
    }

    // Convenience methods
    func success(title: String, message: String? = nil) {
        show(type: .success, title: title, message: message)
    }

    func error(title: String, message: String? = nil) {
        show(type: .error, title: title, message: message)
    }

    func info(title: String, message: String? = nil) {
        show(type: .info, title: title, message: message)
    }

    func warning(title: String, message: String? = nil) {
        show(type: .warning, title: title, message: message)
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @State private var toastManager = ServiceContainer.shared.resolve(ToastManager.self)

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let toast = toastManager.currentToast {
                ToastView(toast: toast) {
                    toastManager.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
                .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: toastManager.currentToast != nil)
    }
}

extension View {
    func toastContainer() -> some View {
        modifier(ToastModifier())
    }
}

// MARK: - Preview
#Preview {
    let toastManager = ToastManager()
    return VStack(spacing: HeirloomSpacing.lg) {
        Button("Show Success") {
            toastManager.success(
                title: "Recipe Saved!",
                message: "Your recipe has been added to your collection."
            )
        }
        .buttonStyle(.primary)

        Button("Show Error") {
            toastManager.error(
                title: "Import Failed",
                message: "Could not import recipe from URL."
            )
        }
        .buttonStyle(.primary)

        Button("Show Info") {
            toastManager.info(
                title: "Sync Complete",
                message: "Your recipes are up to date."
            )
        }
        .buttonStyle(.primary)

        Button("Show Warning") {
            toastManager.warning(
                title: "Network Unavailable",
                message: "Changes will sync when connection is restored."
            )
        }
        .buttonStyle(.primary)
    }
    .padding()
    .toastContainer()
}
