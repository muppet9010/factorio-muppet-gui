local ShowMessage = {} ---@class ShowMessage
local GUIUtil = require("utility.manager-libraries.gui-util")
local Commands = require("utility.helper-utils.commands-utils")
local Logging = require("utility.helper-utils.logging-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local GUIActionsClick = require("utility.manager-libraries.gui-actions-click")
local Colors = require("utility.lists.colors")

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

---@class CloseDetails # Must have either `timeout` or `xbutton` populated.
---@field timeout uint|nil # If populated must be greater than 0. A nil value means don't auto close, a number greater than 0 is how many seconds before auto close.
---@field xbutton boolean|nil # If true then an x button is put on the GUI to close it.

---@class GuiToRemoveDetails
---@field name string
---@field type string


---@alias ShowMessage_Logic "only"|"not"|"all"
---@alias ShowMessage_Position "top"|"left"|"center"
---@alias ShowMessage_FontSize "small"|"medium"|"large"
---@alias ShowMessage_FontStyle "regular"|"semibold"|"bold"

local errorMessageStart = "ERROR: command muppet_gui_show_message: "

ShowMessage.CreateGlobals = function()
    global.showMessage = global.showMessage or {} ---@class ShowMessage_Global
    global.showMessage.count = global.showMessage.count or 0 ---@type int
    global.showMessage.buttons = nil ---@type nil Was created as an empty table in a previous version. So destroy it just to be safe.
end

ShowMessage.OnLoad = function()
    Commands.Register("muppet_gui_show_message", { "api-description.muppet_gui_show_message" }, ShowMessage.ShowMessage_CommandRun, true)
    EventScheduler.RegisterScheduledEventType("ShowMessage.RemoveNamedElementForAll", ShowMessage.RemoveNamedElementForAll)
    GUIActionsClick.LinkGuiClickActionNameToFunction("ShowMessage.CloseSimpleTextFrame", ShowMessage.CloseSimpleTextFrame)
end

--- The show_message command has been run.
---@param commandData CustomCommandData
ShowMessage.ShowMessage_CommandRun = function(commandData)
    local data = game.json_to_table(commandData.parameter) --[[@as ShowMessageDetails]]
    if data == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory JSON object not provided")
        return
    end

    local audienceSuccess, players = ShowMessage.GetAudienceData(data)
    if not audienceSuccess then
        return
    end

    local messageSuccess, simpleText, position, fontType, fontColor, maxWidth = ShowMessage.GetMessageData(data)
    if not messageSuccess then
        return
    end

    local closeSuccess, closeTick, closeButton = ShowMessage.GetCloseData(data)
    if not closeSuccess then
        return
    end

    if simpleText ~= nil then
        global.showMessage.count = global.showMessage.count + 1
        local elementName = "muppet_gui_show_message" .. global.showMessage.count
        for _, player in pairs(players) do
            GUIUtil.AddElement(
                {
                    parent = player.gui[position],
                    descriptiveName = elementName,
                    type = "frame",
                    direction = "horizontal",
                    style = "muppet_frame_content_marginTL",
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
                            style = "muppet_flow_horizontal_marginTL_paddingBR",
                            styling = { horizontal_align = "right", horizontally_stretchable = true },
                            exclude = not closeButton,
                            children = {
                                {
                                    descriptiveName = elementName .. "_close",
                                    type = "sprite-button",
                                    sprite = "utility/close_white",
                                    style = "muppet_sprite_button_frameCloseButtonClickable",
                                    registerClick = { actionName = "ShowMessage.CloseSimpleTextFrame", data = { name = elementName, type = "frame" } --[[@as GuiToRemoveDetails]] }
                                }
                            }
                        }
                    }
                }
            )
        end
        if closeTick ~= nil then
            EventScheduler.ScheduleEventOnce(closeTick, "ShowMessage.RemoveNamedElementForAll", global.showMessage.count, { name = elementName, type = "frame" }--[[@as GuiToRemoveDetails]] )
        end
    end
end

--- Work out the audience settings from the raw data.
---@param data ShowMessageDetails
---@return boolean success
---@return LuaPlayer[] players
---@return ShowMessage_Logic logic
ShowMessage.GetAudienceData = function(data)
    if data.audience == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'audience' object not provided")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local players = {}
    local logic = data.audience.logic
    if logic == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'audience.logic' string not provided")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if logic == "all" then
        players = game.connected_players
    else
        local playerNames = data.audience.players
        if playerNames == nil then
            Logging.LogPrintError(errorMessageStart .. "mandatory 'audience.players' array not provided")
            return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        if logic == "only" then
            for _, player in pairs(game.connected_players) do
                for _, playerName in pairs(playerNames) do
                    if player.name == playerName then
                        table.insert(players, player)
                    end
                end
            end
        elseif logic == "not" then
            local potentialPlayers = game.connected_players
            for i, player in pairs(potentialPlayers) do
                for _, playerName in pairs(playerNames) do
                    if player.name == playerName then
                        table.remove(potentialPlayers, i)
                        break
                    end
                end
            end
            players = potentialPlayers
        else
            Logging.LogPrintError(errorMessageStart .. "invalid 'audience.logic' string not provided")
            return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    end

    return true, players, logic
end

--- Work out the message details from the raw data.
---@param data ShowMessageDetails
---@return boolean success
---@return string simpleText
---@return ShowMessage_Position position
---@return ShowMessage_FontStyle fontType
---@return Color fontColor
---@return uint|nil maxWidth
ShowMessage.GetMessageData = function(data)
    local message = data.message
    if message == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'message' object not provided")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local simpleText = message.simpleText
    if simpleText ~= nil then
        simpleText = tostring(simpleText)
    else
        Logging.LogPrintError(errorMessageStart .. "mandatory 'message.simpleText' object not provided")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local position = message.position
    if position == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'message.position' string not provided")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if position ~= "top" and position ~= "left" and position ~= "center" then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'message.position' string not valid type: '" .. position .. "'")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local fontSize, fontStyle = message.fontSize, message.fontStyle
    if fontSize == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'message.fontSize' string not provided")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontSize ~= "small" and fontSize ~= "medium" and fontSize ~= "large" then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'message.fontSize' string not valid type: '" .. fontSize .. "'")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontStyle == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'message.fontStyle' string not provided")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    if fontStyle ~= "regular" and fontStyle ~= "semibold" and fontStyle ~= "bold" then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'message.fontStyle' string not valid type: '" .. fontStyle .. "'")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end
    local fontType = "muppet_label_text_" .. fontSize
    if fontStyle ~= "regular" then
        fontType = fontType .. "_" .. fontStyle
    end

    local fontColorString = message.fontColor
    local fontColor = Colors.white
    if fontColorString ~= nil and fontColorString ~= "" then
        fontColor = Colors[fontColorString] --[[@as Color]]
        if fontColor == nil then
            Logging.LogPrintError(errorMessageStart .. "mandatory 'message.fontColor' string not valid type: '" .. fontColorString .. "'")
            return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
    end

    local maxWidth ---@type uint
    if message.maxWidth ~= nil and message.maxWidth ~= "" then
        maxWidth = tonumber(message.maxWidth) --[[@as uint]]
        if maxWidth == nil or maxWidth <= 0 then
            Logging.LogPrintError(errorMessageStart .. "optional 'message.maxWidth' is set, but not a positive number: '" .. fontColorString .. "'")
            return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        maxWidth = math.floor(maxWidth) --[[@as uint]]
    end

    return true, simpleText, position, fontType, fontColor, maxWidth
end

--- Work out the close details from the raw data.
---@param data ShowMessageDetails
---@return boolean success
---@return uint|nil closeTick
---@return boolean closeButton
ShowMessage.GetCloseData = function(data)
    local close = data.close
    if close == nil then
        Logging.LogPrintError(errorMessageStart .. "mandatory 'close' object not provided")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local closeTick ---@type uint|nil
    local CloseTimeoutString = close.timeout
    if CloseTimeoutString ~= nil then
        local closeTimeout = tonumber(CloseTimeoutString)
        if closeTimeout == nil or closeTimeout <= 0 then
            Logging.LogPrintError(errorMessageStart .. "'close.timeout' specified, but not valid positive number: '" .. CloseTimeoutString .. "'")
            return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
        end
        closeTick = game.tick + (closeTimeout * 60)
    end

    local closeButton = false
    if close.xbutton ~= nil and close.xbutton == true then
        closeButton = true
    end

    if closeTick == nil and closeButton == false then
        Logging.LogPrintError(errorMessageStart .. "no way to close GUI specified")
        return false ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    return true, closeTick, closeButton
end

--- Called to remove all instances of a specific GUI for all players.
---@param eventData UtilityScheduledEvent_CallbackObject
ShowMessage.RemoveNamedElementForAll = function(eventData)
    local data = eventData.data ---@type GuiToRemoveDetails
    for _, player in pairs(game.players) do
        ShowMessage.RemoveNamedElementForPlayer(player.index, data.name, data.type)
    end
    GUIActionsClick.RemoveGuiForClick(eventData.data.name .. "_close", "sprite-button")
end

--- Actually remove the GUI element.
---@param playerIndex uint
---@param name string
---@param type string
ShowMessage.RemoveNamedElementForPlayer = function(playerIndex, name, type)
    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "ShowMessage", name, type)
end

--- Called to close a specific GUI for a specific player.
---@param actionData any
ShowMessage.CloseSimpleTextFrame = function(actionData)
    local data = actionData.data ---@type GuiToRemoveDetails
    ShowMessage.RemoveNamedElementForPlayer(actionData.playerIndex, data.name, data.type)
end

return ShowMessage
