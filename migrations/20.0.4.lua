local GUIUtil = require("utility.manager-libraries.gui-util")

-- Remove old never used global.
global.showMessage.buttons = nil ---@type nil

-- Clear any old Message GUIs to avoid them erroring.
for _, player in pairs(game.players) do
    GUIUtil.DestroyPlayersReferenceStorage(player.index, "ShowMessage")
end

-- Clear any old scheduled removals.
for _, tickEvents in pairs(global.UTILITYSCHEDULEDFUNCTIONS) do
    for tickEventName in pairs(tickEvents) do
        if tickEventName == "ShowMessage.RemoveNamedElementForAll" then
            tickEvents["ShowMessage.RemoveNamedElementForAll"] = nil
        end
    end
end

-- Clear any old click registrations.
global.UTILITYGUIACTIONSGUICLICK = {}
