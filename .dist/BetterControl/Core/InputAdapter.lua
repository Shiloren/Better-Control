local _, ns = ...

local InputAdapter = {}
ns.InputAdapter = InputAdapter

local PROFILES = {
	mouse = {
		confirm = "Click",
		cancel = "Esc",
		quick = "+1",
		max = "Max",
		prevTab = "Q",
		nextTab = "E",
		pageDown = "PgDn",
		pageUp = "PgUp",
		select = "Space",
		commit = "Enter",
	},
	xbox = {
		confirm = "A",
		cancel = "B",
		quick = "X",
		max = "Y",
		prevTab = "LB",
		nextTab = "RB",
		pageDown = "LT",
		pageUp = "RT",
		select = "View",
		commit = "Menu",
	},
}

local BUTTON_MAP = {
	ENTER = "confirm",
	SPACE = "confirm",
	NUMPADENTER = "confirm",
	BUTTON1 = "confirm",
	PAD1 = "confirm",
	ESCAPE = "cancel",
	BACKSPACE = "cancel",
	PAD2 = "cancel",
	X = "quick",
	PAD3 = "quick",
	Y = "max",
	PAD4 = "max",
	Q = "prevTab",
	PAGEUP = "prevTab",
	PADLSHOULDER = "prevTab",
	E = "nextTab",
	PAGEDOWN = "nextTab",
	PADRSHOULDER = "nextTab",
	PADLTRIGGER = "pageDown",
	PADRTRIGGER = "pageUp",
	PADBACK = "select",
	TAB = "select",
	PADFORWARD = "commit",
	UP = "up",
	DOWN = "down",
	LEFT = "left",
	RIGHT = "right",
	W = "up",
	S = "down",
	A = "left",
	D = "right",
	PADDUP = "up",
	PADDDOWN = "down",
	PADDLEFT = "left",
	PADDRIGHT = "right",
	PADLSTICKUP = "up",
	PADLSTICKDOWN = "down",
	PADLSTICKLEFT = "left",
	PADLSTICKRIGHT = "right",
}

local function getVendorConfig()
	return ns.DB and ns.DB.vendor or ns.DEFAULTS.vendor
end

function InputAdapter:GetMode()
	local config = getVendorConfig()
	if config.preferredInputMode and config.preferredInputMode ~= "auto" then
		return config.preferredInputMode
	end

	if config.detectConsolePort and IsAddOnLoaded and IsAddOnLoaded("ConsolePort") then
		return "xbox"
	end

	if GetCVarBool and GetCVarBool("GamePadEnable") then
		return "xbox"
	end

	return "mouse"
end

function InputAdapter:IsControllerMode()
	return self:GetMode() ~= "mouse"
end

function InputAdapter:GetProfile()
	return PROFILES[self:GetMode()] or PROFILES.mouse
end

function InputAdapter:GetActionLabel(action)
	local profile = self:GetProfile()
	return profile[action] or action
end

function InputAdapter:NormalizeButton(button)
	if not button then
		return nil
	end

	button = tostring(button):upper()

	local config = getVendorConfig()
	if config.allyBackLeftKey and button == tostring(config.allyBackLeftKey):upper() then
		return "select"
	end

	if config.allyBackRightKey and button == tostring(config.allyBackRightKey):upper() then
		return "commit"
	end

	return BUTTON_MAP[button]
end

function InputAdapter:Attach(frame, callback)
	if frame.SetPropagateKeyboardInput then
		frame:SetPropagateKeyboardInput(false)
	end

	if frame.EnableKeyboard then
		frame:EnableKeyboard(true)
	end

	if frame.EnableMouseWheel then
		frame:EnableMouseWheel(true)
	end

	if frame.EnableGamePadButton then
		frame:EnableGamePadButton(true)
	end

	frame:SetScript("OnKeyDown", function(_, key)
		local action = InputAdapter:NormalizeButton(key)
		if action then
			callback(action, key)
		end
	end)

	frame:SetScript("OnGamePadButtonDown", function(_, button)
		local action = InputAdapter:NormalizeButton(button)
		if action then
			callback(action, button)
		end
	end)
end
