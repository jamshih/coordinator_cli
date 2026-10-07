# Architecture

## System boundary

`coordinator_cli` runs locally in the user's terminal on macOS and coordinates browser-based ChatGPT agent sessions in Brave.

It does not replace the Commander and does not autonomously define product direction.

## Components

### 1. CLI shell

Responsibilities:
- start/stop coordinator sessions;
- show project/work-item state;
- list known chats;
- request routing;
- show pending agent responses;
- trigger local validation workflows;
- persist an auditable local event log.

### 2. Chat Registry

Stores, at minimum:
- project: `diet_tracking` or `door-access`;
- human chat title;
- role/team;
- work-item/issue;
- conversation URL/ID when known;
- tab/window locator when live;
- status: active / waiting / blocked / archived;
- last-seen timestamp.

Title matching is for human-friendly indexing. Conversation URL/ID is canonical once learned.

### 3. Brave Adapter

Must be proven on the user's Mac before implementation is locked.

Candidate mechanisms to evaluate:
- Chromium DevTools Protocol / Playwright connection to Brave launched with remote debugging;
- Brave/Chromium AppleScript support for tab discovery;
- macOS Accessibility/UI scripting as a fallback for copy/paste and tab control.

The Research/Platform team must test which combination can:
- enumerate open Brave windows/tabs;
- read ChatGPT tab title + URL;
- focus a specific conversation;
- open a new ChatGPT tab/chat;
- paste a supplied message;
- submit;
- retrieve the latest assistant response reliably;
- survive renamed chats and reordered tabs.

Do not assume an existing normally launched Brave instance is CDP-attachable. Verify the launch/permission model locally.

### 4. Router

The router may classify a Commander-approved work item into a known team/chat using registry metadata. It may not invent a new product task or rewrite the substantive prompt.

Preferred routing inputs:
- explicit project;
- GitHub issue/work-item ID;
- requested team/role;
- chat title aliases;
- session state.

Ambiguity must be surfaced to the Commander rather than guessed.

### 5. Transport Envelope

Every routed message should carry machine metadata separate from the human text:
- message/session ID;
- project;
- work item;
- from role;
- to role/chat;
- message type;
- parent message;
- timestamp;
- content hash.

The human text is transported unchanged unless the Commander explicitly requests a rewrite.

### 6. Debate Orchestrator

State machine:

`ASSIGNED -> CANDIDATE -> CHALLENGE -> REVISION -> RE_REVIEW -> CONSENSUS_PENDING -> COMMANDER_DECISION`

If material disagreement remains, continue the review loop or escalate with a concise disagreement record. No implementation should treat unresolved debate as approval.

### 7. Gate Store

Locked validation artifacts should use versioned paths, for example:

`contracts/<work-item>/v1/GATE.md`
`contracts/<work-item>/v1/gate.lock.json`

The lock record should include:
- work item;
- gate version;
- source commit/SHA;
- file hashes;
- Validation approval;
- Commander approval;
- timestamp.

Implementation must be rejected if it modifies a locked gate or validates against a different hash.

### 8. Local Validation Runner

All required checks execute on the user's Mac. The runner should:
- detect architecture/macOS/tool versions;
- verify declared dependencies are available;
- execute project-specific commands;
- capture stdout/stderr/exit code;
- store a machine-readable result;
- post a concise evidence summary to GitHub.

Required validation must not rely on GitHub Actions.

## Security and privacy constraints

- Do not store ChatGPT cookies/tokens in the repository.
- Prefer using the user's existing logged-in browser session.
- Keep browser-control permissions local.
- Treat Accessibility, Automation, and remote-debugging permissions as sensitive capabilities.
- Redact secrets from logs before GitHub posting.
- Never paste secrets into agent chats unless explicitly required and approved.
