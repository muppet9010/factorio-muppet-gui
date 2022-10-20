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
| audience | players | special | string[] | An array of players to have the logic applied to. If the `logic` option is `only` or `not` then the `players` list is mandatory. If the `logic` option is `all` then the `players` list will be ignored and can be removed or be be nil. |
| message | position | mandatory | string | Position on the screen. Valid values `top`, `left` and `center`. Will be added to the end of any other mod GUIs in that position on the screen. |
| message | fontSize | mandatory | string | The size of the text. Valid values: `small`, `medium`, `large` |
| message | fontStyle | mandatory | string | The style of the text. Valid values: `regular`, `semibold`, `bold` |
| message | fontColor | optional | string | The color of the text. Valid values found in `utility\lists\colors.lua` or at `https://www.rapidtables.com/web/color/html-color-codes.html` , i.e. `red`. Can be removed or be nil for the default of white. |
| message | simpleText | mandatory | string | The text to be shown in the message. |
| message | maxWidth | optional | uint | Max width of the message box in pixels. Suggested minimum value is 200 and a large width is 1000. Text will wrap on to multiple lines automatically within the set width. Exclude the option or set to nil if no max width is desired. |
| message | background | optional | string | The background type of the GUI. Either `main`, `contentInnerLight` or `transparent`. Defaults to `main`.
| close | timeout | special | uint | Either `timeout` or `xbutton` must be specified. If Timeout is provided and greater than 0 the message will auto close after this number of seconds. |
| close | xbutton | special | boolean | Either `timeout` or `xbutton` must be specified. If XButton is enabled (true) then a close X button will be shown on the top right of the GUI message. |
| close | xbuttonColor | optional | string | The color of the close button if its enabled. Either `white` or `black`. Defaults to `white`. |

They are defined to the command/remote call as an object of `Option Group` fields. With each option group field being an object of it's fields.

- Format `table<string, table<string, any>`.
- Partial example: `{ audience = {logic="all"} }`

-------------------------------------------------



#### Notes

- `background` options are: `main` is the default Factorio grey color used in Factorio GUI borders. `contentInnerLight` is the light grey content backgrounds used in some Factorio GUIs. `transparent` is no background color.

-------------------------------------------------



#### Remote Interface

Remote Interface syntax: `remote.call("muppet_gui", "show_message", [OPTIONS TABLE]}`

The [OPTIONS TABLE] in the remote interface syntax is the above Options object as a Lua table.

###### Examples

An auto closing GUI for all connected players, shown at the top of the screen:

`/sc remote.call("muppet_gui", "show_message", { audience={logic="all"} , message={simpleText="a test message to show to all players", position="top", fontSize="large", fontStyle="regular", fontColor="lightRed"} , close={timeout=5} })`

A GUi with a close X button for all connected players not specifically excluded, shown in the center of the screen:

`/sc remote.call("muppet_gui", "show_message", { audience={players={"player1","player7"}, logic="not"} , message={simpleText="a test message to show to all but a few players", position="center", fontSize="small", fontStyle="bold"} , close={xbutton=true} })`

Black text and close button on a transparent background:

`/sc remote.call("muppet_gui", "show_message", { audience={logic="all"} , message={simpleText="some black text", position="center", fontSize="large", fontStyle="bold", fontColor="black", background="transparent"} , close={xbutton=true, xbuttonColor="black"} })`

-------------------------------------------------



#### Factorio Command

Command syntax: `/muppet_gui_show_message [OPTIONS JSON]`

The [OPTIONS JSON] in the command syntax is the above Options object in JSON string format.

While JSON doesn't define `nil` or `null`, Factorio JSON does recognise `null` and convert it to `nil` in Lua.

###### Examples

An auto closing GUI for all connected players, shown at the top of the screen:

`/muppet_gui_show_message {"audience": {"logic":"all"}, "message":{"simpleText":"a test message to show to all players", "position":"top", "fontSize":"large", "fontStyle":"regular", "fontColor":"lightRed"}, "close":{"timeout":5}}`

A GUi with a close X button for all connected players not specifically excluded, shown in the center of the screen:

`/muppet_gui_show_message {"audience": {"players":["player1", "player7"], "logic":"not"}, "message":{"simpleText":"a test message to show to all but a few players", "position":"center", "fontSize":"small", "fontStyle":"bold"}, "close":{"xbutton":true}}`

Black text and close button on a transparent background:

`/muppet_gui_show_message {"audience": {"logic":"all"}, "message":{"simpleText":"some black text", "position":"center", "fontSize":"large", "fontStyle":"bold", "fontColor":"black", "background":"transparent"}, "close":{"xbutton":true, "xbuttonColor":"black"}}`