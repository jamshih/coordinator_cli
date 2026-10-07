# AGENTS.md

## Authority

The Commander is the product manager and final decision-maker.

The Coordinator CLI is a transport/orchestration layer only. It may route, schedule, record, compare status, and enforce workflow constraints. It must not create new product requirements or silently reinterpret Commander instructions.

## Required behavior for every agent

- Claim or clearly identify the GitHub issue/work item before starting.
- Read the relevant repository contracts and prior discussion.
- Log substantive findings, decisions, blockers, evidence, and handoffs on GitHub.
- Keep transmissions concise but specific.
- Accept normal grammar errors in incoming messages; do not intentionally introduce errors.
- Run required validation locally on the user's Mac unless a work item explicitly says otherwise.
- Check that proposed dependencies and automation methods support the user's local macOS environment, including Apple Silicon where applicable.
- Do not treat GitHub Actions as the required validation authority for this project.

## Debate rule

For every proposal, contract, implementation, or review session:

1. The owner states its candidate and evidence.
2. At least one independent challenger attempts to falsify it.
3. The owner answers each material objection.
4. The challenger re-reviews the revised candidate.
5. Continue until there are no material unresolved objections.
6. If consensus cannot be reached safely, record the exact disagreement and escalate to the Commander. Agents do not resolve product-policy disputes by assumption.

Consensus is evidence for the Commander; it does not replace Commander approval.

## Locked validation gates

Validation owns the validation contract and gate lifecycle.

- Implementation agents may consume a locked gate but may not edit it.
- A locked gate is versioned and immutable.
- Changes require a new gate version, a fresh Validation review, and Commander approval.
- Supervisor must verify the gate hash/version before accepting implementation evidence.

## Chat handling

The coordinator should use:
- human-readable chat title for discovery/indexing;
- canonical conversation URL/ID as the stable target after discovery;
- project + team + work-item metadata to disambiguate similarly named chats.

The coordinator must send Commander-approved task text and agent handoffs verbatim except for transport wrappers/metadata defined by the protocol.
