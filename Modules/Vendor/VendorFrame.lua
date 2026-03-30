local _, ns = ...

local Factory = ns.FrameFactory
local L = ns.L or {}
local tokens = ns.SkinTokens
local Input = ns.InputAdapter

local Controller = {}
ns.VendorFrame = Controller

local TAB_ORDER = { "buy", "sell", "buyback", "repair" }

local function ResolveTabLabel(tabId)
	if tabId == "buy" then
		return _G.MERCHANT or _G.MERCHANT_BUY or L.BUY or "Buy"
	elseif tabId == "sell" then
		return _G.SELL or L.SELL or "Sell"
	elseif tabId == "buyback" then
		return _G.BUYBACK or L.BUYBACK or "Buyback"
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
		self.frame:Hide()
	end
end

function Controller:OnEvent(event, ...)
	if event == "MERCHANT_SHOW" then
		ns.Debug("Event: MERCHANT_SHOW. Initializing UI...")
		self:ShowWindow()
		-- Small delay to let items load
		ns.JobScheduler:Schedule(0.1, function()
			self:RefreshActiveView()
		end)
	elseif event == "MERCHANT_CLOSED" then
		if self.frame then
			self.frame:Hide()
		end
		self:ReleaseMerchantFrame()
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

	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.subtitle:SetPoint("TOPLEFT", 18, -21)
	frame.subtitle:SetPoint("TOPRIGHT", -140, -21)
	frame.subtitle:SetJustifyH("LEFT")
	frame.subtitle:SetText(L.APP_SUBTITLE)
	frame.subtitle:SetAlpha(0.8)

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

	-- Secondary loop for positioning (requires tabsById to be populated)
	for tabIndex, tabId in ipairs(TAB_ORDER) do
		local tab = frame.tabsById[tabId]
		if tab then
			if tabIndex == 1 then
				-- Shifted right to 62 to clear provide safe spacing from portrait
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
	
	frame.numTabs = #TAB_ORDER

	frame.content = CreateFrame("Frame", nil, frame.Inset)
	frame.content:SetAllPoints()

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
		self.frame:Hide()
		self:ReleaseMerchantFrame()
		if MerchantFrame then
			MerchantFrame:SetAlpha(1)
		end
	end)

	self.views = {}
	self.views.buy = CreateFrame("Frame", nil, frame.content)
	self.views.buy:SetAllPoints()
	
	-- Buy view container needs to route HandleAction to its children
	self.views.buy.HandleAction = function(view, action)
		if view.catalog and view.catalog.HandleAction and view.catalog:HandleAction(action) then
			return true
		end
		if view.flow and view.flow.HandleAction and view.flow:HandleAction(action) then
			return true
		end
		return false
	end

	-- Safe creation of views using Mixins
	xpcall(function()
		self.views.buy.catalog = ns.VendorCatalogView:New(self.views.buy, self)
		self.views.buy.flow = ns.VendorBuyFlow:New(self.views.buy, self)
		self.views.sell = ns.VendorSellView:New(frame.content, self)
		self.views.buyback = ns.VendorBuybackView:New(frame.content, self)
		self.views.repair = ns.VendorRepairView:New(frame.content, self)
	end, function(err) 
		ns.Debug("CRITICAL ERROR during View Creation: " .. tostring(err)) 
	end)

	Input:Attach(frame, function(action)
		self:HandleInput(action)
	end)
	
	ns.BindingDispatcher = function(action)
		self:HandleInput(action)
	end

	self:SetTab(ns.DB.vendor.rememberTab or "buy")
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

	for id, view in pairs(self.views) do
		if id == tabId then
			view:Show()
		else
			view:Hide()
		end
	end

	self:RefreshActiveView()
end

function Controller:RefreshActiveView()
	if not self.views then return end
	
	local view = self.views[self.activeTab]
	if not view then return end

	-- Robust refresh calls
	if self.activeTab == "buy" then
		if view.catalog and view.catalog.Refresh then
			view.catalog:Refresh()
		end
	elseif view.Refresh then
		view:Refresh()
	end
end

function Controller:SetSelectedBuyItem(item)
	if self.views.buy and self.views.buy.flow then
		self.views.buy.flow:SetItem(item)
	end
end

function Controller:StartSelectedPurchase()
	if self.views.buy and self.views.buy.flow then
		self.views.buy.flow:StartPurchase()
	end
end

function Controller:RequestPurchase(item, quantity)
	if not item or not item.index then return false, "No item" end
	
	-- Use compatibility layer for Midnight (12.x) support
	ns.Compat.BuyItem(item.index, quantity)
	return true
end

function Controller:HandleInput(action)
	local view = self.views[self.activeTab]
	if view and view.HandleAction then
		if view:HandleAction(action) then
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
		self.frame:Hide()
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
