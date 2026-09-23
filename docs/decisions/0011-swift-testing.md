# 0011: Swift Testing for all tests

**Status:** Accepted

## Context
Tests cover async code, actors and `@MainActor` ViewModels, and many are table-driven.

## Decision
Use Swift Testing (`@Suite`, `@Test`, `#expect`, `#require`, parameterized `arguments:`,
`.timeLimit`). Tests are hosted by the app, whose entry point starts an empty scene under test
so application startup has no side effects.

## Alternatives
- **XCTest**: mature, but more verbose, and weaker for async and parameterized tests.
  UI tests (XCUITest) may still be added later for smoke flows, since Swift Testing does not
  cover UI automation.

## Consequences
- Expressive failure messages (`#expect` captures values) and cheap parameterized cases.
- Requires Xcode 16+, which is already a project requirement.
