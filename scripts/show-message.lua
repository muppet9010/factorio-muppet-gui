local ShowMessage = {} ---@class ShowMessage
local GUIUtil = require("utility.manager-libraries.gui-util")
local Commands = require("utility.helper-utils.commands-utils")
local Logging = require("utility.helper-utils.logging-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local GUIActionsClick = require("utility.manager-libraries.gui-actions-click")
local Colors = require("utility.lists.colors")
local MathUtils = require("utility.helper-utils.math-utils")
local StyleData = require("utility.lists.style-data")
local MuppetStyles = StyleData.MuppetStyles
local TableUtils = require("utility.helper-utils.table-utils")

---@class ShowMessageDetails
---@field audience AudienceDetails
---@field message MessageDetails
---@field close CloseDetails

---@class AudienceDetails
---@field players string[]|nil # An array of 0 or more player names. Mandatory if `logic` is not `all.
---@field logic ShowMessage_Logic

---@class MessageDetails
---@field position ShowMessage_Position
---@field fontSize ShowMessage_FontSize
---@field fontStyle ShowMessage_FontStyle
---@field fontColor string|nil # Color name in utility color list or blank/nil for default of white.
---@field simpleText string
---@field maxWidth uint|nil # nil doesn't set a limit on Gui element width.
---@field background ShowMessage_Background|nil

---@class CloseDetails # Must have either `timeout` or `xbutton` populated.
---@field timeout uint|nil # If populated must be greater than 0. A nil value means don't auto close, a number greater than 0 is how many seconds before auto close.
---@field xbutton boolean|nil # If true then an x button is put on the GUI to close it.
---@field xbuttonColor ShowMessage_CloseButtonColor|nil

---@class GuiToRemoveDetails
---@field name string
---@field type string

---@alias ShowMessage_Logic "only"|"not"|"all"
---@alias ShowMessage_Position "top"|"left"|"center"
---@alias ShowMessage_FontSize "small"|"medium"|"large"
---@alias ShowMessage_FontStyle "regular"|"semibold"|"bold"
---@alias ShowMessage_Background "main"|"contentInnerLight"|"transparent"|"brightGreen"|"brightRed"|
---@alias ShowMessage_CloseButtonColor "white"|"black"



ShowMessage.CreateGlobals = function()
    global.showMessage = global.showMessage or {} ---@class ShowMessage_Global
    global.showMessage.count = global.showMessage.count or 0 ---@type int
    global.showMessage.buttons = {} ---@type table<string, table<uint, LuaPlayer>> # A table with the close button name to a list of players that have it open still. The player list is player.index to LuaPlayer.
end

ShowMessage.OnLoad = function()
    Commands.Register("muppet_gui_show_message", { "api-description.muppet_gui_show_message" }, ShowMessage.ShowMessage_CommandRun, true)
    EventScheduler.RegisterScheduledEventType("ShowMessage.RemoveNamedElementForAll", ShowMessage.RemoveNamedElementForAll)
    GUIActionsClick.LinkGuiClickActionNameToFunction("ShowMessage.CloseSimpleTextFrame", ShowMessage.CloseSimpleTextFrame)
end

--- The show_message command has been run.
---@param commandData CustomCommandData
ShowMessage.ShowMessage_CommandRun = function(commandData)
    local errorMessageStart = "ERROR: command muppet_gui_show_message: "
    local warningPrefix = "Warning: command muppet_gui_show_message: "

    local data = game.json_to_table(commandData.parameter) --[[@as ShowMessageDetails]]
    if data == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory JSON object not provided")
        return
    end

    local errorMessage = ShowMessage.ShowMessage_DoIt(data, warningPrefix)
    if errorMessage ~= nil then
        Logging.LogPrintError(errorMessageStart .. errorMessage)
        return
    end
end

--- The show_message command has been run.
---@param data ShowMessageDetails
ShowMessage.ShowMessage_RemoteInterface = function(data)
    local errorMessageStart = "ERROR: remote `muppet_gui.show_message`: "
    local warningPrefix = "Warning: remote `muppet_gui.show_message`: "

    if data == nil or type(data) ~= "table" then
        Logging.LogPrintError(errorMessageStart .. "mandatory options object not provided")
        return
    end

    local errorMessage = ShowMessage.ShowMessage_DoIt(data, warningPrefix)
    if errorMessage ~= nil then
        Logging.LogPrintError(errorMessageStart .. errorMessage)
        return
    end
end

--- Add the message from the command/remote.
---@param data ShowMessageDetails
---@param warningPrefix string
---@return string|nil errorMessage
ShowMessage.ShowMessage_DoIt = function(data, warningPrefix)
    local audienceErrorMessage, players = ShowMessage.GetAudienceData(data)
    if audienceErrorMessage ~= nil then
        return audienceErrorMessage
    end

    local messageErrorMessage, simpleText, position, fontType, fontSize, fontColor, maxWidth, background = ShowMessage.GetMessageData(data)
    if messageErrorMessage ~= nil then
        return messageErrorMessage
    end

    local closeErrorMessage, closeTick, closeButton, closeButtonColor = ShowMessage.GetCloseData(data, warningPrefix)
    if closeErrorMessage ~= nil then
        return closeErrorMessage
    end

    if simpleText ~= nil then
        global.showMessage.count = global.showMessage.count + 1
        local elementName = "muppet_gui_show_message" .. global.showMessage.count

        -- Process the option specific stuff.
        ---@type table<uint, LuaPlayer>, table<string, any>
        local buttonPlayerList, closeButtonStyling
        local closeButtonSprite
        if closeButton then
            buttonPlayerList = {}
            global.showMessage.buttons[elementName] = buttonPlayerList
            if fontSize == "small" then
                -- The GUI size for the text is too small for a full sized close button, so shrink it a bit to fit.
                closeButtonStyling = { width = 12, height = 12 }
            end
            if closeButtonColor == "white" then
                closeButtonSprite = "utility/close_white"
            else
                closeButtonSprite = "utility/close_black"
            end
        end
        local outerContainerType, outerContainerSubType
        if background == "transparent" then
            -- Gets a flow object as we don't have a frame with no graphics style in the library.
            outerContainerType = "flow"
            outerContainerSubType = "horizontal"
        else
            -- All others get a standard frame.
            outerContainerType = "frame"
            outerContainerSubType = background
        end

        -- Make the generic GUI details object.
        ---@type UtilityGuiUtil_ElementDetails_Add
        local guiElementDetails = {
            descriptiveName = elementName,
            type = outerContainerType,
            direction = "horizontal",
            style = MuppetStyles[outerContainerType][outerContainerSubType].marginTL,
            storeName = "ShowMessage",
            styling = { maximal_width = maxWidth },
            children = {
                {
                    type = "label",
                    caption = simpleText,
                    style = fontType,
                    styling = { font_color = fontColor }
                },
                {
                    type = "flow",
                    direction = "horizontal",
                    style = MuppetStyles.flow.horizontal.marginTL_paddingBR,
                    styling = { horizontal_align = "right", horizontally_stretchable = true },
                    exclude = not closeButton,
                    children = {
                        {
                            descriptiveName = elementName .. "_close",
                            type = "sprite-button",
                            sprite = closeButtonSprite,
                            style = MuppetStyles.spriteButton.noBorderHover_clickable, -- Means we never have a depressed graphic, but that doesn't matter as its having the hover that people will notice.
                            styling = closeButtonStyling,
                            registerClick = { actionName = "ShowMessage.CloseSimpleTextFrame", data = { name = elementName, type = outerContainerType } --[[@as GuiToRemoveDetails]] }
                        }
                    }
                }
            }
        }

        -- Add the GUI to each player.
        for _, player in pairs(players) do
            local flowElements = GUIUtil.AddElement({
                parent = player.gui.center,
                type = "flow",
                direction = "vertical",
                style = MuppetStyles.flow.vertical.plain,
                styling = { vertically_stretchable = true, vertical_align = "center" },
                children = {
                    {
                        descriptiveName = "centerTop",
                        type = "flow",
                        direction = "horizontal",
                        style = MuppetStyles.flow.horizontal.plain,
                        styling = { vertical_align = "top" },
                        returnElement = true
                    },
                    {
                        descriptiveName = "centerMiddle",
                        type = "flow",
                        direction = "horizontal",
                        style = MuppetStyles.flow.horizontal.plain,
                        styling = { vertical_align = "center", height = player.display_resolution.height / 3 },
                        returnElement = true
                    },
                    {
                        descriptiveName = "centerBottom",
                        type = "flow",
                        direction = "horizontal",
                        style = MuppetStyles.flow.horizontal.plain,
                        styling = { vertical_align = "bottom" },
                        returnElement = true
                    },
                }
            }) ---@cast flowElements - nil

            local topEntry = TableUtils.DeepCopy(guiElementDetails)
            local bottomEntry = TableUtils.DeepCopy(guiElementDetails)

            topEntry.parent = flowElements["muppet_gui-centerTop-flow"]
            topEntry.descriptiveName = topEntry.descriptiveName .. "_top"
            topEntry.children[1].caption = "top"
            GUIUtil.AddElement(topEntry)

            guiElementDetails.parent = flowElements["muppet_gui-centerMiddle-flow"]
            guiElementDetails.descriptiveName = guiElementDetails.descriptiveName .. "_middle"
            guiElementDetails.children[1].caption = "middle"
            GUIUtil.AddElement(guiElementDetails)

            bottomEntry.parent = flowElements["muppet_gui-centerBottom-flow"]
            bottomEntry.descriptiveName = bottomEntry.descriptiveName .. "_bottom"
            bottomEntry.children[1].caption = "bottom"
            GUIUtil.AddElement(bottomEntry)

            if closeButton then
                buttonPlayerList[player.index] = player
            end
        end

        -- Log the timeout close of the GUI if enabled.
        if closeTick ~= nil then
            EventScheduler.ScheduleEventOnce(closeTick, "ShowMessage.RemoveNamedElementForAll", global.showMessage.count, { name = elementName, type = "frame" }--[[@as GuiToRemoveDetails]] )
        end
    end

    return nil
end

--- Work out the audience settings from the raw data.
---@param data ShowMessageDetails
---@return string|nil errorMessage
---@return LuaPlayer[] players
---@return ShowMessage_Logic logic
ShowMessage.GetAudienceData = function(data)
    if data.audience == nil then
        return "mandatory 'audience' object not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local players = {}
    local logic = data.audience.logic
    if logic == nil then
        return "mandatory 'audience.logic' string not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if logic == "all" then
        players = game.connected_players
    else
        local playerNames = data.audience.players
        if playerNames == nil then
            return "mandatory 'audience.players' array not provided and logic wasn't the `all` option." ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        local playerNamesAsKeys = {} ---@type table<string, string>
        for _, playerName in pairs(playerNames) do
            if type(playerName) == "string" then
                playerNamesAsKeys[playerName] = playerName
            else
                return "'audience.players' array contained value that wasn't a string, got: `" .. tostring(playerName) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
            end
        end
        if logic == "only" then
            for _, player in pairs(game.connected_players) do
                if playerNamesAsKeys[player.name] ~= nil then
                    table.insert(players, player)
                end
            end
        elseif logic == "not" then
            local potentialPlayers = game.connected_players
            for i, player in pairs(potentialPlayers) do
                if playerNamesAsKeys[player.name] ~= nil then
                    table.remove(potentialPlayers, i)
                end
            end
            players = potentialPlayers
        else
            return "invalid 'audience.logic' option provided, got: `" .. tostring(logic) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    end

    return nil, players, logic
end

--- Work out the message details from the raw data.
---@param data ShowMessageDetails
---@return string|nil errorMessage
---@return string simpleText
---@return ShowMessage_Position position
---@return ShowMessage_FontStyle fontType
---@return ShowMessage_FontSize fontSize
---@return Color fontColor
---@return uint|nil maxWidth
---@return ShowMessage_Background background
ShowMessage.GetMessageData = function(data)
    local message = data.message
    if message == nil then
        return "mandatory 'message' object not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local simpleText = message.simpleText
    if simpleText ~= nil then
        simpleText = tostring(simpleText)
    else
        return "mandatory 'message.simpleText' object not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local position = message.position
    if position == nil then
        return "mandatory 'message.position' string not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if position ~= "top" and position ~= "left" and position ~= "center" then
        return "mandatory 'message.position' string not valid option, got: `" .. tostring(position) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local fontSize, fontStyle = message.fontSize, message.fontStyle
    if fontSize == nil then
        return "mandatory 'message.fontSize' string not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontSize ~= "small" and fontSize ~= "medium" and fontSize ~= "large" then
        return "mandatory 'message.fontSize' string not valid option, got: `" .. tostring(fontSize) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontStyle == nil then
        return "mandatory 'message.fontStyle' string not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontStyle ~= "regular" and fontStyle ~= "semibold" and fontStyle ~= "bold" then
        return "mandatory 'message.fontStyle' string not valid option, got: `" .. tostring(fontStyle) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    local fontType
    if fontStyle == "regular" then
        fontType = MuppetStyles.label.text[fontSize].plain
    else
        fontType = MuppetStyles.label.text[fontSize][fontStyle]
    end

    local fontColorString = message.fontColor
    local fontColor = Colors.white
    if fontColorString ~= nil and fontColorString ~= "" then
        fontColor = Colors[fontColorString] --[[@as Color]]
        if fontColor == nil then
            return "mandatory 'message.fontColor' string not valid option, got: `" .. tostring(fontColorString) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    end

    local maxWidth ---@type uint
    if message.maxWidth ~= nil and message.maxWidth ~= "" then
        maxWidth = tonumber(message.maxWidth) --[[@as uint]]
        if maxWidth == nil or maxWidth <= 0 then
            return "optional 'message.maxWidth' is set, but not a positive number: `" .. tostring(fontColorString) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        maxWidth = math.floor(maxWidth) --[[@as uint]]
    end

    local background = message.background
    if background ~= nil then
        if background ~= "main" and background ~= "contentInnerLight" and background ~= "transparent" and background ~= "brightGreen" and background ~= "brightRed" then
            return "mandatory 'message.background' string not valid option, got: `" .. tostring(background) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    else
        background = "main"
    end

    return nil, simpleText, position, fontType, fontSize, fontColor, maxWidth, background
end

--- Work out the close details from the raw data.
---@param data ShowMessageDetails
---@param warningPrefix string
---@return string|nil errorMessage
---@return uint|nil closeTick
---@return boolean closeButton
---@return ShowMessage_CloseButtonColor|nil closeButtonType
ShowMessage.GetCloseData = function(data, warningPrefix)
    local close = data.close
    if close == nil then
        return "mandatory 'close' object not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local closeTick ---@type uint|nil
    local CloseTimeoutString = close.timeout
    if CloseTimeoutString ~= nil then
        local closeTimeout = tonumber(CloseTimeoutString)
        if closeTimeout == nil or closeTimeout <= 0 then
            return "'close.timeout' specified, but not valid positive number, got: `" .. tostring(CloseTimeoutString) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        closeTick = game.tick + math.floor(closeTimeout * 60)
        if closeTick > MathUtils.uintMax then
            closeTick = MathUtils.uintMax
            Logging.LogPrintWarning(warningPrefix .. "close.timeout was set so large its been capped to the end of Factorio time, timeout requested: " .. tostring(closeTimeout))
        end
    end

    local closeButton
    if close.xbutton ~= nil then
        if type(close.xbutton) ~= "boolean" then
            return "'close.xbutton' specified, but not a boolean or nil value, got: `" .. tostring(close.xbutton) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        closeButton = close.xbutton ---@cast closeButton - nil
    else
        closeButton = false
    end

    if closeTick == nil and closeButton == false then
        return "no way to close GUI specified, either `timeout` or `xbutton` must be provided." ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local closeButtonColor = close.xbuttonColor
    if closeButtonColor ~= nil then
        if closeButtonColor ~= "white" and closeButtonColor ~= "black" then
            return "mandatory 'close.xbuttonColor' string not valid option, got: `" .. tostring(closeButtonColor) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    else
        closeButtonColor = "white"
    end

    return nil, closeTick, closeButton, closeButtonColor
end

--- Called to remove all instances of a specific GUI for all players after a set time period.
---@param eventData UtilityScheduledEvent_CallbackObject
ShowMessage.RemoveNamedElementForAll = function(eventData)
    local data = eventData.data ---@type GuiToRemoveDetails

    -- Remove this GUI for every player (past or present).
    for _, player in pairs(game.players) do
        ShowMessage.RemoveNamedElementForPlayer(player.index, data.name, data.type)
    end

    -- If there was a close button on this GUI tidy up the globals related to it.
    if global.showMessage.buttons[data.name] ~= nil then
        GUIActionsClick.RemoveGuiForClick(data.name .. "_close", "sprite-button")
        global.showMessage.buttons[data.name] = nil
    end
end

--- Player clicks to close their specific GUI.
---@param actionData any
ShowMessage.CloseSimpleTextFrame = function(actionData)
    local data = actionData.data ---@type GuiToRemoveDetails

    -- Remove the GUI for this player.
    ShowMessage.RemoveNamedElementForPlayer(actionData.playerIndex, data.name, data.type)

    -- Track that the GUI has been closed for this player.
    local playersGuiOpen = global.showMessage.buttons[data.name]
    if playersGuiOpen ~= nil then
        playersGuiOpen[actionData.playerIndex] = nil
        -- If this was the last player with this GUI open then remove the global entries.
        if not next(playersGuiOpen) then
            GUIActionsClick.RemoveGuiForClick(data.name .. "_close", "sprite-button")
            global.showMessage.buttons[data.name] = nil
        end
    end
end

--- Actually remove the GUI element.
---@param playerIndex uint
---@param name string
---@param type string
ShowMessage.RemoveNamedElementForPlayer = function(playerIndex, name, type)
    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "ShowMessage", name, type)
end

return ShowMessage
