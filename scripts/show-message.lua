local ShowMessage = {} ---@class ShowMessage
local GUIUtil = require("utility.manager-libraries.gui-util")
local Commands = require("utility.helper-utils.commands-utils")
local Logging = require("utility.helper-utils.logging-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local GUIActionsClick = require("utility.manager-libraries.gui-actions-click")
local Colors = require("utility.lists.colors")
local MathUtils = require("utility.helper-utils.math-utils")
local StyleData = require("utility.lists.style-data")
local MuppetStyles, MuppetFonts = StyleData.MuppetStyles, StyleData.MuppetFonts
local StringUtils = require("utility.helper-utils.string-utils")

---@class ShowMessageDetails
---@field audience AudienceDetails
---@field message MessageDetails
---@field close CloseDetails
---@field timer TimerDetails|nil # optional module

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

---@class TimerDetails
---@field startingValue int
---@field countDirection ShowMessage_TimerCountDirection|nil
---@field displayFormat ShowMessage_TimerDisplayFormat|nil

---@class GuiDetails
---@field name string # The element name used in the mod side, but not its GUI name which includes its type.
---@field type string # The LuaGuiElement type.
---@field finished boolean # If the GUI message is finished with an removed.
---@field openPlayers table<uint, LuaPlayer> # A list of players that have it open still. The player list is player.index to LuaPlayer.
---@field originalSimpleText string
---@field closeButton boolean
---@field timerCountDirection ShowMessage_TimerCountDirection|nil
---@field timerCurrentSeconds int|nil
---@field timerDisplayFormat ShowMessage_TimerDisplayFormat|nil

---@alias ShowMessage_Logic "only"|"not"|"all"
---@alias ShowMessage_Position "top"|"left"|"center"|"aboveCenter"|"belowCenter"
---@alias ShowMessage_FontSize "small"|"medium"|"large"|"huge"|"massive"|"gigantic"
---@alias ShowMessage_FontStyle "regular"|"semibold"|"bold"
---@alias ShowMessage_Background "main"|"contentInnerLight"|"transparent"|"brightGreen"|"brightRed"|"brightOrange"
---@alias ShowMessage_CloseButtonColor "white"|"black"
---@alias ShowMessage_TimerCountDirection "down"|"up"
---@alias ShowMessage_TimerDisplayFormat "second"|"minute"

ShowMessage.CreateGlobals = function()
    global.showMessage = global.showMessage or {} ---@class ShowMessage_Global
    global.showMessage.count = global.showMessage.count or 0 ---@type int
    global.showMessage.guis = global.showMessage.guis or {} ---@type table<string, GuiDetails> # Key'd by name (messageId) of the GuiDetails.
end

ShowMessage.OnLoad = function()
    Commands.Register("muppet_gui_show_message", { "api-description.muppet_gui_show_message" }, ShowMessage.ShowMessage_CommandRun, true)
    EventScheduler.RegisterScheduledEventType("ShowMessage.RemoveNamedElementForAll_Scheduled", ShowMessage.RemoveNamedElementForAll_Scheduled)
    GUIActionsClick.LinkGuiClickActionNameToFunction("ShowMessage.CloseSimpleTextFrame_Scheduled", ShowMessage.CloseSimpleTextFrame_Scheduled)
    EventScheduler.RegisterScheduledEventType("ShowMessage.UpdateSimpleTextTimer_Scheduled", ShowMessage.UpdateSimpleTextTimer_Scheduled)

    MOD.Interfaces.ShowMessage = {}
    MOD.Interfaces.ShowMessage.RemoveGuiForAll = ShowMessage.RemoveGuiForAll
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

    return
end

--- The show_message remote interface has been called.
---@param data ShowMessageDetails
ShowMessage.ShowMessage_RemoteInterface = function(data)
    local errorMessageStart = "ERROR: remote `muppet_gui.show_message`: "
    local warningPrefix = "Warning: remote `muppet_gui.show_message`: "

    if data == nil or type(data) ~= "table" then
        Logging.LogPrintError(errorMessageStart .. "mandatory options object not provided")
        return
    end

    local errorMessage, messageId = ShowMessage.ShowMessage_DoIt(data, warningPrefix)
    if errorMessage ~= nil then
        Logging.LogPrintError(errorMessageStart .. errorMessage)
        return
    end

    return messageId
end

--- Add the message from the command/remote.
---@param data ShowMessageDetails
---@param warningPrefix string
---@return string|nil errorMessage
---@return string messageId
ShowMessage.ShowMessage_DoIt = function(data, warningPrefix)
    local currentTick = game.tick

    local audienceErrorMessage, players = ShowMessage.GetAudienceData(data, warningPrefix)
    if audienceErrorMessage ~= nil then
        return audienceErrorMessage, ""
    end

    local messageErrorMessage, simpleText, position, labelType, fontType, fontSize, fontColor, maxWidth, background = ShowMessage.GetMessageData(data, warningPrefix)
    if messageErrorMessage ~= nil then
        return messageErrorMessage, ""
    end

    local closeErrorMessage, closeTick, closeButton, closeButtonColor = ShowMessage.GetCloseData(data, warningPrefix, currentTick)
    if closeErrorMessage ~= nil then
        return closeErrorMessage, ""
    end

    local timerErrorMessage, timerFeatureUsed, timerStartingValue, timerCountDirection, timerDisplayFormat = ShowMessage.GetTimerData(data, warningPrefix)
    if timerErrorMessage ~= nil then
        return timerErrorMessage, ""
    end

    -- Generate the outer message GUI's id.
    global.showMessage.count = global.showMessage.count + 1
    local messageId = "muppet_gui_show_message" .. global.showMessage.count

    if simpleText ~= nil then
        -- Process the option specific stuff.
        ---@type table<string, any>
        local closeButtonStyling
        local closeButtonSprite
        if closeButton then
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

        local simpleRenderText
        if timerFeatureUsed then
            simpleRenderText = ShowMessage.GetSimpleTextTimerRenderText(simpleText, timerStartingValue, timerDisplayFormat)
        else
            simpleRenderText = simpleText
        end

        ---@type GuiDetails
        local guiDetails = {
            name = messageId,
            type = outerContainerType,
            finished = false,
            openPlayers = {},
            originalSimpleText = simpleText,
            closeButton = closeButton
        }
        global.showMessage.guis[messageId] = guiDetails

        -- Add the GUI to each player.
        for _, player in pairs(players) do
            local player_index = player.index
            local parentGui ---@type LuaGuiElement

            -- Do any parent flow setup to add our message too.
            if position == "center" or position == "aboveCenter" or position == "belowCenter" then
                -- If its a center GUI ensure special position flows are present.

                -- Get the vertically positioned flows or create them if needed.
                local aboveCenterFlow = GUIUtil.GetElementFromPlayersReferenceStorage(player_index, "ShowMessage", "aboveCenter", "flow")
                local centerFlow, belowCenterFlow
                if aboveCenterFlow == nil or not aboveCenterFlow.valid then
                    -- Either never had the center flows made, or another mod has destroyed them under us.
                    local flowElements = GUIUtil.AddElement({
                        parent = player.gui.center,
                        type = "flow",
                        direction = "vertical",
                        style = MuppetStyles.flow.vertical.plain,
                        styling = { vertically_stretchable = true, vertical_align = "center" },
                        children = {
                            {
                                descriptiveName = "aboveCenter",
                                type = "flow",
                                storeName = "ShowMessage",
                                returnElement = true,
                                direction = "horizontal",
                                style = MuppetStyles.flow.horizontal.plain,
                                styling = { vertical_align = "top", horizontal_align = "center", horizontally_stretchable = true }
                            },
                            {
                                descriptiveName = "center",
                                type = "flow",
                                storeName = "ShowMessage",
                                returnElement = true,
                                direction = "horizontal",
                                style = MuppetStyles.flow.horizontal.plain,
                                styling = { vertical_align = "center", height = player.display_resolution.height / 3, horizontal_align = "center", horizontally_stretchable = true }
                            },
                            {
                                descriptiveName = "belowCenter",
                                type = "flow",
                                storeName = "ShowMessage",
                                returnElement = true,
                                direction = "horizontal",
                                style = MuppetStyles.flow.horizontal.plain,
                                styling = { vertical_align = "bottom", horizontal_align = "center", horizontally_stretchable = true }
                            },
                        }
                    }) ---@cast flowElements - nil
                    aboveCenterFlow = flowElements["muppet_gui-aboveCenter-flow"]
                    centerFlow = flowElements["muppet_gui-center-flow"]
                    belowCenterFlow = flowElements["muppet_gui-belowCenter-flow"]
                else
                    centerFlow = GUIUtil.GetElementFromPlayersReferenceStorage(player_index, "ShowMessage", "center", "flow")
                    belowCenterFlow = GUIUtil.GetElementFromPlayersReferenceStorage(player_index, "ShowMessage", "belowCenter", "flow")
                    centerFlow.style.height = player.display_resolution.height / 3 -- Update the height each time as a way to handle screen resolution changes over time. We don't want to bother reacting to the event.
                end

                -- Record the custom center parent GUI for adding the message to normally.
                if position == "aboveCenter" then
                    parentGui = aboveCenterFlow
                elseif position == "center" then
                    parentGui = centerFlow
                else
                    parentGui = belowCenterFlow
                end
            elseif position == "top" or position == "left" then
                parentGui = player.gui[position] --[[@as LuaGuiElement]]
            end

            -- Add the message GUI to the player.
            GUIUtil.AddElement({
                parent = parentGui,
                descriptiveName = messageId,
                type = outerContainerType,
                direction = "horizontal",
                style = MuppetStyles[outerContainerType][outerContainerSubType].marginTL,
                storeName = "ShowMessage",
                styling = { maximal_width = maxWidth },
                children = {
                    {
                        descriptiveName = messageId .. "_simpleText",
                        type = "label",
                        caption = simpleRenderText,
                        style = labelType,
                        storeName = "ShowMessage",
                        styling = { font_color = fontColor, font = fontType }
                    },
                    {
                        type = "flow",
                        direction = "horizontal",
                        style = MuppetStyles.flow.horizontal.marginTL_paddingBR,
                        styling = { horizontal_align = "right" },
                        exclude = not closeButton,
                        children = {
                            {
                                descriptiveName = messageId .. "_close",
                                type = "sprite-button",
                                sprite = closeButtonSprite,
                                style = MuppetStyles.spriteButton.noBorderHover_clickable, -- Means we never have a depressed graphic, but that doesn't matter as its having the hover that people will notice.
                                styling = closeButtonStyling,
                                registerClick = { actionName = "ShowMessage.CloseSimpleTextFrame_Scheduled", data = guiDetails }
                            }
                        }
                    }
                }
            })

            -- Record the player having this GUI open.
            guiDetails.openPlayers[player_index] = player
        end

        -- Log the timeout close of the GUI if enabled.
        if closeTick ~= nil then
            EventScheduler.ScheduleEventOnce(closeTick, "ShowMessage.RemoveNamedElementForAll_Scheduled", global.showMessage.count, guiDetails)
        end

        -- Schedule the timer to be updated if its in use.
        if timerFeatureUsed then
            guiDetails.timerCountDirection = timerCountDirection
            guiDetails.timerCurrentSeconds = timerStartingValue
            guiDetails.timerDisplayFormat = timerDisplayFormat
            EventScheduler.ScheduleEventOnce(currentTick + 60, "ShowMessage.UpdateSimpleTextTimer_Scheduled", messageId .. guiDetails.timerCurrentSeconds, guiDetails)
        end
    end

    return nil, messageId
end

--- Work out the audience settings from the raw data.
---@param data ShowMessageDetails
---@param warningPrefix string
---@return string|nil errorMessage
---@return LuaPlayer[] players
---@return ShowMessage_Logic logic
ShowMessage.GetAudienceData = function(data, warningPrefix)
    if data.audience == nil then
        return "mandatory `audience` object not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    for key in pairs(data.audience--[[@as table<string, any>]] ) do
        if key ~= "logic" and key ~= "players" then
            Logging.LogPrintWarning(warningPrefix .. "`audience` contained an unexpected key that will be ignored: `" .. tostring(key) .. "`")
        end
    end

    local players = {}
    local logic = data.audience.logic
    if logic == nil then
        return "mandatory `audience.logic` string not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if logic == "all" then
        players = game.connected_players
    else
        local playerNames = data.audience.players
        if playerNames == nil then
            return "mandatory `audience.players` array not provided and logic wasn't the `all` option." ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        local playerNamesAsKeys = {} ---@type table<string, string>
        for _, playerName in pairs(playerNames) do
            if type(playerName) == "string" then
                playerNamesAsKeys[playerName] = playerName
            else
                return "`audience.players` array contained value that wasn't a string, got: `" .. tostring(playerName) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
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
            return "invalid `audience.logic` option provided, got: `" .. tostring(logic) .. "`" ---@diagnostic disable-line:missing-return-value # We don`t need to return the other fields for a non success.
        end
    end

    return nil, players, logic
end

--- Work out the message details from the raw data.
---@param data ShowMessageDetails
---@param warningPrefix string
---@return string|nil errorMessage
---@return string simpleText
---@return ShowMessage_Position position
---@return string labelType
---@return string|nil fontType
---@return ShowMessage_FontSize fontSize
---@return Color fontColor
---@return uint|nil maxWidth
---@return ShowMessage_Background background
ShowMessage.GetMessageData = function(data, warningPrefix)
    local message = data.message
    if message == nil then
        return "mandatory `message` object not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    for key in pairs(data.audience--[[@as table<string, any>]] ) do
        if key ~= "logic" and key ~= "players" then
            Logging.LogPrintWarning(warningPrefix .. "`message` contained an unexpected key that will be ignored: `" .. tostring(key) .. "`")
        end
    end

    local simpleText = message.simpleText
    if simpleText ~= nil then
        simpleText = tostring(simpleText)
    else
        return "mandatory `message.simpleText` object not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local position = message.position
    if position == nil then
        return "mandatory `message.position` string not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if position ~= "top" and position ~= "left" and position ~= "center" and position ~= "aboveCenter" and position ~= "belowCenter" then
        return "mandatory `message.position` string not valid option, got: `" .. tostring(position) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local fontSize, fontStyle = message.fontSize, message.fontStyle
    if fontSize == nil then
        return "mandatory `message.fontSize` string not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontSize ~= "small" and fontSize ~= "medium" and fontSize ~= "large" and fontSize ~= "huge" and fontSize ~= "massive" and fontSize ~= "gigantic" then
        return "mandatory `message.fontSize` string not valid option, got: `" .. tostring(fontSize) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontStyle == nil then
        return "mandatory `message.fontStyle` string not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontStyle ~= "regular" and fontStyle ~= "semibold" and fontStyle ~= "bold" then
        return "mandatory `message.fontStyle` string not valid option, got: `" .. tostring(fontStyle) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    -- The non standard font sizes need capturing separately as there's no label styles for them.
    local labelType
    local fontType ---@type string|nil
    if fontSize == "small" or fontSize == "medium" or fontSize == "large" then
        if fontStyle == "regular" then
            labelType = MuppetStyles.label.text[fontSize].plain
        else
            labelType = MuppetStyles.label.text[fontSize][fontStyle]
        end
    else
        -- The massive font sizes.
        labelType = MuppetStyles.label.text["large"][fontStyle]
        if fontStyle == "regular" then
            fontType = MuppetFonts["muppet_" .. fontSize .. StyleData.styleVersion] --[[@as string]]
        else
            fontType = MuppetFonts["muppet_" .. fontSize .. "_" .. fontStyle .. StyleData.styleVersion] --[[@as string]]
        end
    end

    local fontColorString = message.fontColor
    local fontColor = Colors.white
    if fontColorString ~= nil then
        fontColor = Colors[fontColorString] --[[@as Color]]
        if fontColor == nil then
            return "`message.fontColor` specified not a valid option, got: `" .. tostring(fontColorString) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    end

    local maxWidth = message.maxWidth
    if maxWidth ~= nil then
        if type(maxWidth) ~= "number" then
            return "optional `message.maxWidth` is set, but isn't a number, is type: `" .. type(maxWidth) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        maxWidth = math.floor(maxWidth) --[[@as uint]]
        if maxWidth <= 0 then
            return "optional `message.maxWidth` is set, but not a positive number: `" .. tostring(fontColorString) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    end

    local background = message.background
    if background ~= nil then
        if background ~= "main" and background ~= "contentInnerLight" and background ~= "transparent" and background ~= "brightGreen" and background ~= "brightRed" and background ~= "brightOrange" then
            return "`message.background` provided, but not a valid option, got: `" .. tostring(background) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    else
        background = "main"
    end

    return nil, simpleText, position, labelType, fontType, fontSize, fontColor, maxWidth, background
end

--- Work out the close details from the raw data.
---@param data ShowMessageDetails
---@param warningPrefix string
---@param currentTick uint
---@return string|nil errorMessage
---@return uint|nil closeTick
---@return boolean closeButton
---@return ShowMessage_CloseButtonColor|nil closeButtonType
ShowMessage.GetCloseData = function(data, warningPrefix, currentTick)
    local close = data.close
    if close == nil then
        return "mandatory `close` object not provided" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    for key in pairs(data.audience--[[@as table<string, any>]] ) do
        if key ~= "logic" and key ~= "players" then
            Logging.LogPrintWarning(warningPrefix .. "`close` contained an unexpected key that will be ignored: `" .. tostring(key) .. "`")
        end
    end

    local closeTick ---@type uint|nil
    local closeTimeout = close.timeout
    if closeTimeout ~= nil then
        if type(closeTimeout) ~= "number" then
            return "optional `close.timeout` is set, but isn't a number, is type: `" .. type(closeTimeout) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        if closeTimeout <= 0 then
            return "`close.timeout` specified, but not valid positive number, got: `" .. tostring(closeTimeout) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        closeTick = currentTick + math.floor(closeTimeout * 60)
        if closeTick > MathUtils.uintMax then
            closeTick = MathUtils.uintMax
            Logging.LogPrintWarning(warningPrefix .. "`close.timeout` was set so large its been capped to the end of Factorio time, timeout requested: `" .. tostring(closeTimeout) .. "`")
        end
    end

    local closeButton
    if close.xbutton ~= nil then
        if type(close.xbutton) ~= "boolean" then
            return "`close.xbutton` specified, but not a boolean or nil value, got: `" .. tostring(close.xbutton) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
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
            return "`close.xbuttonColor` specified, but not a valid option, got: `" .. tostring(closeButtonColor) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    else
        closeButtonColor = "white"
    end

    return nil, closeTick, closeButton, closeButtonColor
end


--- Work out the timer details from the raw data.
---@param data ShowMessageDetails
---@param warningPrefix string
---@return string|nil timerErrorMessage
---@return boolean timerFeatureUsed # IF the timer feature is being used or not.
---@return int timerStartingValue
---@return ShowMessage_TimerCountDirection timerCountDirection
---@return ShowMessage_TimerDisplayFormat timerDisplayFormat
ShowMessage.GetTimerData = function(data, warningPrefix)
    local timer = data.timer
    local timerFeatureUsed
    if timer == nil then
        timerFeatureUsed = false
        return nil, timerFeatureUsed ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    timerFeatureUsed = true

    for key in pairs(data.audience--[[@as table<string, any>]] ) do
        if key ~= "logic" and key ~= "players" then
            Logging.LogPrintWarning(warningPrefix .. "`timer` contained an unexpected key that will be ignored: `" .. tostring(key) .. "`")
        end
    end

    local timerStartingValue = timer.startingValue
    if timerStartingValue == nil then
        return "`timer.startingValue` is mandatory when the `timer` function is in use." ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    timerStartingValue = math.floor(timerStartingValue)

    local timerCountDirection = timer.countDirection
    if timerCountDirection ~= nil then
        if timerCountDirection ~= "up" and timerCountDirection ~= "down" then
            return "optional `timer.countDirection` string not valid option, got: `" .. tostring(timerCountDirection) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    else
        timerCountDirection = "down"
    end

    local timerDisplayFormat = timer.displayFormat
    if timerDisplayFormat ~= nil then
        if timerDisplayFormat ~= "second" and timerDisplayFormat ~= "minute" then
            return "optional `timer.displayFormat` string not valid option, got: `" .. tostring(timerDisplayFormat) .. "`" ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    else
        timerDisplayFormat = "second"
    end

    if string.find(data.message.simpleText, "[!TIMER!]", 1, true) == nil then
        Logging.LogPrintWarning(warningPrefix .. "`timer` was configured, but the special `[!TIMER!]` string wasn't included in the `message.simpleText`")
        timerFeatureUsed = false
    end

    return nil, timerFeatureUsed, timerStartingValue, timerCountDirection, timerDisplayFormat
end

--- Called to remove all instances of a specific GUI for all players after a set time period.
---@param eventData UtilityScheduledEvent_CallbackObject
ShowMessage.RemoveNamedElementForAll_Scheduled = function(eventData)
    local guiDetails = eventData.data ---@type GuiDetails

    -- Remove the GUI for all players.
    ShowMessage.RemoveGuiForAll(guiDetails)
end

--- Remove a GUI for all remaining open players and tidy everything up.
---@param guiDetails GuiDetails
ShowMessage.RemoveGuiForAll = function(guiDetails)
    -- Remove this GUI for every player (past or present).
    for playerIndex in pairs(guiDetails.openPlayers) do
        GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "ShowMessage", guiDetails.name, guiDetails.type)
    end

    -- If there was a close button on this GUI tidy up the globals related to it.
    if guiDetails.closeButton ~= nil then
        GUIActionsClick.RemoveGuiForClick(guiDetails.name .. "_close", "sprite-button")
    end

    -- Remove the Gui Details from the global as all dealt with.
    global.showMessage.guis[guiDetails.name] = nil

    -- Set to be finished with, so any other scheduled feature with a reference to it knows it's completed.
    guiDetails.finished = true
end

--- Player clicks to close their specific GUI.
---@param actionData UtilityGuiActionsClick_ActionData
ShowMessage.CloseSimpleTextFrame_Scheduled = function(actionData)
    local guiDetails = actionData.data ---@type GuiDetails

    -- Remove the GUI for this player.
    GUIUtil.DestroyElementInPlayersReferenceStorage(actionData.playerIndex, "ShowMessage", guiDetails.name, guiDetails.type)

    -- Track that the GUI has been closed for this player.
    local playersGuiOpen = guiDetails.openPlayers
    if playersGuiOpen ~= nil then
        playersGuiOpen[actionData.playerIndex] = nil
        -- If this was the last player with this GUI open call the close for ALL function to tidy everything up.
        if not next(playersGuiOpen) then
            ShowMessage.RemoveGuiForAll(guiDetails)
        end
    end
end

--- Called every second to update the instances of a GUI's simple text
---@param eventData UtilityScheduledEvent_CallbackObject
ShowMessage.UpdateSimpleTextTimer_Scheduled = function(eventData)
    local guiDetails = eventData.data ---@type GuiDetails
    if guiDetails.finished == true or next(guiDetails.openPlayers) == nil then
        -- All the instances have been closed or removed already.
        return
    end

    if guiDetails.timerCountDirection == "down" then
        guiDetails.timerCurrentSeconds = guiDetails.timerCurrentSeconds - 1
    else
        guiDetails.timerCurrentSeconds = guiDetails.timerCurrentSeconds + 1
    end

    local renderText = ShowMessage.GetSimpleTextTimerRenderText(guiDetails.originalSimpleText, guiDetails.timerCurrentSeconds, guiDetails.timerDisplayFormat)

    for playerIndex in pairs(guiDetails.openPlayers) do
        local guiLuaElementToUpdate = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "ShowMessage", guiDetails.name .. "_simpleText", "label")
        if guiLuaElementToUpdate == nil then
            -- Error on our side.
            Logging.LogPrintError("Error muppet_gui_show_message: we've lost our own GUI with a timer, oops. Report to mod author.")
            return
        elseif guiLuaElementToUpdate.valid then
            guiLuaElementToUpdate.caption = renderText
        else
            -- Something removed our GUI.
            Logging.LogPrintError("Error muppet_gui_show_message: another mod deleted our GUI, so can't update its timer.")
            return
        end
    end

    EventScheduler.ScheduleEventOnce(eventData.tick + 60, "ShowMessage.UpdateSimpleTextTimer_Scheduled", guiDetails.name .. guiDetails.timerCurrentSeconds, guiDetails)
end

--- Called to generate the render text for a timer in simpleText.
---@param simpleText string
---@param currentSeconds int
---@param timerDisplayFormat ShowMessage_TimerDisplayFormat
---@return string simpleRenderText
ShowMessage.GetSimpleTextTimerRenderText = function(simpleText, currentSeconds, timerDisplayFormat)
    local timePretty
    if timerDisplayFormat == "minute" then
        -- Can use the timer display function naturally. With the time units auto updating.
        timePretty = StringUtils.DisplayTimeOfTicks(currentSeconds * 60, timerDisplayFormat, "second")
    else
        timePretty = StringUtils.PadNumberToMinimumDigits(currentSeconds, 2)
    end
    local renderText = string.gsub(simpleText, "%[!TIMER!]", timePretty, 1)
    return renderText
end

return ShowMessage
