local ADDON_NAME, ns = ...

_G.BetterControl = ns
ns.name = ADDON_NAME
ns.modules = {}

BINDING_HEADER_BETTERCONTROL = "Better Control"
BINDING_NAME_BETTERCONTROL_VENDOR_CONFIRM = "Vendor: Confirm / Start"
BINDING_NAME_BETTERCONTROL_VENDOR_CANCEL = "Vendor: Cancel / Close"
BINDING_NAME_BETTERCONTROL_VENDOR_QUICK = "Vendor: Quick Action"
BINDING_NAME_BETTERCONTROL_VENDOR_MAX = "Vendor: Max Action"
BINDING_NAME_BETTERCONTROL_VENDOR_SELECT = "Vendor: Mode / Select Toggle"
BINDING_NAME_BETTERCONTROL_VENDOR_COMMIT = "Vendor: Commit Grouped Action"
BINDING_NAME_BETTERCONTROL_VENDOR_PREV_TAB = "Vendor: Previous Tab"
BINDING_NAME_BETTERCONTROL_VENDOR_NEXT_TAB = "Vendor: Next Tab"
BINDING_NAME_BETTERCONTROL_VENDOR_UP = "Vendor: Move Up"
BINDING_NAME_BETTERCONTROL_VENDOR_DOWN = "Vendor: Move Down"
BINDING_NAME_BETTERCONTROL_VENDOR_PAGE_DOWN = "Vendor: Large Step Down"
BINDING_NAME_BETTERCONTROL_VENDOR_PAGE_UP = "Vendor: Large Step Up"

local function copyDefaults(source, destination)
	if type(source) ~= "table" then
		return destination
	end

	if type(destination) ~= "table" then
		destination = {}
	end

	for key, value in pairs(source) do
		if type(value) == "table" then
			destination[key] = copyDefaults(value, destination[key])
		elseif destination[key] == nil then
			destination[key] = value
		end
	end

	return destination
end

ns.DEFAULTS = {
	vendor = {
		enabled = true,
		defaultFilter = "consumables",
		baseCadence = 0.5,
		maxCadence = 1.5,
		detectConsolePort = true,
		preferredInputMode = "auto",
		rememberTab = "buy",
		lastQuantityMode = "purchase",
		allyBackLeftKey = nil,
		allyBackRightKey = nil,
		quickAmounts = { 1, "bundle", "max" },
	},
}

function ns.RegisterModule(name, module)
	ns.modules[name] = module
end

function BetterControl_HandleBinding(action)
	if ns and ns.BindingDispatcher then
		ns.BindingDispatcher(action)
	end
end

local addon = CreateFrame("Frame")
ns.Addon = addon

local function dispatch(method, ...)
	for _, module in pairs(ns.modules) do
		local handler = module[method]
		if type(handler) == "function" then
			handler(module, ...)
		end
	end
end

function addon:RegisterRuntimeEvent(eventName)
	self:RegisterEvent(eventName)
end

function addon:GetDB()
	return ns.DB
end

SLASH_BETTERCONTROL1 = "/bettercontrol"
SLASH_BETTERCONTROL2 = "/bcv"
SlashCmdList.BETTERCONTROL = function(message)
	dispatch("OnSlashCommand", message)
end

SLASH_BCRELOAD1 = "/rl"
SlashCmdList["BCRELOAD"] = function()
	ReloadUI()
end

addon:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local loadedName = ...
		if loadedName ~= ADDON_NAME then
			return
		end

		BetterControlDB = copyDefaults(ns.DEFAULTS, BetterControlDB or {})
		ns.DB = BetterControlDB
		dispatch("OnAddonLoaded")
		return
	end

	if event == "PLAYER_LOGIN" then
		dispatch("OnPlayerLogin")
		return
	end

	dispatch("OnEvent", event, ...)
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
