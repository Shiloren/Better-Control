local _, ns = ...

local Utils = {}
ns.VendorPurchaseUtils = Utils

local Queue = {}
Queue.__index = Queue
ns.PurchaseQueueMixin = Queue

local cadenceSteps = { 0.5, 0.75, 1.0, 1.25, 1.5 }
local ITEM_CLASS_CONSUMABLE = Enum and Enum.ItemClass and (Enum.ItemClass.Consumable or 0) or 0
local ITEM_CLASS_TRADEGOODS = Enum and Enum.ItemClass and (Enum.ItemClass.Tradegoods or Enum.ItemClass.TradeGoods or 7) or 7

local busyMessages = {
	[ERR_OBJECT_IS_BUSY or ""] = true,
}
local stopMessages = {
	[ERR_INV_FULL or ""] = "Inventory full",
	[ERR_NOT_ENOUGH_MONEY or ""] = "Not enough money",
	[ERR_VENDOR_OUT_OF_STOCK or ""] = "Vendor stock depleted",
	[ERR_ITEM_MAX_COUNT or ""] = "Reached item cap",
	[ERR_CANT_CARRY_MORE_OF_THIS or ""] = "Reached carry limit",
}

local function getItemInfoInstant(itemReference)
	if C_Item and C_Item.GetItemInfoInstant then
		return C_Item.GetItemInfoInstant(itemReference)
	end

	if GetItemInfoInstant then
		return GetItemInfoInstant(itemReference)
	end
end

function Utils.RoundDownToUnit(quantity, unitSize)
	unitSize = math.max(1, unitSize or 1)
	quantity = math.max(0, quantity or 0)
	return math.floor(quantity / unitSize) * unitSize
end

function Utils.RoundUpToUnit(quantity, unitSize)
	unitSize = math.max(1, unitSize or 1)
	quantity = math.max(0, quantity or 0)
	if quantity == 0 then
		return 0
	end
	return math.ceil(quantity / unitSize) * unitSize
end

function Utils.GetOwnedCount(item)
	local itemReference = item and (item.itemID or item.itemLink)
	if not itemReference or not GetItemCount then
		return 0
	end

	return GetItemCount(itemReference) or 0
end

function Utils.GetRawStock(item)
	if not item or not item.index then
		return -1
	end

	local info = ns.Compat.GetItemInfo(item.index)
	if not info or info.numAvailable == nil then
		return -1
	end

	if info.numAvailable < 0 then
		return -1
	end

	local stackCount = math.max(1, info.stackCount or item.unitSize or 1)
	return info.numAvailable * stackCount
end

function Utils.GetAffordableQuantity(item)
	if not item or not item.index then
		return 0
	end

	local unitSize = math.max(1, item.unitSize or 1)
	local limit = item.maxPerRequest or ns.Compat.GetItemMaxStack(item.index) or unitSize

	if item.price and item.price > 0 then
		limit = math.min(limit, math.floor(GetMoney() / (item.price / unitSize)))
	end

	local hasCurrencyCost = false
	if item.extendedCosts then
		for _, cost in ipairs(item.extendedCosts) do
			local perUnit = cost.amount / unitSize
			if cost.link and not cost.currencyName then
				local owned = GetItemCount(cost.link) or 0
				limit = math.min(limit, math.floor(owned / perUnit))
			elseif cost.currencyName then
				hasCurrencyCost = true
			end
		end
	end

	if hasCurrencyCost then
		if not ns.Compat.CanAffordItem(item.index) then
			return 0
		end

		limit = math.min(limit, unitSize)
	end

	local stockLimit = Utils.GetRawStock(item)
	if stockLimit > -1 then
		limit = math.min(limit, stockLimit)
	end

	if limit < unitSize then
		return 0
	end

	return Utils.RoundDownToUnit(limit, unitSize)
end

function Utils.BuildExtendedCosts(index)
	local costs = {}
	local totalCosts = ns.Compat.GetItemCostInfo(index) or 0
	for costIndex = 1, totalCosts do
		local texture, amount, link, currencyName = ns.Compat.GetItemCostItem(index, costIndex)
		costs[#costs + 1] = {
			texture = texture,
			amount = amount or 0,
			link = link,
			currencyName = currencyName,
		}
	end
	return costs
end

function Utils.DescribeCosts(item, quantity)
	if not item then
		return ""
	end

	quantity = math.max(item.unitSize or 1, quantity or item.unitSize or 1)
	local multiplier = quantity / math.max(1, item.unitSize or 1)
	local parts = {}

	if item.price and item.price > 0 then
		parts[#parts + 1] = ns.FrameFactory.FormatMoney(math.floor(item.price * multiplier))
	end

	if item.extendedCosts then
		for _, cost in ipairs(item.extendedCosts) do
			local total = math.floor(cost.amount * multiplier)
			if cost.currencyName then
				parts[#parts + 1] = string.format("%d %s", total, cost.currencyName)
			elseif cost.link then
				parts[#parts + 1] = string.format("%d x %s", total, cost.link)
			end
		end
	end

	return table.concat(parts, " + ")
end

function Utils.BuildVendorItem(index)
	local info = ns.Compat.GetItemInfo(index)
	if not info or not info.name then
		return nil
	end

	local itemLink = ns.Compat.GetItemLink(index)
	local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
	local _, itemType, itemSubType, _, instantIcon, classID = getItemInfoInstant(itemLink or itemID)
	local quality = itemLink and select(3, GetItemInfo(itemLink))
	local unitSize = math.max(1, info.stackCount or 1)

	return {
		index = index,
		itemID = itemID,
		itemLink = itemLink,
		name = info.name,
		icon = info.texture or instantIcon,
		price = info.price or 0,
		unitSize = unitSize,
		maxPerRequest = ns.Compat.GetItemMaxStack(index) or unitSize,
		stock = info.numAvailable or -1,
		availableQuantity = info.numAvailable and info.numAvailable > -1 and info.numAvailable * unitSize or math.huge,
		extendedCosts = info.hasExtendedCost and Utils.BuildExtendedCosts(index) or {},
		isConsumable = classID == ITEM_CLASS_CONSUMABLE,
		isReagent = classID == ITEM_CLASS_TRADEGOODS or itemSubType == (REAGENTS or "Reagents"),
		isPurchasable = info.isPurchasable ~= false,
		isUsable = info.isUsable ~= false,
		isRefundable = C_MerchantFrame and C_MerchantFrame.IsMerchantItemRefundable and C_MerchantFrame.IsMerchantItemRefundable(index),
		itemType = itemType,
		itemSubType = itemSubType,
		quality = quality,
	}
end

function Queue:New(owner)
	return setmetatable({
		owner = owner,
		timer = nil,
		job = nil,
	}, self)
end

function Queue:GetBaseCadence()
	local config = ns.DB and ns.DB.vendor or ns.DEFAULTS.vendor
	return math.max(0.25, config.baseCadence or cadenceSteps[1])
end

function Queue:GetMaxCadence()
	local config = ns.DB and ns.DB.vendor or ns.DEFAULTS.vendor
	return math.max(self:GetBaseCadence(), config.maxCadence or cadenceSteps[#cadenceSteps])
end

function Queue:GetNextCadence(current)
	for _, cadence in ipairs(cadenceSteps) do
		if cadence > current then
			return math.min(cadence, self:GetMaxCadence())
		end
	end

	return self:GetMaxCadence()
end

function Queue:Notify()
	if self.owner and self.owner.OnQueueStatusChanged then
		self.owner:OnQueueStatusChanged(self.job)
	end
end

function Queue:Schedule(delay, callback)
	if self.timer then
		ns.JobScheduler:Cancel(self.timer)
		self.timer = nil
	end

	self.timer = ns.JobScheduler:Schedule(delay, function()
		self.timer = nil
		callback()
	end)
end

function Queue:Start(item, quantity)
	if not item then
		return false, "No item selected"
	end

	local unitSize = math.max(1, item.unitSize or 1)
	quantity = Utils.RoundDownToUnit(quantity, unitSize)
	if quantity < unitSize then
		return false, "Target too low"
	end

	self:Cancel("Replaced")
	self.job = {
		state = "queued",
		item = item,
		targetQty = quantity,
		purchasedQty = 0,
		remainingQty = quantity,
		cadence = self:GetBaseCadence(),
		retries = 0,
		status = string.format("Queued %d x %s", quantity, ns.GetItemDisplayName(item)),
	}
	self:Notify()
	self:Schedule(0, function()
		self:IssueNextChunk()
	end)
	return true
end

function Queue:Cancel(reason)
	if self.timer then
		ns.JobScheduler:Cancel(self.timer)
		self.timer = nil
	end

	if self.job then
		self.job.state = "stopped"
		self.job.status = reason or "Cancelled"
		self.job.awaiting = nil
		self:Notify()
	end

	self.job = nil
end

function Queue:Complete()
	if not self.job then
		return
	end

	self.job.state = "complete"
	self.job.status = string.format("Completed %d x %s", self.job.purchasedQty, ns.GetItemDisplayName(self.job.item))
	self.job.awaiting = nil
	self:Notify()
	self.job = nil
end

function Queue:Stop(reason)
	if not self.job then
		return
	end

	self.job.state = "stopped"
	self.job.status = reason or "Stopped"
	self.job.awaiting = nil
	self:Notify()
	self.job = nil
end

function Queue:ComputeChunk(item, remainingQty)
	local unitSize = math.max(1, item.unitSize or 1)
	local affordable = Utils.GetAffordableQuantity(item)
	if affordable <= 0 then
		return 0
	end

	local stock = Utils.GetRawStock(item)
	local chunk = math.min(
		remainingQty,
		item.maxPerRequest or unitSize,
		affordable
	)

	if stock > -1 then
		chunk = math.min(chunk, stock)
	end

	chunk = Utils.RoundDownToUnit(chunk, unitSize)
	if chunk < unitSize then
		return 0
	end

	return chunk
end

function Queue:IssueNextChunk()
	local job = self.job
	if not job then
		return
	end

	if not MerchantFrame or not MerchantFrame:IsShown() then
		self:Stop("Merchant closed")
		return
	end

	if job.remainingQty <= 0 then
		self:Complete()
		return
	end

	local chunk = self:ComputeChunk(job.item, job.remainingQty)
	if chunk <= 0 then
		if Utils.GetAffordableQuantity(job.item) <= 0 then
			self:Stop("Cannot afford next batch")
		else
			self:Stop("No stock available")
		end
		return
	end

	local ownedBefore = Utils.GetOwnedCount(job.item)
	local stockBefore = Utils.GetRawStock(job.item)
	local moneyBefore = GetMoney()
	local okay, err = self.owner:RequestPurchase(job.item, chunk)
	if not okay then
		self:Stop(err or "Purchase rejected")
		return
	end

	job.awaiting = {
		requestedQty = chunk,
		ownedBefore = ownedBefore,
		stockBefore = stockBefore,
		moneyBefore = moneyBefore,
	}
	job.state = "waiting"
	job.status = string.format("Buying %d / %d", job.purchasedQty, job.targetQty)
	self:Notify()
	self:Schedule(job.cadence, function()
		self:CheckAwaiting()
	end)
end

function Queue:MarkSuccess(quantity)
	local job = self.job
	if not job or not job.awaiting then
		return
	end

	quantity = Utils.RoundDownToUnit(quantity > 0 and quantity or job.awaiting.requestedQty, job.item.unitSize)
	if quantity <= 0 then
		quantity = job.awaiting.requestedQty
	end

	job.awaiting = nil
	job.retries = 0
	job.cadence = self:GetBaseCadence()
	job.purchasedQty = math.min(job.targetQty, job.purchasedQty + quantity)
	job.remainingQty = math.max(0, job.targetQty - job.purchasedQty)
	job.state = "running"
	job.status = string.format("Purchased %d / %d", job.purchasedQty, job.targetQty)
	self:Notify()

	if job.remainingQty <= 0 then
		self:Complete()
		return
	end

	self:Schedule(job.cadence, function()
		self:IssueNextChunk()
	end)
end

function Queue:Backoff(reason)
	local job = self.job
	if not job then
		return
	end

	job.awaiting = nil
	job.retries = job.retries + 1
	if job.retries >= 3 then
		self:Stop(reason or "Too many retries")
		return
	end

	job.cadence = self:GetNextCadence(job.cadence)
	job.state = "backoff"
	job.status = string.format("%s, retrying in %.2fs", reason or "Waiting for merchant", job.cadence)
	self:Notify()
	self:Schedule(job.cadence, function()
		self:IssueNextChunk()
	end)
end

function Queue:TryResolveAwaiting()
	local job = self.job
	if not job or not job.awaiting then
		return false
	end

	local ownedNow = Utils.GetOwnedCount(job.item)
	local stockNow = Utils.GetRawStock(job.item)
	local moneyNow = GetMoney()
	local deltaOwned = ownedNow - job.awaiting.ownedBefore

	if deltaOwned > 0 then
		self:MarkSuccess(deltaOwned)
		return true
	end

	if (stockNow > -1 and job.awaiting.stockBefore > -1 and stockNow < job.awaiting.stockBefore) or moneyNow < job.awaiting.moneyBefore then
		self:MarkSuccess(job.awaiting.requestedQty)
		return true
	end

	return false
end

function Queue:CheckAwaiting()
	if self:TryResolveAwaiting() then
		return
	end

	self:Backoff("Merchant did not confirm batch")
end

function Queue:HandleUIError(message)
	if not self.job or not self.job.awaiting or not message then
		return
	end

	if busyMessages[message] then
		self:Backoff("Vendor busy")
		return
	end

	local reason = stopMessages[message]
	if reason then
		self:Stop(reason)
	end
end

function Queue:OnEvent(event, ...)
	if not self.job then
		return
	end

	if event == "MERCHANT_CLOSED" then
		self:Stop("Merchant closed")
		return
	end

	if event == "UI_ERROR_MESSAGE" then
		local _, message = ...
		self:HandleUIError(message or ...)
		return
	end

	if event == "MERCHANT_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
		self:TryResolveAwaiting()
	end
end
