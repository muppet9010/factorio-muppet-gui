local RemoveMessage = {} ---@class RemoveMessage
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

---@class RemoveMessageDetails
---@field messageId string

--- The remove_message remote interface has been called.
---@param data RemoveMessageDetails
RemoveMessage.RemoveMessage_RemoteInterface = function(data)
    local errorMessageStart = "ERROR: remote `muppet_gui.remove_message`: "
    local warningPrefix = "Warning: remote `muppet_gui.remove_message`: "

    if data == nil or type(data) ~= "table" then
        Logging.LogPrintError(errorMessageStart .. "mandatory options object not provided")
        return
    end

    local errorMessage = RemoveMessage.RemoveMessage_DoIt(data, warningPrefix)
    if errorMessage ~= nil then
        Logging.LogPrintError(errorMessageStart .. errorMessage)
        return
    end
end

--- Remove the message from the command/remote.
---@param data RemoveMessageDetails
---@param warningPrefix string
---@return string|nil errorMessage
RemoveMessage.RemoveMessage_DoIt = function(data, warningPrefix)
    for key in pairs(data--[[@as table<string, any>]] ) do
        if key ~= "messageId" then
            Logging.LogPrintWarning(warningPrefix .. "contained an unexpected key that will be ignored: `" .. tostring(key) .. "`")
        end
    end

    local messageId = data.messageId
    if messageId == nil then
        return "mandatory `messageId` not provided." ---@diagnostic disable-line:missing-return-value # We don't need to return the other fields for a non success.
    end

    local messageToRemove = global.showMessage.guis[messageId]
    if messageToRemove == nil then
        Logging.LogPrintWarning(warningPrefix .. "requested removal of a non existant message: `" .. tostring(messageId) .. "`")
        return
    end

    -- Call to remove the GUI for all players.
    MOD.Interfaces.ShowMessage.RemoveGuiForAll(messageToRemove)
end

return RemoveMessage
