local showMessage = {}
local GUIUtil = require("utility/gui-util")
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local Utils = require("utility/utils")

showMessage.OnLoad = function()
    Commands.Register("muppet_gui_show_message", {"api-description.muppet_gui_show_message"}, showMessage.CommandRun, true)
end

showMessage.CommandRun = function(commandData)
    local errorMessageStart = "ERROR: command muppet_gui_show_message: "
    game.print(commandData.parameter)
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
    local simpleText = message.text
    if simpleText ~= nil then
        simpleText = tostring(simpleText)
    end

    local close = data.close
    if close == nil then
        Logging.LogPrint(errorMessageStart .. "mandatory 'close' object not provided")
        return
    end
    if close.timeout ~= nil then
    --TODO get and store setting, also schedule removal of message
    end

    if simpleText ~= nil then
        for _, player in pairs(players) do
            global.messageCount = global.messageCount + 1
            local frame = GUIUtil.AddElement({parent = player.gui.top, name = "muppet_gui_show_message" .. global.messageCount, type = "frame", style = "muppet_margin_frame_content"})
            GUIUtil.AddElement({parent = frame, name = "muppet_gui_show_message" .. global.messageCount, type = "label", caption = simpleText, style = "muppet_large_bold_text"})
        end
    end
end

return showMessage
