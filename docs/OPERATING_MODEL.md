# Operating Model

## Simplicity first

This is a small personal side project, not an enterprise orchestration platform.

Every team should ask: **what is the smallest thing that solves the current problem reliably?**

Reject speculative abstractions and infrastructure. Build the minimum vertical slice first and add machinery only when evidence shows it is necessary.

## Team structure

### Commander
Owns priorities, product decisions, gate approval, conflict resolution, and final merge/ship decisions.

### Team R — Research & Platform Feasibility
Owns evidence gathering. First mission: prove Brave/ChatGPT automation on the user's Mac and verify dependency support.

### Team P — Proposal / RFC
Turns Commander intent and Research evidence into candidate architecture/RFCs. Does not implement production code.

### Team C — Contract & Protocol
Defines only the contracts needed for current implementation: message transport, chat registry/routing, debate state, error/retry behavior, and Commander/agent authority boundaries.

### Team V — Validation & Gate
Adversarially audits proposals/contracts, writes executable acceptance criteria, performs repeated audition/revision, and publishes immutable versioned validation gates.

### Team I — Implementation
Implements only against Commander-approved, locked contracts/gates. Cannot edit locked gate artifacts.

### Team E — Engineering & Integration
Owns CLI packaging, macOS integration, process lifecycle, logging, local test runner, dependency checks, lightweight usage tracking, and integration across browser/router/state components.

### Team S — Supervision / Red Team
Independently checks scope, security, gate integrity, evidence quality, regressions, overengineering, and whether consensus is real rather than asserted.

## Mandatory debate pattern

Each significant work item gets at least:
- owner/candidate;
- independent challenger;
- revision when needed;
- re-review;
- consensus record;
- Commander decision.

The debate should be proportionate. Do not create ceremony for trivial changes.

For implementation, Team I presents evidence; Team V attempts to break it against the locked gate; Team S independently checks both. Material defects return to implementation. Contract defects go back to Team C/V as a new gate version; implementation does not patch the gate itself.

## Suggested first phases

### Phase 0 — Feasibility
Prove local Brave control and ChatGPT text send/receive. Determine permissions, dependency support, and the simplest viable browser-control method on the user's Mac.

### Phase 1 — Minimal contracts
Freeze only what the first slice needs: authority boundary, minimal chat registry, transport rules, basic error handling, and gate lock.

### Phase 2 — Minimal vertical slice
One CLI command routes one prewritten Commander message to one known ChatGPT chat, retrieves one response, and records lightweight usage.

### Phase 3 — Multi-agent debate
Route a work item through candidate/challenge/revision/re-review with GitHub logging.

### Phase 4 — Dual-project coordination
Support Diet Tracking and Door Access chat registries, issue bindings, and project-specific local validation commands.

### Phase 5 — Hardening only as needed
Add crash recovery, duplicate-send prevention, renamed-chat recovery, stale-response detection, permission recovery, or stronger persistence only when testing demonstrates the need.
