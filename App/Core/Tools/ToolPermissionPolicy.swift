import Foundation

/// The policy decision for one tool call.
enum ToolPermission: Hashable, Sendable {
    case allowed
    case requiresApproval(reason: String)
    case blocked(reason: String)
}

/// Decides whether a tool call may run, from the tool's declared effect and
/// its arguments. Tools never decide their own permission.
///
/// Phase 3 rules (docs/security/permissions.md):
/// - reading inside the project is allowed, except files that commonly hold
///   secrets, which require approval;
/// - writing files requires approval;
/// - running commands requires approval (refined by the command policy in Phase 4).
struct ToolPermissionPolicy: Sendable {
    /// File name patterns treated as secrets. Matched case-insensitively on
    /// the last path component.
    static let sensitiveFilePatterns = [
        ".env", ".env.*", "*.pem", "*.key", "*.p12", "*.pfx", "id_rsa*", "id_ed25519*", "id_ecdsa*",
        ".npmrc", ".netrc", ".pypirc", "*.keystore", "credentials*", "secrets.*"
    ]

    func permission(for tool: any AgentTool, arguments: ToolArguments) -> ToolPermission {
        switch tool.effect {
        case .readOnly:
            if let path = arguments.values["path"]?.stringValue, Self.isSensitive(path: path) {
                return .requiresApproval(reason: "This file may contain secrets.")
            }
            return .allowed
        case .writesFiles:
            return .requiresApproval(reason: "This changes files in your project.")
        case .executesCommands:
            return .requiresApproval(reason: "This runs a command on your Mac.")
        }
    }

    static func isSensitive(path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        return sensitiveFilePatterns.contains { fnmatch($0, name, 0) == 0 }
    }
}
