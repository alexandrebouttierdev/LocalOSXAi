# 0029: The user's system prompt adds to the built-in one

**Status:** Accepted

## Context
Users want to give the agent standing instructions (language, style, rules) without writing
them in every project's AGENTS.md. The built-in system prompt carries the tool-use rules
(read before editing, write long files in steps, respect denied approvals) that local models
need to use tools well.

## Decision
- Settings › System Prompt holds **the user's instructions**, stored with the agent settings
  (`AgentSettings.customInstructions`, UserDefaults: not a secret), at most 20,000 characters.
- They are **added after the built-in prompt** under “# Instructions from the user”, and
  **before the project's instructions**, which are more specific and so come last.
- The page shows the built-in prompt read-only, so the user sees what they add to.
- Read with the other settings at the start of each run: an edit applies to the next message.

## Alternatives
- **Replace the built-in prompt**: full control, but one edit can remove the tool rules and the
  agent then misuses tools on local models; the failures would look like app bugs.
- **Per-project only (AGENTS.md)**: already exists; standing preferences would be copied into
  every project.

## Consequences
- Instructions use context in every request; the page shows their estimated tokens.
- A user instruction can still contradict a built-in rule; tool calls stay validated and the
  permission policy still applies, whatever the prompt says.
