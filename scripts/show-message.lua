local ShowMessage = {}
local GUIUtil = require("utility/gui-util")
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local GUIActionsClick = require("utility/gui-actions-click")
local Colors = require("utility/colors")
--local Utils = require("utility/utils")

local errorMessageStart = "ERROR: command muppet_gui_show_message: "

ShowMessage.CreateGlobals = function()
    global.showMessage = global.showMessage or {}
    global.showMessage.count = global.showMessage.count or 0
    global.showMessage.buttons = global.showMessage.buttons or {}
end

ShowMessage.OnLoad = function()
    Commands.Register("muppet_gui_show_message", {"api-description.muppet_gui_show_message"}, ShowMessage.CommandRun, true)
    EventScheduler.RegisterScheduledEventType("ShowMessage.RemoveNamedElementForAll", ShowMessage.RemoveNamedElementForAll)
    GUIActionsClick.LinkGuiClickActionNameToFunction("ShowMessage.CloseSimpleTextFrame", ShowMessage.CloseSimpleTextFrame)
end

ShowMessage.CommandRun = function(commandData)
    local data = game.json_to_table(commandData.parameter)
    if data == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory JSON object not provided")
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
                    name = elementName,
                    type = "frame",
                    direction = "horizontal",
                    style = "muppet_frame_content_marginTL",
                    storeName = "ShowMessage",
                    styling = {maximal_width = maxWidth},
                    children = {
                        {
                            type = "label",
                            caption = simpleText,
                            style = fontType,
                            styling = {font_color = fontColor}
                        },
                        {
                            type = "flow",
                            direction = "horizontal",
                            style = "muppet_flow_horizontal_marginTL_paddingBR",
                            styling = {horizontal_align = "right", horizontally_stretchable = true},
                            exclude = not closeButton,
                            children = {
                                {
                                    name = elementName .. "_close",
                                    type = "sprite-button",
                                    sprite = "utility/close_white",
                                    style = "muppet_sprite_button_frameCloseButtonClickable",
                                    registerClick = {actionName = "ShowMessage.CloseSimpleTextFrame", data = {name = elementName, type = "frame"}}
                                }
                            }
                        }
                    }
                }
            )
        end
        if closeTick ~= nil then
            EventScheduler.ScheduleEvent(closeTick, "ShowMessage.RemoveNamedElementForAll", global.showMessage.count, {name = elementName, type = "frame"})
        end
    end
end

ShowMessage.GetAudienceData = function(data)
    if data.audience == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'audience' object not provided")
        return
    end

    local players = {}
    local logic = data.audience.logic
    if logic == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'audience.logic' string not provided")
        return
    end
    if logic == "all" then
        players = game.connected_players
    else
        local playerNames = data.audience.players
        if playerNames == nil then
            Logging.LogPrint(errorMessageStart .. "mandatory 'audience.players' array not provided")
            return
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
            Logging.LogPrint(errorMessageStart .. "invalid 'audience.logic' string not provided")
            return
        end
    end

    return true, players, logic
end

ShowMessage.GetMessageData = function(data)
    local message = data.message
    if message == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'message' object not provided")
        return
    end

    local simpleText = message.simpleText
    if simpleText ~= nil then
        simpleText = tostring(simpleText)
    else
        Logging.LogPrint(errorMessageStart .. "mandatory 'message.simpleText' object not provided")
        return
    end

    local position = message.position
    if position == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'message.position' string not provided")
        return
    end
    if position ~= "top" and position ~= "left" and position ~= "center" then
        Logging.LogPrint(errorMessageStart .. "mandatory 'message.position' string not valid type: '" .. position .. "'")
        return
    end

    local fontSize, fontStyle = message.fontSize, message.fontStyle
    if fontSize == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'message.fontSize' string not provided")
        return
    end
    if fontSize ~= "small" and fontSize ~= "medium" and fontSize ~= "large" then
        Logging.LogPrint(errorMessageStart .. "mandatory 'message.fontSize' string not valid type: '" .. fontSize .. "'")
        return
    end
    if fontStyle == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'message.fontStyle' string not provided")
        return
    end
    if fontStyle ~= "regular" and fontStyle ~= "semibold" and fontStyle ~= "bold" then
        Logging.LogPrint(errorMessageStart .. "mandatory 'message.fontStyle' string not valid type: '" .. fontStyle .. "'")
        return
    end
    local fontType = "muppet_label_text_" .. fontSize .. "_"
    if fontStyle ~= "regular" then
        fontType = fontType .. fontStyle
    end

    local fontColorString = message.fontColor
    local fontColor = Colors.white
    if fontColorString ~= nil and fontColorString ~= "" then
        fontColor = Colors[fontColorString]
        if fontColor == nil then
            Logging.LogPrint(errorMessageStart .. "mandatory 'message.fontColor' string not valid type: '" .. fontColorString .. "'")
            return
        end
    end

    local maxWidth = nil
    if message.maxWidth ~= nil and message.maxWidth ~= "" then
        maxWidth = tonumber(message.maxWidth)
        if maxWidth == nil or maxWidth <= 0 then
            Logging.LogPrint(errorMessageStart .. "optional 'message.maxWidth' is set, but not a positive number: '" .. fontColorString .. "'")
            return
        end
    end

    return true, simpleText, position, fontType, fontColor, maxWidth
end

ShowMessage.GetCloseData = function(data)
    local close = data.close
    if close == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'close' object not provided")
        return
    end

    local closeTick = nil
    local CloseTimeoutString = close.timeout
    if CloseTimeoutString ~= nil then
        local closeTimeout = tonumber(CloseTimeoutString)
        if closeTimeout == nil or closeTimeout <= 0 then
            Logging.LogPrint(errorMessageStart .. "'close.timeout' specified, but not valid positive number: '" .. CloseTimeoutString .. "'")
            return
        end
        closeTick = game.tick + (closeTimeout * 60)
    end

    local closeButton = false
    if close.xbutton ~= nil and close.xbutton == true then
        closeButton = true
    end

    if closeTick == nil and closeButton == false then
        Logging.LogPrint(errorMessageStart .. "no way to close GUI specified")
        return
    end

    return true, closeTick, closeButton
end

ShowMessage.RemoveNamedElementForAll = function(eventData)
    local data = eventData.data
    for _, player in pairs(game.players) do
        ShowMessage.RemoveNamedElementForPlayer(player.index, data.name, data.type)
    end
end

ShowMessage.RemoveNamedElementForPlayer = function(playerIndex, name, type)
    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "ShowMessage", name, type)
end

ShowMessage.CloseSimpleTextFrame = function(actionData)
    ShowMessage.RemoveNamedElementForPlayer(actionData.playerIndex, actionData.data.name, actionData.data.type)
    GUIActionsClick.RemoveGuiForClick(actionData.data.name, actionData.data.type)
end

return ShowMessage
