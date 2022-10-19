# factorio-muppet-gui


A mod that can show messages as required. Designed for use with streaming integrations. WIP.

All commands accept only a single dictionary in JSON format as their argument. Must be entered as a single line on the command.

Simple In-game Message
----------------

A simple command to put a message in-game within a GUI to players. Supports options around auto closing or close X button, white or black listing named players from the message, as well as the look and feel of the message.

- Command syntax: `/muppet_gui_show_message JSON`
- Formatted JSON structure with comments "--" :
```
	{
		--The audience of the message
		"audience": {
			--An array of players to have the logic applied to. If logic is "only" or "not" the players list will be used. If logic is "all" the players list will be ignored and can be removed or an empty list [].
			"players": [
				[PLAYERNAME AS STRING],
				[PLAYERNAME N AS STRING]
			]

			--Logic to be applied with the player list. Supports "only", "not" and "all". Only does the players list. Not does the players other than the list. All applies to all connected players.
			"logic": [LOGIC OPTION AS STRING]
		},

		--The message to be shown
		"message": {
			--Position on the screen. Supports "top", "left" and "center". Will be added to the end of any other mod GUIs in that position.
			"position": [POSITION OPTION AS STRING]

			--The size of the text. Valid options: "small", "medium", "large"
			"fontSize": [FONT SIZE AS STRING]

			--The style of the text. Valid options: "regular", "semibold", "bold"
			"fontStyle": [FONT STYLE AS STRING]

			--The color of the text. OPTIONAL. Valid options found in "utility/colors.lua" or at https://www.rapidtables.com/web/color/html-color-codes.html , i.e. "lightRed". Can be removed or blank string "" for the default of white.
			"fontColor": [COLOR NAME AS STRING]

			--A single text string to show
			"simpleText": [TEXT TO SHOW AS STRING]

			--Max width of the message box in pixels. OPTIONAL. Suggested minimum value is 200 and a large width is 1000. Text will wrap on to multiple lines. Exclude the option or set to blank string "" if no max width desired.
			"maxWidth": [WIDTH IN PIXELS]
		}

		--The close conditions - must have 1 or more specified
		"close": {
			--If Timeout exists and is > 0 the message will auto close after this number of seconds.
			"timeout": [AUTO CLOSE SECONDS]

			--If XButton exists and set to true then a close X button will be shown on the right of the GUI message
			"xbutton": true
		}
	}
```
- example command 1:
	`/muppet_gui_show_message {"audience": {"players":[], "logic":"all"}, "message":{"simpleText":"a test message to show to all players", "position":"top", "fontSize":"large", "fontStyle":"regular", "fontColor":"lightRed"}, "close":{"timeout":5}}`
- example command 2:
	`/muppet_gui_show_message {"audience": {"players":["muppet9010", "player7"], "logic":"not"}, "message":{"simpleText":"a test message to show to all but a few players", "position":"top", "fontSize":"small", "fontStyle":"bold", "fontColor":"white"}, "close":{"xbutton":true}}`