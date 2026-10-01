---
name: phase-gate
description: Use when deciding whether a Chelis phase is actually complete. Applies the repo’s completion standard, checks manual gates, examples, docs, and phase-specific acceptance criteria before any completion claim.
---

# Phase Gate

Use this skill when a phase is claimed complete or nearly complete.

## Acceptance Oracle

Before judging a phase, identify its single authoritative oracle:

- one command
- one named suite
- or one documented manual validation runner

Treat all other evidence as supporting material, not the completion decision itself.

## Completion Rule

Do not call the phase complete if any of these remain:

- broken default gate
- missing or ambiguous phase oracle
- hidden manual-only acceptance criteria not documented as such
- false-perfect machine-facing reports
- examples/docs whose meaning contradicts the actual implementation
<!-- shell-local:begin -->
<!-- shell-local:exclude:begin -->
<!-- ## Default Gate -->
<!-- ## Additional Required Checks -->
<!-- shell-local:exclude:end -->

## Coral Gate And Acceptance

Run the local gate documented in `CONTRIBUTING.md` with the compiler pinned
by `reef.toml`, then inspect applicable hosted CI on the exact candidate
head. For a phase-completion claim, also run the named acceptance oracle in
`spec/scope.md` and record any manual gates as separate evidence.
<!-- shell-local:end -->
