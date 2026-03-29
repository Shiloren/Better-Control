local _, ns = ...

local Factory = ns.FrameFactory
local L = ns.L
local Utils = ns.VendorPurchaseUtils

StaticPopupDialogs.BETTERCONTROL_CONFIRM_VENDOR_PURCHASE = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	OnAccept = function(_, data)
		if data and data.callback then
			data.callback()
		end
	end,
}

local BuyFlow = {}
BuyFlow.__index = BuyFlow
ns.VendorBuyFlow = BuyFlow

function BuyFlow:New(parent, owner)
	local frame = CreateFrame("Frame", nil, parent)
	setmetatable(frame, self)
	frame.owner = owner
	frame.item = nil
	frame.quantityMode = ns.DB.vendor.lastQuantityMode or "purchase"
	frame.value = 0
	frame:SetAllPoints()

	frame.panel = Factory.CreateInset(frame, 278, 434)
	frame.panel:SetPoint("TOPRIGHT", -4, -42)

	frame.title = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", 14, -12)
	frame.title:SetPoint("RIGHT", -14, 0)
	frame.title:SetJustifyH("LEFT")
	frame.title:SetText(L.STATUS_NO_SELECTION)

	frame.icon = frame.panel:CreateTexture(nil, "ARTWORK")
	frame.icon:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -10)
	frame.icon:SetSize(42, 42)
	frame.icon:SetTexture(134400)

	frame.summary = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.summary:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, 0)
	frame.summary:SetPoint("RIGHT", -14, 0)
	frame.summary:SetJustifyH("LEFT")

	frame.modePurchase = Factory.CreateButton(frame.panel, L.MODE_PURCHASE, 120, 22)
	frame.modePurchase:SetPoint("TOPLEFT", frame.icon, "BOTTOMLEFT", 0, -14)
	frame.modePurchase:SetScript("OnClick", function()
		frame:SetMode("purchase")
	end)

	frame.modeTotal = Factory.CreateButton(frame.panel, L.MODE_TOTAL, 120, 22)
	frame.modeTotal:SetPoint("LEFT", frame.modePurchase, "RIGHT", 8, 0)
	frame.modeTotal:SetScript("OnClick", function()
		frame:SetMode("total")
	end)

	frame.valueLabel = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.valueLabel:SetPoint("TOPLEFT", frame.modePurchase, "BOTTOMLEFT", 0, -16)
	frame.valueLabel:SetText(L.QUEUE_TARGET)

	frame.valueText = frame.panel:CreateFontString(nil, "OVERLAY", "QuestFont_Enormous")
	frame.valueText:SetPoint("TOPLEFT", frame.valueLabel, "BOTTOMLEFT", 0, -8)
	frame.valueText:SetText("0")

	frame.purchaseHint = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.purchaseHint:SetPoint("TOPLEFT", frame.valueText, "BOTTOMLEFT", 0, -6)
	frame.purchaseHint:SetPoint("RIGHT", -14, 0)
	frame.purchaseHint:SetJustifyH("LEFT")

	frame.quickMinus = Factory.CreateButton(frame.panel, "-1x", 54, 22)
	frame.quickMinus:SetPoint("TOPLEFT", frame.purchaseHint, "BOTTOMLEFT", 0, -12)
	frame.quickMinus:SetScript("OnClick", function()
		frame:AdjustBundles(-1)
	end)

	frame.quickMinusFive = Factory.CreateButton(frame.panel, "-5x", 54, 22)
	frame.quickMinusFive:SetPoint("LEFT", frame.quickMinus, "RIGHT", 4, 0)
	frame.quickMinusFive:SetScript("OnClick", function()
		frame:AdjustBundles(-5)
	end)

	frame.quickPlus = Factory.CreateButton(frame.panel, "+1x", 54, 22)
	frame.quickPlus:SetPoint("LEFT", frame.quickMinusFive, "RIGHT", 4, 0)
	frame.quickPlus:SetScript("OnClick", function()
		frame:AdjustBundles(1)
	end)

	frame.quickPlusFive = Factory.CreateButton(frame.panel, "+5x", 54, 22)
	frame.quickPlusFive:SetPoint("LEFT", frame.quickPlus, "RIGHT", 4, 0)
	frame.quickPlusFive:SetScript("OnClick", function()
		frame:AdjustBundles(5)
	end)

	frame.quickMax = Factory.CreateButton(frame.panel, "Max", 54, 22)
	frame.quickMax:SetPoint("TOPLEFT", frame.quickMinus, "BOTTOMLEFT", 0, -6)
	frame.quickMax:SetScript("OnClick", function()
		frame:SetMax()
	end)

	frame.startButton = Factory.CreateButton(frame.panel, L.START_PURCHASE, 120, 24)
	frame.startButton:SetPoint("LEFT", frame.quickMax, "RIGHT", 4, 0)
	frame.startButton:SetScript("OnClick", function()
		frame:StartPurchase()
	end)

	frame.cancelButton = Factory.CreateButton(frame.panel, L.QUEUE_CANCEL, 120, 24)
	frame.cancelButton:SetPoint("LEFT", frame.startButton, "RIGHT", 4, 0)
	frame.cancelButton:SetScript("OnClick", function()
		frame.owner.purchaseQueue:Cancel("Cancelled")
	end)

	frame.progress = CreateFrame("StatusBar", nil, frame.panel)
	frame.progress:SetPoint("TOPLEFT", frame.quickMax, "BOTTOMLEFT", 0, -18)
	frame.progress:SetPoint("RIGHT", -14, 0)
	frame.progress:SetHeight(18)
	frame.progress:SetMinMaxValues(0, 1)
	frame.progress:SetValue(0)
	frame.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	frame.progress:SetStatusBarColor(1.0, 0.82, 0.1)

	frame.progressText = frame.progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.progressText:SetPoint("CENTER")
	frame.progressText:SetText(L.STATUS_IDLE)

	frame.queueStatus = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.queueStatus:SetPoint("TOPLEFT", frame.progress, "BOTTOMLEFT", 0, -12)
	frame.queueStatus:SetPoint("RIGHT", -14, 0)
	frame.queueStatus:SetJustifyH("LEFT")
	frame.queueStatus:SetText(L.STATUS_IDLE)

	frame.costs = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.costs:SetPoint("TOPLEFT", frame.queueStatus, "BOTTOMLEFT", 0, -12)
	frame.costs:SetPoint("RIGHT", -14, 0)
	frame.costs:SetJustifyH("LEFT")
	frame.costs:SetText("")

	return frame
end

function BuyFlow:SetMode(mode)
	self.quantityMode = mode
	ns.DB.vendor.lastQuantityMode = mode
	self:ResetValueForItem()
	self:Refresh()
end

function BuyFlow:GetOwned()
	if not self.item then
		return 0
	end

	return Utils.GetOwnedCount(self.item)
end

function BuyFlow:ResetValueForItem()
	if not self.item then
		self.value = 0
		return
	end

	if self.quantityMode == "total" then
		self.value = self:GetOwned() + self.item.unitSize
	else
		self.value = self.item.unitSize
	end
end

function BuyFlow:SetItem(item)
	self.item = item
	self:ResetValueForItem()
	self:Refresh()
end

function BuyFlow:GetResolvedPurchaseQuantity()
	if not self.item then
		return 0
	end

	local quantity = self.value
	if self.quantityMode == "total" then
		quantity = math.max(0, self.value - self:GetOwned())
	end

	return Utils.RoundDownToUnit(quantity, self.item.unitSize)
end

function BuyFlow:AdjustBundles(multiplier)
	if not self.item then
		return
	end

	local delta = (self.item.unitSize or 1) * multiplier
	local minimum = self.quantityMode == "total" and self:GetOwned() or self.item.unitSize
	self.value = math.max(minimum, self.value + delta)
	self.value = Utils.RoundDownToUnit(self.value, self.item.unitSize)
	self:Refresh()
end

function BuyFlow:SetMax()
	if not self.item then
		return
	end

	local maxQuantity = Utils.GetAffordableQuantity(self.item)
	if self.quantityMode == "total" then
		self.value = self:GetOwned() + maxQuantity
	else
		self.value = maxQuantity
	end
	self:Refresh()
end

function BuyFlow:PromptPurchase(quantity)
	local item = self.item
	local costText = Utils.DescribeCosts(item, quantity)
	local title = string.format("%s\n\n%s", string.format(L.WARNING_PURCHASE, string.format("%d x %s", quantity, item.name)), L.CONFIRM_WARNING)
	if costText ~= "" then
		title = string.format("%s\n\n%s", title, costText)
	end

	StaticPopup_Show("BETTERCONTROL_CONFIRM_VENDOR_PURCHASE", title, nil, {
		callback = function()
			self.owner.purchaseQueue:Start(item, quantity)
		end,
	})
end

function BuyFlow:StartPurchase()
	local quantity = self:GetResolvedPurchaseQuantity()
	if not self.item or quantity <= 0 then
		self.queueStatus:SetText("No quantity to buy.")
		return
	end

	local requiresPrompt = (self.item.price or 0) >= (MERCHANT_HIGH_PRICE_COST or 1500000)
	if #self.item.extendedCosts > 0 or self.item.isRefundable == false or requiresPrompt then
		self:PromptPurchase(quantity)
	else
		self.owner.purchaseQueue:Start(self.item, quantity)
	end
end

function BuyFlow:OnQueueStatusChanged(job)
	if not job then
		self.progress:SetValue(0)
		self.progressText:SetText(L.STATUS_IDLE)
		self.queueStatus:SetText(L.STATUS_IDLE)
		self:Refresh()
		return
	end

	local total = math.max(1, job.targetQty)
	self.progress:SetMinMaxValues(0, total)
	self.progress:SetValue(job.purchasedQty or 0)
	self.progressText:SetText(string.format("%d / %d", job.purchasedQty or 0, total))
	self.queueStatus:SetText(job.status or L.STATUS_IDLE)
	self:Refresh()
end

function BuyFlow:Refresh()
	local item = self.item
	if not item then
		self.title:SetText(L.STATUS_NO_SELECTION)
		self.summary:SetText("")
		self.valueText:SetText("0")
		self.purchaseHint:SetText("")
		self.costs:SetText("")
		self.modePurchase:SetEnabled(false)
		self.modeTotal:SetEnabled(false)
		self.startButton:SetEnabled(false)
		self.quickMinus:SetEnabled(false)
		self.quickMinusFive:SetEnabled(false)
		self.quickPlus:SetEnabled(false)
		self.quickPlusFive:SetEnabled(false)
		self.quickMax:SetEnabled(false)
		return
	end

	local owned = self:GetOwned()
	local affordable = Utils.GetAffordableQuantity(item)
	local resolved = self:GetResolvedPurchaseQuantity()

	self.modePurchase:SetEnabled(self.quantityMode ~= "purchase")
	self.modeTotal:SetEnabled(self.quantityMode ~= "total")
	self.startButton:SetEnabled(resolved >= item.unitSize)
	self.quickMinus:SetEnabled(true)
	self.quickMinusFive:SetEnabled(true)
	self.quickPlus:SetEnabled(true)
	self.quickPlusFive:SetEnabled(true)
	self.quickMax:SetEnabled(affordable >= item.unitSize)

	self.title:SetText(item.name)
	self.icon:SetTexture(item.icon or 134400)
	self.summary:SetText(string.format("%s: %d\n%s: %d\n%s: %s", L.OWNED, owned, L.BUNDLE, item.unitSize, L.PRICE, Utils.DescribeCosts(item, item.unitSize)))
	self.valueText:SetText(BreakUpLargeNumbers(self.value))
	self.purchaseHint:SetText(string.format("Will buy %d now. Max immediate batch %d.", resolved, affordable))
	self.costs:SetText(string.format("Target cost: %s", Utils.DescribeCosts(item, resolved)))
end

function BuyFlow:HandleAction(action)
	if not self.item then
		return false
	end

	if action == "confirm" then
		self:StartPurchase()
	elseif action == "quick" then
		self:AdjustBundles(1)
	elseif action == "max" then
		self:SetMax()
	elseif action == "pageDown" then
		self:AdjustBundles(-5)
	elseif action == "pageUp" then
		self:AdjustBundles(5)
	elseif action == "select" then
		self:SetMode(self.quantityMode == "purchase" and "total" or "purchase")
	elseif action == "cancel" then
		self.owner.purchaseQueue:Cancel("Cancelled")
	else
		return false
	end

	return true
end
