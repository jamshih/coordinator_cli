# Team R Brave/ChatGPT feasibility POC

Research-only throwaway POC for GitHub Issue #2. It deliberately uses only macOS built-ins: `osascript` + Brave's Chromium AppleScript surface.

## Why this candidate

The POC targets the already logged-in Brave session. It does not enable a DevTools TCP port, copy cookies, launch a second browser profile, install Playwright, or introduce a daemon/service.

It exercises:
- enumerate Brave tabs;
- print ChatGPT title + URL;
- select and activate a unique ChatGPT tab by human title;
- open a new ChatGPT tab;
- paste a caller-supplied string without rewriting it;
- refuse to overwrite an existing composer draft;
- verify the pasted text before clicking Send;
- wait for a new assistant response;
- retrieve the latest visible assistant text.

Title matching is intentionally fail-closed: zero or multiple matches are errors. Once a conversation URL is discovered, production code should store that URL as the canonical target and use title only for discovery/recovery.

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

## Read-only smoke checks

```bash
osascript research/brave_chatgpt_poc.applescript doctor
osascript research/brave_chatgpt_poc.applescript list-chatgpt
osascript research/brave_chatgpt_poc.applescript activate-title "Diet Team B"
osascript research/brave_chatgpt_poc.applescript latest-title "Diet Team B"
```

Expected `list-chatgpt` columns:

`window_index<TAB>tab_index<TAB>title<TAB>url`

Reorder Brave tabs, rerun `list-chatgpt`, and verify title selection still activates the intended conversation.

Rename a ChatGPT chat, wait for the tab title to update, rerun `list-chatgpt`, and verify the new title is discoverable. The canonical conversation URL should remain the same.

## Non-sensitive send/receive proof

Use a dedicated test chat or another chat where this harmless probe is acceptable:

```bash
osascript research/brave_chatgpt_poc.applescript send-title "YOUR TEST CHAT TITLE" "TEAM_R_POC_TEST_20261007 — reply only with POC_OK"
```

The command refuses to send if:
- the title resolves to zero tabs;
- the title resolves to multiple tabs;
- the composer already contains a draft;
- the pasted text does not exactly match the supplied argument;
- the send button is not ready.

It then waits up to 180 seconds for a new assistant turn and returns visible response text.

## Open-new-chat proof

```bash
osascript research/brave_chatgpt_poc.applescript new-chat
```

A brand-new chat begins at `https://chatgpt.com/`. A stable conversation URL/ID normally exists only after the conversation is created by a send; production code should capture the URL after that transition.

## Known POC limitations

- ChatGPT DOM selectors can change. This POC uses semantic/stable-looking attributes where possible (`#prompt-textarea`, `data-message-author-role`, `data-testid`) but must be re-tested against the live site.
- Completion detection uses the presence of ChatGPT's stop button plus a new assistant turn. Tool-heavy/rich responses may need stronger production logic.
- Latest-response extraction returns visible text, not a lossless reconstruction of every rich widget/artifact.
- `set the clipboard` replaces the current clipboard contents. Production code should decide whether/how to preserve and restore it.
- Title matching allows exact title and the common ` - ChatGPT` / ` | ChatGPT` suffixes only, and fails on duplicates rather than guessing.
- This branch is evidence scaffolding, not production architecture.

## Token estimate V0

Do not add a tokenizer dependency for the first slice. Store exact visible character counts and a clearly labeled rough token estimate such as:

`estimated_tokens_v0 = ceil(character_count / 4)`

Record the estimator name/version and `authoritative: false`. This is intentionally approximate and can be replaced later if mixed-language/code accuracy becomes materially useful.
