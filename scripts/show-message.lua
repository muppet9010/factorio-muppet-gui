local ShowMessage = {}
local GUIUtil = require("utility/gui-util")
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local GUIActions = require("utility/gui-actions")
--local Utils = require("utility/utils")

ShowMessage.CreateGlobals = function()
    global.showMessage = global.showMessage or {}
    global.showMessage.count = global.showMessage.count or 0
    global.showMessage.buttons = global.showMessage.buttons or {}
end

ShowMessage.OnLoad = function()
    Commands.Register("muppet_gui_show_message", {"api-description.muppet_gui_show_message"}, ShowMessage.CommandRun, true)
    EventScheduler.RegisterScheduledEventType("ShowMessage.RemoveNamedElementForAll", ShowMessage.RemoveNamedElementForAll)
    GUIActions.RegisterActionType("ShowMessage.CloseSimpleTextFrame", ShowMessage.CloseSimpleTextFrame)
end

ShowMessage.CommandRun = function(commandData)
    local errorMessageStart = "ERROR: command muppet_gui_show_message: "
    local data = game.json_to_table(commandData.parameter)
    if data == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory JSON object not provided")
        return
    end

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

    local message = data.message
    if message == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'message' object not provided")
        return
    end
    local simpleText = message.simpleText
    if simpleText ~= nil then
        simpleText = tostring(simpleText)
    end

    local close = data.close
    if close == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'close' object not provided")
        return
    end
    local closeTick = nil
    if close.timeout ~= nil then
        local closeTimeout = tonumber(close.timeout)
        if closeTimeout == nil or closeTimeout <= 0 then
            Logging.LogPrint(errorMessageStart .. "'close.timeout' specified, but not valid positive number")
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

    if simpleText ~= nil then
        global.showMessage.count = global.showMessage.count + 1
        local elementName = "muppet_gui_show_message" .. global.showMessage.count
        for _, player in pairs(players) do
            local frame = GUIUtil.AddElement({parent = player.gui.top, name = elementName, type = "frame", style = "muppet_margin_frame_content"}, "ShowMessage")
            GUIUtil.AddElement({parent = frame, name = elementName, type = "label", caption = simpleText, style = "muppet_large_bold_text"})
            if closeButton == true then
                local closeButtonName = elementName .. "_close"
                GUIUtil.AddElement({parent = frame, name = closeButtonName, type = "sprite-button", sprite = "utility/close_white", style = "close_button"})
                GUIActions.RegisterButtonToAction(closeButtonName, "sprite-button", "ShowMessage.CloseSimpleTextFrame", {name = elementName, type = "frame"})
            end
        end
        if closeTick ~= nil then
            EventScheduler.ScheduleEvent(closeTick, "ShowMessage.RemoveNamedElementForAll", global.showMessage.count, {name = elementName, type = "frame"})
        end
    end
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
    GUIActions.RemoveButton(actionData.data.name, actionData.data.type)
end

return ShowMessage
