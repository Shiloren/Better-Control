local _, ns = ...

local FocusList = {}
FocusList.__index = FocusList
ns.FocusList = FocusList

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	end

	if value > maximum then
		return maximum
	end

	return value
end

function FocusList:New(visibleCount)
	return setmetatable({
		visibleCount = visibleCount or 1,
		items = {},
		index = 0,
		offset = 0,
		onChanged = nil,
	}, self)
end

function FocusList:SetVisibleCount(visibleCount)
	self.visibleCount = math.max(1, visibleCount or 1)
	self:EnsureVisible()
end

function FocusList:SetItems(items)
	self.items = items or {}

	if #self.items == 0 then
		self.index = 0
		self.offset = 0
	else
		if self.index == 0 then
			self.index = 1
		end

		self.index = clamp(self.index, 1, #self.items)
		self:EnsureVisible()
	end

	self:Notify()
end

function FocusList:SetOnChanged(handler)
	self.onChanged = handler
end

function FocusList:GetItems()
	return self.items
end

function FocusList:GetItem(index)
	return self.items[index or self.index]
end

function FocusList:GetIndex()
	return self.index
end

function FocusList:SetIndex(index)
	if #self.items == 0 then
		self.index = 0
		self.offset = 0
		self:Notify()
		return
	end

	self.index = clamp(index, 1, #self.items)
	self:EnsureVisible()
	self:Notify()
end

function FocusList:Move(delta)
	if #self.items == 0 then
		return
	end

	self:SetIndex(self.index + delta)
end

function FocusList:Page(delta)
	if #self.items == 0 then
		return
	end

	self:SetIndex(self.index + (delta * self.visibleCount))
end

function FocusList:GetVisibleRange()
	local first = self.offset + 1
	local last = math.min(#self.items, self.offset + self.visibleCount)
	return first, last
end

function FocusList:EnsureVisible()
	if #self.items == 0 then
		self.offset = 0
		return
	end

	local maxOffset = math.max(0, #self.items - self.visibleCount)
	if self.index <= self.offset then
		self.offset = self.index - 1
	elseif self.index > self.offset + self.visibleCount then
		self.offset = self.index - self.visibleCount
	end

	self.offset = clamp(self.offset, 0, maxOffset)
end

function FocusList:Notify()
	if self.onChanged then
		self.onChanged(self)
	end
end
