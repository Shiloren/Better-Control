local _, ns = ...

-- ============================================================================
-- Core/MacroSystem.lua
-- Sistema de grabación y reproducción de secuencias de compra (macros).
-- Trigger: presionar ambos sticks (L3 + R3 = PADLSTICK + PADRSTICK).
-- Fase 11 de la UI Revolucionaria.
-- ============================================================================

local MacroSystem = {}
ns.MacroSystem = MacroSystem

-- Estado de ejecución
MacroSystem.isRecording   = false
MacroSystem.isPlaying     = false
MacroSystem.currentMacro  = nil   -- macro en reproducción
MacroSystem.currentStep   = 0
MacroSystem.recordBuffer  = nil   -- macro siendo grabado

-- ──────────────────────────────────────────────────────────────────────────────
-- Estructura de un macro
-- ──────────────────────────────────────────────────────────────────────────────
--[[
Macro = {
    macroId     = string,
    name        = string,
    description = string,
    steps       = {
        { type = "loadCart",    cartId = string }
        { type = "execute",     action = "buyAll"|"clearCart" }
        { type = "wait",        duration = number }
        { type = "notify",      message = string }
    },
    lastUsed    = number (timestamp),
    useCount    = number,
}
--]]

-- ──────────────────────────────────────────────────────────────────────────────
-- Acceso a datos persistidos
-- ──────────────────────────────────────────────────────────────────────────────

local function getMacros()
	if not ns.DB then return {} end
	if not ns.DB.macros then ns.DB.macros = {} end
	return ns.DB.macros
end

-- ──────────────────────────────────────────────────────────────────────────────
-- CRUD de macros
-- ──────────────────────────────────────────────────────────────────────────────

function MacroSystem:CreateMacro(name, description)
	local macroId = "macro-" .. tostring(math.floor(GetTime()))
	local macro = {
		macroId     = macroId,
		name        = name or "New Macro",
		description = description or "",
		steps       = {},
		lastUsed    = 0,
		useCount    = 0,
	}
	local macros = getMacros()
	table.insert(macros, macro)
	return macro
end

function MacroSystem:GetMacro(macroId)
	for _, m in ipairs(getMacros()) do
		if m.macroId == macroId then return m end
	end
end

function MacroSystem:DeleteMacro(macroId)
	local macros = getMacros()
	for i, m in ipairs(macros) do
		if m.macroId == macroId then
			table.remove(macros, i)
			return true
		end
	end
	return false
end

function MacroSystem:GetAllMacros()
	return getMacros()
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Grabación
-- ──────────────────────────────────────────────────────────────────────────────

function MacroSystem:StartRecording(name)
	if self.isRecording then
		self:StopRecording()
	end
	self.recordBuffer = self:CreateMacro(name or "Recorded Macro")
	-- Quitar de la lista persistida hasta que termine la grabación
	local macros = getMacros()
	table.remove(macros, #macros)

	self.isRecording = true
	ns.Debug("[MacroSystem] Recording started: " .. self.recordBuffer.name)
	print("|cff00ccff[Better Control]|r |cffffff00Grabando macro:|r " .. self.recordBuffer.name .. " - realiza tus compras.")
end

function MacroSystem:RecordStep(stepType, data)
	if not self.isRecording or not self.recordBuffer then return end
	local step = { type = stepType }
	if data then
		for k, v in pairs(data) do step[k] = v end
	end
	table.insert(self.recordBuffer.steps, step)
end

function MacroSystem:StopRecording()
	if not self.isRecording then return end
	self.isRecording = false

	if self.recordBuffer and #self.recordBuffer.steps > 0 then
		table.insert(getMacros(), self.recordBuffer)
		ns.Debug("[MacroSystem] Macro saved: " .. self.recordBuffer.name ..
			" (" .. #self.recordBuffer.steps .. " steps)")
		print("|cff00ff00[Better Control]|r Macro guardado: " ..
			self.recordBuffer.name .. " (" .. #self.recordBuffer.steps .. " pasos)")
	end
	self.recordBuffer = nil
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Reproducción
-- ──────────────────────────────────────────────────────────────────────────────

function MacroSystem:Play(macroId)
	if self.isPlaying then
		ns.Debug("[MacroSystem] Already playing a macro, skipping.")
		return
	end

	local macro = self:GetMacro(macroId)
	if not macro or #macro.steps == 0 then
		print("|cffff6600[Better Control]|r Macro no encontrado o vacío: " .. tostring(macroId))
		return
	end

	self.isPlaying    = true
	self.currentMacro = macro
	self.currentStep  = 0

	macro.lastUsed = time()
	macro.useCount = (macro.useCount or 0) + 1

	print("|cff00ccff[Better Control]|r Ejecutando macro: |cffffff00" .. macro.name .. "|r")
	self:ExecuteNextStep()
end

function MacroSystem:ExecuteNextStep()
	if not self.isPlaying or not self.currentMacro then return end

	self.currentStep = self.currentStep + 1
	local steps = self.currentMacro.steps

	if self.currentStep > #steps then
		-- Macro finalizado
		self.isPlaying    = false
		self.currentMacro = nil
		self.currentStep  = 0
		print("|cff00ff00[Better Control]|r Macro completado.")
		if ns.HapticFeedback then ns.HapticFeedback:Trigger("success", 1.0) end
		return
	end

	local step = steps[self.currentStep]
	self:ExecuteStep(step)
end

function MacroSystem:ExecuteStep(step)
	local delay = 0

	if step.type == "loadCart" then
		local sa = ns.VendorFrame and ns.VendorFrame.views and ns.VendorFrame.views.buyFlow and ns.VendorFrame.views.buyFlow.smartActions
		if sa and sa.LoadDetectedCart then
			local cart = self:FindCartById(step.cartId)
			if cart then sa:LoadDetectedCart(cart) end
		end

	elseif step.type == "execute" then
		local vf = ns.VendorFrame
		if step.action == "buyAll" then
			if vf and vf.BuyAllCart then vf:BuyAllCart() end
		elseif step.action == "clearCart" then
			if vf and vf.ClearCart then vf:ClearCart() end
		end

	elseif step.type == "wait" then
		delay = step.duration or 1

	elseif step.type == "notify" then
		print("|cff00ccff[Better Control]|r " .. (step.message or ""))
	end

	C_Timer.After(delay, function()
		self:ExecuteNextStep()
	end)
end

function MacroSystem:FindCartById(cartId)
	if not ns.DB then return nil end
	local carts = ns.DB.detectedCarts or {}
	for _, c in ipairs(carts) do
		if c.cartId == cartId or c.name == cartId then
			return c
		end
	end
	return nil
end

function MacroSystem:Stop()
	self.isPlaying    = false
	self.currentMacro = nil
	self.currentStep  = 0
	print("|cffff6600[Better Control]|r Macro detenido.")
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Trigger: L3 + R3 (ambos sticks pulsados)
-- ──────────────────────────────────────────────────────────────────────────────

function MacroSystem:OnAddonLoaded()
	local l3Down = false
	local r3Down = false

	self.listenerFrame = CreateFrame("Frame", "BCMacroSystemListener")
	local listener = self.listenerFrame
	listener:EnableGamePadButton(true)

	listener:SetScript("OnGamePadButtonDown", function(_, button)
		if button == "PADLSTICK" then l3Down = true end
		if button == "PADRSTICK" then r3Down = true end

		if l3Down and r3Down then
			l3Down, r3Down = false, false
			-- Abrir editor de macros si no hay macro en curso
			if not self.isPlaying then
				if ns.MacroEditor then
					ns.MacroEditor:Toggle()
				end
			else
				self:Stop()
			end
		end
	end)

	listener:SetScript("OnGamePadButtonUp", function(_, button)
		if button == "PADLSTICK" then l3Down = false end
		if button == "PADRSTICK" then r3Down = false end
	end)
end

ns.RegisterModule("MacroSystem", MacroSystem)
