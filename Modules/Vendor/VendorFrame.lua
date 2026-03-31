local _, ns = ...

local Factory = ns.FrameFactory
local L = ns.L or {}
local tokens = ns.SkinTokens
local Input = ns.InputAdapter

local Controller = {}
ns.VendorFrame = Controller

local TAB_ORDER = { "main", "buyback" }

local function ResolveTabLabel(tabId)
	if tabId == "main" then
		return _G.MERCHANT or L.MERCHANT or "Merchant"
	elseif tabId == "buy" then
		return _G.MERCHANT_BUY or _G.BUY or L.BUY or "Buy"
	elseif tabId == "sell" then
		return _G.SELL or L.SELL or "Sell"
	elseif tabId == "buyback" then
		return (MerchantFrameTab2 and MerchantFrameTab2:GetText()) or _G.BUYBACK or L.BUYBACK or "Buyback"
	elseif tabId == "repair" then
		return _G.REPAIR or L.REPAIR or "Repair"
	end
	return "Tab"
end

function Controller:OnAddonLoaded()
	-- Initialization if needed
end

function Controller:OnSlashCommand(msg)
	if msg == "" or msg == "show" then
		self:ShowWindow()
	elseif msg == "hide" or msg == "close" then
		self:Close("slash")
	elseif msg == "load" then
		-- Load the contextual cart suggested on vendor open
		if self._suggestedCart then
			local smartActions = self.views and self.views.buyFlow and self.views.buyFlow.smartActions
			if smartActions then
				smartActions:LoadDetectedCart(self._suggestedCart)
				print(string.format("|cff00ccff[Better Control]|r Loading cart: '%s'", self._suggestedCart.name))
			else
				print("|cffff6600[Better Control]|r Smart actions not available. Open a vendor first.")
			end
		else
			print("|cffff6600[Better Control]|r No cart suggestion available. Open a vendor to get one.")
		end
	end
end

function Controller:OnEvent(event, ...)
	if event == "MERCHANT_SHOW" then
		ns.Debug("Event: MERCHANT_SHOW. Initializing UI...")

		-- Start telemetry session
		local vendorName = UnitName and UnitName("target") or "Vendor"
		if ns.Telemetry then ns.Telemetry:StartSession(vendorName) end

		self:ShowWindow()
		-- Small delay to let items load
		ns.JobScheduler:Schedule(0.1, function()
			self:RefreshActiveView()
			-- Auto-popup suggestion after items are loaded
			ns.JobScheduler:Schedule(0.5, function()
				self:CheckAutoPopup()
			end)
		end)
	elseif event == "MERCHANT_CLOSED" then
		-- Finalize telemetry session before closing
		if ns.Telemetry then ns.Telemetry:FinalizeSession() end
		self:Close("MERCHANT_CLOSED")
	elseif event == "MERCHANT_UPDATE" then
		self:RefreshActiveView()
	elseif event == "BAG_UPDATE_DELAYED" then
		self:RefreshActiveView()
	end
end

function Controller:ShowWindow()
	ns.Debug("ShowWindow: Requesting display")
	if not self.frame then
		self:CreateFrame()
	end

	if self.frame then
		self.frame:Show()
		self:AdoptMerchantFrame()
	else
		ns.Debug("ERROR: Could not show window (frame is nil)")
	end
end

function Controller:AdoptMerchantFrame()
	if MerchantFrame then
		MerchantFrame:SetAlpha(0)
		MerchantFrame:SetIgnoreParentAlpha(true)
	end
end

function Controller:ReleaseMerchantFrame()
	if MerchantFrame then
		MerchantFrame:SetAlpha(1)
		MerchantFrame:SetIgnoreParentAlpha(false)
	end
end

function Controller:Close(reason)
	if self._closing then return end
	self._closing = true
	
	ns.Debug("Closing Vendor interaction via canonical helper: " .. (reason or "unknown"))
	
	-- 1. Close interaction for all paths EXCEPT when already closed by event
	if reason ~= "MERCHANT_CLOSED" then
		-- Canonical compatibility close: Handles Midnight (C_MerchantFrame) and Legacy
		ns.Compat.CloseMerchantInteraction()
	end
	
	-- 2. Hide our UI
	if self.frame and self.frame:IsShown() then
		self.frame:Hide()
	end
	
	-- 3. Release Blizzard UI state
	self:ReleaseMerchantFrame()
	
	self._closing = false
end

-- Deprecated: use Close(reason)
function Controller:CloseWindowAndInteraction()
	self:Close("window")
end

function Controller:OnPlayerLogin()
	ns.Debug("OnPlayerLogin: Initializing Better Control Vendor...")
	ns.InputAdapter:DetectInitialMode()
	self.purchaseQueue = ns.PurchaseQueueMixin:New(self)
	self:CreateFrame()

	ns.Addon:RegisterRuntimeEvent("MERCHANT_SHOW")
	ns.Addon:RegisterRuntimeEvent("MERCHANT_CLOSED")
	ns.Addon:RegisterRuntimeEvent("MERCHANT_UPDATE")
	ns.Addon:RegisterRuntimeEvent("BAG_UPDATE_DELAYED")
end

function Controller:CreateFrame()
	local frame = Factory.CreateMainFrame("BetterControlVendorFrame", UIParent, L.APP_TITLE or "Vendor")
	frame:SetPoint("CENTER")
	frame:Hide()
	
	-- Explicitly bind Inset from ButtonFrameTemplate
	frame.Inset = _G[frame:GetName() .. "Inset"]
	self.frame = frame

	frame.input = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.input:SetPoint("TOPRIGHT", -14, -12)
	
	ns.InputAdapter:OnModeChanged(function(mode)
		local label = mode == "xbox" and "Controller" or "Mouse / Keyboard"
		frame.input:SetText("Input: " .. label)
	end)

	frame:SetScript("OnHide", function()
		self:Close("hide")
	end)

	if frame.CloseButton then
		frame.CloseButton:SetScript("OnClick", function()
			self:Close("button")
		end)
	end

	frame.device = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.device:SetPoint("TOPRIGHT", -48, -38)
	frame.device:Hide() -- Hide collision-prone unused text

	frame.tabsById = {}
	frame.Tabs = {}
	for tabIndex, tabId in ipairs(TAB_ORDER) do
		local tab = Factory.CreateTab(frame, tabIndex, ResolveTabLabel(tabId), string.format("%sTab%d", frame:GetName(), tabIndex))
		tab.tabId = tabId
		tab:SetScript("OnClick", function()
			self:SetTab(tabId)
		end)
		frame.Tabs[tabIndex] = tab
		frame.tabsById[tabId] = tab
	end

	-- Positioning for Main Tabs
	for tabIndex, tabId in ipairs(TAB_ORDER) do
		local tab = frame.tabsById[tabId]
		if tab then
			if tabIndex == 1 then
				tab:SetPoint("BOTTOMLEFT", frame.Inset, "TOPLEFT", 62, 2)
			else
				local prevTabId = TAB_ORDER[tabIndex - 1]
				local prevTab = frame.tabsById[prevTabId]
				if prevTab then
					tab:SetPoint("LEFT", prevTab, "RIGHT", -4, 0)
				end
			end
		end
	end
	
	-- Positioning for Main Tabs
	for tabIndex, tabId in ipairs(TAB_ORDER) do
		local tab = frame.tabsById[tabId]
		if tab then
			if tabIndex == 1 then
				tab:SetPoint("BOTTOMLEFT", frame.Inset, "TOPLEFT", 62, 2)
			else
				local prevTabId = TAB_ORDER[tabIndex - 1]
				local prevTab = frame.tabsById[prevTabId]
				if prevTab then
					tab:SetPoint("LEFT", prevTab, "RIGHT", -4, 0)
				end
			end
		end
	end
	
	-- Global "Sell Junk" and "Repair" buttons for the main surface header
	frame.headerActions = CreateFrame("Frame", nil, frame)
	frame.headerActions:SetSize(300, 30)
	frame.headerActions:SetPoint("TOPRIGHT", frame.Inset, "TOPRIGHT", -10, -5)

	frame.sellJunkButton = Factory.CreateButton(frame.headerActions, L.SELL_JUNK or "Sell Junk", 90, 22)
	frame.sellJunkButton:SetPoint("RIGHT", 0, 0)
	frame.sellJunkButton:SetScript("OnClick", function()
		if self.views.sell and self.views.sell.SellJunk then
			self.views.sell:SellJunk()
		end
	end)

	frame.repairAllButton = Factory.CreateButton(frame.headerActions, L.REPAIR_ALL or "Repair All", 90, 22)
	frame.repairAllButton:SetPoint("RIGHT", frame.sellJunkButton, "LEFT", -4, 0)
	frame.repairAllButton:SetScript("OnClick", function()
		if self.views.repair and self.views.repair.RepairAll then
			self.views.repair:RepairAll(false)
		end
	end)

	frame.repairGuildButton = Factory.CreateButton(frame.headerActions, L.REPAIR_GUILD or "Guild", 70, 22)
	frame.repairGuildButton:SetPoint("RIGHT", frame.repairAllButton, "LEFT", -4, 0)
	frame.repairGuildButton:SetScript("OnClick", function()
		if self.views.repair and self.views.repair.RepairAll then
			self.views.repair:RepairAll(true)
		end
	end)

	frame.numTabs = #TAB_ORDER

	frame.content = CreateFrame("Frame", nil, frame.Inset)
	frame.content:SetAllPoints()

	-- Explicit Container Regions for Unified Main Layout
	frame.regions = {}
	-- Left Column: Catalog and Sell List
	frame.regions.catalog = CreateFrame("Frame", nil, frame.content)
	frame.regions.catalog:SetSize(tokens.panels.leftWidth, 210)
	frame.regions.catalog:SetPoint("TOPLEFT", 4, -42)
	
	frame.regions.sellList = CreateFrame("Frame", nil, frame.content)
	frame.regions.sellList:SetSize(tokens.panels.leftWidth, 210)
	frame.regions.sellList:SetPoint("TOPLEFT", 4, -266)
	
	-- Right Column: Buy Flow Detail and Sell Contextual Actions
	frame.regions.buyFlow = CreateFrame("Frame", nil, frame.content)
	frame.regions.buyFlow:SetSize(tokens.panels.rightWidth, 210)
	frame.regions.buyFlow:SetPoint("TOPRIGHT", -4, -42)
	
	frame.regions.sellDetail = CreateFrame("Frame", nil, frame.content)
	frame.regions.sellDetail:SetSize(tokens.panels.rightWidth, 210)
	frame.regions.sellDetail:SetPoint("TOPRIGHT", -4, -266)

	frame.footer = Factory.CreateFooter(frame)
	frame.footer:SetPoint("BOTTOMLEFT", 4, 4)
	frame.footer:SetPoint("BOTTOMRIGHT", -4, 4)

	local hints = {
		{ action = "confirm", text = L.HINT_CONFIRM },
		{ action = "cancel", text = L.HINT_CANCEL },
		{ action = "quick", text = L.HINT_QUICK },
		{ action = "max", text = L.HINT_MAX },
	}

	local previousHint
	for _, data in ipairs(hints) do
		local hint = Factory.CreateHint(frame.footer)
		hint.key:SetText(Input:GetActionLabel(data.action))
		hint.text:SetText(data.text)
		
		if previousHint then
			hint:SetPoint("LEFT", previousHint, "RIGHT", 16, 0)
		else
			hint:SetPoint("LEFT", 12, 0)
		end
		previousHint = hint
	end

	frame.toggleBlizz = Factory.CreateButton(frame, "Blizzard UI", 100, 20)
	frame.toggleBlizz:SetPoint("TOPRIGHT", frame.CloseButton, "TOPLEFT", -8, 0)
	frame.toggleBlizz:SetScript("OnClick", function()
		ns.Debug("Switching to Blizzard UI. Use /bcv to return.")
		self._closing = true -- Prevent OnHide from terminating the interaction
		self.frame:Hide()
		self:ReleaseMerchantFrame()
		if MerchantFrame then
			MerchantFrame:SetAlpha(1)
		end
		self._closing = false
	end)

	-- Safe creation of views using Mixins into deterministic regions
	self.views = {}
	xpcall(function()
		-- Catalog View hosts the Merchant Item List
		self.views.catalog = ns.VendorCatalogView:New(frame.regions.catalog, self, 4, true)

		-- BuyFlow hosts the Details and Purchase Flow for Merchant Items
		self.views.buyFlow = ns.VendorBuyFlow:New(frame.regions.buyFlow, self, true)

		-- SmartActionsPanel embedded inside the buyFlow region (shown when no item selected)
		if ns.VendorSmartActionsPanel then
			self.views.buyFlow.smartActions = ns.VendorSmartActionsPanel:New(frame.regions.buyFlow, self)
		end

		-- SellView split across two regions: List and Detail
		self.views.sell = ns.VendorSellView:New(frame.regions.sellList, self, 4, true, frame.regions.sellDetail)

		-- Full Screen Views (Tabs) - Still direct in content as they own the space when active
		self.views.buyback = ns.VendorBuybackView:New(frame.content, self, math.floor(434/tokens.list.rowHeight))
		self.views.repair = ns.VendorRepairView:New(frame.content, self)

		-- Initial setup: Ensure all embeddable parts follow their region's constraints
		self.views.catalog:SetAllPoints()
		self.views.buyFlow:SetAllPoints()
		self.views.sell:SetAllPoints() -- Host frame handles cross-communication
	end, function(err)
		ns.Debug("CRITICAL ERROR during View Creation: " .. tostring(err))
	end)

	Input:Attach(frame, function(action)
		self:HandleInput(action)
	end)
	
	ns.BindingDispatcher = function(action)
		self:HandleInput(action)
	end

	-- Restore last session or default
	self:SetTab("main")
	
	ns.Debug("CreateFrame: Complete")
end

function Controller:SetTab(tabId)
	if not self.frame then return end
	
	self.activeTab = tabId
	ns.DB.vendor.rememberTab = tabId

	for id, tab in pairs(self.frame.tabsById) do
		if id == tabId then
			PanelTemplates_SelectTab(tab)
		else
			PanelTemplates_DeselectTab(tab)
		end
	end

	if tabId == "main" then
		self.activeList = self.activeList or "catalog"
		self.frame.headerActions:Show()
		-- Show all regions belonging to the unified surface
		for _, region in pairs(self.frame.regions) do region:Show() end
		self.views.buyback:Hide()
		self.views.repair:Hide()
	else
		self.frame.headerActions:Hide()
		-- Hide all regions before showing a whole-frame tab
		for _, region in pairs(self.frame.regions) do region:Hide() end
		if tabId == "buyback" then
			self.views.buyback:Show()
			self.views.repair:Hide()
		elseif tabId == "repair" then -- Handled by separate view if direct nav is used
			self.views.buyback:Hide()
			self.views.repair:Show()
		end
	end

	self:RefreshActiveView()
end

function Controller:RefreshActiveView()
	if not self.views then return end
	
	if self.activeTab == "main" then
		if self.views.catalog then self.views.catalog:Refresh() end
		if self.views.sell then self.views.sell:Refresh() end
		if self.views.repair then self.views.repair:Refresh() end
		if self.views.buyFlow then self.views.buyFlow:Refresh() end
	elseif self.activeTab == "buyback" then
		if self.views.buyback then self.views.buyback:Refresh() end
	end
end

-- Auto-popup: suggest contextual cart when vendor opens (Fase 5)
function Controller:CheckAutoPopup()
	if not ns.DB then return end
	local settings = ns.DB.insightSettings
	if not (settings and settings.enabled and settings.showAutoPopup) then return end
	if not ns.CartRecognizer then return end

	local d = date("*t", time())
	local weekday = d.wday - 1
	local hour = d.hour

	local contextCarts = ns.CartRecognizer:GetCartsByContext(weekday, hour)
	if not contextCarts or #contextCarts == 0 then return end

	local bestCart = contextCarts[1]
	-- Only suggest if used at least twice to avoid noise
	if (bestCart.occurrences or 0) < 2 then return end

	-- Build item preview text (first 3 items)
	local preview = {}
	for i = 1, math.min(3, #bestCart.items) do
		local item = bestCart.items[i]
		table.insert(preview, string.format("• %s x%d", item.itemName or "?", item.typicalQuantity or 1))
	end
	if #bestCart.items > 3 then
		table.insert(preview, string.format("  ...and %d more", #bestCart.items - 3))
	end

	local msg = string.format(
		"|cff00ccff[Better Control]|r Recognized your usual cart: |cffffff00'%s'|r (used %dx)\n%s\n|cffffff00Type /bcv load to use it.|r",
		bestCart.name, bestCart.occurrences, table.concat(preview, "\n")
	)

	-- Store suggestion for optional load command
	self._suggestedCart = bestCart

	print(" ")
	print(msg)
	print(" ")

	-- Also show in the smart actions panel status if visible
	if self.views and self.views.buyFlow and self.views.buyFlow.smartActions then
		self.views.buyFlow.smartActions.statusLine:SetText(
			string.format("Suggestion: '%s' (%dx)", bestCart.name, bestCart.occurrences)
		)
	end
end

function Controller:SetSelectedBuyItem(item)
	if self.views.buyFlow then
		self.views.buyFlow:SetItem(item)
	end
end

function Controller:StartSelectedPurchase()
	if self.views.buyFlow then
		self.views.buyFlow:StartPurchase()
	end
end

function Controller:PurchaseImmediately(item)
	if self.views.buyFlow then
		self.views.buyFlow:DirectPurchase(item)
	end
end

function Controller:RequestPurchase(item, quantity)
	if not item or not item.index then return false, "No item" end
	
	-- Use compatibility layer for Midnight (12.x) support
	ns.Compat.BuyItem(item.index, quantity)
	return true
end

function Controller:HandleInput(action)
	if self.activeTab == "main" then
		-- Use 'select' (TAB or View button) to toggle focus between Buy Catalog and Sell List
		if action == "select" then
			self.activeList = (self.activeList == "sell") and "catalog" or "sell"
			ns.Debug("Active List focus switched to: " .. self.activeList)
			return true
		end

		local targetList = (self.activeList == "sell") and self.views.sell or self.views.catalog
		if targetList and targetList.HandleAction and targetList:HandleAction(action) then
			return true
		end

		-- If the active list didn't handle the action (e.g. quantity adjust, quick confirm, max)
		-- give the relevant detail panel a chance to handle it.
		if self.activeList == "catalog" and self.views.buyFlow and self.views.buyFlow.HandleAction then
			if self.views.buyFlow:HandleAction(action) then
				return true
			end
		elseif self.activeList == "sell" and self.views.sell and self.views.sell.HandleAction then
			-- Logic for sell actions (handled inside SellView detail part)
			if self.views.sell:HandleAction(action) then
				return true
			end
		end
	elseif self.activeTab == "buyback" then
		if self.views.buyback and self.views.buyback.HandleAction and self.views.buyback:HandleAction(action) then
			return true
		end
	end

	if action == "prevTab" then
		self:CycleTab(-1)
		return true
	elseif action == "nextTab" then
		self:CycleTab(1)
		return true
	elseif action == "cancel" then
		self:Close("escape")
		return true
	end

	return false
end

function Controller:CycleTab(delta)
	local currentIndex = 1
	for i, id in ipairs(TAB_ORDER) do
		if id == self.activeTab then
			currentIndex = i
			break
		end
	end

	local nextIndex = currentIndex + delta
	if nextIndex < 1 then nextIndex = #TAB_ORDER end
	if nextIndex > #TAB_ORDER then nextIndex = 1 end
	
	self:SetTab(TAB_ORDER[nextIndex])
end

ns.RegisterModule("VendorFrame", Controller)
