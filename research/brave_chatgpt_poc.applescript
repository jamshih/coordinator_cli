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
		return activateMatch(my requireUniqueURLMatch(item 2 of argv))
	else if commandName is "ensure-url" then
		if (count of argv) < 2 then error "ensure-url requires a canonical ChatGPT URL"
		return ensureCanonicalURL(item 2 of argv)
	else if commandName is "new-chat" then
		return openNewChat()
	else if commandName is "latest-title" then
		if (count of argv) < 2 then error "latest-title requires a chat title"
		return latestForMatch(my requireUniqueTitleMatch(item 2 of argv))
	else if commandName is "latest-url" then
		if (count of argv) < 2 then error "latest-url requires a canonical ChatGPT URL"
		return latestForMatch(my requireUniqueURLMatch(item 2 of argv))
	else if commandName is "send-title" then
		if (count of argv) < 3 then error "send-title requires a chat title and message text"
		return sendAndWait(my requireUniqueTitleMatch(item 2 of argv), item 3 of argv)
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
	set matches to {}
	tell application "Brave Browser"
		repeat with wi from 1 to (count of windows)
			repeat with ti from 1 to (count of tabs of window wi)
				set currentTab to tab ti of window wi
				set tTitle to title of currentTab
				set tURL to URL of currentTab
				set tID to id of currentTab
				set tLoading to loading of currentTab
				if tURL is wantedURL then set end of matches to {wi, ti, tTitle, tURL, tID, tLoading}
			end repeat
		end repeat
	end tell
	return matches
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

on requireUniqueTitleMatch(wantedTitle)
	set matches to my findTitleMatches(wantedTitle)
	if (count of matches) = 0 then error "No open ChatGPT tab matched title: " & wantedTitle
	if (count of matches) > 1 then error "Ambiguous ChatGPT title; " & (count of matches) & " tabs matched: " & wantedTitle
	return item 1 of matches
end requireUniqueTitleMatch

on requireUniqueURLMatch(wantedURL)
	if not my isChatGPTURL(wantedURL) then error "Refusing non-ChatGPT URL: " & wantedURL
	set matches to my findURLMatches(wantedURL)
	if (count of matches) = 0 then error "No open tab matched canonical URL: " & wantedURL
	if (count of matches) > 1 then error "Ambiguous canonical URL; " & (count of matches) & " tabs are open for: " & wantedURL
	return item 1 of matches
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

on ensureCanonicalURL(wantedURL)
	if not my isChatGPTURL(wantedURL) then error "Refusing non-ChatGPT URL: " & wantedURL

	set matches to my findURLMatches(wantedURL)
	if (count of matches) = 1 then return my activateMatch(item 1 of matches)
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

		set matches to my findURLMatches(wantedURL)
		if (count of matches) > 1 then
			error "Ambiguous canonical URL after reopen; " & (count of matches) & " tabs match: " & wantedURL
		end if

		set trackedTabs to my findTabByID(createdTabID)
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
				return my activateMatch(exactMatch)
			end if
		else if (lastObservedLoading is false) and (lastObservedURL is not wantedURL) then
			error "Redirect ambiguity: created tab finished loading at " & lastObservedURL & " instead of requested canonical URL " & wantedURL
		end if
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
	my activateMatch(theMatch)
	set js to "(() => { const a=[...document.querySelectorAll('[data-message-author-role=assistant]')]; if(!a.length) return ''; const last=a[a.length-1]; const md=last.querySelector('.markdown'); return (md||last).innerText.trim(); })()"
	tell application "Brave Browser"
		tell active tab of front window to return execute javascript js
	end tell
end latestForMatch

on sendAndWait(theMatch, messageText)
	my activateMatch(theMatch)
	set canonicalURL to item 4 of theMatch

	set preflightJS to "(() => { const c=document.querySelector('#prompt-textarea,[contenteditable=true][role=textbox]'); if(!c) return 'NO_COMPOSER'; if(document.querySelector('button[data-testid=stop-button]')) return 'BUSY_GENERATING'; const existing=(c.innerText||'').trim(); if(existing.length) return 'COMPOSER_NOT_EMPTY'; c.focus(); c.click(); const a=document.querySelectorAll('[data-message-author-role=assistant]').length; const u=document.querySelectorAll('[data-message-author-role=user]').length; return 'READY|' + a + '|' + u; })()"
	tell application "Brave Browser"
		tell active tab of front window to set preflight to execute javascript preflightJS
	end tell
	if preflight is "NO_COMPOSER" then error "ChatGPT composer not found; DOM may have changed or the page is not ready"
	if preflight is "BUSY_GENERATING" then error "Refusing to send while ChatGPT is already generating"
	if preflight is "COMPOSER_NOT_EMPTY" then error "Refusing to overwrite an existing ChatGPT draft"
	if preflight does not start with "READY|" then error "Unexpected preflight state: " & preflight

	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "|"
	set baselineAssistantCount to (text item 2 of preflight) as integer
	set baselineUserCount to (text item 3 of preflight) as integer
	set AppleScript's text item delimiters to oldDelims

	set the clipboard to messageText
	tell application "Brave Browser"
		tell active tab of front window to paste selection
	end tell
	delay 0.3

	tell application "Brave Browser"
		tell active tab of front window to set pastedText to execute javascript "(() => { const c=document.querySelector('#prompt-textarea,[contenteditable=true][role=textbox]'); return c ? c.innerText : ''; })()"
	end tell
	if pastedText is not messageText then error "Paste verification failed; message was NOT submitted"

	set sendJS to "(() => { const b=document.querySelector('#composer-submit-button,[data-testid=send-button]'); if(!b || b.disabled) return 'SEND_NOT_READY'; b.click(); return 'SENT'; })()"
	tell application "Brave Browser"
		tell active tab of front window to set sendState to execute javascript sendJS
	end tell
	if sendState is not "SENT" then error "Message was NOT submitted: " & sendState

	set userTurnConfirmed to false
	repeat with attempt from 1 to 10
		delay 0.5
		set userJS to "(() => { const u=[...document.querySelectorAll('[data-message-author-role=user]')]; if(!u.length) return ''; return u[u.length-1].innerText.trim(); })()"
		tell application "Brave Browser"
			tell active tab of front window to set lastUserText to execute javascript userJS
		end tell
		if lastUserText is messageText then
			set userTurnConfirmed to true
			exit repeat
		end if
	end repeat
	if userTurnConfirmed is false then error "Submitted user turn could not be verified; refusing to associate a later response"

	set idleConfirmations to 0
	repeat with attempt from 1 to 180
		delay 1
		set stateJS to "(() => { const a=document.querySelectorAll('[data-message-author-role=assistant]').length; const u=document.querySelectorAll('[data-message-author-role=user]').length; const busy=!!document.querySelector('button[data-testid=stop-button]'); return a + '|' + u + '|' + (busy ? '1' : '0'); })()"
		tell application "Brave Browser"
			tell active tab of front window to set responseState to execute javascript stateJS
		end tell

		set oldDelims to AppleScript's text item delimiters
		set AppleScript's text item delimiters to "|"
		set responseAssistantCount to (text item 1 of responseState) as integer
		set responseUserCount to (text item 2 of responseState) as integer
		set isBusy to text item 3 of responseState
		set AppleScript's text item delimiters to oldDelims

		if (responseAssistantCount > baselineAssistantCount) and (responseUserCount > baselineUserCount) and (isBusy is "0") then
			set idleConfirmations to idleConfirmations + 1
		else
			set idleConfirmations to 0
		end if

		if idleConfirmations is greater than or equal to 2 then
			set freshMatch to my requireUniqueURLMatch(canonicalURL)
			return my latestForMatch(freshMatch)
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
