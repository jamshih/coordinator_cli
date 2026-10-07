-- Team R throwaway feasibility POC.
-- Research-only: proves the smallest AppleScript + JavaScript-from-Apple-Events path.
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
		return activateByTitle(item 2 of argv)
	else if commandName is "new-chat" then
		return openNewChat()
	else if commandName is "latest-title" then
		if (count of argv) < 2 then error "latest-title requires a chat title"
		return latestByTitle(item 2 of argv)
	else if commandName is "send-title" then
		if (count of argv) < 3 then error "send-title requires a chat title and message text"
		return sendAndWait(item 2 of argv, item 3 of argv)
	else
		error "Unknown command: " & commandName
	end if
end run

on usageText()
	return "Usage:" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript doctor" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript list-chatgpt" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript activate-title \"Diet Team B\"" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript new-chat" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript latest-title \"Diet Team B\"" & linefeed & ¬
		"  osascript research/brave_chatgpt_poc.applescript send-title \"Diet Team B\" \"TEAM_R_POC_TEST_20261007\""
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
		set windowCount to count of windows
		repeat with wi from 1 to windowCount
			set tabCount to count of tabs of window wi
			repeat with ti from 1 to tabCount
				set currentTab to tab ti of window wi
				set tTitle to title of currentTab
				set tURL to URL of currentTab
				if my isChatGPTURL(tURL) and my titleMatches(tTitle, wantedTitle) then
					set end of matches to {wi, ti, tTitle, tURL}
				end if
			end repeat
		end repeat
	end tell
	return matches
end findTitleMatches

on requireUniqueTitleMatch(wantedTitle)
	set matches to my findTitleMatches(wantedTitle)
	if (count of matches) = 0 then error "No open ChatGPT tab matched title: " & wantedTitle
	if (count of matches) > 1 then error "Ambiguous ChatGPT title; " & (count of matches) & " tabs matched: " & wantedTitle
	return item 1 of matches
end requireUniqueTitleMatch

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

on activateByTitle(wantedTitle)
	return my activateMatch(my requireUniqueTitleMatch(wantedTitle))
end activateByTitle

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

on latestByTitle(wantedTitle)
	set theMatch to my requireUniqueTitleMatch(wantedTitle)
	my activateMatch(theMatch)
	set js to "(() => { const a=[...document.querySelectorAll('[data-message-author-role=assistant]')]; if(!a.length) return ''; const last=a[a.length-1]; const md=last.querySelector('.markdown'); return (md||last).innerText.trim(); })()"
	tell application "Brave Browser"
		tell active tab of front window to return execute javascript js
	end tell
end latestByTitle

on sendAndWait(wantedTitle, messageText)
	set theMatch to my requireUniqueTitleMatch(wantedTitle)
	my activateMatch(theMatch)

	set preflightJS to "(() => { const c=document.querySelector('#prompt-textarea,[contenteditable=true][role=textbox]'); if(!c) return 'NO_COMPOSER'; const existing=(c.innerText||'').trim(); if(existing.length) return 'COMPOSER_NOT_EMPTY'; c.focus(); c.click(); const n=document.querySelectorAll('[data-message-author-role=assistant]').length; return 'READY|' + n; })()"
	tell application "Brave Browser"
		tell active tab of front window to set preflight to execute javascript preflightJS
	end tell
	if preflight is "NO_COMPOSER" then error "ChatGPT composer not found; DOM may have changed or the page is not ready"
	if preflight is "COMPOSER_NOT_EMPTY" then error "Refusing to overwrite an existing ChatGPT draft"
	if preflight does not start with "READY|" then error "Unexpected preflight state: " & preflight

	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "|"
	set baselineCount to (text item 2 of preflight) as integer
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

	set idleConfirmations to 0
	repeat with attempt from 1 to 180
		delay 1
		set stateJS to "(() => { const n=document.querySelectorAll('[data-message-author-role=assistant]').length; const busy=!!document.querySelector('button[data-testid=stop-button]'); return n + '|' + (busy ? '1' : '0'); })()"
		tell application "Brave Browser"
			tell active tab of front window to set responseState to execute javascript stateJS
		end tell

		set oldDelims to AppleScript's text item delimiters
		set AppleScript's text item delimiters to "|"
		set responseCount to (text item 1 of responseState) as integer
		set isBusy to text item 2 of responseState
		set AppleScript's text item delimiters to oldDelims

		if (responseCount > baselineCount) and (isBusy is "0") then
			set idleConfirmations to idleConfirmations + 1
		else
			set idleConfirmations to 0
		end if

		if idleConfirmations ≥ 2 then return my latestByTitle(wantedTitle)
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
