# 0003: Feature-first organization

**Status:** Accepted

## Context
A layer-first layout (`Views/`, `ViewModels/`, `Services/` at the root) scatters each feature
across the tree and tends to grow a global `Services/` folder that holds all business logic.

## Decision
Organize by domain: `App/Features/<Feature>/{Models,Views,ViewModels,Services,Components,Tests}`.
Cross-cutting contracts live in `Core`, reusable UI in `Shared`, and technology implementations
in `Infrastructure`. Feature tests sit next to the feature and are compiled only into the test
target.

## Alternatives
- **Layer-first**: familiar, but poor locality and an unclear ownership of logic.
- **One Swift package per feature**: compiler-enforced boundaries, but heavy for the current
  size (see ADR 0012).

## Consequences
- A change to a feature usually touches one folder.
- Cross-feature dependencies must be managed explicitly. The rule is one direction, on models
  only, with coordination in Workspace.
