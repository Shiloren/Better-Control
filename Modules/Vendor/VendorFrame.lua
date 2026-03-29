local _, ns = ...

local Factory = ns.FrameFactory
local Input = ns.InputAdapter
local L = ns.L

local Controller = {}
ns.RegisterModule("Vendor", Controller)

local TAB_ORDER = { "buy", "sell", "buyback", "repair" }
local TAB_LABELS = {
	buy = L.BUY,
	sell = L.SELL,
	buyback = L.BUYBACK,
	repair = L.REPAIR,
}

local function getFooterMap(tab)
	if tab == "buy" then
		return {
			{ action = "confirm", label = "Start" },
			{ action = "quick", label = "+1 bundle" },
			{ action = "max", label = "Max" },
			{ action = "select", label = "Mode" },
			{ action = "prevTab", label = "Prev tab" },
			{ action = "nextTab", label = "Next tab" },
		}
	end

	if tab == "sell" then
		return {
			{ action = "confirm", label = "Sell one" },
			{ action = "quick", label = "Sell stack" },
			{ action = "max", label = "Sell junk" },
			{ action = "select", label = "Toggle" },
			{ action = "commit", label = "Sell marked" },
			{ action = "cancel", label = "Close" },
		}
	end

	if tab == "buyback" then
		return {
			{ action = "confirm", label = "Buy back" },
			{ action = "pageDown", label = "Page -" },
			{ action = "pageUp", label = "Page +" },
			{ action = "prevTab", label = "Prev tab" },
			{ action = "nextTab", label = "Next tab" },
			{ action = "cancel", label = "Close" },
		}
	end

	return {
		{ action = "confirm", label = "Equipped" },
		{ action = "quick", label = "Repair all" },
		{ action = "max", label = "Guild repair" },
		{ action = "prevTab", label = "Prev tab" },
		{ action = "nextTab", label = "Next tab" },
		{ action = "cancel", label = "Close" },
	}
end

function Controller:OnAddonLoaded()
	ns.Addon:RegisterRuntimeEvent("MERCHANT_SHOW")
	ns.Addon:RegisterRuntimeEvent("MERCHANT_CLOSED")
	ns.Addon:RegisterRuntimeEvent("MERCHANT_UPDATE")
	ns.Addon:RegisterRuntimeEvent("PLAYER_MONEY")
	ns.Addon:RegisterRuntimeEvent("CURRENCY_DISPLAY_UPDATE")
	ns.Addon:RegisterRuntimeEvent("BAG_UPDATE_DELAYED")
	ns.Addon:RegisterRuntimeEvent("GUILDBANK_UPDATE_MONEY")
	ns.Addon:RegisterRuntimeEvent("GUILDBANK_UPDATE_WITHDRAWMONEY")
	ns.Addon:RegisterRuntimeEvent("UI_ERROR_MESSAGE")
end

function Controller:OnPlayerLogin()
	ns.InputAdapter:DetectInitialMode()
	self.purchaseQueue = ns.PurchaseQueueMixin:New(self)
	self:CreateFrame()
end

function Controller:CreateFrame()
	local frame = Factory.CreateMainFrame("BetterControlVendorFrame", UIParent, L.APP_TITLE)
	frame:Hide()
	self.frame = frame
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame.CloseButton:SetScript("OnClick", function()
		CloseMerchant()
	end)

	frame.input = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.input:SetPoint("TOPRIGHT", -14, -12)
	
	ns.InputAdapter:OnModeChanged(function(mode)
		local label = mode == "xbox" and "Controller" or "Mouse / Keyboard"
		frame.input:SetText("Input: " .. label)
	end)

	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.subtitle:SetPoint("TOPLEFT", 16, -36)
	frame.subtitle:SetPoint("RIGHT", -42, 0)
	frame.subtitle:SetJustifyH("LEFT")
	frame.subtitle:SetText(L.APP_SUBTITLE)

	frame.device = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.device:SetPoint("TOPRIGHT", -48, -38)

	frame.tabsById = {}
	frame.Tabs = {}
	for tabIndex, tabId in ipairs(TAB_ORDER) do
		local tab = Factory.CreateTab(frame, tabIndex, TAB_LABELS[tabId], string.format("%sTab%d", frame:GetName(), tabIndex))
		if tabIndex == 1 then
			tab:SetPoint("BOTTOMLEFT", frame.Inset, "TOPLEFT", 6, 2)
		else
			tab:SetPoint("LEFT", frame.tabsById[TAB_ORDER[tabIndex - 1]], "RIGHT", -4, 0)
		end
		tab.tabId = tabId
		tab:SetScript("OnClick", function(selfTab)
			self:SetTab(selfTab.tabId)
		end)
		frame.Tabs[tabIndex] = tab
		frame.tabsById[tabId] = tab
	end
	frame.numTabs = #TAB_ORDER

	frame.content = CreateFrame("Frame", nil, frame.Inset)
	frame.content:SetPoint("TOPLEFT", 4, -4)
	frame.content:SetPoint("BOTTOMRIGHT", -4, 44)

	frame.footer = Factory.CreateFooter(frame)
	frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
	frame.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
	frame.hints = {}
	local previousHint
	for index = 1, 6 do
		local hint = Factory.CreateHint(frame.footer)
		if previousHint then
			hint:SetPoint("LEFT", previousHint, "RIGHT", 6, 0)
		else
			hint:SetPoint("LEFT", 6, 0)
		end
		frame.hints[index] = hint
		previousHint = hint
	end

	self.views = {}

	self.views.buy = CreateFrame("Frame", nil, frame.content)
	self.views.buy:SetAllPoints()
	self.views.buy.catalog = ns.VendorCatalogView:New(self.views.buy, self)
	self.views.buy.flow = ns.VendorBuyFlow:New(self.views.buy, self)

	self.views.sell = ns.VendorSellView:New(frame.content, self)
	self.views.buyback = ns.VendorBuybackView:New(frame.content, self)
	self.views.repair = ns.VendorRepairView:New(frame.content, self)

	Input:Attach(frame, function(action)
		self:HandleInput(action)
	end)
	ns.BindingDispatcher = function(action)
		self:HandleInput(action)
	end

	self:SetTab(ns.DB.vendor.rememberTab or "buy")
end

function Controller:SetTab(tabId)
	if not self.frame then
		return
	end

	self.activeTab = tabId
	ns.DB.vendor.rememberTab = tabId

	for viewId, view in pairs(self.views) do
		view:SetShown(viewId == tabId)
	end

	for index, orderedTabId in ipairs(TAB_ORDER) do
		if orderedTabId == tabId then
			PanelTemplates_SetTab(self.frame, index)
			break
		end
	end

	self:UpdateFooter()
	if MerchantFrame and MerchantFrame:IsShown() then
		self:RefreshActiveView()
	end
end

function Controller:CycleTab(step)
	local currentIndex = 1
	for index, tabId in ipairs(TAB_ORDER) do
		if tabId == self.activeTab then
			currentIndex = index
			break
		end
	end

	currentIndex = currentIndex + step
	if currentIndex < 1 then
		currentIndex = #TAB_ORDER
	elseif currentIndex > #TAB_ORDER then
		currentIndex = 1
	end

	self:SetTab(TAB_ORDER[currentIndex])
end

function Controller:UpdateFooter()
	local hintMap = getFooterMap(self.activeTab)
	for index, hintData in ipairs(hintMap) do
		local hint = self.frame.hints[index]
		hint.key:SetText(Input:GetActionLabel(hintData.action))
		hint.text:SetText(hintData.label)
		hint:Show()
	end

	for index = #hintMap + 1, #self.frame.hints do
		self.frame.hints[index]:Hide()
	end

	self.frame.device:SetText(string.format("%s: %s", L.DEVICE_PROFILE, Input:IsControllerMode() and L.ALLY_LAYOUT or L.MOUSE_LAYOUT))
end

function Controller:SetSelectedBuyItem(item)
	self.selectedBuyItem = item
	self.views.buy.flow:SetItem(item)
end

function Controller:GetSelectedBuyItem()
	return self.selectedBuyItem
end

function Controller:StartSelectedPurchase()
	if self.views and self.views.buy and self.views.buy.flow then
		self.views.buy.flow:StartPurchase()
	end
end

function Controller:OnQueueStatusChanged(job)
	if self.views and self.views.buy and self.views.buy.flow then
		self.views.buy.flow:OnQueueStatusChanged(job)
	end
end

function Controller:RequestPurchase(item, quantity)
	if not item or not quantity or quantity <= 0 then
		return false, "Invalid purchase request"
	end

	ns.Compat.BuyItem(item.index, quantity)
	return true
end

function Controller:RefreshAll()
	for _, tabId in ipairs(TAB_ORDER) do
		local previousTab = self.activeTab
		self.activeTab = tabId
		self:RefreshActiveView()
		self.activeTab = previousTab
	end
end

function Controller:RefreshActiveView()
	if self.activeTab == "buy" then
		self.views.buy.catalog:Refresh()
		self.views.buy.flow:Refresh()
	elseif self.activeTab == "sell" then
		self.views.sell:Refresh()
	elseif self.activeTab == "buyback" then
		self.views.buyback:Refresh()
	elseif self.activeTab == "repair" then
		self.views.repair:Refresh()
	end
end

function Controller:AdoptMerchantFrame()
	if not MerchantFrame then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		self.frame:SetFrameStrata("HIGH")
		self.frame:Raise()
		return
	end

	if not self.merchantState then
		self.merchantState = {
			mouseEnabled = MerchantFrame:IsMouseEnabled(),
		}
	end

	MerchantFrame:EnableMouse(false)

	self.frame:ClearAllPoints()
	self.frame:SetPoint("CENTER", MerchantFrame, "CENTER", 0, 0)
	self.frame:SetFrameStrata("HIGH")
	self.frame:SetFrameLevel(MerchantFrame:GetFrameLevel() + 20)
	self.frame:Raise()
end

function Controller:ReleaseMerchantFrame()
	if not MerchantFrame or not self.merchantState then
		return
	end

	MerchantFrame:EnableMouse(self.merchantState.mouseEnabled ~= false)
end

function Controller:HandleInput(action)
	if not self.frame or not self.frame:IsShown() then
		return
	end

	if action == "prevTab" then
		self:CycleTab(-1)
		return
	end

	if action == "nextTab" then
		self:CycleTab(1)
		return
	end

	if action == "cancel" and self.purchaseQueue and self.purchaseQueue.job then
		self.purchaseQueue:Cancel("Cancelled")
		return
	end

	if action == "cancel" then
		CloseMerchant()
		return
	end

	local handled = false
	if self.activeTab == "buy" then
		handled = self.views.buy.flow:HandleAction(action)
		if not handled then
			handled = self.views.buy.catalog:HandleAction(action)
		end
	elseif self.activeTab == "sell" then
		handled = self.views.sell:HandleAction(action)
	elseif self.activeTab == "buyback" then
		handled = self.views.buyback:HandleAction(action)
	elseif self.activeTab == "repair" then
		handled = self.views.repair:HandleAction(action)
	end

	if handled then
		self:UpdateFooter()
	end
end

function Controller:OnEvent(event, ...)
	if not self.frame then
		return
	end

	if event == "MERCHANT_SHOW" then
		if not ns.DB.vendor.enabled then
			return
		end

		ns.JobScheduler:Schedule(0, function()
			xpcall(function()
				self:AdoptMerchantFrame()
				self.frame:Show()
				self:RefreshActiveView()
				self:UpdateFooter()
			end, geterrorhandler())
		end)
		return
	end

	if event == "MERCHANT_CLOSED" then
		self.purchaseQueue:OnEvent(event, ...)
		self:ReleaseMerchantFrame()
		self.frame:Hide()
		return
	end

	self.purchaseQueue:OnEvent(event, ...)

	if self.frame:IsShown() then
		if event == "MERCHANT_UPDATE" or event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "GUILDBANK_UPDATE_MONEY" or event == "GUILDBANK_UPDATE_WITHDRAWMONEY" then
			self:RefreshActiveView()
		end
	end
end

function Controller:OnSlashCommand(message)
	if not MerchantFrame or not MerchantFrame:IsShown() then
		print("Better Control: open a merchant to use the vendor surface.")
		return
	end

	if message == "sell" then
		self:SetTab("sell")
	elseif message == "buyback" then
		self:SetTab("buyback")
	elseif message == "repair" then
		self:SetTab("repair")
	else
		self:SetTab("buy")
	end

	self:AdoptMerchantFrame()
	self.frame:Show()
	self:UpdateFooter()
end
