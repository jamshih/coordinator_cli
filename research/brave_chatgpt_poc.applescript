-- Team R throwaway feasibility POC.
-- Research-only: tests the smallest AppleScript + JavaScript-from-Apple-Events path.
-- It intentionally has no external dependencies and is not production coordinator code.

on run argv
	if (count of argv) = 0 then return usageText()
	set commandName to item 1 of argv

	if commandName is "doctor" then
		return doctor()
	else if commandName is "list" then
		return listTabs(false)
	else if commandName is "list-chatgpt" then
		return listTabs(true)
	else if commandName is "activate-title" then
		if (count of argv) < 2 then error "activate-title requires a chat title"
		return activateMatch(my requireUniqueTitleMatch(item 2 of argv))
	else if commandName is "activate-url" then
		if (count of argv) < 2 then error "activate-url requires a canonical ChatGPT URL"
		return activateCanonicalMatch(my requireUniqueURLMatch(item 2 of argv))
	else if commandName is "ensure-url" then
		if (count of argv) < 2 then error "ensure-url requires a canonical ChatGPT URL"
		return ensureCanonicalURL(item 2 of argv)
	else if commandName is "new-chat" then
		return openNewChat()
	else if commandName is "latest-title" then
		error "latest-title is disabled: title is discovery-only metadata. Use latest-url with the canonical ChatGPT conversation URL."
	else if commandName is "latest-url" then
		if (count of argv) < 2 then error "latest-url requires a canonical ChatGPT URL"
		return latestForMatch(my requireUniqueURLMatch(item 2 of argv))
	else if commandName is "send-title" then
		error "send-title is disabled: title is discovery-only metadata. Use send-url with the canonical ChatGPT conversation URL."
	else if commandName is "send-url" then
		if (count of argv) < 3 then error "send-url requires a canonical ChatGPT URL and message text"
		return sendAndWait(my requireUniqueURLMatch(item 2 of argv), item 3 of argv)
	else
		error "Unknown command: " & commandName
	end if
end run

on usageText()
	return "Usage:" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript doctor" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript list-chatgpt" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript activate-title \"Diet Team B\"" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript activate-url \"https://chatgpt.com/c/...\"" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript ensure-url \"https://chatgpt.com/c/...\"" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript new-chat" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript latest-url \"https://chatgpt.com/c/...\"" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript send-url \"https://chatgpt.com/c/...\" \"TEAM_R_POC_TEST_20261007\""
end usageText

on doctor()
	tell application "Brave Browser"
		if (count of windows) = 0 then error "Brave is running but has no open window"
		set braveVersion to version
		set pageResult to ""
		try
			tell active tab of front window to set pageResult to execute javascript "JSON.stringify({title:document.title,url:location.href})"
		on error errText number errNum
			error "Brave AppleScript works, but JavaScript-from-Apple-Events failed. Enable Brave > View > Developer > Allow JavaScript from Apple Events. Original error " & errNum & ": " & errText
		end try
	end tell
	return "Brave=" & braveVersion & linefeed & "JavaScriptAppleEvents=OK" & linefeed & pageResult
end doctor

on listTabs(chatGPTOnly)
	set rows to {}
	tell application "Brave Browser"
		set windowCount to count of windows
		repeat with wi from 1 to windowCount
			set tabCount to count of tabs of window wi
			repeat with ti from 1 to tabCount
				set currentTab to tab ti of window wi
				set tTitle to title of currentTab
				set tURL to URL of currentTab
				if (chatGPTOnly is false) or my isChatGPTURL(tURL) then
					set end of rows to (wi as text) & tab & (ti as text) & tab & tTitle & tab & tURL
				end if
			end repeat
		end repeat
	end tell
	return my joinLines(rows)
end listTabs

on isChatGPTURL(theURL)
	if theURL starts with "https://chatgpt.com/" then return true
	if theURL starts with "http://chatgpt.com/" then return true
	return false
end isChatGPTURL

on titleMatches(rawTitle, wantedTitle)
	if rawTitle is wantedTitle then return true
	if rawTitle is (wantedTitle & " - ChatGPT") then return true
	if rawTitle is (wantedTitle & " | ChatGPT") then return true
	return false
end titleMatches

on findTitleMatches(wantedTitle)
	set matches to {}
	tell application "Brave Browser"
		repeat with wi from 1 to (count of windows)
			repeat with ti from 1 to (count of tabs of window wi)
				set currentTab to tab ti of window wi
				set tTitle to title of currentTab
				set tURL to URL of currentTab
				set tID to id of currentTab
				set tLoading to loading of currentTab
				if my isChatGPTURL(tURL) and my titleMatches(tTitle, wantedTitle) then set end of matches to {wi, ti, tTitle, tURL, tID, tLoading}
			end repeat
		end repeat
	end tell
	return matches
end findTitleMatches

on findURLMatches(wantedURL)
	repeat with attempt from 1 to 10
		set scanResult to my scanVerificationState(wantedURL, "__TEAM_R_NO_TAB_ID__")
		if item 1 of scanResult is true then return item 2 of scanResult
		delay 0.05
	end repeat
	error "Brave tab set kept mutating during canonical URL discovery; refusing operation"
end findURLMatches

on findTabByID(wantedID)
	set matches to {}
	tell application "Brave Browser"
		repeat with wi from 1 to (count of windows)
			repeat with ti from 1 to (count of tabs of window wi)
				set currentTab to tab ti of window wi
				set tID to id of currentTab
				if (tID as text) is (wantedID as text) then
					set tTitle to title of currentTab
					set tURL to URL of currentTab
					set tLoading to loading of currentTab
					set end of matches to {wi, ti, tTitle, tURL, tID, tLoading}
				end if
			end repeat
		end repeat
	end tell
	return matches
end findTabByID

-- Verification-only scanner. Brave may mutate/reorder/replace tabs while a
-- scan is in progress. If a tab index becomes invalid (-1719), the entire
-- snapshot is discarded so ensureCanonicalURL can rescan fresh state inside
-- its bounded verification loop.
on sameIDLists(leftIDs, rightIDs)
	if (count of leftIDs) is not (count of rightIDs) then return false
	repeat with i from 1 to (count of leftIDs)
		if ((item i of leftIDs) as text) is not ((item i of rightIDs) as text) then return false
	end repeat
	return true
end sameIDLists

on scanVerificationState(wantedURL, wantedID)
	set urlMatches to {}
	set idMatches to {}
	try
		tell application "Brave Browser"
			set startWindowIDs to id of windows

			repeat with wi from 1 to (count of startWindowIDs)
				set stableWindowID to item wi of startWindowIDs
				set stableWindow to first window whose id is stableWindowID
				set startTabIDs to id of tabs of stableWindow

				repeat with ti from 1 to (count of startTabIDs)
					set stableTabID to item ti of startTabIDs
					set stableTab to first tab of stableWindow whose id is stableTabID
					set tTitle to title of stableTab
					set tURL to URL of stableTab
					set tLoading to loading of stableTab

					-- Re-read identity after properties so a replacement cannot
					-- silently mix URL/title from one tab with ID from another.
					set finalTabID to id of stableTab
					set finalURL to URL of stableTab
					if (finalTabID as text) is not (stableTabID as text) then return {false, {}, {}}
					if finalURL is not tURL then return {false, {}, {}}

					set tabSnapshot to {wi, ti, tTitle, tURL, stableTabID, tLoading, stableWindowID}
					if tURL is wantedURL then set end of urlMatches to tabSnapshot
					if (stableTabID as text) is (wantedID as text) then set end of idMatches to tabSnapshot
				end repeat

				set endTabIDs to id of tabs of stableWindow
				if my sameIDLists(startTabIDs, endTabIDs) is false then return {false, {}, {}}
			end repeat

			set endWindowIDs to id of windows
			if my sameIDLists(startWindowIDs, endWindowIDs) is false then return {false, {}, {}}
		end tell
	on error errText number errNum
		if (errNum is -1719) or (errNum is -1728) then return {false, {}, {}}
		error errText number errNum
	end try
	return {true, urlMatches, idMatches}
end scanVerificationState

on requireUniqueTitleMatch(wantedTitle)
	set matches to my findTitleMatches(wantedTitle)
	if (count of matches) = 0 then error "No open ChatGPT tab matched title: " & wantedTitle
	if (count of matches) > 1 then error "Ambiguous ChatGPT title; " & (count of matches) & " tabs matched: " & wantedTitle
	return item 1 of matches
end requireUniqueTitleMatch

on requireUniqueURLMatch(wantedURL)
	if not my isChatGPTURL(wantedURL) then error "Refusing non-ChatGPT URL: " & wantedURL
	repeat with attempt from 1 to 30
		set scanResult to my scanVerificationState(wantedURL, "__TEAM_R_NO_TAB_ID__")
		if item 1 of scanResult is true then
			set matches to item 2 of scanResult
			if (count of matches) > 1 then error "Ambiguous canonical URL; " & (count of matches) & " tabs are open for: " & wantedURL
			if (count of matches) = 1 then return item 1 of matches
		end if
		-- A legitimate Chromium replacement can briefly leave no visible
		-- canonical tab. This is pre-action discovery only, so bounded rescan
		-- is safe; no content action is retried.
		delay 0.1
	end repeat
	error "No open tab matched canonical URL after bounded re-resolution: " & wantedURL
end requireUniqueURLMatch

on activateMatch(theMatch)
	set wi to item 1 of theMatch
	set ti to item 2 of theMatch
	tell application "Brave Browser"
		set active tab index of window wi to ti
		set index of window wi to 1
		activate
		delay 0.2
		set currentTab to active tab of front window
		return (title of currentTab) & tab & (URL of currentTab)
	end tell
end activateMatch

-- Canonical operations may use captured indices only as a focus hint.
-- Authorization comes from re-verifying the active Brave tab's stable ID
-- and exact canonical conversation URL immediately before content access.
on activateCanonicalMatch(theMatch)
	set expectedURL to item 4 of theMatch
	set expectedID to item 5 of theMatch

	-- Re-resolve by canonical URL immediately before focus. The old tab ID is
	-- a binding hint only: if Chromium legitimately replaced that tab, a new
	-- ID may be accepted only after the old ID is absent and the canonical URL
	-- is still unique.
	set freshMatch to my resolveCanonicalIdentity(expectedID, expectedURL)
	set wi to item 1 of freshMatch
	set ti to item 2 of freshMatch

	try
		tell application "Brave Browser"
			-- Capture the window object before changing focus. Re-addressing
			-- "window wi" after activation/reordering can refer to a different
			-- numeric position.
			set targetWindow to window wi
			set active tab index of targetWindow to ti
			activate
			set index of targetWindow to 1
		end tell
	on error errText number errNum
		if errNum is -1719 then error "Canonical target mutated during focus; refusing stale numeric-index activation"
		error errText number errNum
	end try

	delay 0.2
	return my verifiedActiveSnapshot(expectedID, expectedURL)
end activateCanonicalMatch

on resolveCanonicalIdentity(expectedID, expectedURL)
	repeat with attempt from 1 to 30
		set verificationScan to my scanVerificationState(expectedURL, expectedID)
		if item 1 of verificationScan is true then
			set urlMatches to item 2 of verificationScan
			set idMatches to item 3 of verificationScan

			if (count of urlMatches) > 1 then error "Ambiguous canonical URL during identity re-resolution; refusing operation"
			if (count of idMatches) > 1 then error "Ambiguous canonical tab ID during identity re-resolution; refusing operation"

			if (count of idMatches) = 1 then
				set idMatch to item 1 of idMatches
				if (item 4 of idMatch) is not expectedURL then error "Previous canonical tab ID still exists at a different URL; refusing rebind"
			end if

			if (count of urlMatches) = 1 then
				set urlMatch to item 1 of urlMatches
				if (count of idMatches) = 1 then
					if ((item 5 of urlMatch) as text) is not (expectedID as text) then error "Canonical URL conflicts with the still-live previous tab ID; refusing operation"
				end if
				-- If idMatches is empty, the old ID disappeared and this single
				-- exact canonical URL is the candidate replacement binding.
				return urlMatch
			end if

			-- Zero URL matches are tolerated only while the previous ID is also
			-- absent. If the old ID still exists, the URL check above would have
			-- rejected any navigation away from the canonical conversation.
		end if
		delay 0.1
	end repeat

	error "Canonical target disappeared during bounded identity re-resolution; refusing operation"
end resolveCanonicalIdentity
on verifiedActiveSnapshot(expectedID, expectedURL)
	-- One consistent Brave snapshot proves uniqueness and whether the previous
	-- tab ID still exists. A disappeared old ID may rebind only to the single
	-- exact canonical URL that is also the active front tab.
	set verificationScan to my scanVerificationState(expectedURL, expectedID)
	if item 1 of verificationScan is false then error "Canonical target mutated during active-tab verification; refusing content access"
	set urlMatches to item 2 of verificationScan
	set idMatches to item 3 of verificationScan

	if (count of urlMatches) is not 1 then
		if (count of urlMatches) = 0 then error "Canonical target URL disappeared before content access; refusing operation"
		error "Ambiguous canonical URL before content access; refusing operation"
	end if
	if (count of idMatches) > 1 then error "Ambiguous previous tab ID before content access; refusing operation"

	set canonicalMatch to item 1 of urlMatches
	set reboundID to item 5 of canonicalMatch

	if (count of idMatches) = 1 then
		set oldMatch to item 1 of idMatches
		if (item 4 of oldMatch) is not expectedURL then error "Previous canonical tab ID still exists at a different URL; refusing rebind"
		if (reboundID as text) is not (expectedID as text) then error "Canonical URL conflicts with still-live previous tab ID; refusing operation"
	end if

	try
		tell application "Brave Browser"
			if (count of windows) = 0 then error "No Brave window exists while verifying canonical target"
			set currentTab to active tab of front window
			set actualID to id of currentTab
			set actualURL to URL of currentTab
			set actualTitle to title of currentTab
		end tell
	on error errText number errNum
		if errNum is -1719 then error "Canonical target mutated during active-tab verification; refusing content access"
		error errText number errNum
	end try

	if actualURL is not expectedURL then error "Active tab is not the unique canonical conversation; refusing operation"
	if (actualID as text) is not (reboundID as text) then error "Active tab does not match the unique canonical URL binding; refusing operation"
	return {actualTitle, actualURL, actualID}
end verifiedActiveSnapshot

-- Content transport does not depend on the globally front Brave window.
-- Resolve the unique canonical URL twice, then address the exact owning window
-- and tab by their stable IDs. This lets RDC/browser work continue even when
-- another Brave window or macOS Space is frontmost.
on executeVerifiedJavaScript(expectedID, expectedURL, jsText)
	set firstBinding to my resolveCanonicalIdentity(expectedID, expectedURL)
	set boundID to item 5 of firstBinding

	-- Repeat canonical proof immediately before the read/Send action.
	set finalBinding to my resolveCanonicalIdentity(boundID, expectedURL)
	if ((item 5 of finalBinding) as text) is not (boundID as text) then error "Canonical tab binding changed before JavaScript; refusing operation"
	set targetWindowID to item 7 of finalBinding

	try
		tell application "Brave Browser"
			set targetWindow to first window whose id is targetWindowID
			set targetTab to first tab of targetWindow whose id is boundID
			set actualID to id of targetTab
			set actualURL to URL of targetTab
			if actualURL is not expectedURL then error "Canonical URL changed immediately before JavaScript; refusing operation"
			if (actualID as text) is not (boundID as text) then error "Canonical tab binding changed immediately before JavaScript; refusing operation"
			tell targetTab to return execute javascript jsText
		end tell
	on error errText number errNum
		if errNum is -1719 then error "Canonical target mutated immediately before JavaScript; refusing operation"
		error errText number errNum
	end try
end executeVerifiedJavaScript

on pasteVerifiedSelection(expectedID, expectedURL)
	set firstBinding to my resolveCanonicalIdentity(expectedID, expectedURL)
	set boundID to item 5 of firstBinding

	-- Repeat canonical proof immediately before paste. Numeric tab index is
	-- only a local focus hint inside the already-identified owning window.
	set finalBinding to my resolveCanonicalIdentity(boundID, expectedURL)
	if ((item 5 of finalBinding) as text) is not (boundID as text) then error "Canonical tab binding changed before paste; refusing operation"
	set targetTabIndex to item 2 of finalBinding
	set targetWindowID to item 7 of finalBinding

	try
		tell application "Brave Browser"
			set targetWindow to first window whose id is targetWindowID
			set active tab index of targetWindow to targetTabIndex
			set targetTab to first tab of targetWindow whose id is boundID
			set localActiveTab to active tab of targetWindow

			if (URL of targetTab) is not expectedURL then error "Canonical target URL changed immediately before paste; refusing operation"
			if ((id of targetTab) as text) is not (boundID as text) then error "Canonical target ID changed immediately before paste; refusing operation"
			if (URL of localActiveTab) is not expectedURL then error "Numeric focus hint selected a different URL; refusing paste"
			if ((id of localActiveTab) as text) is not (boundID as text) then error "Numeric focus hint selected a different tab ID; refusing paste"

			tell targetTab to paste selection
		end tell
	on error errText number errNum
		if errNum is -1719 then error "Canonical target mutated immediately before paste; refusing operation"
		error errText number errNum
	end try
end pasteVerifiedSelection

on ensureCanonicalURL(wantedURL)
	if not my isChatGPTURL(wantedURL) then error "Refusing non-ChatGPT URL: " & wantedURL

	set matches to my findURLMatches(wantedURL)
	if (count of matches) = 1 then return my activateCanonicalMatch(item 1 of matches)
	if (count of matches) > 1 then error "Ambiguous canonical URL; " & (count of matches) & " tabs are open for: " & wantedURL

	tell application "Brave Browser"
		if (count of windows) = 0 then make new window
		set newTab to make new tab at end of tabs of front window with properties {URL:wantedURL}
		set createdTabID to id of newTab
		set active tab index of front window to (count of tabs of front window)
		activate
	end tell

	set lastObservedURL to "<not observed>"
	set lastObservedLoading to "<unknown>"

	repeat with attempt from 1 to 40
		delay 0.25

		set verificationScan to my scanVerificationState(wantedURL, createdTabID)
		if item 1 of verificationScan is true then
			set matches to item 2 of verificationScan
			set trackedTabs to item 3 of verificationScan

			if (count of matches) > 1 then
				error "Ambiguous canonical URL after reopen; " & (count of matches) & " tabs match: " & wantedURL
			end if

			if (count of trackedTabs) = 0 then
				if (count of matches) = 1 then
					error "Created tab was replaced or disappeared before verification; requested canonical URL exists in a different tab. Refusing ambiguous success for: " & wantedURL
				end if
				error "Created tab was closed, replaced, or otherwise disappeared before canonical URL verification: " & wantedURL
			end if
			if (count of trackedTabs) > 1 then error "Unexpected duplicate tab ID while verifying canonical URL"

			set trackedTab to item 1 of trackedTabs
			set lastObservedURL to item 4 of trackedTab
			set lastObservedLoading to item 6 of trackedTab

			if (count of matches) = 1 then
				set exactMatch to item 1 of matches
				if ((item 5 of exactMatch) as text) is not (createdTabID as text) then
					error "Redirect/replacement ambiguity: requested canonical URL appeared in a different tab while the created tab remained at: " & lastObservedURL
				end if
				if lastObservedLoading is false then
					-- Numeric indices are only ephemeral scan metadata. Success is
					-- based on stable tab ID + exact canonical URL + loading=false.
					return (item 3 of exactMatch) & tab & (item 4 of exactMatch)
				end if
			else if (lastObservedLoading is false) and (lastObservedURL is not wantedURL) then
				error "Redirect ambiguity: created tab finished loading at " & lastObservedURL & " instead of requested canonical URL " & wantedURL
			end if
		end if
		-- A false scan result means Brave returned -1719 while mutating tabs.
		-- Discard that entire snapshot and let the next bounded poll rescan.
	end repeat

	error "Timed out verifying reopened canonical URL after 10 seconds. Created tab still observed at " & lastObservedURL & " (loading=" & (lastObservedLoading as text) & "); requested " & wantedURL
end ensureCanonicalURL

on openNewChat()
	tell application "Brave Browser"
		if (count of windows) = 0 then make new window
		set newTab to make new tab at end of tabs of front window with properties {URL:"https://chatgpt.com/"}
		set active tab index of front window to (count of tabs of front window)
		activate
		delay 1
		return (title of newTab) & tab & (URL of newTab)
	end tell
end openNewChat

on latestForMatch(theMatch)
	set expectedURL to item 4 of theMatch
	set expectedID to item 5 of theMatch
	return my latestForActiveCanonical(expectedID, expectedURL)
end latestForMatch

on latestForActiveCanonical(expectedID, expectedURL)
	set js to "(() => { let a=[...document.querySelectorAll('[data-message-author-role=assistant]')]; if(!a.length) a=[...document.querySelectorAll('h4[data-conversation-role=assistant]')].map(h=>h.parentElement); if(!a.length) return ''; const last=a[a.length-1]; const md=last.querySelector('.markdown'); if(md) return md.innerText.trim(); const marker=last.querySelector('h4[data-conversation-role=assistant]'); const body=marker?.nextElementSibling; return (body||last).innerText.trim(); })()"
	return my executeVerifiedJavaScript(expectedID, expectedURL, js)
end latestForActiveCanonical

on sendAndWait(theMatch, messageText)
	set canonicalURL to item 4 of theMatch
	set expectedTabID to item 5 of theMatch

	set preflightJS to "(() => { const c=document.querySelector('#prompt-textarea,[contenteditable=true][role=textbox]'); if(!c) return 'NO_COMPOSER'; if(document.querySelector('button[data-testid=stop-button],button[aria-label=\"Stop\"],button[aria-label=\"Stop generating\"],button[aria-label=\"Stop streaming\"]')) return 'BUSY_GENERATING'; const existing=(c.innerText||'').trim(); if(existing.length) return 'COMPOSER_NOT_EMPTY'; c.focus(); c.click(); let a=document.querySelectorAll('[data-message-author-role=assistant]').length; if(!a) a=document.querySelectorAll('h4[data-conversation-role=assistant]').length; let u=document.querySelectorAll('[data-message-author-role=user]').length; if(!u) u=document.querySelectorAll('[data-user-message-bubble=\"true\"]').length; return 'READY|' + a + '|' + u; })()"
	set preflight to my executeVerifiedJavaScript(expectedTabID, canonicalURL, preflightJS)
	if preflight is "NO_COMPOSER" then error "ChatGPT composer not found; DOM may have changed or the page is not ready"
	if preflight is "BUSY_GENERATING" then error "Refusing to send while ChatGPT is already generating"
	if preflight is "COMPOSER_NOT_EMPTY" then error "Refusing to overwrite an existing ChatGPT draft"
	if preflight does not start with "READY|" then error "Unexpected preflight state: " & preflight

	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "|"
	set baselineAssistantCount to (text item 2 of preflight) as integer
	set baselineUserCount to (text item 3 of preflight) as integer
	set AppleScript's text item delimiters to oldDelims
	set expectedUserCount to baselineUserCount + 1

	set the clipboard to messageText
	my pasteVerifiedSelection(expectedTabID, canonicalURL)
	delay 0.3

	-- ChatGPT's ProseMirror may render pasted URLs as rich-link widgets.
	-- innerText is CSS/layout-sensitive and can insert visual newlines that
	-- were not present in the clipboard payload. Reconstruct logical editor
	-- text from DOM text nodes plus explicit <br> nodes instead.
	set pastedText to my executeVerifiedJavaScript(expectedTabID, canonicalURL, "(() => { const c=document.querySelector('#prompt-textarea,[contenteditable=true][role=textbox]'); if(!c) return ''; let out=''; const walk=n=>{ if(n.nodeType===Node.TEXT_NODE){out+=n.nodeValue||'';return;} if(n.nodeType===Node.ELEMENT_NODE&&n.tagName==='BR'){out+='\\n';return;} for(const ch of n.childNodes) walk(ch); }; walk(c); return out; })()")
	if pastedText is not messageText then error "Paste verification failed; message was NOT submitted and draft ownership is ambiguous"

	set sendJS to "(() => { const b=document.querySelector('#composer-submit-button,[data-testid=send-button],button[aria-label=\"Send\"]'); if(!b || b.disabled) return 'SEND_NOT_READY'; b.click(); return 'SENT'; })()"
	set sendState to my executeVerifiedJavaScript(expectedTabID, canonicalURL, sendJS)
	if sendState is not "SENT" then error "Message was NOT submitted: " & sendState

	set userTurnConfirmed to false
	repeat with attempt from 1 to 10
		delay 0.5
		set observedUserCount to (my executeVerifiedJavaScript(expectedTabID, canonicalURL, "(() => { let u=document.querySelectorAll('[data-message-author-role=user]').length; if(!u) u=document.querySelectorAll('[data-user-message-bubble=\"true\"]').length; return u.toString(); })()")) as integer
		if observedUserCount > expectedUserCount then error "Manual/concurrent interference detected before submitted turn confirmation; refusing response association"
		if observedUserCount is expectedUserCount then
			set lastUserText to my executeVerifiedJavaScript(expectedTabID, canonicalURL, "(() => { let u=[...document.querySelectorAll('[data-message-author-role=user]')]; if(!u.length) u=[...document.querySelectorAll('[data-user-message-bubble=\"true\"]')]; const semantic=n=>{ const root=n.querySelector('[data-search-result-target]')||n; const c=root.cloneNode(true); c.querySelectorAll('[data-markdown-copy=\"exclude\"],[data-thread-find-skip=\"true\"],[aria-hidden=\"true\"],[inert]').forEach(x=>x.remove()); return (c.innerText||c.textContent||'').trim(); }; return u.length ? semantic(u[u.length-1]) : ''; })()")
			if lastUserText is messageText then
				set userTurnConfirmed to true
				exit repeat
			else
				error "Tracked user sequence changed before submitted turn confirmation; refusing response association"
			end if
		end if
	end repeat
	if userTurnConfirmed is false then error "Submitted user turn could not be verified; refusing to associate a later response"

	set userSequenceJS to "(() => { let u=[...document.querySelectorAll('[data-message-author-role=user]')]; if(!u.length) u=[...document.querySelectorAll('[data-user-message-bubble=\"true\"]')]; const semantic=n=>{ const root=n.querySelector('[data-search-result-target]')||n; const c=root.cloneNode(true); c.querySelectorAll('[data-markdown-copy=\"exclude\"],[data-thread-find-skip=\"true\"],[aria-hidden=\"true\"],[inert]').forEach(x=>x.remove()); return (c.innerText||c.textContent||'').trim(); }; return JSON.stringify(u.map(semantic)); })()"
	set ownedUserSequence to my executeVerifiedJavaScript(expectedTabID, canonicalURL, userSequenceJS)

	set idleConfirmations to 0
	repeat with attempt from 1 to 180
		delay 1

		set responseState to my executeVerifiedJavaScript(expectedTabID, canonicalURL, "(() => { let a=document.querySelectorAll('[data-message-author-role=assistant]').length; if(!a) a=document.querySelectorAll('h4[data-conversation-role=assistant]').length; let u=document.querySelectorAll('[data-message-author-role=user]').length; if(!u) u=document.querySelectorAll('[data-user-message-bubble=\"true\"]').length; const busy=!!document.querySelector('button[data-testid=stop-button],button[aria-label=\"Stop\"],button[aria-label=\"Stop generating\"],button[aria-label=\"Stop streaming\"]'); return a + '|' + u + '|' + (busy ? '1' : '0'); })()")

		set oldDelims to AppleScript's text item delimiters
		set AppleScript's text item delimiters to "|"
		set responseAssistantCount to (text item 1 of responseState) as integer
		set responseUserCount to (text item 2 of responseState) as integer
		set isBusy to text item 3 of responseState
		set AppleScript's text item delimiters to oldDelims

		if responseUserCount is not expectedUserCount then error "Manual/concurrent interference detected: unexpected additional or missing user turn; refusing response association"
		set currentUserSequence to my executeVerifiedJavaScript(expectedTabID, canonicalURL, userSequenceJS)
		if currentUserSequence is not ownedUserSequence then error "Manual/concurrent interference detected: tracked user sequence changed; refusing response association"

		if (responseAssistantCount > baselineAssistantCount) and (isBusy is "0") then
			set idleConfirmations to idleConfirmations + 1
		else
			set idleConfirmations to 0
		end if

		if idleConfirmations is greater than or equal to 2 then
			-- Final ownership check immediately before response extraction.
			set finalUserSequence to my executeVerifiedJavaScript(expectedTabID, canonicalURL, userSequenceJS)
			if finalUserSequence is not ownedUserSequence then error "Manual/concurrent interference detected before response extraction; refusing response association"
			return my latestForActiveCanonical(expectedTabID, canonicalURL)
		end if
	end repeat

	error "Timed out waiting for a completed assistant response after 180 seconds"
end sendAndWait

on joinLines(theItems)
	if (count of theItems) = 0 then return ""
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to linefeed
	set joined to theItems as text
	set AppleScript's text item delimiters to oldDelims
	return joined
end joinLines
