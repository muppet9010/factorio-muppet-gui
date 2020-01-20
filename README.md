# factorio-muppet-gui


A mod that can show messages as required. Designed for use with streaming integrations. WIP.

All arguments via commands accept only a single table in JSON format. Must be entered as a single line. i.e. `{"audience": {"players": ["muppet9010"], "logic": "only"}, "message": "a test message to show"}`

muppet_gui_show_message
----------------
A simple command to put a message in-game within a GUI to currently connected players as per the Audience JSON section. Takes 1 argument that is a JSON format WITHOUT spaces.

formatted JSON structure with comments "--" :
```
{
    --The audience of the message
    "audience": {
        --An array of players to have the logic applied to. If logic is "only" or "not" the players list will be used. If logic is "all" the players list will be ignored and can be removed or an empty list.
        "players": [
            [PLAYERNAME AS STRING]
        ],
        --Logic to be applied with the player list. Supports "only", "not" and "all". Only does the players list. Not does the players other than the list. All applies to all connected players.
        "logic": [LOGIC OPTION AS STRING]
    },

    --The message to be shown
    "message": {
        --A single text string to show
        "text": [TEXT TO SHOW AS STRING],
    }

    --The close conditions
    "close": {
        --If Timeout exists the message will auto close after this number of seconds.
        "timeout": [AUTO CLOSE SECONDS]
    }
}
```

example command with JSON value:
```
/muppet_gui_show_message {"audience": {"players": ["muppet9010"], "logic": "only"}, "message": {"text": "a test message to show"}, "close":{"timeout":5}}
```
