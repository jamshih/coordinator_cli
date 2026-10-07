# coordinator_cli

Local-first CLI coordinator for routing work between the Commander and specialist ChatGPT agent chats in Brave on macOS.

## Purpose

The coordinator is a bridge, not the product manager.

- The **Commander** owns product decisions, priorities, approvals, and final merge/ship decisions.
- The **Coordinator CLI** discovers/opens the correct Brave/ChatGPT chat, transports messages, records state, and enforces workflow rules.
- Specialist agents research, propose, challenge, implement, validate, and supervise work for the Diet Tracking and Door Access projects.
- The coordinator must **not invent prompts, product requirements, or decisions**. It transports Commander-approved task payloads and agent responses.

## Core workflow

1. Commander creates/approves a work item.
2. Coordinator selects the correct project + chat from the chat registry.
3. Relevant specialist agents independently inspect the task.
4. Agents debate findings and proposed changes.
5. Proposal/contract is revised until consensus or explicitly escalated to the Commander.
6. Validation Team auditions the contract and locks an immutable validation gate.
7. Implementation Team works against the locked gate and may not edit it.
8. Engineering + Validation run all required checks locally on the user's Mac.
9. Supervisor independently checks evidence, scope, gate integrity, and consensus record.
10. Commander makes the final decision.

## Global operating rules

- Local macOS validation is authoritative for this project. Do not depend on GitHub Actions for required validation.
- Before selecting dependencies, verify local macOS/Apple Silicon support and Brave compatibility.
- Messages between chats should be concise, specific, and tolerant of ordinary grammar mistakes. Do not deliberately add mistakes.
- Every agent session must log meaningful work to GitHub.
- Human-readable ChatGPT chat titles are used for indexing; stable conversation URLs/IDs should be stored once discovered.
- No specialist agent may silently change another team's locked contract.
- If a locked gate needs revision, create a new version and send it back through Validation + Commander approval.

See:
- `AGENTS.md`
- `docs/ARCHITECTURE.md`
- `docs/OPERATING_MODEL.md`
- `docs/VALIDATION_GATE_PROTOCOL.md`
