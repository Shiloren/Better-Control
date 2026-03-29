local _, ns = ...

local Factory = ns.FrameFactory
local L = ns.L or {}
local tokens = ns.SkinTokens

local SellView = {}
SellView.__index = SellView
ns.VendorSellView = SellView

local function getMaxBagIndex()
	return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

local function makeKey(entry)
	return string.format("%d:%d", entry.bag, entry.slot)
end

function SellView:New(parent, owner)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Mixin(frame, self)
	frame.owner = owner
	frame.items = {}
	frame.selected = {}
	frame.batchTask = nil
	frame.focus = ns.FocusList:New(tokens.list.visibleRows)
	frame.focus:SetOnChanged(function()
		frame:RefreshRows()
	end)
	frame.rows = {}
	frame:SetAllPoints()

	frame.left = Factory.CreateInset(frame, 430, 434)
	frame.left:SetPoint("TOPLEFT", 4, -42)

	frame.right = Factory.CreateInset(frame, 268, 434)
	frame.right:SetPoint("TOPRIGHT", -4, -42)

	frame.title = frame.left:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", 14, -12)
	frame.title:SetText(L.SELL)

	frame.empty = frame.left:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.empty:SetPoint("CENTER")
	frame.empty:SetText(L.STATUS_SELL_EMPTY)
	frame.empty:Hide()

	for rowIndex = 1, tokens.list.visibleRows do
		local row = Factory.CreateRow(frame.left, 410, tokens.list.rowHeight)
		row:SetPoint("TOPLEFT", 10, -40 - ((rowIndex - 1) * tokens.list.rowHeight))
		row.toggle = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		row.toggle:SetPoint("LEFT", row.stock, "LEFT", -22, 0)
		row.toggle:SetText("")
		row:SetScript("OnClick", function(selfRow)
			frame.focus:SetIndex(selfRow.itemPosition)
			frame:RefreshDetail()
		end)
		frame.rows[rowIndex] = row
	end

	frame.detailIcon = frame.right:CreateTexture(nil, "ARTWORK")
	frame.detailIcon:SetPoint("TOPLEFT", 14, -16)
	frame.detailIcon:SetSize(42, 42)
	frame.detailIcon:SetTexture(134400)

	frame.detailTitle = frame.right:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.detailTitle:SetPoint("TOPLEFT", frame.detailIcon, "TOPRIGHT", 10, 0)
	frame.detailTitle:SetPoint("RIGHT", -14, 0)
	frame.detailTitle:SetJustifyH("LEFT")

	frame.detailText = frame.right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.detailText:SetPoint("TOPLEFT", frame.detailIcon, "BOTTOMLEFT", 0, -12)
	frame.detailText:SetPoint("RIGHT", -14, 0)
	frame.detailText:SetJustifyH("LEFT")

	frame.sellOneButton = Factory.CreateButton(frame.right, L.SELL_ONE, 118, 24)
	frame.sellOneButton:SetPoint("TOPLEFT", frame.detailText, "BOTTOMLEFT", 0, -20)
	frame.sellOneButton:SetScript("OnClick", function()
		frame:SellFocused(1)
	end)

	frame.sellStackButton = Factory.CreateButton(frame.right, L.SELL_STACK, 118, 24)
	frame.sellStackButton:SetPoint("LEFT", frame.sellOneButton, "RIGHT", 8, 0)
	frame.sellStackButton:SetScript("OnClick", function()
		frame:SellFocused("stack")
	end)

	frame.sellSelectedButton = Factory.CreateButton(frame.right, L.SELL_SELECTED, 118, 24)
	frame.sellSelectedButton:SetPoint("TOPLEFT", frame.sellOneButton, "BOTTOMLEFT", 0, -8)
	frame.sellSelectedButton:SetScript("OnClick", function()
		frame:SellSelected()
	end)

	frame.sellJunkButton = Factory.CreateButton(frame.right, L.SELL_JUNK, 118, 24)
	frame.sellJunkButton:SetPoint("LEFT", frame.sellSelectedButton, "RIGHT", 8, 0)
	frame.sellJunkButton:SetScript("OnClick", function()
		frame:SellJunk()
	end)

	frame.status = frame.right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.status:SetPoint("TOPLEFT", frame.sellSelectedButton, "BOTTOMLEFT", 0, -16)
	frame.status:SetPoint("RIGHT", -14, 0)
	frame.status:SetJustifyH("LEFT")
	frame.status:SetText(L.STATUS_IDLE)

	return frame
end

function SellView:SetStatus(text)
	self.status:SetText(text or L.STATUS_IDLE)
end

function SellView:BuildItems()
	local items = {}
	for bag = 0, getMaxBagIndex() do
		local slotCount = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, slotCount do
			local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink then
						local itemName, itemLink, quality, _, _, _, _, _, _, texture, sellPrice, _, _, _, _, _, classID = GetItemInfo(info.hyperlink)
						sellPrice = sellPrice or 0
						if sellPrice > 0 then
							items[#items + 1] = {
								bag = bag,
								slot = slot,
								count = info.stackCount or 1,
								itemLink = info.hyperlink,
								name = itemName or info.hyperlink,
								icon = info.iconFileID or texture,
								quality = quality,
								isConsumable = ns.Compat.IsConsumable(info.hyperlink),
								isJunk = quality == Enum.ItemQuality.Poor,
								sellPrice = sellPrice,
							}
						end
			end
		end
	end

	table.sort(items, function(left, right)
		if left.isJunk ~= right.isJunk then
			return left.isJunk
		end
		return left.name < right.name
	end)

	return items
end

function SellView:Refresh()
	local selectedKey = self:GetFocusedItem() and makeKey(self:GetFocusedItem())
	self.items = self:BuildItems()
	self.focus:SetItems(self.items)

	if selectedKey then
		for index, entry in ipairs(self.items) do
			if makeKey(entry) == selectedKey then
				self.focus:SetIndex(index)
				break
			end
		end
	end

	self.empty:SetShown(#self.items == 0)
	self:RefreshRows()
	self:RefreshDetail()
end

function SellView:GetFocusedItem()
	return self.focus:GetItem()
end

function SellView:RefreshRows()
	local selected = self.focus:GetIndex()
	local firstVisible = select(1, self.focus:GetVisibleRange())

	for rowIndex, row in ipairs(self.rows) do
		local itemPosition = firstVisible + rowIndex - 1
		local item = self.items[itemPosition]
		row.itemPosition = itemPosition

		if item then
			local success, err = pcall(function()
				local key = makeKey(item)
				row:Show()
				row.icon:SetTexture(item.icon or 134400)
				row.name:SetText(item.name)
				row.meta:SetText(string.format("Bag %d Slot %d  Count %d", item.bag, item.slot, item.count))
				row.price:SetText(Factory.FormatMoney((item.sellPrice or 0) * item.count))
				row.stock:SetText(item.isJunk and "Junk" or "")
				row.toggle:SetText(self.selected[key] and "[x]" or "[ ]")
				
				Factory.UpdateRowSemantics(row, item)
				Factory.SetRowSelected(row, selected == itemPosition)
			end)

			if not success then
				ns.Debug(string.format("Error rendering Sell row %d: %s", itemPosition, tostring(err)))
				row:Hide()
			end
		else
			row:Hide()
		end
	end
end

function SellView:RefreshDetail()
	local item = self:GetFocusedItem()
	if not item then
		self.detailIcon:SetTexture(134400)
		self.detailTitle:SetText(L.STATUS_SELL_EMPTY)
		self.detailText:SetText("")
		self.sellOneButton:SetEnabled(false)
		self.sellStackButton:SetEnabled(false)
		self.sellSelectedButton:SetEnabled(false)
		self.sellJunkButton:SetEnabled(true)
		return
	end

	self.detailIcon:SetTexture(item.icon or 134400)
	self.detailTitle:SetText(item.name)
	self.detailText:SetText(string.format("Stack: %d\nSingle value: %s\nStack value: %s", item.count, Factory.FormatMoney(item.sellPrice), Factory.FormatMoney(item.sellPrice * item.count)))
	self.sellOneButton:SetEnabled(true)
	self.sellStackButton:SetEnabled(true)
	self.sellSelectedButton:SetEnabled(next(self.selected) ~= nil)
	self.sellJunkButton:SetEnabled(true)
end

function SellView:FindEmptySlot()
	for bag = 0, getMaxBagIndex() do
		local freeSlots = C_Container and C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bag)
		if freeSlots and freeSlots > 0 then
			local slotCount = C_Container.GetContainerNumSlots(bag)
			for slot = 1, slotCount do
				local info = C_Container.GetContainerItemInfo(bag, slot)
				if not info then
					return bag, slot
				end
			end
		end
	end
end

function SellView:SellEntry(entry, quantity)
	if not entry then
		return false, "No item"
	end

	if quantity == "stack" or quantity >= entry.count then
		if C_Container and C_Container.UseContainerItem then
			C_Container.UseContainerItem(entry.bag, entry.slot)
			return true
		end
		return false, "Container API unavailable"
	end

	local emptyBag, emptySlot = self:FindEmptySlot()
	if not emptyBag then
		return false, L.NOT_ENOUGH_SPACE
	end

	ClearCursor()
	C_Container.SplitContainerItem(entry.bag, entry.slot, quantity)
	C_Container.PickupContainerItem(emptyBag, emptySlot)
	C_Container.UseContainerItem(emptyBag, emptySlot)
	ClearCursor()
	return true
end

function SellView:SellFocused(quantity)
	local entry = self:GetFocusedItem()
	local ok, err = self:SellEntry(entry, quantity)
	self:SetStatus(ok and "Sold item." or err)
	self:Refresh()
end

function SellView:ToggleFocused()
	local entry = self:GetFocusedItem()
	if not entry then
		return
	end

	local key = makeKey(entry)
	self.selected[key] = not self.selected[key] and entry or nil
	self:SetStatus(self.selected[key] and "Marked item." or "Unmarked item.")
	self:RefreshRows()
	self:RefreshDetail()
end

function SellView:SellSelected()
	if self.batchTask then
		ns.JobScheduler:Cancel(self.batchTask)
		self.batchTask = nil
	end

	local queue = {}
	for _, entry in ipairs(self.items) do
		if self.selected[makeKey(entry)] then
			queue[#queue + 1] = entry
		end
	end

	if #queue == 0 then
		self:SetStatus("No selected items.")
		return
	end

	local function step()
		local entry = table.remove(queue, 1)
		if not entry then
			wipe(self.selected)
			self.batchTask = nil
			self:SetStatus("Selected items sold.")
			self:Refresh()
			return
		end

		self:SellEntry(entry, "stack")
		self.batchTask = ns.JobScheduler:Schedule(0.08, step)
	end

	step()
end

function SellView:SellJunk()
	if C_MerchantFrame and C_MerchantFrame.IsSellAllJunkEnabled and C_MerchantFrame.IsSellAllJunkEnabled() and C_MerchantFrame.SellAllJunkItems then
		C_MerchantFrame.SellAllJunkItems()
		self:SetStatus("Sold junk with merchant cleanup.")
	else
		for _, entry in ipairs(self.items) do
			if entry.isJunk then
				self:SellEntry(entry, "stack")
			end
		end
		self:SetStatus("Sold junk items.")
	end

	self:Refresh()
end

function SellView:HandleAction(action)
	if action == "up" then
		self.focus:Move(-1)
	elseif action == "down" then
		self.focus:Move(1)
	elseif action == "pageDown" then
		self.focus:Page(-1)
	elseif action == "pageUp" then
		self.focus:Page(1)
	elseif action == "confirm" then
		self:SellFocused(1)
		return true
	elseif action == "quick" then
		self:SellFocused("stack")
		return true
	elseif action == "max" then
		self:SellJunk()
		return true
	elseif action == "select" then
		self:ToggleFocused()
		return true
	elseif action == "commit" then
		self:SellSelected()
		return true
	else
		return false
	end

	self:RefreshRows()
	self:RefreshDetail()
	return true
end
