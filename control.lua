local ShowMessage = require("scripts/show-message")

local function CreateGlobals()
    global.messageCount = global.messageCount or 0
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    ShowMessage.OnLoad()
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
