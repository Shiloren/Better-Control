local _, ns = ...

local Factory = ns.FrameFactory
local L = ns.L or {}
local tokens = ns.SkinTokens
local Utils = ns.VendorPurchaseUtils

local CatalogView = {}
CatalogView.__index = CatalogView
ns.VendorCatalogView = CatalogView

local FILTERS = {
	{ id = "all", label = L.FILTER_ALL },
	{ id = "consumables", label = L.FILTER_CONSUMABLES },
	{ id = "reagents", label = L.FILTER_REAGENTS },
	{ id = "limited", label = L.FILTER_LIMITED },
	{ id = "affordable", label = L.FILTER_AFFORDABLE },
}

local function filterItem(filterId, item)
	if filterId == "all" then
		return true
	end

	if filterId == "consumables" then
		return item.isConsumable
	end

	if filterId == "reagents" then
		return item.isReagent
	end

	if filterId == "limited" then
		return item.stock and item.stock > -1
	end

	if filterId == "affordable" then
		return Utils.GetAffordableQuantity(item) >= math.max(1, item.unitSize or 1)
	end

	return true
end

function CatalogView:New(parent, owner, numRows, compact)
	numRows = numRows or tokens.list.visibleRows
	local frame = CreateFrame("Frame", nil, parent)
	ns.Mixin(frame, self)
	
	frame.owner = owner
	frame.items = {}
	frame.filter = ns.DB.vendor.defaultFilter or "all"
	frame.rows = {}
	frame.focus = ns.FocusList:New(numRows)
	frame.focus:SetOnChanged(function()
		frame:RefreshRows()
	end)

	frame:SetAllPoints()

	frame.header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.header:SetPoint("TOPLEFT", 14, -12)
	frame.header:SetText(L.BUY)
	frame.header:Hide() -- Hide redundant header in unified mode

	frame.filters = CreateFrame("Frame", nil, frame)
	frame.filters:SetPoint("TOPLEFT", 14, compact and -4 or -32)
	frame.filters:SetSize(tokens.panels.leftWidth - 28, 22)

	frame.filterButtons = {}
	local previousButton
	for _, filter in ipairs(FILTERS) do
		local button = Factory.CreateButton(frame.filters, filter.label, 78, 20)
		if previousButton then
			button:SetPoint("LEFT", previousButton, "RIGHT", 4, 0)
		else
			button:SetPoint("LEFT", 0, 0)
		end
		button.filterId = filter.id
		button:SetScript("OnClick", function(selfButton)
			frame:SetFilter(selfButton.filterId)
		end)
		frame.filterButtons[#frame.filterButtons + 1] = button
		previousButton = button
	end

	frame.list = Factory.CreateInset(frame, tokens.panels.leftWidth, compact and 210 or 400)
	frame.list:SetPoint("TOPLEFT", frame.filters, "BOTTOMLEFT", 0, compact and -4 or -8)

	frame.empty = frame.list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.empty:SetPoint("CENTER")
	frame.empty:SetText(L.STATUS_NO_SELECTION)
	frame.empty:Hide()

	for rowIndex = 1, numRows do
		local row = Factory.CreateRow(frame.list, tokens.panels.leftWidth - 20, tokens.list.rowHeight)
		row:SetPoint("TOPLEFT", 10, -10 - ((rowIndex - 1) * tokens.list.rowHeight))
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", function(selfRow, button)
			if button == "RightButton" and ns.InputAdapter:GetMode() == "mouse" then
				local item = frame.items[selfRow.itemPosition]
				if item then
					frame.owner:PurchaseImmediately(item)
				end
			else
				frame.focus:SetIndex(selfRow.itemPosition)
				frame.owner:SetSelectedBuyItem(frame.focus:GetItem())
			end
		end)
		row:SetScript("OnMouseWheel", function(_, delta)
			frame:HandleAction(delta < 0 and "down" or "up")
		end)
		frame.rows[rowIndex] = row
	end

	frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.footer:SetPoint("TOPLEFT", frame.list, "BOTTOMLEFT", 2, -8)
	frame.footer:SetPoint("RIGHT", frame.list, "BOTTOMRIGHT", -2, 0)
	frame.footer:SetJustifyH("LEFT")

	frame:SetScript("OnMouseWheel", function(_, delta)
		frame:HandleAction(delta < 0 and "down" or "up")
	end)

	ns.Debug("CatalogView:New initialized successfully")
	return frame
end

function CatalogView:SetFilter(filterId)
	self.filter = filterId
	ns.DB.vendor.defaultFilter = filterId
	self:Refresh()
end

function CatalogView:GetSelectedItem()
	return self.focus:GetItem()
end

function CatalogView:Refresh()
	local selectedIndex = self:GetSelectedItem() and self:GetSelectedItem().index
	local total = ns.Compat.GetNumItems()
	ns.Debug(string.format("Catalog Refresh: Found %d items in API.", total))

	local items = {}
	local buildCount = 0
	for index = 1, total do
		local item = Utils.BuildVendorItem(index)
		if item then
			buildCount = buildCount + 1
			if filterItem(self.filter, item) then
				items[#items + 1] = item
			end
		end
	end

	ns.Debug(string.format("Catalog Results: %d built, %d passed filter (%s).", buildCount, #items, self.filter))

	self.items = items
	self.focus:SetItems(items)

	if selectedIndex then
		for position, item in ipairs(items) do
			if item.index == selectedIndex then
				self.focus:SetIndex(position)
				break
			end
		end
	end

	if #items == 0 then
		self.owner:SetSelectedBuyItem(nil)
		self.empty:Show()
	else
		self.empty:Hide()
		self.owner:SetSelectedBuyItem(self.focus:GetItem())
	end

	for _, button in ipairs(self.filterButtons) do
		button:SetEnabled(button.filterId ~= self.filter)
	end

	self.footer:SetText(string.format("%d items, filter: %s", #items, self.filter))
	self:RefreshRows()
end

function CatalogView:RefreshRows()
	local selected = self.focus:GetIndex()
	local firstVisible = select(1, self.focus:GetVisibleRange())

	for rowIndex, row in ipairs(self.rows) do
		local itemPosition = firstVisible + rowIndex - 1
		local item = self.items[itemPosition]
		row.itemPosition = itemPosition

		if item then
			local success, err = pcall(function()
				local affordable = Utils.GetAffordableQuantity(item)
				row:Show()
				row.icon:SetTexture(item.icon or 134400)
				row.name:SetText(item.name)
				row.meta:SetText(string.format("%s: %d  %s: %d  Can buy: %d", L.OWNED, Utils.GetOwnedCount(item), L.BUNDLE, item.unitSize, affordable))
				row.price:SetText(Utils.DescribeCosts(item, item.unitSize))
				if item.stock and item.stock > -1 then
					row.stock:SetText(string.format("%s: %d", L.VENDOR_STOCK, item.stock))
				else
					row.stock:SetText("Unlimited")
				end

				ns.FrameFactory.UpdateRowSemantics(row, item)
				
				-- Usability indicators: tint icon if not usable or affordable
				if affordable >= item.unitSize and item.isUsable then
					row.icon:SetVertexColor(1, 1, 1, 1)
				else
					row.icon:SetVertexColor(1, 0.2, 0.2, 0.9)
				end

				ns.FrameFactory.SetRowSelected(row, selected == itemPosition)
			end)

			if not success then
				ns.Debug(string.format("Error rendering Catalog row %d: %s", itemPosition, tostring(err)))
				-- Ensure row is in a safe state if it failed
				row:Hide()
			end
		else
			row:Hide()
		end
	end
end

function CatalogView:HandleAction(action)
	if action == "up" then
		self.focus:Move(-1)
	elseif action == "down" then
		self.focus:Move(1)
	elseif action == "pageDown" then
		self.focus:Page(-1)
	elseif action == "pageUp" then
		self.focus:Page(1)
	elseif action == "confirm" then
		self.owner:StartSelectedPurchase()
		return true
	else
		return false
	end

	self.owner:SetSelectedBuyItem(self.focus:GetItem())
	return true
end
