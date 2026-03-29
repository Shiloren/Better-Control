local _, ns = ...

local Factory = ns.FrameFactory
local L = ns.L or {}
local tokens = ns.SkinTokens

local BuybackView = {}
BuybackView.__index = BuybackView
ns.VendorBuybackView = BuybackView

function BuybackView:New(parent, owner)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Mixin(frame, self)
	frame.owner = owner
	frame.items = {}
	frame.rows = {}
	frame.focus = ns.FocusList:New(tokens.list.visibleRows)
	frame.focus:SetOnChanged(function()
		frame:RefreshRows()
	end)
	frame:SetAllPoints()

	frame.left = Factory.CreateInset(frame, 430, 434)
	frame.left:SetPoint("TOPLEFT", 4, -42)

	frame.right = Factory.CreateInset(frame, 268, 434)
	frame.right:SetPoint("TOPRIGHT", -4, -42)

	frame.title = frame.left:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", 14, -12)
	frame.title:SetText(L.BUYBACK)

	frame.empty = frame.left:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.empty:SetPoint("CENTER")
	frame.empty:SetText(L.STATUS_BUYBACK_EMPTY)
	frame.empty:Hide()

	for rowIndex = 1, tokens.list.visibleRows do
		local row = Factory.CreateRow(frame.left, 410, tokens.list.rowHeight)
		row:SetPoint("TOPLEFT", 10, -40 - ((rowIndex - 1) * tokens.list.rowHeight))
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

	frame.action = Factory.CreateButton(frame.right, L.BUYBACK, 248, 24)
	frame.action:SetPoint("TOPLEFT", frame.detailText, "BOTTOMLEFT", 0, -20)
	frame.action:SetScript("OnClick", function()
		frame:BuybackFocused()
	end)

	frame.status = frame.right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.status:SetPoint("TOPLEFT", frame.action, "BOTTOMLEFT", 0, -16)
	frame.status:SetPoint("RIGHT", -14, 0)
	frame.status:SetJustifyH("LEFT")
	frame.status:SetText(L.STATUS_IDLE)

	return frame
end

function BuybackView:SetStatus(text)
	self.status:SetText(text or L.STATUS_IDLE)
end

function BuybackView:BuildItems()
	local items = {}
	local total = ns.Compat.GetNumBuybackItems()
	for index = 1, total do
		local info = ns.Compat.GetBuybackItemInfo(index)
		if info and info.name then
			local itemName, itemLink, quality, _, _, _, _, _, _, texture, _, _, _, _, _, classID = GetItemInfo(info.name)
			if not itemLink then
				itemLink = ns.Compat.GetBuybackItemLink(index)
			end
			if itemLink and not quality then
				quality = select(3, GetItemInfo(itemLink))
			end

			items[#items + 1] = {
				index = index,
				name = info.name,
				icon = info.texture,
				price = info.price or 0,
				quantity = info.quantity or 1,
				isUsable = info.isUsable ~= false,
				isConsumable = classID == Enum.ItemClass.Consumable,
				quality = quality or info.quality,
				itemLink = itemLink,
			}
		end
	end
	return items
end

function BuybackView:GetFocusedItem()
	return self.focus:GetItem()
end

function BuybackView:Refresh()
	local selectedIndex = self:GetFocusedItem() and self:GetFocusedItem().index
	self.items = self:BuildItems()
	self.focus:SetItems(self.items)

	if selectedIndex then
		for index, entry in ipairs(self.items) do
			if entry.index == selectedIndex then
				self.focus:SetIndex(index)
				break
			end
		end
	end

	self.empty:SetShown(#self.items == 0)
	self:RefreshRows()
	self:RefreshDetail()
end

function BuybackView:RefreshRows()
	local selected = self.focus:GetIndex()
	local firstVisible = select(1, self.focus:GetVisibleRange())
	for rowIndex, row in ipairs(self.rows) do
		local itemPosition = firstVisible + rowIndex - 1
		local item = self.items[itemPosition]
		row.itemPosition = itemPosition
		if item then
			row:Show()
			row.icon:SetTexture(item.icon or 134400)
			row.name:SetText(item.name)
			row.meta:SetText(string.format("Quantity: %d", item.quantity))
			row.price:SetText(Factory.FormatMoney(item.price))
			row.stock:SetText("")
			
			Factory.UpdateRowSemantics(row, item)
			
			-- Usability indicators: tint icon if not affordable (not usable in buyback context? usually yes)
			if (GetMoney() >= item.price) and item.isUsable then
				row.icon:SetVertexColor(1, 1, 1, 1)
			else
				row.icon:SetVertexColor(1, 0.2, 0.2, 0.9)
			end
			
			Factory.SetRowSelected(row, selected == itemPosition)
		else
			row:Hide()
		end
	end
end

function BuybackView:RefreshDetail()
	local item = self:GetFocusedItem()
	if not item then
		self.detailIcon:SetTexture(134400)
		self.detailTitle:SetText(L.STATUS_BUYBACK_EMPTY)
		self.detailText:SetText("")
		self.action:SetEnabled(false)
		return
	end

	self.detailIcon:SetTexture(item.icon or 134400)
	self.detailTitle:SetText(item.name)
	self.detailText:SetText(string.format("Quantity: %d\nCost: %s", item.quantity, Factory.FormatMoney(item.price)))
	self.action:SetEnabled(true)
end

function BuybackView:BuybackFocused()
	local item = self:GetFocusedItem()
	if not item then
		return
	end

	ns.Compat.BuybackItem(item.index)
	self:SetStatus(string.format("Bought back %s.", item.name))
	self:Refresh()
end

function BuybackView:HandleAction(action)
	if action == "up" then
		self.focus:Move(-1)
	elseif action == "down" then
		self.focus:Move(1)
	elseif action == "pageDown" then
		self.focus:Page(-1)
	elseif action == "pageUp" then
		self.focus:Page(1)
	elseif action == "confirm" then
		self:BuybackFocused()
		return true
	else
		return false
	end

	self:RefreshRows()
	self:RefreshDetail()
	return true
end
