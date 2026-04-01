local _, ns = ...

-- ============================================================================
-- Core/BatchOverlay.lua
-- Overlays contextuales que aparecen al mantener L2/R2 (PADLTRIGGER/PADRTRIGGER).
-- Muestran acciones batch disponibles para el ítem seleccionado.
-- Fase 9 de la UI Revolucionaria.
-- ============================================================================

local BatchOverlay = {}
ns.BatchOverlay = BatchOverlay

-- Estado de triggers
BatchOverlay.L2Down        = false
BatchOverlay.R2Down        = false
BatchOverlay.currentOverlay = nil
BatchOverlay.frame          = nil

-- Definición de los tres modos de overlay
local OVERLAYS = {
	batch = {
		title   = "BATCH OPERATIONS",
		color   = { 0.2, 0.6, 1 },
		actions = {
			{ button = "A", label = "+10 items",      value = 10 },
			{ button = "B", label = "+100 items",     value = 100 },
			{ button = "X", label = "+1000 items",    value = 1000 },
			{ button = "Y", label = "Fill to Stack",  value = "stack" },
		},
	},
	actions = {
		title   = "QUICK ACTIONS",
		color   = { 0.2, 0.85, 0.4 },
		actions = {
			{ button = "A", label = "Add to Cart",       action = "addToCart" },
			{ button = "B", label = "Buy Now",           action = "buyNow" },
			{ button = "X", label = "Add to Favorites",  action = "addFavorite" },
			{ button = "Y", label = "Show in Cart",      action = "showCart" },
		},
	},
	mega = {
		title   = "MEGA BATCH MODE",
		color   = { 1, 0.4, 0.1 },
		actions = {
			{ button = "A", label = "+1000 items",    value = 1000 },
			{ button = "B", label = "+10000 items",   value = 10000 },
			{ button = "X", label = "Max Affordable", value = "max" },
			{ button = "Y", label = "Fill All Bags",  value = "fillBags" },
		},
	},
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Cambio de estado de triggers
-- ──────────────────────────────────────────────────────────────────────────────

function BatchOverlay:OnTriggerStateChanged(trigger, isDown)
	if trigger == "L2" then
		self.L2Down = isDown
	elseif trigger == "R2" then
		self.R2Down = isDown
	end

	if self.L2Down and self.R2Down then
		self:ShowOverlay("mega")
	elseif self.L2Down then
		self:ShowOverlay("batch")
	elseif self.R2Down then
		self:ShowOverlay("actions")
	else
		self:HideOverlay()
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Mostrar / ocultar overlay
-- ──────────────────────────────────────────────────────────────────────────────

function BatchOverlay:ShowOverlay(overlayType)
	if self.currentOverlay == overlayType then return end
	self.currentOverlay = overlayType

	if not self.frame then
		self:CreateFrame()
	end

	local cfg = OVERLAYS[overlayType]
	if not cfg then return end

	-- Actualizar título y color de acento
	self.frame.title:SetText(cfg.title)
	self.frame.titleBar:SetColorTexture(cfg.color[1], cfg.color[2], cfg.color[3], 0.8)

	-- Actualizar filas
	for i, row in ipairs(self.frame.rows) do
		local action = cfg.actions[i]
		if action then
			row.button:SetText("[" .. action.button .. "]")
			row.label:SetText(action.label)
			row.data = action
			row:Show()
		else
			row:Hide()
		end
	end

	self.frame:Show()
	if self.frame.fadeIn then self.frame.fadeIn:Play() end
end

function BatchOverlay:HideOverlay()
	if not self.frame or not self.currentOverlay then return end
	self.currentOverlay = nil

	if self.frame.fadeOut then self.frame.fadeOut:Play() end
	C_Timer.After(0.18, function()
		if self.frame and not self.currentOverlay then
			self.frame:Hide()
		end
	end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Ejecutar acción cuando se presiona botón con overlay visible
-- Devuelve true si consumió el input, false si debe pasar al sistema normal.
-- ──────────────────────────────────────────────────────────────────────────────

function BatchOverlay:ExecuteAction(button)
	if not self.currentOverlay then return false end

	local cfg = OVERLAYS[self.currentOverlay]
	for _, action in ipairs(cfg.actions) do
		if action.button == button then
			self:DoAction(action)
			return true
		end
	end
	return false
end

function BatchOverlay:DoAction(action)
	local vf           = ns.VendorFrame
	local selectedItem = vf and vf.GetSelectedItem and vf:GetSelectedItem()
	if not selectedItem then return end

	if action.value ~= nil then
		local qty = action.value
		if qty == "stack" then
			qty = (ns.Compat and ns.Compat.GetItemMaxStack and
				ns.Compat.GetItemMaxStack(selectedItem.index)) or 200
		elseif qty == "max" then
			local price = selectedItem.price or 1
			qty = price > 0 and math.floor(GetMoney() / price) or 0
		elseif qty == "fillBags" then
			local freeSlots = (vf.GetFreeBagSlots and vf:GetFreeBagSlots()) or 0
			local stackSize = (ns.Compat and ns.Compat.GetItemMaxStack and
				ns.Compat.GetItemMaxStack(selectedItem.index)) or 200
			qty = freeSlots * stackSize
		end

		if vf and vf.AddToCart and type(qty) == "number" and qty > 0 then
			vf:AddToCart(selectedItem.itemId, qty)
		end

	elseif action.action then
		local a = action.action
		if a == "addToCart" then
			if vf and vf.QuickAddToCart then vf:QuickAddToCart() end
		elseif a == "buyNow" then
			if vf and vf.BuyNow then vf:BuyNow(selectedItem) end
		elseif a == "addFavorite" then
			if ns.SmartActions and ns.SmartActions.AddItemToFavorites then
				ns.SmartActions:AddItemToFavorites(selectedItem)
			end
		elseif a == "showCart" then
			if vf and vf.ShowCart then vf:ShowCart() end
		end
	end

	if ns.HapticFeedback then
		ns.HapticFeedback:Trigger("batchAction", 0.3)
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Construcción del frame
-- ──────────────────────────────────────────────────────────────────────────────

function BatchOverlay:CreateFrame()
	local frame = CreateFrame("Frame", "BCBatchOverlay", UIParent)
	frame:SetSize(280, 185)
	frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0)
	frame:SetFrameStrata("DIALOG")
	frame:Hide()

	-- Fondo principal
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.04, 0.04, 0.06, 0.92)

	-- Barra de título
	frame.titleBar = frame:CreateTexture(nil, "BORDER")
	frame.titleBar:SetSize(280, 32)
	frame.titleBar:SetPoint("TOP")
	frame.titleBar:SetColorTexture(0.2, 0.6, 1, 0.8)

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOP", 0, -8)
	frame.title:SetTextColor(1, 1, 1)

	-- Filas de acciones (máximo 4)
	frame.rows = {}
	for i = 1, 4 do
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(260, 30)
		row:SetPoint("TOP", frame, "TOP", 0, -38 - (i - 1) * 34)

		-- Separador
		if i > 1 then
			local sep = row:CreateTexture(nil, "BACKGROUND")
			sep:SetSize(260, 1)
			sep:SetPoint("TOP")
			sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)
		end

		row.button = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.button:SetPoint("LEFT", 12, 0)
		row.button:SetTextColor(1, 0.85, 0.1)
		row.button:SetWidth(40)
		row.button:SetJustifyH("LEFT")

		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.label:SetPoint("LEFT", row.button, "RIGHT", 4, 0)
		row.label:SetTextColor(0.9, 0.9, 0.9)

		table.insert(frame.rows, row)
	end

	-- Animaciones
	local fadeIn = frame:CreateAnimationGroup()
	local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
	fadeInAlpha:SetFromAlpha(0)
	fadeInAlpha:SetToAlpha(1)
	fadeInAlpha:SetDuration(0.12)
	frame.fadeIn = fadeIn

	local fadeOut = frame:CreateAnimationGroup()
	local fadeOutAlpha = fadeOut:CreateAnimation("Alpha")
	fadeOutAlpha:SetFromAlpha(1)
	fadeOutAlpha:SetToAlpha(0)
	fadeOutAlpha:SetDuration(0.12)
	frame.fadeOut = fadeOut

	self.frame = frame
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Integración: escuchar triggers del gamepad
-- ──────────────────────────────────────────────────────────────────────────────

function BatchOverlay:OnAddonLoaded()
	self.listenerFrame = CreateFrame("Frame", "BCBatchOverlayListener")
	local listener = self.listenerFrame
	listener:EnableGamePadButton(true)

	listener:SetScript("OnGamePadButtonDown", function(_, button)
		if button == "PADLTRIGGER" then
			self:OnTriggerStateChanged("L2", true)
		elseif button == "PADRTRIGGER" then
			self:OnTriggerStateChanged("R2", true)
		elseif self.currentOverlay then
			-- Mapear PAD1-4 a A/B/X/Y
			local btnMap = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y" }
			local mapped = btnMap[button]
			if mapped then
				self:ExecuteAction(mapped)
			end
		end
	end)

	listener:SetScript("OnGamePadButtonUp", function(_, button)
		if button == "PADLTRIGGER" then
			self:OnTriggerStateChanged("L2", false)
		elseif button == "PADRTRIGGER" then
			self:OnTriggerStateChanged("R2", false)
		end
	end)
end

ns.RegisterModule("BatchOverlay", BatchOverlay)
