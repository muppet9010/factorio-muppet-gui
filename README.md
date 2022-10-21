# factorio-muppet-gui


A mod that can show messages as required. Designed for use with streaming integrations.




Simple In-game Message
===============

A simple command to put a message in-game within a GUI to players. Supports options around auto closing or close X button, white or black listing named players from the message, as well as the look and feel of the message.

#### Options

The available options are listed below.

| Option Group | Option Name | Mandatory | Value Type | Details |
| --- | --- | --- | --- | --- |
| audience | logic | mandatory | string | The logic to be applied with the `players` option to define which connected players see the message. Valid values `only`, `not` and `all`. |
| audience | players | special | string[] | An array of players to have the logic applied to. If the `logic` option is `only` or `not` then the `players` list is mandatory. If the `logic` option is `all` then the `players` list will be ignored and can be either not provided or be `nil`. |
| message | position | mandatory | string | Position on the screen. Valid values `top`, `left`, `center`, `aboveCenter`, `belowCenter`. See Notes for details. |
| message | fontSize | mandatory | string | The size of the text. Valid values: `small`, `medium`, `large` |
| message | fontStyle | mandatory | string | The style of the text. Valid values: `regular`, `semibold`, `bold` |
| message | fontColor | optional | string | The color of the text. See notes for valid list of color options. If not provided or `nil` the default of `white` is used. |
| message | simpleText | mandatory | string | The text to be shown in the message. |
| message | maxWidth | optional | uint | Max width of the message box in pixels. Suggested minimum value is 200 and a large width of 1000. Text will wrap on to multiple lines automatically within the set width. Don't provide the option or set to nil if no max width is desired. Default is no max width and this works fine with shorter messages. |
| message | background | optional | string | The background type of the GUI. Either `main`, `contentInnerLight`, `transparent`, `brightRed`, `brightGreen`, `brightYellow`. Defaults to `main`.
| close | timeout | special | uint | Either `timeout` or `xbutton` must be specified. If Timeout is provided and greater than 0 the message will auto close after this number of seconds. |
| close | xbutton | special | boolean | Either `timeout` or `xbutton` must be specified. If XButton is enabled (true) then a close X button will be shown on the top right of the GUI message. |
| close | xbuttonColor | optional | string | The color of the close button if its enabled. Either `white` or `black`. Defaults to `white`. |

They are defined to the command/remote call as an object of `Option Group` fields. With each option group field being an object of it's fields.

- Format `table<string, table<string, any>`.
- Partial example: `{ audience = {logic="all"} }`

-------------------------------------------------



#### Notes

- `position` options are all relative and will be added to the end of any GUIs in that position on the screen. `top` is along the top of the screen, left to right. `left` is along the left edge of the screen, top to bottom. `center` is in the very center middle of the screen (horizontally and vertically), multiple GUIs expand horizontally. `aboveCenter` is about 1/3 down from the top middle of the screen, multiple GUIs expand horizontally. `belowCenter` is about 1/3 up from the bottom middle of the screen, multiple GUIs expand horizontally. If other mods add GUIs to the center of the screen then these will stack horizontally to this mod's 3 center position message GUIs.
- `fontColor` options can be found either in the mod files at `utility\lists\colors.lua` or at the website `https://www.rapidtables.com/web/color/html-color-codes.html`. The option defaults to the value of `white`.
- `background` options are are from the main Factorio game: `main` is the default Factorio GUI grey colors. `contentInnerLight` is the light grey in some content backgrounds. `transparent` is no background color 9see through). `brightRed`, `brightGreen` and `brightYellow` are self explanatory, but use of a non white `fontColor` and `xbuttonColor` is advised.
- The various choices in the GUI are often limited by what graphics Vanilla Factorio includes. If there's something specific you'd like added raise it in the discussion section and I can check if there is already a graphic for it.

-------------------------------------------------



#### Remote Interface

Remote Interface syntax: `remote.call("muppet_gui", "show_message", [OPTIONS TABLE]}`

The [OPTIONS TABLE] in the remote interface syntax is the above Options object as a Lua table.

###### Examples

An auto closing GUI for all connected players, shown at the top of the screen:

`/sc remote.call("muppet_gui", "show_message", { audience={logic="all"} , message={simpleText="a test message to show to all players", position="top", fontSize="large", fontStyle="regular", fontColor="lightRed"} , close={timeout=5} })`

A GUi with a close X button for all connected players not specifically excluded, shown in the left of the screen:

`/sc remote.call("muppet_gui", "show_message", { audience={players={"player1","player7"}, logic="not"} , message={simpleText="a test message to show to all but a few players", position="left", fontSize="small", fontStyle="bold"} , close={xbutton=true} })`

A short essay on a transparent background at the center of the screen with a small max width:

`/sc remote.call("muppet_gui", "show_message", { audience={logic="all"} , message={simpleText="a really long message slap bang in the center of the screen right in the way. But at least you can see through the background of all this text.", position="center", fontSize="large", fontStyle="bold", fontColor="black", background="transparent", maxWidth=300} , close={xbutton=true, xbuttonColor="black"} })`

A bright green background box with black text that auto closes above the center of the screen:

`/sc remote.call("muppet_gui", "show_message", { audience={logic="all"} , message={simpleText="a positive message", position="aboveCenter", fontSize="medium", fontStyle="bold", fontColor="black", background="brightGreen"} , close={timeout=10} })`

-------------------------------------------------



#### Factorio Command

Command syntax: `/muppet_gui_show_message [OPTIONS JSON]`

The [OPTIONS JSON] in the command syntax is the above Options object in JSON string format.

While JSON doesn't define `nil` or `null`, Factorio JSON does recognise `null` and convert it to `nil` in Lua.

###### Examples

An auto closing GUI for all connected players, shown at the top of the screen:

`/muppet_gui_show_message { "audience": {"logic":"all"}, "message":{"simpleText":"a test message to show to all players", "position":"top", "fontSize":"large", "fontStyle":"regular", "fontColor":"lightRed"}, "close":{"timeout":5} }`

A GUi with a close X button for all connected players not specifically excluded, shown in the left of the screen:

`/muppet_gui_show_message { "audience": {"players":["player1", "player7"], "logic":"not"}, "message":{"simpleText":"a test message to show to all but a few players", "position":"left", "fontSize":"small", "fontStyle":"bold"}, "close":{"xbutton":true} }`

A short essay on a transparent background at the center of the screen with a small max width:

`/muppet_gui_show_message { "audience": {"logic":"all"}, "message":{"simpleText":"a really long message slap bang in the center of the screen right in the way. But at least you can see through the background of all this text.", "position":"center", "fontSize":"large", "fontStyle":"bold", "fontColor":"black", "background":"transparent", "maxWidth":300}, "close":{"xbutton":true, "xbuttonColor":"black"} }`

A bright green background box with black text that auto closes above the center of the screen:

`/muppet_gui_show_message { "audience": {"logic":"all"}, "message":{"simpleText":"a positive message", "position":"aboveCenter", "fontSize":"medium", "fontStyle":"bold", "fontColor":"black", "background":"brightGreen"}, "close":{"timeout":10} }`