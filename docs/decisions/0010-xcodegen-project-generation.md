# 0010: Generate the Xcode project with XcodeGen

**Status:** Accepted

## Context
Hand-edited `.pbxproj` files cause merge conflicts and are hard to review, especially when
agents add files. Feature-first tests must be excluded from the app target and included in the
test target by pattern.

## Decision
Describe targets, settings and schemes in `project.yml`. Generate `LocalOSXAi.xcodeproj` with
XcodeGen (`make generate`), and do not commit it. Glob patterns send `**/Tests/**` to the test
target only. Build settings enforce Swift 6, complete strict concurrency and warnings as errors.

## Alternatives
- **Committed .xcodeproj**: no tool needed, but noisy diffs and conflicts.
- **Pure Swift Package for the app**: awkward for app bundles, resources, Info.plist and signing.
- **Tuist**: more powerful, but heavier than needed today.

## Consequences
- Contributors need `brew install xcodegen`, and must regenerate after adding files.
- Project configuration is reviewable text.
