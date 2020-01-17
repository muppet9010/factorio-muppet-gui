local function CreateGlobals()
end

local function OnLoad()
	--Any Remote Interface registration calls can go in here or in root of control.lua
end

local function OnStartup()
    CreateGlobals()
    OnSettingChanged(nil)
	OnLoad()
end


script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
