import SwiftUI

// MARK: - Error View
/// Beautiful error display with icon, message, and recovery actions
struct ErrorView: View {

    let error: LyoError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?

    @State private var isRetrying = false

    init(
        error: LyoError,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 24) {
            // Error Icon
            errorIcon
                .font(.system(size: 64))
                .foregroundColor(errorColor)

            // Error Content
            VStack(spacing: 12) {
                Text(errorTitle)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal)

            // Action Buttons
            VStack(spacing: 12) {
                // Retry Button
                if error.isRetryable, let onRetry = onRetry {
                    Button(action: {
                        isRetrying = true
                        onRetry()
                        // Reset after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isRetrying = false
                        }
                    }) {
                        HStack {
                            if isRetrying {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Try Again")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRetrying)
                }

                // Authentication Button
                if error.requiresAuthentication {
                    Button(action: {
                        // Navigate to login
                        NotificationCenter.default.post(name: .requiresAuthentication, object: nil)
                    }) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text("Sign In Again")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }

                // Dismiss Button
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }

                // Support Button
                if !error.isUserError {
                    Button(action: {
                        // Open support
                        if let url = URL(string: "mailto:\(AppConfig.supportEmail)?subject=Error Report") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Contact Support")
                        }
                        .font(.callout)
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
        }
        .padding(24)
        .background(Color(.systemBackground))
    }

    // MARK: - Computed Properties

    private var errorIcon: Image {
        switch error {
        case .network(.noInternetConnection):
            return Image(systemName: "wifi.slash")
        case .network(.unauthorized):
            return Image(systemName: "lock.shield")
        case .network(.timeout):
            return Image(systemName: "clock.arrow.circlepath")
        case .network(.serverError):
            return Image(systemName: "server.rack")
        case .validation:
            return Image(systemName: "exclamationmark.triangle")
        case .business(.insufficientCredits):
            return Image(systemName: "creditcard")
        case .ai(.quotaExceeded):
            return Image(systemName: "brain")
        case .storage(.insufficientSpace):
            return Image(systemName: "externaldrive")
        default:
            return Image(systemName: "exclamationmark.circle")
        }
    }

    private var errorColor: Color {
        switch error {
        case .network(.noInternetConnection):
            return .orange
        case .network(.unauthorized):
            return .red
        case .validation:
            return .yellow
        case .business:
            return .blue
        default:
            return .red
        }
    }

    private var errorTitle: String {
        switch error {
        case .network(.noInternetConnection):
            return "No Internet Connection"
        case .network(.unauthorized):
            return "Authentication Required"
        case .network(.timeout):
            return "Request Timed Out"
        case .network(.serverError):
            return "Server Error"
        case .validation:
            return "Invalid Input"
        case .business(.insufficientCredits):
            return "Insufficient Credits"
        case .ai(.quotaExceeded):
            return "AI Usage Limit Reached"
        case .storage(.insufficientSpace):
            return "Storage Full"
        default:
            return "Something Went Wrong"
        }
    }

    private var errorMessage: String {
        error.errorDescription ?? "An unexpected error occurred"
    }
}

// MARK: - Error Toast
/// Lightweight toast notification for non-critical errors
struct ErrorToast: View {

    let message: String
    let icon: String
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(Color.red)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - View Modifier for Error Handling
struct ErrorHandling: ViewModifier {

    @Binding var error: LyoError?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        ZStack {
            content

            if let error = error {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        self.error = nil
                    }

                ErrorView(
                    error: error,
                    onRetry: onRetry,
                    onDismiss: {
                        self.error = nil
                    }
                )
                .padding()
            }
        }
    }
}

extension View {
    func errorAlert(error: Binding<LyoError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorHandling(error: error, onRetry: onRetry))
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let requiresAuthentication = Notification.Name("requiresAuthentication")
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        ErrorView(
            error: .network(.noInternetConnection),
            onRetry: {},
            onDismiss: {}
        )

        ErrorView(
            error: .network(.unauthorized),
            onRetry: nil,
            onDismiss: {}
        )

        ErrorView(
            error: .ai(.quotaExceeded),
            onRetry: {},
            onDismiss: {}
        )
    }
}
