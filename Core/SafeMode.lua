local _, ns = ...

-- ============================================================================
-- Core/SafeMode.lua
-- Confirmaciones extra y cooldowns para prevenir errores costosos.
-- Fase 12 de la UI Revolucionaria.
-- ============================================================================

local SafeMode = {}
ns.SafeMode = SafeMode

-- Defaults
local DEFAULT_SAFE = {
	enabled                = false,
	confirmThreshold       = 10000,  -- cobre (10g) — pedir confirmación si supera
	confirmMaxBuy          = true,   -- siempre confirmar compras "max"
	cooldownBetweenBatch   = 2,      -- segundos entre acciones batch
	maxBatchSize           = 5000,   -- cantidad máxima de items por batch
}

-- Estado de cooldown
SafeMode.lastBatchTime = 0

-- ──────────────────────────────────────────────────────────────────────────────
-- Acceso a datos
-- ──────────────────────────────────────────────────────────────────────────────

local function getCfg()
	if not ns.DB then return DEFAULT_SAFE end
	if not ns.DB.safeMode then
		ns.DB.safeMode = {}
		for k, v in pairs(DEFAULT_SAFE) do
			ns.DB.safeMode[k] = v
		end
	end
	return ns.DB.safeMode
end

-- ──────────────────────────────────────────────────────────────────────────────
-- API pública
-- ──────────────────────────────────────────────────────────────────────────────

-- Verifica si una compra necesita confirmación.
-- callback(confirmed) se llama con true/false cuando el usuario decide.
function SafeMode:CheckPurchase(totalCost, isMaxBuy, callback)
	if type(callback) ~= "function" then return end

	local cfg = getCfg()
	if not cfg.enabled then
		callback(true)
		return
	end

	local needsConfirm = (totalCost >= cfg.confirmThreshold)
		or (isMaxBuy and cfg.confirmMaxBuy)

	if not needsConfirm then
		callback(true)
		return
	end

	self:ShowConfirmDialog(totalCost, callback)
end

-- Verifica si se puede hacer una acción batch (cooldown + tamaño máximo).
-- Devuelve true si se puede proceder, false si está en cooldown.
function SafeMode:CanDoBatchAction(qty)
	local cfg = getCfg()
	if not cfg.enabled then return true end

	local now = GetTime()
	if now - self.lastBatchTime < cfg.cooldownBetweenBatch then
		local remaining = cfg.cooldownBetweenBatch - (now - self.lastBatchTime)
		print(string.format(
			"|cffff6600[Better Control]|r Safe Mode: espera %.1fs antes del siguiente batch.",
			remaining))
		if ns.HapticFeedback then ns.HapticFeedback:Trigger("error", 0.3) end
		return false
	end

	if qty and cfg.maxBatchSize and qty > cfg.maxBatchSize then
		print(string.format(
			"|cffff6600[Better Control]|r Safe Mode: máximo %d ítems por batch.",
			cfg.maxBatchSize))
		if ns.HapticFeedback then ns.HapticFeedback:Trigger("error", 0.3) end
		return false
	end

	return true
end

-- Registrar que se realizó un batch (para cooldown)
function SafeMode:MarkBatchDone()
	self.lastBatchTime = GetTime()
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Diálogo de confirmación
-- ──────────────────────────────────────────────────────────────────────────────

function SafeMode:ShowConfirmDialog(totalCost, callback)
	if not self.dialogFrame then
		self:BuildDialog()
	end

	local fmtMoney = ns.FrameFactory and ns.FrameFactory.FormatMoney or tostring
	local balance  = GetMoney and GetMoney() or 0
	local afterBuy = balance - totalCost

	self.dialogFrame.costLine:SetText(
		"Estás a punto de gastar:  |cffffff00" .. fmtMoney(totalCost) .. "|r")
	self.dialogFrame.balanceLine:SetText(
		"Saldo resultante:          |cffffff00" .. fmtMoney(math.max(afterBuy, 0)) .. "|r")

	-- Guardar callback
	self.pendingCallback = callback

	self.dialogFrame:Show()

	if ns.HapticFeedback then ns.HapticFeedback:Trigger("confirm", 1.0) end
end

function SafeMode:BuildDialog()
	local frame = CreateFrame("Frame", "BCSafeModeDialog", UIParent, "BasicFrameTemplate")
	frame:SetSize(340, 180)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("FULLSCREEN_DIALOG")

	if frame.TitleText then
		frame.TitleText:SetText("Confirmar Compra")
	end

	local warning = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	warning:SetPoint("TOP", 0, -30)
	warning:SetText("|cffff8800Compra grande detectada|r")

	frame.costLine = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.costLine:SetPoint("TOP", 0, -60)
	frame.costLine:SetText("")

	frame.balanceLine = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.balanceLine:SetPoint("TOP", 0, -82)
	frame.balanceLine:SetText("")

	-- Botón Confirmar
	local btnOk = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	btnOk:SetSize(110, 26)
	btnOk:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 14)
	btnOk:SetText("Confirmar [A]")
	btnOk:SetScript("OnClick", function()
		frame:Hide()
		if self.pendingCallback then
			self.pendingCallback(true)
			self.pendingCallback = nil
		end
	end)

	-- Botón Cancelar
	local btnCancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	btnCancel:SetSize(110, 26)
	btnCancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 14)
	btnCancel:SetText("Cancelar [B]")
	btnCancel:SetScript("OnClick", function()
		frame:Hide()
		if self.pendingCallback then
			self.pendingCallback(false)
			self.pendingCallback = nil
		end
	end)

	-- Gamepad shortcuts
	frame:EnableGamePadButton(true)
	frame:SetScript("OnGamePadButtonDown", function(_, button)
		if button == "PAD1" then     -- A
			btnOk:Click()
		elseif button == "PAD2" then -- B
			btnCancel:Click()
		end
	end)

	frame:Hide()
	self.dialogFrame = frame
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Inicialización
-- ──────────────────────────────────────────────────────────────────────────────

function SafeMode:OnAddonLoaded()
	if ns.DEFAULTS then
		if not ns.DEFAULTS.safeMode then
			ns.DEFAULTS.safeMode = {}
			for k, v in pairs(DEFAULT_SAFE) do
				ns.DEFAULTS.safeMode[k] = v
			end
		end
	end
end

ns.RegisterModule("SafeMode", SafeMode)
