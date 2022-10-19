local ShowMessage = require("scripts.show-message")
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
