import Foundation

/// User-adjustable limits of an agent run (Settings › General).
///
/// Read at the start of every run, so a change applies to the next run.
struct AgentSettings: Hashable, Sendable, Codable {
    /// Model calls per run before the run stops and asks the user to continue.
    var maxIterations: Int
    /// Seconds a single tool call may run before it is stopped.
    var toolTimeoutSeconds: Int

    static let defaults = AgentSettings(maxIterations: 25, toolTimeoutSeconds: 30)
    static let maxIterationsRange = 5...100
    static let toolTimeoutChoices = [15, 30, 60, 120, 300]

    /// Brings values edited elsewhere (or saved by an older version) back in range.
    var clamped: AgentSettings {
        AgentSettings(
            maxIterations: min(max(maxIterations, Self.maxIterationsRange.lowerBound), Self.maxIterationsRange.upperBound),
            toolTimeoutSeconds: Self.toolTimeoutChoices.min { abs($0 - toolTimeoutSeconds) < abs($1 - toolTimeoutSeconds) }
                ?? Self.defaults.toolTimeoutSeconds
        )
    }
}
