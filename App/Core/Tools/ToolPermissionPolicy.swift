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
/// Rules (docs/security/permissions.md):
/// - reading inside the project is allowed, except files that commonly hold
///   secrets, which require approval;
/// - writing files requires approval;
/// - commands are classified by `CommandPolicy`: read-only and test commands
///   run, others require approval, dangerous ones are blocked.
struct ToolPermissionPolicy: Sendable {
    var commands = CommandPolicy()
    /// The project's command rules, set for each run.
    var commandRules = CommandRules()

    /// File name patterns treated as secrets. Matched case-insensitively on
    /// the last path component.
    static let sensitiveFilePatterns = [
        ".env", ".env.*", "*.pem", "*.key", "*.p12", "*.pfx", "id_rsa*", "id_ed25519*", "id_ecdsa*",
        ".npmrc", ".netrc", ".pypirc", "*.keystore", "credentials*", "secrets.*"
    ]

    func permission(for tool: any AgentTool, arguments: ToolArguments, projectRoot: URL) -> ToolPermission {
        switch tool.effect {
        case .readOnly:
            if let path = arguments.values["path"]?.stringValue, Self.isSensitive(path: path) {
                return .requiresApproval(reason: "This file may contain secrets.")
            }
            return .allowed
        case .writesFiles:
            return .requiresApproval(reason: "This changes files in your project.")
        case .executesCommands:
            guard let command = arguments.values["command"]?.stringValue else {
                return .requiresApproval(reason: "This runs a command on your Mac.")
            }
            switch commands.decision(for: command, projectRoot: projectRoot, rules: commandRules) {
            case .allowed: return .allowed
            case .requiresApproval(let reason): return .requiresApproval(reason: reason)
            case .blocked(let reason): return .blocked(reason: reason)
            }
        }
    }

    static func isSensitive(path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        return sensitiveFilePatterns.contains { fnmatch($0, name, 0) == 0 }
    }
}
