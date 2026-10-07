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

## Reopen verification repair

The earlier `ensure-url` implementation created a tab, waited one fixed second, and returned the original AppleScript `newTab` object's title/URL without proving that the tab still existed in Brave.

That produced a false-positive local result: the command printed the requested canonical URL even though a subsequent full tab scan found no such tab.

The repaired `ensure-url` now:

- creates the requested canonical URL;
- records the new Brave tab's unique tab ID;
- polls every 250 ms for up to 10 seconds;
- rescans **all** Brave windows/tabs on every poll;
- tracks the created tab by ID while navigation occurs;
- succeeds only when exactly one tab has the requested canonical URL, that exact tab is the created tab, and its `loading` state is false;
- fails closed if the created tab disappears/replaces, redirects and settles elsewhere, the canonical URL appears in another tab, duplicate exact matches appear, or verification times out.

The failure text includes the last observed URL/loading state where available so the local retest can distinguish redirect vs replacement/closure.

### Exact reopen retest

Start from a currently open known chat:

```bash
CHAT_URL='https://chatgpt.com/c/...'

osascript research/brave_chatgpt_poc.applescript activate-url "$CHAT_URL"
```

Close that exact chat tab manually, then run:

```bash
osascript research/brave_chatgpt_poc.applescript ensure-url "$CHAT_URL"
osascript research/brave_chatgpt_poc.applescript activate-url "$CHAT_URL"
osascript research/brave_chatgpt_poc.applescript list-chatgpt | grep -F "$CHAT_URL"
```

Then wait three seconds and verify again:

```bash
sleep 3
osascript research/brave_chatgpt_poc.applescript activate-url "$CHAT_URL"
osascript research/brave_chatgpt_poc.applescript list-chatgpt | grep -F "$CHAT_URL"
```

If `ensure-url` fails, preserve its exact stderr. Its diagnostic should identify whether the created tab disappeared/replaced, redirected to a different final URL, became ambiguous, or timed out while still loading.

## Tab-mutation scan repair

A second local retest exposed a narrower race in the first reopen-verification repair.

Observed failure:

```text
Brave Browser got an error:
Can’t get tab 9 of window 1. Invalid index. (-1719)
```

Root cause: the verification logic correctly used stable Brave tab ID for identity, but the scanner still enumerated the live tab list with numeric indices. Brave/ChatGPT may replace, close, or reorder tabs while navigation is in progress, so a previously valid upper bound can become stale before `tab ti of window wi` is read.

The repaired verification path keeps numeric indices only as ephemeral scan metadata. Identity remains:

- stable Brave tab ID for the created tab;
- exact canonical ChatGPT URL.

Each 250 ms poll now performs one combined verification scan that collects both:
- exact canonical-URL matches;
- created-tab-ID matches.

If Brave raises AppleScript invalid-index error `-1719` anywhere during that scan, the **entire scan snapshot is discarded**. No conclusion is drawn from partial data. The existing outer 40-poll / 10-second bound then rescans current Brave state.

All other errors still propagate. Existing fail-closed rules for disappearance/replacement, redirect ambiguity, duplicate exact matches, and timeout remain unchanged.

### Exact tab-mutation retest

```bash
git fetch origin team-r/brave-feasibility-poc
git switch --detach 7d40bfea861e4ef80c478695be58c6ce585be1c4

CHAT_URL='https://chatgpt.com/c/...'

osascript research/brave_chatgpt_poc.applescript activate-url "$CHAT_URL"
```

Close that exact tab manually, then:

```bash
osascript research/brave_chatgpt_poc.applescript ensure-url "$CHAT_URL"

osascript research/brave_chatgpt_poc.applescript activate-url "$CHAT_URL"
osascript research/brave_chatgpt_poc.applescript list-chatgpt | grep -F "$CHAT_URL"

sleep 3

osascript research/brave_chatgpt_poc.applescript activate-url "$CHAT_URL"
osascript research/brave_chatgpt_poc.applescript list-chatgpt | grep -F "$CHAT_URL"
```

The acceptance condition is unchanged: `ensure-url` may succeed only after a single durable exact canonical-URL match exists for the stable created-tab ID. A transient `-1719` must be absorbed as a discarded scan, not returned to the caller and not treated as evidence of success.

## Team S final-blocker repair

The final Team S review of candidate `6c50be45630ed439fe74f2ae11609041ec30a975` found three remaining code-level blockers. The revised POC keeps the same AppleScript + Brave JavaScript-from-Apple-Events architecture and changes only identity/correlation checks.

### 1. Canonical content operations re-verify active identity

Canonical lookup records include the stable Brave tab ID and exact canonical ChatGPT URL. Captured numeric window/tab indices may be used only as a best-effort focus hint.

Before JavaScript content access, clipboard paste, or Send click, the POC now re-checks the **active Brave tab object** and requires both:

- stable Brave tab ID equals the expected tab ID;
- URL equals the exact expected canonical conversation URL.

Any ID mismatch, URL mismatch, missing tab/window, or tab mutation fails closed. A stale numeric index is never authorization for read/send.

### 2. Title-only content operations are disabled

Titles remain discovery/indexing metadata.

- `activate-title` remains available as a discovery/focus aid.
- `latest-title` now fails with an instruction to use `latest-url`.
- `send-title` now fails with an instruction to use `send-url`.

Real content reads and sends therefore require canonical URL binding.

### 3. sendAndWait retains user-turn ownership

After the submitted user turn is verified, the POC captures the exact visible user-turn sequence as JSON plus the expected user-turn count.

During every response-wait poll it now requires:

- user-turn count remains exactly baseline + 1;
- the complete visible user-turn sequence remains byte-for-byte unchanged;
- stable Brave tab ID and exact canonical URL remain verified before each DOM observation.

If another user turn appears, a tracked user turn changes, or canonical ownership changes, the POC aborts and refuses to return the latest assistant response.

### Exact local validation

Checkout the immutable candidate SHA recorded on Issue #2, then set a disposable/safe canonical ChatGPT test conversation URL:

```bash
cd ~/coordinator_cli
git fetch origin team-r/brave-feasibility-poc
git switch --detach <IMMUTABLE_SHA>

CHAT_URL='https://chatgpt.com/c/...'
```

Syntax and identity smoke:

```bash
osacompile -o /tmp/team-r-poc.scpt research/brave_chatgpt_poc.applescript
osascript research/brave_chatgpt_poc.applescript activate-url "$CHAT_URL"
osascript research/brave_chatgpt_poc.applescript latest-url "$CHAT_URL"
```

Title-only content operations must fail:

```bash
osascript research/brave_chatgpt_poc.applescript latest-title "Some Chat Title"
osascript research/brave_chatgpt_poc.applescript send-title "Some Chat Title" "MUST_NOT_SEND"
```

Harmless send/receive:

```bash
TEST_TEXT='TEAM_R_POC_SEND_TEST_20261007 — reply only with POC_OK'
osascript research/brave_chatgpt_poc.applescript send-url "$CHAT_URL" "$TEST_TEXT"
```

Acceptance evidence must show the supplied text was submitted once and the corresponding completed assistant response was returned.

Additional live checks:

- create a non-empty composer draft, then verify `send-url` refuses without overwriting/sending it;
- while ChatGPT is generating, verify a second `send-url` refuses with the busy-state guard where practical;
- after a tracked send is accepted, introduce an additional/manual user turn before response extraction and verify the original invocation aborts with a manual/concurrent-interference error rather than returning a later assistant response.

These are POC validation steps only; no queue, daemon, service, database, Playwright, CDP, or Accessibility dependency is introduced.

## Current ChatGPT DOM compatibility observed during local validation

While preparing the required live send/receive proof, the current ChatGPT page on the Commander's Mac exposed newer DOM markers than the original POC selectors:

- Send button: `button[aria-label="Send"]`;
- active generation control: `button[aria-label="Stop"]`;
- user message bubble: `[data-user-message-bubble="true"]`;
- assistant response unit: an `h4[data-conversation-role="assistant"]` marker inside the assistant unit.

The POC now keeps the original selectors and adds these as narrow fallbacks. This is compatibility maintenance only; it does not change canonical identity, routing, polling, or correlation semantics.

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
