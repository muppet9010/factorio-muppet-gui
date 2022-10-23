local ShowMessage = require("scripts.show-message")
local RemoveMessage = require("scripts.remove-message")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local GUIActionsClick = require("utility.manager-libraries.gui-actions-click")

local function CreateGlobals()
    ShowMessage.CreateGlobals()
end

local function OnLoad()
    remote.remove_interface("muppet_gui")
    remote.add_interface(
        "muppet_gui",
        {
            show_message = ShowMessage.ShowMessage_RemoteInterface,
            remove_message = RemoveMessage.RemoveMessage_RemoteInterface
        }
    )

    ShowMessage.OnLoad()
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)

EventScheduler.RegisterScheduler()
GUIActionsClick.MonitorGuiClickActions()

-- Mod wide function interface table creation. Means EmmyLua can support it.
MOD = MOD or {} ---@class MOD
MOD.Interfaces = MOD.Interfaces or {} ---@class MOD_InternalInterfaces
--[[
    Populate and use from within module's OnLoad() functions with simple table reference structures, i.e:
        MOD.Interfaces.Tunnel = MOD.Interfaces.Tunnel or {} ---@class InternalInterfaces_XXXXXX
        MOD.Interfaces.Tunnel.CompleteTunnel = Tunnel.CompleteTunnel
--]]
--
