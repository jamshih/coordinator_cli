# Validation Gate Protocol

## Goal

Create acceptance contracts that implementation cannot weaken after work begins.

## Gate lifecycle

`DRAFT -> AUDITION -> REVISION -> RE-AUDIT -> LOCK_CANDIDATE -> COMMANDER_APPROVED -> LOCKED`

Validation must actively attempt to break the candidate with negative cases before lock.

## Required gate contents

Each gate must define:
- exact scope and non-goals;
- inputs/outputs;
- invariants;
- failure behavior;
- negative/adversarial cases;
- local macOS validation commands;
- expected evidence;
- dependency/platform requirements;
- files/components implementation is allowed to change;
- files/components implementation is forbidden to change.

## Locking

When approved:
- copy the final gate to a versioned immutable directory;
- compute cryptographic hashes for gate artifacts;
- record source commit and approvals in `gate.lock.json`;
- post the gate version/hash to the GitHub work item.

A locked gate is never edited in place.

## Implementation rule

Team I must:
- declare the exact gate version/hash before coding;
- run the gate locally on the user's Mac;
- attach results;
- prove no locked artifact changed.

If implementation discovers a bad requirement, it must file a gate-change request. Team V creates and re-audits a new version; the Commander decides whether to adopt it.

## Supervisor rule

Team S rejects a completion claim when:
- the gate hash differs;
- required local commands were not run;
- evidence is missing or stale;
- implementation changed a locked contract;
- a material objection was skipped;
- the result depends on GitHub Actions instead of the required local Mac checks.
