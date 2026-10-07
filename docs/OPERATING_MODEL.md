# Operating Model

## Team structure

### Commander
Owns priorities, product decisions, gate approval, conflict resolution, and final merge/ship decisions.

### Team R — Research & Platform Feasibility
Owns evidence gathering. First mission: prove Brave/ChatGPT automation on the user's Mac and verify dependency support.

### Team P — Proposal / RFC
Turns Commander intent and Research evidence into candidate architecture/RFCs. Does not implement production code.

### Team C — Contract & Protocol
Defines message envelopes, chat registry schema, routing semantics, debate state machine, error/retry semantics, and Commander/agent authority boundaries.

### Team V — Validation & Gate
Adversarially audits proposals/contracts, writes executable acceptance criteria, performs repeated audition/revision, and publishes immutable versioned validation gates.

### Team I — Implementation
Implements only against Commander-approved, locked contracts/gates. Cannot edit locked gate artifacts.

### Team E — Engineering & Integration
Owns CLI packaging, macOS integration, process lifecycle, logging, local test runner, dependency checks, and integration across browser/router/state components.

### Team S — Supervision / Red Team
Independently checks scope, security, gate integrity, evidence quality, regressions, and whether consensus is real rather than asserted.

## Mandatory debate pattern

Each significant work item gets at least:
- owner/candidate;
- independent challenger;
- revision;
- re-review;
- consensus record;
- Commander decision.

For implementation, Team I presents evidence; Team V attempts to break it against the locked gate; Team S independently checks both. Material defects return to implementation. Contract defects go back to Team C/V as a new gate version; implementation does not patch the gate itself.

## Suggested first phases

### Phase 0 — Feasibility
Prove local Brave control and ChatGPT text send/receive. Determine permissions and dependency support on the user's Mac.

### Phase 1 — Contracts
Freeze authority model, chat registry, transport envelope, routing rules, debate protocol, error handling, and gate-lock format.

### Phase 2 — Minimal vertical slice
One CLI command routes one prewritten Commander message to one known ChatGPT chat and retrieves one response.

### Phase 3 — Multi-agent debate
Route a work item through candidate/challenge/revision/re-review with GitHub logging.

### Phase 4 — Dual-project coordination
Support Diet Tracking and Door Access chat registries, issue bindings, and project-specific validation commands.

### Phase 5 — Hardening
Crash recovery, duplicate-send prevention, idempotency, tab churn, renamed chats, stale response detection, permission loss, redaction, and audit replay.
