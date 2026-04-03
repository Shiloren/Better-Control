local _, ns = ...

-- ============================================================================
-- Core/AdaptiveUI.lua
-- Adapta la UI dinámicamente según patrones de uso aprendidos del usuario.
-- Fase 13 de la UI Revolucionaria.
-- ============================================================================

local AdaptiveUI = {}
ns.AdaptiveUI = AdaptiveUI

-- Umbrales para tomar decisiones
local GESTURE_PREFERENCE_THRESHOLD = 0.60  -- >60% gestos → preferir gestos
local CART_PREFERENCE_THRESHOLD    = 0.50  -- >50% carritos → expandir carritos

-- ──────────────────────────────────────────────────────────────────────────────
-- Análisis de patrones de uso
-- ──────────────────────────────────────────────────────────────────────────────

function AdaptiveUI:AnalyzeUsagePatterns()
	local tel = ns.DB and ns.DB.telemetry
	if not tel then
		return { prefersGestures = false, prefersCarts = false, topActions = {} }
	end

	-- Ratio gestos vs botones
	local gestureUse = tel.gesturesUsed    or 0
	local buttonUse  = tel.buttonsUsed     or 0
	local total      = gestureUse + buttonUse
	local gestureRatio = total > 0 and (gestureUse / total) or 0

	-- Ratio carritos vs compras manuales
	local cartUse    = tel.cartsLoaded     or 0
	local manualUse  = tel.manualPurchases or 0
	local cartTotal  = cartUse + manualUse
	local cartRatio  = cartTotal > 0 and (cartUse / cartTotal) or 0

	-- Top 3 acciones más frecuentes
	local topActions = self:GetTopActions(tel.actionFrequency or {}, 3)

	return {
		prefersGestures = gestureRatio >= GESTURE_PREFERENCE_THRESHOLD,
		prefersCarts    = cartRatio    >= CART_PREFERENCE_THRESHOLD,
		topActions      = topActions,
		gestureRatio    = gestureRatio,
		cartRatio       = cartRatio,
	}
end

function AdaptiveUI:GetTopActions(actionFrequency, n)
	local list = {}
	for action, count in pairs(actionFrequency) do
		table.insert(list, { action = action, count = count })
	end
	table.sort(list, function(a, b) return a.count > b.count end)

	local top = {}
	for i = 1, math.min(n, #list) do
		table.insert(top, list[i])
	end
	return top
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Aplicar adaptaciones al VendorFrame
-- ──────────────────────────────────────────────────────────────────────────────

function AdaptiveUI:ApplyAdaptations()
	local patterns = self:AnalyzeUsagePatterns()
	local vf       = ns.VendorFrame
	if not vf then return end

	-- Hints de gestos vs botones
	if vf.ShowGestureHints then
		vf:ShowGestureHints(patterns.prefersGestures)
	end
	if vf.ShowButtonHints then
		vf:ShowButtonHints(not patterns.prefersGestures)
	end

	-- Layout de carritos
	if patterns.prefersCarts then
		if vf.ExpandCartsSection  then vf:ExpandCartsSection()  end
		if vf.MinimizeCatalog     then vf:MinimizeCatalog()     end
	else
		if vf.CollapseCartsSection then vf:CollapseCartsSection() end
		if vf.ExpandCatalog        then vf:ExpandCatalog()        end
	end

	-- Reasignar acciones rápidas según las más usadas
	if #patterns.topActions > 0 then
		self:RemapQuickActions(patterns.topActions)
	end

	-- Guardar perfil calculado para uso de otros módulos
	self.lastProfile = patterns
	ns.Debug(string.format(
		"[AdaptiveUI] gestures=%.0f%% carts=%.0f%%",
		patterns.gestureRatio * 100,
		patterns.cartRatio    * 100
	))
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Reasignar acciones rápidas
-- ──────────────────────────────────────────────────────────────────────────────

function AdaptiveUI:RemapQuickActions(topActions)
	local vf = ns.VendorFrame
	if not vf or not vf.SetQuickActionOrder then return end

	local actionNames = {}
	for _, entry in ipairs(topActions) do
		table.insert(actionNames, entry.action)
	end

	vf:SetQuickActionOrder(actionNames)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Registrar uso de acciones (llamado por VendorFrame/SmartActions)
-- ──────────────────────────────────────────────────────────────────────────────

function AdaptiveUI:RecordAction(actionName, isGesture)
	if not ns.DB then return end
	local tel = ns.DB.telemetry
	if not tel then return end

	-- Frecuencia de acción específica
	if not tel.actionFrequency then tel.actionFrequency = {} end
	tel.actionFrequency[actionName] = (tel.actionFrequency[actionName] or 0) + 1

	-- Contadores globales
	if isGesture then
		tel.gesturesUsed = (tel.gesturesUsed or 0) + 1
	else
		tel.buttonsUsed = (tel.buttonsUsed or 0) + 1
	end
end

function AdaptiveUI:RecordCartLoad()
	if not ns.DB or not ns.DB.telemetry then return end
	local tel = ns.DB.telemetry
	tel.cartsLoaded = (tel.cartsLoaded or 0) + 1
end

function AdaptiveUI:RecordManualPurchase()
	if not ns.DB or not ns.DB.telemetry then return end
	local tel = ns.DB.telemetry
	tel.manualPurchases = (tel.manualPurchases or 0) + 1
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Perfil de override manual del usuario
-- ──────────────────────────────────────────────────────────────────────────────

function AdaptiveUI:SetUserOverride(key, value)
	if not ns.DB then return end
	if not ns.DB.adaptiveOverrides then ns.DB.adaptiveOverrides = {} end
	ns.DB.adaptiveOverrides[key] = value
	-- Re-aplicar adaptaciones con el override
	self:ApplyAdaptations()
end

function AdaptiveUI:GetUserOverride(key)
	if not ns.DB or not ns.DB.adaptiveOverrides then return nil end
	return ns.DB.adaptiveOverrides[key]
end

function AdaptiveUI:ClearUserOverrides()
	if ns.DB then ns.DB.adaptiveOverrides = {} end
	self:ApplyAdaptations()
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Inicialización
-- ──────────────────────────────────────────────────────────────────────────────

function AdaptiveUI:OnAddonLoaded()
	-- ns.DEFAULTS.telemetry no existe como tabla; los campos se inicializan
	-- directamente en ns.DB.telemetry que gestiona Core/Telemetry.lua.
	-- RecordAction() y RecordCartLoad() hacen sus propios guards, así que
	-- no es necesario pre-poblar aquí.
end

function AdaptiveUI:OnPlayerLogin()
	-- Pequeño delay para que VendorFrame esté listo
	C_Timer.After(1, function()
		self:ApplyAdaptations()
	end)
end

ns.RegisterModule("AdaptiveUI", AdaptiveUI)
