import Foundation

/// User-adjustable limits of an agent run and how it reports back
/// (Settings › General).
///
/// Read at the start of every run, so a change applies to the next run;
/// notification choices are read each time a session needs the user.
struct AgentSettings: Hashable, Sendable, Codable {
    /// Model calls per run before the run stops and asks the user to continue.
    var maxIterations: Int
    /// Seconds a single tool call may run before it is stopped.
    var toolTimeoutSeconds: Int
    /// Summarize earlier conversation with the model when it outgrows the
    /// context, instead of only dropping the oldest messages.
    var summarizesHistory = true
    /// Share of the model's prompt budget, in percent, a run may start with
    /// before earlier conversation is summarized (`HistoryCompaction`).
    var compactThresholdPercent = 50
    /// Post a notification when the agent answers or needs an approval while
    /// the user is not looking at the session.
    var showsNotifications = true
    /// Play a sound at the same moments, even while looking at the session.
    var playsSound = true
    /// The user's own instructions, added to the system prompt of every run,
    /// after the built-in prompt and before the project's instructions.
    var customInstructions = ""

    static let defaults = AgentSettings(maxIterations: 25, toolTimeoutSeconds: 30)
    static let maxIterationsRange = 5...100
    static let toolTimeoutChoices = [15, 30, 60, 120, 300]
    /// Lower summarizes more often, keeping more room for each run; higher
    /// keeps more messages verbatim. Above 80 %, a run would start with too
    /// little room for its own tool results.
    static let compactThresholdChoices = [30, 40, 50, 60, 70, 80]
    /// About 5K tokens: room for real guidance without eating a small context.
    static let maxCustomInstructionsCharacters = 20_000

    /// Brings values edited elsewhere (or saved by an older version) back in range.
    var clamped: AgentSettings {
        AgentSettings(
            maxIterations: min(max(maxIterations, Self.maxIterationsRange.lowerBound), Self.maxIterationsRange.upperBound),
            toolTimeoutSeconds: Self.nearest(toolTimeoutSeconds, in: Self.toolTimeoutChoices) ?? Self.defaults.toolTimeoutSeconds,
            summarizesHistory: summarizesHistory,
            compactThresholdPercent: Self.nearest(compactThresholdPercent, in: Self.compactThresholdChoices)
                ?? Self.defaults.compactThresholdPercent,
            showsNotifications: showsNotifications,
            playsSound: playsSound,
            customInstructions: String(customInstructions.prefix(Self.maxCustomInstructionsCharacters))
        )
    }

    private static func nearest(_ value: Int, in choices: [Int]) -> Int? {
        choices.min { abs($0 - value) < abs($1 - value) }
    }
}

extension AgentSettings {
    /// Decodes settings saved by any version of `agent.v1`; fields added
    /// later take their default.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxIterations = try container.decode(Int.self, forKey: .maxIterations)
        toolTimeoutSeconds = try container.decode(Int.self, forKey: .toolTimeoutSeconds)
        summarizesHistory = try container.decodeIfPresent(Bool.self, forKey: .summarizesHistory) ?? true
        compactThresholdPercent = try container.decodeIfPresent(Int.self, forKey: .compactThresholdPercent)
            ?? Self.defaults.compactThresholdPercent
        showsNotifications = try container.decodeIfPresent(Bool.self, forKey: .showsNotifications) ?? true
        playsSound = try container.decodeIfPresent(Bool.self, forKey: .playsSound) ?? true
        customInstructions = try container.decodeIfPresent(String.self, forKey: .customInstructions) ?? ""
    }
}
