# Team R Brave/ChatGPT feasibility POC

Research-only throwaway POC for GitHub Issue #2. It deliberately uses only macOS built-ins: `osascript` + Brave's Chromium AppleScript surface.

## Candidate

**AppleScript for tab/window discovery and activation + Brave's built-in JavaScript-from-Apple-Events for ChatGPT DOM reads/actions.**

After initial discovery by human-readable title, use the exact ChatGPT conversation URL as the canonical target. Re-scan current windows/tabs each operation; do not persist tab indices.

No CDP port, separate browser profile, Playwright install, daemon, service, database, queue, or extension is required for this POC.

## One-time Brave setting

In Brave:

`View -> Developer -> Allow JavaScript from Apple Events`

macOS may also ask whether Terminal (or the eventual CLI host) may control Brave. Approve that under:

`System Settings -> Privacy & Security -> Automation`

This POC does **not** require Accessibility permission unless a later fallback uses `System Events` UI scripting.

## Environment capture

Run these locally on the target Mac:

```bash
sw_vers
uname -m
"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --version
osascript -e 'tell application "Brave Browser" to get version'
command -v osascript
node --version 2>/dev/null || true
python3 --version 2>/dev/null || true
```

Node and Python are informational only; the POC does not require either.

## Read-only smoke checks

```bash
osascript research/brave_chatgpt_poc.applescript doctor
osascript research/brave_chatgpt_poc.applescript list-chatgpt
osascript research/brave_chatgpt_poc.applescript activate-title "Diet Team B"
osascript research/brave_chatgpt_poc.applescript latest-title "Diet Team B"
```

Expected `list-chatgpt` columns:

`window_index<TAB>tab_index<TAB>title<TAB>url`

Copy the URL for a discovered chat, then prove canonical targeting:

```bash
CHAT_URL='https://chatgpt.com/c/...'
osascript research/brave_chatgpt_poc.applescript activate-url "$CHAT_URL"
osascript research/brave_chatgpt_poc.applescript latest-url "$CHAT_URL"

# Close that tab, then prove the canonical URL can reacquire it:
osascript research/brave_chatgpt_poc.applescript ensure-url "$CHAT_URL"
```

Reorder Brave tabs and repeat `activate-url`; the POC re-scans all windows/tabs, so tab order should not matter.

Rename the ChatGPT chat and repeat `activate-url`; the canonical URL should continue to target the same conversation even though the human title changed. Re-run `list-chatgpt` to discover the new title.

## Non-sensitive send/receive proof

Use a dedicated test chat or another chat where this harmless probe is acceptable:

```bash
CHAT_URL='https://chatgpt.com/c/...'
osascript research/brave_chatgpt_poc.applescript send-url "$CHAT_URL" "TEAM_R_POC_TEST_20261007 — reply only with POC_OK"
```

The command refuses to send if:
- the canonical URL resolves to zero or multiple open tabs when using send-url;
- the target is not `chatgpt.com`;
- ChatGPT is already generating;
- the composer already contains a draft;
- the pasted text does not exactly match the supplied argument;
- the send button is not ready;
- the newly submitted user turn cannot be verified.

It snapshots user/assistant turn counts before Send, waits for a *new* assistant turn, waits for generation to become idle, then returns the latest visible assistant text.

For discovery-only testing, `send-title` also exists, but URL targeting is the intended post-discovery path.

## Open-new-chat proof

```bash
osascript research/brave_chatgpt_poc.applescript new-chat
```

A brand-new chat begins at `https://chatgpt.com/`. A stable conversation URL/ID is only useful after ChatGPT creates the conversation. Production code should capture the page URL after the first successful send and persist that exact URL as the canonical registry value.

## Evidence to record locally

Paste the exact stdout/stderr and exit status into Issue #2 for:

1. environment capture;
2. `doctor`;
3. `list-chatgpt`;
4. title activation;
5. canonical-URL activation before/after tab reorder;
6. canonical-URL activation before/after chat rename;
7. close the tab and reacquire it with `ensure-url`;
8. harmless send/receive probe;
9. one intentional duplicate-title failure, if easy to create;
10. one non-empty-draft refusal;
11. one send-while-generating refusal.

Do not post unrelated tab URLs, private chat contents, cookies, tokens, or secrets.

## Known POC limitations

- ChatGPT DOM selectors can change. This POC uses semantic/stable-looking attributes where possible (`#prompt-textarea`, `data-message-author-role`, `data-testid`) but must be re-tested against the live site.
- Completion detection uses a new-turn baseline plus ChatGPT's stop-button state. Tool-heavy/rich responses may need stronger production logic.
- Latest-response extraction returns visible text, not a lossless reconstruction of every rich widget/artifact.
- `set the clipboard` replaces the current clipboard contents. Production code should decide whether/how to preserve and restore it.
- Crash/restart duplicate-send semantics are intentionally not solved in this feasibility POC; Team C should define message identity/idempotency before production implementation.
- The Apple Events permission is powerful: a permitted local process can inspect/execute JavaScript in browser pages. Production must restrict itself to `chatgpt.com`, minimize logs, and never expose this as a network service.
- This branch is evidence scaffolding, not production architecture.

## Token estimate V0

Do not add a tokenizer dependency for the first slice. Store exact visible character counts and a clearly labeled rough token estimate:

`estimated_tokens_v0 = ceil(character_count / 4)`

Record the estimator name/version and `authoritative: false`. This is intentionally approximate. A tokenizer can be added later only if multilingual/code estimation error becomes materially useful.
