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

function ns.Debug(msg, isConsumable)
	if not ns.DB then return end
	if not ns.DB.debugLog then ns.DB.debugLog = {} end
	
	local prefix = "|cff00ccff[BC]|r "
	if isConsumable then
		prefix = prefix .. "|cff00ffff[C]|r "
	end

	table.insert(ns.DB.debugLog, {
		time = GetTime(),
		msg = msg,
		isConsumable = isConsumable
	})
	
	-- Keep only last 100 entries
	if #ns.DB.debugLog > 100 then
		table.remove(ns.DB.debugLog, 1)
	end
	
	print(prefix .. msg)
end

function ns.GetItemDisplayName(item)
	if not item then return "Unknown Item" end
	local name = item.name or "Unknown Item"
	if item.isConsumable and ns.ConsumableSignaler and ns.ConsumableSignaler.FormatItemName then
		return ns.ConsumableSignaler:FormatItemName(name, true)
	end
	return name
end

function ns.Mixin(target, source)
	for key, value in pairs(source) do
		if target[key] == nil then
			target[key] = value
		end
	end
	return target
end

function BetterControl_HandleBinding(action)
	if ns and ns.BindingDispatcher then
		ns.BindingDispatcher(action)
	end
end

-- ============================================================================
-- GamePad Detection and Auto-Configuration
-- ============================================================================

-- CVars verificados oficialmente en Wowpedia (añadidos en Patch 9.0.1)
local GAMEPAD_CVARS = {
	{ name = "GamePadEnable", value = "1", desc = "Habilita soporte de gamepad", required = true },
	{ name = "GamePadEmulateCtrl", value = "1", desc = "Permite modificador Ctrl", required = false },
	{ name = "GamePadEmulateShift", value = "1", desc = "Permite modificador Shift", required = false },
	{ name = "GamePadEmulateAlt", value = "1", desc = "Permite modificador Alt", required = false },
	{ name = "GamePadEmulateEsc", value = "1", desc = "Permite tecla Escape", required = false },
	{ name = "GamePadCursorLeftClick", value = "1", desc = "Habilita clic izquierdo", required = false },
	{ name = "GamePadCursorRightClick", value = "1", desc = "Habilita clic derecho", required = false },
}

function ns.IsGamePadEnabled()
	return GetCVarBool and GetCVarBool("GamePadEnable")
end

function ns.CheckGamePadConfiguration()
	local allConfigured = true
	local missingCVars = {}

	for _, cvar in ipairs(GAMEPAD_CVARS) do
		local current = GetCVar(cvar.name)
		if current ~= cvar.value then
			allConfigured = false
			table.insert(missingCVars, cvar.name)
		end
	end

	return allConfigured, missingCVars
end

function ns.ConfigureGamePad()
	print("|cff00ccff[Better Control]|r Configurando gamepad...")

	local configured = 0
	for _, cvar in ipairs(GAMEPAD_CVARS) do
		local success = pcall(SetCVar, cvar.name, cvar.value)
		if success then
			configured = configured + 1
			print("  |cff00ff00✓|r " .. cvar.desc)
		else
			print("  |cffff0000✗|r Error configurando: " .. cvar.name)
		end
	end

	if configured == #GAMEPAD_CVARS then
		print("|cff00ff00[Better Control]|r GamePad configurado correctamente.")
		print("|cffffff00Escribe /reload para aplicar los cambios.|r")
		return true
	else
		print("|cffff6600[Better Control]|r Algunos CVars no se pudieron configurar.")
		return false
	end
end

function ns.NotifyGamePadStatus()
	-- Solo notificar una vez por sesión
	if ns.DB and ns.DB.gamepadNotified then
		return
	end

	local enabled = ns.IsGamePadEnabled()

	if not enabled then
		-- Esperar 3 segundos después del login para no saturar el chat
		C_Timer.After(3, function()
			print(" ")
			print("|cffff6600========================================|r")
			print("|cff00ccff[Better Control]|r |cffff6600GamePad no detectado|r")
			print(" ")
			print("Para usar un mando/controlador en WoW:")
			print("|cffffff00• Escribe: /bcv setup|r")
			print("|cffffff00• Luego: /reload|r")
			print(" ")
			print("Esto configurará automáticamente todo")
			print("lo necesario para usar tu controlador.")
			print("|cffff6600========================================|r")
			print(" ")
		end)
	else
		-- GamePad habilitado, verificar si está bien configurado
		local allConfigured, missing = ns.CheckGamePadConfiguration()
		if not allConfigured then
			C_Timer.After(3, function()
				print(" ")
				print("|cff00ccff[Better Control]|r GamePad habilitado pero faltan algunas configuraciones.")
				print("|cffffff00Escribe /bcv setup para configurar todo automáticamente.|r")
				print(" ")
			end)
		end
	end

	-- Marcar como notificado para esta sesión
	if ns.DB then
		ns.DB.gamepadNotified = true
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
	-- Procesar comandos especiales primero
	local cmd = message:lower():trim()

	if cmd == "setup" then
		ns.ConfigureGamePad()
		return
	elseif cmd == "check" or cmd == "gamepad" then
		local enabled = ns.IsGamePadEnabled()
		if enabled then
			local allConfigured, missing = ns.CheckGamePadConfiguration()
			if allConfigured then
				print("|cff00ff00[Better Control]|r GamePad correctamente configurado ✓")
			else
				print("|cffff6600[Better Control]|r GamePad habilitado pero faltan configuraciones.")
				print("CVars faltantes: " .. table.concat(missing, ", "))
				print("|cffffff00Usa /bcv setup para configurar todo.|r")
			end
		else
			print("|cffff0000[Better Control]|r GamePad NO habilitado.")
			print("|cffffff00Usa /bcv setup para habilitarlo.|r")
		end
		return
	elseif cmd == "help" or cmd == "?" then
		print(" ")
		print("|cff00ccff[Better Control]|r Comandos disponibles:")
		print("  |cffffff00/bcv|r o |cffffff00/bcv show|r - Abrir ventana de vendor")
		print("  |cffffff00/bcv hide|r - Cerrar ventana de vendor")
		print("  |cffffff00/bcv setup|r - Configurar gamepad automáticamente")
		print("  |cffffff00/bcv check|r - Ver estado de gamepad")
		print("  |cffffff00/bcv help|r - Mostrar esta ayuda")
		print(" ")
		return
	end

	-- Comandos del vendor (show, hide, etc.)
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
		ns.Debug("ADDON_LOADED: Dispatching modules")
		dispatch("OnAddonLoaded")
		return
	end

	if event == "PLAYER_LOGIN" then
		ns.Debug("PLAYER_LOGIN: Dispatching modules")
		xpcall(function()
			dispatch("OnPlayerLogin")
			-- Verificar configuración de gamepad después de que todo esté cargado
			ns.NotifyGamePadStatus()
		end, function(err)
			ns.Debug("CRITICAL ERROR during OnPlayerLogin: " .. tostring(err))
		end)
		return
	end

	dispatch("OnEvent", event, ...)
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
