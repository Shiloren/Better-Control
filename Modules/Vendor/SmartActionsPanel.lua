local _, ns = ...

local Factory = ns.FrameFactory
local L = ns.L or {}
local tokens = ns.SkinTokens

local SmartActionsPanel = {}
SmartActionsPanel.__index = SmartActionsPanel
ns.VendorSmartActionsPanel = SmartActionsPanel

-- Pending sequential cart execution state
local pendingCart = nil
local pendingIndex = 0

-- ============================================================================
-- Constructor
-- ============================================================================

function SmartActionsPanel:New(parent, owner)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Mixin(frame, self)
	frame.owner = owner
	frame:SetAllPoints()

	-- Background panel
	frame.panel = Factory.CreateInset(frame, tokens.panels.rightWidth, 210)
	frame.panel:SetAllPoints()

	-- Title
	frame.title = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", 14, -12)
	frame.title:SetText("Smart Actions")

	-- ── Re-buy Last Order ──────────────────────────────────────────────────
	frame.rebuyLabel = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.rebuyLabel:SetPoint("TOPLEFT", 14, -38)
	frame.rebuyLabel:SetText("Last purchase: none")

	frame.rebuyButton = Factory.CreateButton(frame.panel, "Re-buy Last", 110, 22)
	frame.rebuyButton:SetPoint("TOPLEFT", 14, -56)
	frame.rebuyButton:SetScript("OnClick", function()
		frame:RebuyLastOrder()
	end)

	-- ── Detected Carts ─────────────────────────────────────────────────────
	frame.cartsLabel = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.cartsLabel:SetPoint("TOPLEFT", 14, -88)
	frame.cartsLabel:SetText("Detected carts: none")

	frame.cartsButton = Factory.CreateButton(frame.panel, "Load a Cart", 110, 22)
	frame.cartsButton:SetPoint("TOPLEFT", 14, -106)
	frame.cartsButton:SetEnabled(false)
	frame.cartsButton:SetScript("OnClick", function()
		frame:ShowCartsMenu()
	end)

	-- ── Save current cart ───────────────────────────────────────────────────
	frame.saveButton = Factory.CreateButton(frame.panel, "Save Cart", 110, 22)
	frame.saveButton:SetPoint("TOPLEFT", 14, -138)
	frame.saveButton:SetEnabled(false)
	frame.saveButton:SetScript("OnClick", function()
		frame:PromptSaveCart()
	end)

	-- ── Status line ─────────────────────────────────────────────────────────
	frame.statusLine = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.statusLine:SetPoint("TOPLEFT", 14, -166)
	frame.statusLine:SetPoint("RIGHT", -14, 0)
	frame.statusLine:SetJustifyH("LEFT")
	frame.statusLine:SetText("")

	frame:Hide()
	return frame
end

-- ============================================================================
-- Refresh
-- ============================================================================

function SmartActionsPanel:Refresh()
	-- Last purchase summary
	local last = ns.Telemetry and ns.Telemetry:GetLastPurchase()
	if last and last.cart and #last.cart > 0 then
		local ago = math.floor((time() - last.timestamp) / 60)
		local agoText = ago < 60 and (ago .. "m ago") or (math.floor(ago / 60) .. "h ago")
		self.rebuyLabel:SetText(string.format("Last: %d items – %s", #last.cart, agoText))
		self.rebuyButton:SetEnabled(true)
	else
		self.rebuyLabel:SetText("Last purchase: none")
		self.rebuyButton:SetEnabled(false)
	end

	-- Detected carts
	local db = ns.DB
	local carts = db and db.detectedCarts or {}
	if #carts > 0 then
		self.cartsLabel:SetText(string.format("Detected carts: %d", #carts))
		self.cartsButton:SetEnabled(true)
	else
		self.cartsLabel:SetText("Detected carts: none yet")
		self.cartsButton:SetEnabled(false)
	end

	-- Save cart button active when telemetry has a running session with items
	local session = ns.Telemetry and ns.Telemetry:GetCurrentSession()
	local hasItems = session and session.cart and #session.cart > 0
	self.saveButton:SetEnabled(hasItems or false)

	self.statusLine:SetText("")
end

-- ============================================================================
-- Re-buy Last Order
-- ============================================================================

function SmartActionsPanel:RebuyLastOrder()
	local last = ns.Telemetry and ns.Telemetry:GetLastPurchase()
	if not last or not last.cart or #last.cart == 0 then
		self.statusLine:SetText("No previous purchase found.")
		return
	end
	self:ExecuteCart(last.cart)
end

-- ============================================================================
-- Cart selection menu (custom panel — avoids deprecated UIDropDownMenu APIs)
-- ============================================================================

function SmartActionsPanel:BuildCartsMenuPanel()
	if self._cartsMenu then return self._cartsMenu end

	local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	menu:SetFrameStrata("TOOLTIP")
	menu:SetClampedToScreen(true)
	menu:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets   = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	menu:SetBackdropColor(0.06, 0.06, 0.06, 0.96)
	menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	menu:Hide()

	-- Close on click-outside
	menu:EnableMouse(true)
	local blocker = CreateFrame("Frame", nil, UIParent)
	blocker:SetAllPoints(UIParent)
	blocker:SetFrameStrata("HIGH")
	blocker:EnableMouse(true)
	blocker:Hide()
	blocker:SetScript("OnMouseDown", function()
		blocker:Hide()
		menu:Hide()
	end)
	menu._blocker = blocker

	menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	menu.title:SetPoint("TOPLEFT", 8, -8)
	menu.title:SetText("Detected Carts")

	menu.buttons = {}
	self._cartsMenu = menu
	return menu
end

function SmartActionsPanel:ShowCartsMenu()
	local db = ns.DB
	local carts = db and db.detectedCarts or {}
	if #carts == 0 then return end

	local menu = self:BuildCartsMenuPanel()

	-- Clear previous buttons
	for _, btn in ipairs(menu.buttons) do btn:Hide() end
	menu.buttons = {}

	local ROW_H = 24
	local WIDTH = 200
	local yOff = -28

	for _, cart in ipairs(carts) do
		local c = cart
		local btn = Factory.CreateButton(menu, string.format("%s (%dx)", c.name or "?", c.occurrences or 0), WIDTH - 16, ROW_H)
		btn:SetPoint("TOPLEFT", 8, yOff)
		btn:SetScript("OnClick", function()
			menu._blocker:Hide()
			menu:Hide()
			self:LoadDetectedCart(c)
		end)
		table.insert(menu.buttons, btn)
		yOff = yOff - (ROW_H + 2)
	end

	-- Cancel button
	local cancelBtn = Factory.CreateButton(menu, CANCEL or "Cancel", WIDTH - 16, ROW_H)
	cancelBtn:SetPoint("TOPLEFT", 8, yOff - 4)
	cancelBtn:SetScript("OnClick", function()
		menu._blocker:Hide()
		menu:Hide()
	end)
	table.insert(menu.buttons, cancelBtn)
	yOff = yOff - (ROW_H + 4)

	local totalH = math.abs(yOff) + 12
	menu:SetSize(WIDTH, totalH)

	-- Position near the button
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", self.cartsButton, "BOTTOMLEFT", 0, -4)

	menu._blocker:Show()
	menu:Show()
end

-- ============================================================================
-- Load / Execute carts
-- ============================================================================

function SmartActionsPanel:LoadDetectedCart(cart)
	if ns.AdaptiveUI then
		ns.AdaptiveUI:RecordCartLoad()
	end
	self:ExecuteCart(cart.items)
end

-- Accepts an array of {itemId, quantity} or {itemId, typicalQuantity} entries
function SmartActionsPanel:ExecuteCart(cartItems)
	-- Build list of {vendorItem, quantity} for items found in current vendor
	local toExecute = {}
	for _, entry in ipairs(cartItems) do
		local id = entry.itemId or entry.itemID
		local qty = entry.quantity or entry.typicalQuantity or 1
		if id and id > 0 then
			local vendorItem = self:FindVendorItemByID(id)
			if vendorItem then
				table.insert(toExecute, { item = vendorItem, quantity = qty })
			end
		end
	end

	if #toExecute == 0 then
		self.statusLine:SetText("None of those items found at this vendor.")
		return
	end

	pendingCart = toExecute
	pendingIndex = 1
	self.statusLine:SetText(string.format("Loading cart: 0/%d items…", #toExecute))
	self:ExecuteNextCartItem()
end

function SmartActionsPanel:ExecuteNextCartItem()
	if not pendingCart or pendingIndex > #pendingCart then
		self.statusLine:SetText(string.format("Cart done: %d items purchased.", pendingIndex - 1))
		pendingCart = nil
		pendingIndex = 0
		return
	end

	local entry = pendingCart[pendingIndex]
	pendingIndex = pendingIndex + 1

	local queue = self.owner and self.owner.purchaseQueue
	if not queue then
		self.statusLine:SetText("Purchase queue not available.")
		pendingCart = nil
		return
	end

	local total = pendingCart and #pendingCart or 0
	self.statusLine:SetText(string.format("Buying %d/%d: %s x%d", pendingIndex - 1, total, entry.item.name or "?", entry.quantity))

	queue:Start(entry.item, entry.quantity)

	-- Poll for completion every 0.5s, then proceed to next item
	self:WaitForQueueThen(function()
		self:ExecuteNextCartItem()
	end)
end

function SmartActionsPanel:WaitForQueueThen(callback)
	local queue = self.owner and self.owner.purchaseQueue
	if not queue then callback() return end

	ns.JobScheduler:Schedule(0.5, function()
		if queue.job then
			-- Still running, keep waiting
			self:WaitForQueueThen(callback)
		else
			ns.JobScheduler:Schedule(0.3, callback)
		end
	end)
end

-- ============================================================================
-- Save cart dialog
-- ============================================================================

if not StaticPopupDialogs.BETTERCONTROL_SAVE_CART then
	StaticPopupDialogs.BETTERCONTROL_SAVE_CART = {
		text = "Name your cart:",
		button1 = SAVE or "Save",
		button2 = CANCEL,
		hasEditBox = true,
		maxLetters = 40,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		OnAccept = function(dialog, data)
			local name = dialog.editBox:GetText()
			if name and name ~= "" and data and data.callback then
				data.callback(name)
			end
		end,
		EditBoxOnEnterPressed = function(eb)
			local dialog = eb:GetParent()
			local name = eb:GetText()
			if name and name ~= "" and dialog.data and dialog.data.callback then
				dialog.data.callback(name)
			end
			dialog:Hide()
		end,
	}
end

function SmartActionsPanel:PromptSaveCart()
	local session = ns.Telemetry and ns.Telemetry:GetCurrentSession()
	if not session or not session.cart or #session.cart == 0 then
		self.statusLine:SetText("Nothing purchased yet to save.")
		return
	end

	local cartSnapshot = {}
	for _, entry in ipairs(session.cart) do
		table.insert(cartSnapshot, {
			itemId = entry.itemId,
			itemName = entry.itemName,
			typicalQuantity = entry.quantity,
		})
	end

	StaticPopup_Show("BETTERCONTROL_SAVE_CART", nil, nil, {
		callback = function(name)
			self:SaveCartAsFavorite(name, cartSnapshot)
		end,
	})
end

function SmartActionsPanel:SaveCartAsFavorite(name, items)
	local db = ns.DB
	if not db then return end
	if not db.favorites then db.favorites = {} end

	-- Capture current vendor info from the active telemetry session
	local vendorInfo = nil
	local session = ns.Telemetry and ns.Telemetry:GetCurrentSession()
	if session then
		vendorInfo = {
			name     = session.vendor,
			location = session.vendorLocation,
		}
	end

	table.insert(db.favorites, {
		favoriteId = string.format("user-%d", time()),
		name       = name,
		items      = items,
		vendorInfo = vendorInfo,
		createdAt  = time(),
		lastUsed   = time(),
		useCount   = 0,
	})

	self.statusLine:SetText(string.format("Saved '%s' to favorites!", name))
	ns.Debug("Saved favorite cart: " .. name)
end

-- ============================================================================
-- Helpers
-- ============================================================================

function SmartActionsPanel:FindVendorItemByID(itemId)
	local total = ns.Compat.GetNumItems()
	for i = 1, total do
		local item = ns.VendorPurchaseUtils.BuildVendorItem(i)
		if item and item.itemID == itemId then
			return item
		end
	end
	return nil
end
