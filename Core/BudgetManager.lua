local _, ns = ...

-- ============================================================================
-- Core/BudgetManager.lua
-- Seguimiento de gasto semanal con límite configurable y advertencias.
-- Fase 12 de la UI Revolucionaria.
-- ============================================================================

local BudgetManager = {}
ns.BudgetManager = BudgetManager

-- Defaults inyectados en ns.DEFAULTS desde OnAddonLoaded
local DEFAULT_BUDGET = {
	enabled      = false,
	weeklyLimit  = 100000,  -- en cobre (100g)
	currentSpent = 0,
	weekStart    = 0,       -- timestamp del inicio de la semana actual
	warnings     = {
		at50Percent = true,
		at75Percent = true,
		at90Percent = true,
	},
}

-- Umbrales de advertencia (fracción del límite)
local WARNING_THRESHOLDS = {
	{ key = "at50Percent", pct = 0.50, color = "|cffffff00" },
	{ key = "at75Percent", pct = 0.75, color = "|cffff8800" },
	{ key = "at90Percent", pct = 0.90, color = "|cffff2200" },
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Acceso a datos
-- ──────────────────────────────────────────────────────────────────────────────

local function getBudget()
	if not ns.DB then return DEFAULT_BUDGET end
	if not ns.DB.budgetMode then
		ns.DB.budgetMode = {}
		for k, v in pairs(DEFAULT_BUDGET) do
			ns.DB.budgetMode[k] = v
		end
		ns.DB.budgetMode.warnings = {}
		for k, v in pairs(DEFAULT_BUDGET.warnings) do
			ns.DB.budgetMode.warnings[k] = v
		end
	end
	return ns.DB.budgetMode
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Reset semanal automático
-- ──────────────────────────────────────────────────────────────────────────────

function BudgetManager:CheckWeekReset()
	local budget = getBudget()
	local now    = time()

	-- Calcular inicio de la semana actual (lunes a las 00:00)
	local t    = date("*t", now)
	local wday = t.wday -- 1=dom, 2=lun, ...
	local daysFromMonday = (wday == 1) and 6 or (wday - 2)
	local weekStart = now - daysFromMonday * 86400
		- t.hour * 3600 - t.min * 60 - t.sec

	if budget.weekStart < weekStart then
		budget.weekStart    = weekStart
		budget.currentSpent = 0
		budget.warnedThresholds = {}
		ns.Debug("[BudgetManager] Weekly budget reset.")
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Registrar gasto
-- ──────────────────────────────────────────────────────────────────────────────

function BudgetManager:RecordSpend(amountCopper)
	local budget = getBudget()
	if not budget.enabled then return end

	self:CheckWeekReset()
	budget.currentSpent = (budget.currentSpent or 0) + amountCopper
	self:CheckWarnings()
	self:UpdateIndicator()
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Verificar si una compra supera el presupuesto
-- Devuelve true si la compra es permitida, false si excede el límite.
-- ──────────────────────────────────────────────────────────────────────────────

function BudgetManager:CanAfford(amountCopper)
	local budget = getBudget()
	if not budget.enabled then return true end
	self:CheckWeekReset()
	local remaining = budget.weeklyLimit - (budget.currentSpent or 0)
	return amountCopper <= remaining
end

function BudgetManager:GetRemaining()
	local budget = getBudget()
	self:CheckWeekReset()
	return math.max(budget.weeklyLimit - (budget.currentSpent or 0), 0)
end

function BudgetManager:GetPercent()
	local budget = getBudget()
	if budget.weeklyLimit <= 0 then return 0 end
	return math.min((budget.currentSpent or 0) / budget.weeklyLimit, 1.0)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Advertencias
-- ──────────────────────────────────────────────────────────────────────────────

function BudgetManager:CheckWarnings()
	local budget = getBudget()
	if not budget.warnings then return end
	if not budget.warnedThresholds then budget.warnedThresholds = {} end

	local pct = self:GetPercent()

	for _, threshold in ipairs(WARNING_THRESHOLDS) do
		if budget.warnings[threshold.key]
		   and not budget.warnedThresholds[threshold.key]
		   and pct >= threshold.pct then
			budget.warnedThresholds[threshold.key] = true
			self:ShowWarning(threshold, pct)
		end
	end
end

function BudgetManager:ShowWarning(threshold, currentPct)
	local budget = getBudget()
	local spent   = ns.FrameFactory and ns.FrameFactory.FormatMoney and
		ns.FrameFactory.FormatMoney(budget.currentSpent) or tostring(budget.currentSpent)
	local limit   = ns.FrameFactory and ns.FrameFactory.FormatMoney and
		ns.FrameFactory.FormatMoney(budget.weeklyLimit) or tostring(budget.weeklyLimit)

	print(threshold.color .. "[Better Control] Budget " ..
		math.floor(currentPct * 100) .. "% utilizado|r - " ..
		spent .. " / " .. limit)

	if ns.HapticFeedback then
		ns.HapticFeedback:Trigger("error", 0.6)
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Indicador visual en pantalla
-- ──────────────────────────────────────────────────────────────────────────────

function BudgetManager:UpdateIndicator()
	local budget = getBudget()
	if not budget.enabled then
		if self.indicatorFrame then self.indicatorFrame:Hide() end
		return
	end

	if not self.indicatorFrame then
		self:CreateIndicator()
	end

	local pct = self:GetPercent()
	local remaining = self:GetRemaining()

	-- Texto
	local fmtMoney = ns.FrameFactory and ns.FrameFactory.FormatMoney or tostring
	self.indicatorFrame.remaining:SetText(fmtMoney(remaining) .. " restante")

	-- Barra de progreso
	local bar = self.indicatorFrame.bar
	bar:SetWidth(math.max(pct * 150, 2))

	if pct < 0.5 then
		bar:SetColorTexture(0.2, 0.8, 0.2, 0.9)
	elseif pct < 0.75 then
		bar:SetColorTexture(0.9, 0.7, 0.1, 0.9)
	elseif pct < 0.9 then
		bar:SetColorTexture(1, 0.4, 0.1, 0.9)
	else
		bar:SetColorTexture(1, 0.1, 0.1, 0.9)
	end

	-- Porcentaje
	self.indicatorFrame.pctLabel:SetText(math.floor(pct * 100) .. "%")

	self.indicatorFrame:Show()
end

function BudgetManager:CreateIndicator()
	local f = CreateFrame("Frame", "BCBudgetIndicator", UIParent)
	f:SetSize(170, 44)
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -200)
	f:SetFrameStrata("MEDIUM")

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.04, 0.04, 0.06, 0.85)

	local titleTex = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	titleTex:SetPoint("TOPLEFT", 6, -4)
	titleTex:SetText("Budget Semanal")
	titleTex:SetTextColor(0.6, 0.8, 1)

	f.remaining = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.remaining:SetPoint("TOPRIGHT", -6, -4)
	f.remaining:SetTextColor(0.9, 0.9, 0.9)

	-- Track de la barra (fondo)
	local track = f:CreateTexture(nil, "ARTWORK")
	track:SetSize(150, 10)
	track:SetPoint("BOTTOMLEFT", 10, 6)
	track:SetColorTexture(0.2, 0.2, 0.2, 0.8)

	-- Relleno de la barra
	f.bar = f:CreateTexture(nil, "BORDER")
	f.bar:SetSize(1, 10)
	f.bar:SetPoint("LEFT", track, "LEFT")
	f.bar:SetColorTexture(0.2, 0.8, 0.2, 0.9)

	f.pctLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.pctLabel:SetPoint("RIGHT", track, "RIGHT", 18, 0)
	f.pctLabel:SetTextColor(1, 1, 1)

	self.indicatorFrame = f
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Inicialización
-- ──────────────────────────────────────────────────────────────────────────────

function BudgetManager:OnAddonLoaded()
	if ns.DEFAULTS then
		if not ns.DEFAULTS.budgetMode then
			ns.DEFAULTS.budgetMode = {}
			for k, v in pairs(DEFAULT_BUDGET) do
				ns.DEFAULTS.budgetMode[k] = v
			end
		end
	end
end

function BudgetManager:OnPlayerLogin()
	self:CheckWeekReset()
	self:UpdateIndicator()
end

ns.RegisterModule("BudgetManager", BudgetManager)
