local _, ns = ...

local Factory = ns.FrameFactory
local L = ns.L or {}

local RepairView = {}
RepairView.__index = RepairView
ns.VendorRepairView = RepairView

local function getInventoryRepairCost(slot)
	if not GetInventoryItemRepairCost then
		return 0
	end

	local ok, value = pcall(GetInventoryItemRepairCost, slot)
	if ok and value then
		return value
	end

	ok, value = pcall(GetInventoryItemRepairCost, "player", slot)
	if ok and value then
		return value
	end

	return 0
end

local function getEquippedRepairCost()
	local total = 0

	for slot = 1, (INVSLOT_LAST_EQUIPPED or 19) do
		local repairCost = getInventoryRepairCost(slot)
		if repairCost and repairCost > 0 then
			total = total + repairCost
		end
	end

	return total
end

function RepairView:New(parent, owner)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Mixin(frame, self)
	frame.owner = owner
	frame:SetAllPoints()

	frame.panel = Factory.CreateInset(frame, 706, 434)
	frame.panel:SetPoint("TOPLEFT", 4, -42)

	frame.title = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", 16, -16)
	frame.title:SetText(L.REPAIR)
	frame.title:Hide() -- Hide redundant header

	frame.summary = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.summary:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -14)
	frame.summary:SetPoint("RIGHT", -16, 0)
	frame.summary:SetJustifyH("LEFT")

	frame.equipped = Factory.CreateButton(frame.panel, L.REPAIR_EQUIPPED, 180, 28)
	frame.equipped:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -20)
	frame.equipped:SetScript("OnClick", function()
		frame:RepairEquipped()
	end)

	frame.all = Factory.CreateButton(frame.panel, L.REPAIR_ALL, 180, 28)
	frame.all:SetPoint("LEFT", frame.equipped, "RIGHT", 12, 0)
	frame.all:SetScript("OnClick", function()
		frame:RepairAll(false)
	end)

	frame.guild = Factory.CreateButton(frame.panel, L.REPAIR_GUILD, 180, 28)
	frame.guild:SetPoint("LEFT", frame.all, "RIGHT", 12, 0)
	frame.guild:SetScript("OnClick", function()
		frame:RepairAll(true)
	end)

	frame.status = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.status:SetPoint("TOPLEFT", frame.equipped, "BOTTOMLEFT", 0, -18)
	frame.status:SetPoint("RIGHT", -16, 0)
	frame.status:SetJustifyH("LEFT")
	frame.status:SetText(L.STATUS_REPAIR_IDLE)

	frame.notes = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.notes:SetPoint("TOPLEFT", frame.status, "BOTTOMLEFT", 0, -12)
	frame.notes:SetPoint("RIGHT", -16, 0)
	frame.notes:SetJustifyH("LEFT")

	return frame
end

function RepairView:SetStatus(text)
	self.status:SetText(text or L.STATUS_REPAIR_IDLE)
end

function RepairView:Refresh()
	if not MerchantFrame or not MerchantFrame:IsShown() then
		self.summary:SetText("Open a repair-capable vendor to use repair actions.")
		self.notes:SetText("Repair APIs are only reliable while the proper merchant window is open.")
		self.equipped:SetEnabled(false)
		self.all:SetEnabled(false)
		self.guild:SetEnabled(false)
		return
	end

	local allCost, canRepair = GetRepairAllCost()
	local equippedCost = getEquippedRepairCost()
	local canGuild = CanGuildBankRepair and CanGuildBankRepair()

	self.summary:SetText(string.format("Equipped repair: %s\nRepair all: %s\nGuild bank available: %s", Factory.FormatMoney(equippedCost), Factory.FormatMoney(allCost), canGuild and YES or NO))
	self.notes:SetText("A = equipped, X = all, Y = guild. Xbox / Command Center remain reserved for the handheld shell.")
	self.equipped:SetEnabled(canRepair and equippedCost > 0)
	self.all:SetEnabled(canRepair)
	self.guild:SetEnabled(canRepair and canGuild)
end

function RepairView:RepairEquipped()
	if not MerchantFrame or not MerchantFrame:IsShown() or not CanMerchantRepair or not CanMerchantRepair() then
		self:SetStatus("Merchant cannot repair.")
		return
	end

	if not ShowRepairCursor or not HideRepairCursor then
		self:SetStatus("Repair cursor API unavailable.")
		return
	end

	ShowRepairCursor()
	for slot = 1, (INVSLOT_LAST_EQUIPPED or 19) do
		local repairCost = getInventoryRepairCost(slot)
		if repairCost and repairCost > 0 then
			UseInventoryItem(slot)
		end
	end
	HideRepairCursor()
	self:SetStatus("Repaired equipped gear.")
	self:Refresh()
end

function RepairView:RepairAll(useGuildBank)
	if not MerchantFrame or not MerchantFrame:IsShown() or not CanMerchantRepair or not CanMerchantRepair() then
		self:SetStatus("Merchant cannot repair.")
		return
	end

	if useGuildBank and not (CanGuildBankRepair and CanGuildBankRepair()) then
		self:SetStatus("Guild repair unavailable.")
		return
	end

	RepairAllItems(useGuildBank and 1 or nil)
	self:SetStatus(useGuildBank and "Repaired with guild bank." or "Repaired all gear.")
	self:Refresh()
end

function RepairView:HandleAction(action)
	if action == "confirm" then
		self:RepairEquipped()
	elseif action == "quick" then
		self:RepairAll(false)
	elseif action == "max" then
		self:RepairAll(true)
	else
		return false
	end

	return true
end
