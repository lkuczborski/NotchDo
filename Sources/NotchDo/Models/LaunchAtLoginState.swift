enum LaunchAtLoginState: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable

    var isRequested: Bool {
        self == .enabled || self == .requiresApproval
    }

    var detail: String {
        switch self {
        case .notRegistered:
            "NotchDo won’t open automatically."
        case .enabled:
            "NotchDo opens automatically when you log in."
        case .requiresApproval:
            "Approval is required in System Settings › General › Login Items."
        case .unavailable:
            "Launch at Login isn’t available for this copy of NotchDo."
        }
    }
}
