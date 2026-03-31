local _, ns = ...

local Factory = ns.FrameFactory
local tokens  = ns.SkinTokens

local FavoritesView = {}
FavoritesView.__index = FavoritesView
ns.VendorFavoritesView = FavoritesView

-- ─── Card layout constants ────────────────────────────────────────────────────
local CARD_H        = 86     -- height of each card in pixels
local CARD_GAP      = 6      -- vertical gap between cards
local CARD_PAD      = 8      -- inner horizontal padding
local ICON_SIZE     = 28     -- item icon square size
local ICON_GAP      = 3      -- gap between consecutive icons
local ICON_COUNT    = 3      -- max icons shown per card
local BTN_W         = 80     -- right-side button width
local BTN_H         = 22     -- right-side button height
local BTN_GAP       = 4      -- gap between stacked buttons
local MAX_VISIBLE   = 4      -- number of cards visible at once (no scroll needed for most users)

-- Width of the icon strip (3 icons + 2 gaps between them)
local ICON_STRIP_W  = ICON_COUNT * ICON_SIZE + (ICON_COUNT - 1) * ICON_GAP   -- = 90

-- X offset where text columns begin (after icon strip + a small spacer)
local TEXT_X        = CARD_PAD + ICON_STRIP_W + 10

-- Pending sequential purchase state (module-level — only one VendorFrame instance exists)
local pendingCart  = nil
local pendingIndex = 0

-- ─── WoW map-pin helper (12.x compatible) ────────────────────────────────────
-- x, y are stored as percentage values (0–100).
-- C_Map.SetUserWaypoint expects normalised 0–1 coordinates.
local function PlaceMapPin(mapID, xPct, yPct)
	if not mapID or mapID == 0 then return false end
	if not (C_Map and C_Map.CanSetUserWaypointOnMap) then return false end
	if not C_Map.CanSetUserWaypointOnMap(mapID) then return false end

	-- Clear any existing waypoint first
	if C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
		C_Map.ClearUserWaypoint()
	end

	local nx = (xPct or 0) / 100
	local ny = (yPct or 0) / 100

	-- Preferred modern form (9.0.1+, present in 11.x and 12.x)
	local point
	if UiMapPoint and UiMapPoint.CreateFromCoordinates then
		point = UiMapPoint.CreateFromCoordinates(mapID, nx, ny)
	elseif CreateVector2D then
		-- Fallback: plain table form accepted by older engine builds
		point = { uiMapID = mapID, position = CreateVector2D(nx, ny) }
	else
		return false
	end

	C_Map.SetUserWaypoint(point)

	-- Enable the HUD navigation arrow if available (9.2+)
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	end

	-- Open the world map and navigate to the correct zone
	if OpenWorldMap then
		OpenWorldMap(mapID)
	elseif WorldMapFrame then
		WorldMapFrame:Show()
	end

	return true
end

-- ─── Item icon lookup ─────────────────────────────────────────────────────────
-- Tries several API paths to find the icon texture for a given itemID.
-- Returns the texture path/fileID, or 134400 (question mark) as a safe default.
local function GetItemIcon(itemId)
	if not itemId then return 134400 end

	-- 1. Modern retail: C_Item.GetItemInfoInstant returns a table
	if C_Item and C_Item.GetItemInfoInstant then
		local ok, info = pcall(C_Item.GetItemInfoInstant, itemId)
		if ok and type(info) == "table" then
			return info.icon or info.texture or 134400
		end
	end

	-- 2. Legacy / Midnight fallback: GetItemInfoInstant returns multiple values
	--    Signature: itemID, itemType, itemSubType, equipLoc, icon, classID, subclassID
	if GetItemInfoInstant then
		local ok, _, _, _, _, icon = pcall(GetItemInfoInstant, itemId)
		if ok and icon then return icon end
	end

	return 134400
end

-- ─── Vendor item snapshot ─────────────────────────────────────────────────────
-- Returns a map of [itemID] = vendorItem for every item the current merchant sells.
-- Returns an empty table when no merchant is open.
local function BuildVendorItemMap()
	local map   = {}
	local total = ns.Compat.GetNumItems()
	for i = 1, total do
		local item = ns.VendorPurchaseUtils.BuildVendorItem(i)
		if item and item.itemID then
			map[item.itemID] = item
		end
	end
	return map
end

-- ─── Availability check ───────────────────────────────────────────────────────
-- Returns: available (number), total (number), missingNames (table, up to 3 entries)
local function CheckAvailability(favorite, vendorMap)
	local items = favorite.items
	if not items or #items == 0 then return 0, 0, {} end

	local total     = #items
	local available = 0
	local missing   = {}

	for _, entry in ipairs(items) do
		local id = entry.itemId
		if id and vendorMap[id] then
			available = available + 1
		elseif #missing < 3 then
			table.insert(missing, entry.itemName or ("Item #" .. tostring(id or "?")))
		end
	end

	return available, total, missing
end

-- ─── Sequential cart execution ────────────────────────────────────────────────
-- Executes cartItems one-by-one through the owner's purchaseQueue.
-- statusFn(msg) is called with progress messages.
local function ExecuteCart(owner, cartItems, statusFn)
	local vendorMap = BuildVendorItemMap()
	local toExecute = {}

	for _, entry in ipairs(cartItems) do
		local id  = entry.itemId or entry.itemID
		local qty = entry.typicalQuantity or entry.quantity or 1
		if id and id > 0 and vendorMap[id] then
			table.insert(toExecute, { item = vendorMap[id], quantity = qty })
		end
	end

	if #toExecute == 0 then
		if statusFn then statusFn("None of those items found at this vendor.") end
		return
	end

	pendingCart  = toExecute
	pendingIndex = 1
	if statusFn then statusFn(string.format("Loading cart: 0/%d items…", #toExecute)) end

	local function execNext()
		if not pendingCart or pendingIndex > #pendingCart then
			local done = pendingIndex - 1
			pendingCart  = nil
			pendingIndex = 0
			if statusFn then statusFn(string.format("Cart done: %d items purchased.", done)) end
			return
		end

		local entry = pendingCart[pendingIndex]
		pendingIndex = pendingIndex + 1

		local queue = owner and owner.purchaseQueue
		if not queue then
			if statusFn then statusFn("Purchase queue not available.") end
			pendingCart = nil
			return
		end

		local total = #pendingCart
		if statusFn then
			statusFn(string.format("Buying %d/%d: %s x%d",
				pendingIndex - 1, total, entry.item.name or "?", entry.quantity))
		end

		queue:Start(entry.item, entry.quantity)

		-- Poll every 0.5 s until queue finishes, then proceed to next item
		local function waitThen(cb)
			ns.JobScheduler:Schedule(0.5, function()
				if queue.job then
					waitThen(cb)
				else
					ns.JobScheduler:Schedule(0.3, cb)
				end
			end)
		end

		waitThen(execNext)
	end

	execNext()
end

-- ─── Card frame factory ───────────────────────────────────────────────────────
-- Creates a reusable card Frame.  Wired with dummy scripts; PopulateCard fills in
-- real data and re-wires the button OnClick handlers each Refresh cycle.
local function CreateCard(parent)
	local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	card:SetHeight(CARD_H)
	card:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 10,
		insets   = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	card:SetBackdropColor(0.08, 0.08, 0.10, 0.92)
	card:SetBackdropBorderColor(0.30, 0.30, 0.35, 0.85)

	-- ── Icon strip ────────────────────────────────────────────────────────────
	card.iconFrames = {}
	for i = 1, ICON_COUNT do
		local xOff = CARD_PAD + (i - 1) * (ICON_SIZE + ICON_GAP)
		local ic = CreateFrame("Frame", nil, card, "BackdropTemplate")
		ic:SetSize(ICON_SIZE, ICON_SIZE)
		ic:SetPoint("TOPLEFT", card, "TOPLEFT", xOff, -CARD_PAD)
		ic:SetBackdrop({
			bgFile   = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 8,
			insets   = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		ic:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
		ic:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.7)
		local tex = ic:CreateTexture(nil, "ARTWORK")
		tex:SetPoint("TOPLEFT",     ic, "TOPLEFT",     3, -3)
		tex:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", -3,  3)
		tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		tex:SetTexture(134400)
		ic.tex = tex
		ic:Hide()
		card.iconFrames[i] = ic
	end

	card.moreLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	card.moreLabel:SetPoint("LEFT", card, "LEFT", CARD_PAD + ICON_STRIP_W + 4, 0)
	card.moreLabel:SetText("")

	-- ── Text columns (name, stats, vendor info) ───────────────────────────────
	card.nameLabel = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	card.nameLabel:SetPoint("TOPLEFT",  card, "TOPLEFT",  TEXT_X, -CARD_PAD)
	card.nameLabel:SetPoint("RIGHT",    card, "RIGHT",   -(BTN_W + CARD_PAD + 6), 0)
	card.nameLabel:SetJustifyH("LEFT")

	card.statsLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	card.statsLabel:SetPoint("TOPLEFT", card.nameLabel, "BOTTOMLEFT", 0, -3)
	card.statsLabel:SetPoint("RIGHT",   card.nameLabel,   "RIGHT",    0,  0)
	card.statsLabel:SetJustifyH("LEFT")

	-- "Wrong vendor" badge shown when items are unavailable at this merchant
	card.unavailBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	card.unavailBadge:SetPoint("TOPLEFT", card.statsLabel, "BOTTOMLEFT", 0, -3)
	card.unavailBadge:SetText("|cffff5555Not sold here|r")
	card.unavailBadge:Hide()

	-- Vendor name + coordinates line (bottom of card, below icon strip)
	card.vendorLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	card.vendorLabel:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", TEXT_X,  CARD_PAD)
	card.vendorLabel:SetPoint("RIGHT",      card, "RIGHT",     -(BTN_W + CARD_PAD + 6), 0)
	card.vendorLabel:SetJustifyH("LEFT")
	card.vendorLabel:SetWordWrap(false)

	-- ── Right-side buttons (stacked top→bottom) ───────────────────────────────
	card.buyButton = Factory.CreateButton(card, "Buy Now", BTN_W, BTN_H)
	card.buyButton:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CARD_PAD, -CARD_PAD)

	card.removeButton = Factory.CreateButton(card, "Remove", BTN_W, BTN_H)
	card.removeButton:SetPoint("TOP", card.buyButton, "BOTTOM", 0, -BTN_GAP)

	card.pinButton = Factory.CreateButton(card, "Map Pin", BTN_W, BTN_H)
	card.pinButton:SetPoint("TOP", card.removeButton, "BOTTOM", 0, -BTN_GAP)

	card:Hide()
	return card
end

-- ─── Constructor ──────────────────────────────────────────────────────────────
function FavoritesView:New(parent, owner)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Mixin(frame, self)
	frame.owner   = owner
	frame._data   = {}    -- sorted list of { fav, dbIndex }
	frame._offset = 0     -- scroll offset (number of cards scrolled past)
	frame:SetAllPoints()

	-- Header
	frame.titleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.titleLabel:SetPoint("TOPLEFT", 14, -12)
	frame.titleLabel:SetText("Favorites")

	frame.countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.countLabel:SetPoint("TOPLEFT", frame.titleLabel, "BOTTOMLEFT", 0, -4)
	frame.countLabel:SetText("")

	-- Status/progress line (top-right)
	frame.statusLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.statusLine:SetPoint("TOPRIGHT", -14, -14)
	frame.statusLine:SetJustifyH("RIGHT")
	frame.statusLine:SetText("")

	-- Empty state message
	frame.emptyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.emptyLabel:SetPoint("CENTER", 0, 30)
	frame.emptyLabel:SetText(
		"No favorites saved yet.\n" ..
		"Open a vendor, make a purchase, then use\n" ..
		"'Save Cart' in the Smart Actions panel."
	)
	frame.emptyLabel:SetJustifyH("CENTER")
	frame.emptyLabel:Hide()

	-- Scroll container (between header and nav bar)
	frame.scrollArea = CreateFrame("Frame", nil, frame)
	frame.scrollArea:SetPoint("TOPLEFT",     frame, "TOPLEFT",      8, -52)
	frame.scrollArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",  -8,  44)
	frame.scrollArea:EnableMouseWheel(true)
	frame.scrollArea:SetScript("OnMouseWheel", function(_, delta)
		frame:Scroll(-delta)
	end)

	-- Navigation buttons (bottom of frame)
	frame.upBtn = Factory.CreateButton(frame, "▲", 28, 20)
	frame.upBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 10)
	frame.upBtn:SetScript("OnClick", function() frame:Scroll(-1) end)

	frame.downBtn = Factory.CreateButton(frame, "▼", 28, 20)
	frame.downBtn:SetPoint("LEFT", frame.upBtn, "RIGHT", 4, 0)
	frame.downBtn:SetScript("OnClick", function() frame:Scroll(1) end)

	frame.pageInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.pageInfo:SetPoint("LEFT", frame.downBtn, "RIGHT", 8, 0)
	frame.pageInfo:SetText("")

	-- Card pool: created once, reused across refreshes
	frame._cards = {}
	for i = 1, MAX_VISIBLE do
		local card = CreateCard(frame.scrollArea)
		local yOff = -((i - 1) * (CARD_H + CARD_GAP))
		card:SetPoint("TOPLEFT",  frame.scrollArea, "TOPLEFT",  0, yOff)
		card:SetPoint("RIGHT",    frame.scrollArea, "RIGHT",    0,  0)
		frame._cards[i] = card
	end

	frame:Hide()
	return frame
end

-- ─── Refresh ──────────────────────────────────────────────────────────────────
function FavoritesView:Refresh()
	local db        = ns.DB
	local favorites = db and db.favorites or {}

	-- Build sorted list: most recently used first
	local data = {}
	for i, fav in ipairs(favorites) do
		data[#data + 1] = { fav = fav, dbIndex = i }
	end
	table.sort(data, function(a, b)
		return (a.fav.lastUsed or 0) > (b.fav.lastUsed or 0)
	end)
	self._data = data

	local total = #data
	self.countLabel:SetText(total > 0 and (total .. " saved") or "")

	if total == 0 then
		self.emptyLabel:Show()
		for _, c in ipairs(self._cards) do c:Hide() end
		self.upBtn:SetEnabled(false)
		self.downBtn:SetEnabled(false)
		self.pageInfo:SetText("")
		return
	end

	self.emptyLabel:Hide()

	-- Clamp scroll offset
	local maxOffset = math.max(0, total - MAX_VISIBLE)
	self._offset = math.max(0, math.min(self._offset, maxOffset))

	-- Build vendor item map once (relatively expensive loop over merchant items)
	local vendorMap = BuildVendorItemMap()
	local atVendor  = ns.Compat.GetNumItems() > 0

	-- Populate visible card slots
	for slot = 1, MAX_VISIBLE do
		local dataIdx = self._offset + slot
		local entry   = data[dataIdx]
		local card    = self._cards[slot]
		if entry then
			self:PopulateCard(card, entry.fav, entry.dbIndex, vendorMap, atVendor)
			card:Show()
		else
			card:Hide()
		end
	end

	-- Navigation state
	self.upBtn:SetEnabled(self._offset > 0)
	self.downBtn:SetEnabled(self._offset < maxOffset)
	self.pageInfo:SetText(string.format("%d–%d / %d",
		self._offset + 1,
		math.min(self._offset + MAX_VISIBLE, total),
		total))

	self.statusLine:SetText("")
end

-- ─── PopulateCard ─────────────────────────────────────────────────────────────
function FavoritesView:PopulateCard(card, fav, dbIndex, vendorMap, atVendor)
	local items = fav.items or {}

	-- ── Icons ─────────────────────────────────────────────────────────────────
	for i = 1, ICON_COUNT do
		local ic    = card.iconFrames[i]
		local entry = items[i]
		if entry then
			-- Prefer vendor-map icon (already resolved), fall back to item cache
			local vItem = entry.itemId and vendorMap[entry.itemId]
			local icon  = (vItem and vItem.icon) or GetItemIcon(entry.itemId)
			ic.tex:SetTexture(icon)
			ic:Show()
		else
			ic:Hide()
		end
	end

	local extra = #items - ICON_COUNT
	card.moreLabel:SetText(extra > 0 and string.format("+%d", extra) or "")

	-- ── Name and stats ────────────────────────────────────────────────────────
	card.nameLabel:SetText(fav.name or "Unnamed Favorite")
	local useText = (fav.useCount and fav.useCount > 0)
		and string.format("Used %dx  ·  ", fav.useCount) or ""
	card.statsLabel:SetText(string.format("%s%d item%s",
		useText, #items, #items ~= 1 and "s" or ""))

	-- ── Vendor / location line ────────────────────────────────────────────────
	local vi = fav.vendorInfo
	if vi and vi.name then
		local loc = vi.location
		if loc and loc.mapID and loc.mapID > 0 and (loc.x > 0 or loc.y > 0) then
			card.vendorLabel:SetText(string.format(
				"|cffaaaaaa%s|r  |cff777777%s  %.1f, %.1f|r",
				vi.name, loc.zoneName or "?", loc.x, loc.y))
		else
			card.vendorLabel:SetText(string.format(
				"|cffaaaaaa%s|r  |cff555555(no coordinates)|r", vi.name))
		end
	else
		card.vendorLabel:SetText("|cff555555No purchase history|r")
	end

	-- ── Availability ──────────────────────────────────────────────────────────
	local available, total, _ = CheckAvailability(fav, vendorMap)
	local allAvail = (total == 0) or (available == total)
	local unavail  = atVendor and not allAvail

	if unavail then
		-- Dim the card: darken border, gray out text, desaturate icons
		card:SetBackdropColor(0.05, 0.04, 0.04, 0.95)
		card:SetBackdropBorderColor(0.50, 0.15, 0.15, 0.90)
		card.nameLabel:SetTextColor(0.50, 0.50, 0.50)
		card.statsLabel:SetTextColor(0.40, 0.40, 0.40)
		card.vendorLabel:SetTextColor(0.40, 0.40, 0.40)
		for _, ic in ipairs(card.iconFrames) do
			ic.tex:SetVertexColor(0.40, 0.40, 0.40, 0.80)
		end
		card.unavailBadge:Show()
		card.buyButton:SetEnabled(false)
	else
		-- Normal state
		card:SetBackdropColor(0.08, 0.08, 0.10, 0.92)
		card:SetBackdropBorderColor(0.30, 0.30, 0.35, 0.85)
		card.nameLabel:SetTextColor(1, 1, 1)
		card.statsLabel:SetTextColor(0.85, 0.85, 0.85)
		card.vendorLabel:SetTextColor(0.85, 0.85, 0.85)
		for _, ic in ipairs(card.iconFrames) do
			ic.tex:SetVertexColor(1, 1, 1, 1)
		end
		card.unavailBadge:Hide()
		card.buyButton:SetEnabled(true)
	end

	-- ── Button handlers ───────────────────────────────────────────────────────
	local view = self  -- capture for closures

	card.buyButton:SetScript("OnClick", function()
		if unavail then return end  -- extra safety guard
		-- Update vendor info from the active session (so location stays current)
		local session = ns.Telemetry and ns.Telemetry:GetCurrentSession()
		if session and atVendor then
			if not fav.vendorInfo then fav.vendorInfo = {} end
			fav.vendorInfo.name     = session.vendor
			fav.vendorInfo.location = session.vendorLocation
			fav.lastUsed  = time()
			fav.useCount  = (fav.useCount or 0) + 1
		end
		ExecuteCart(view.owner, fav.items, function(msg)
			view.statusLine:SetText(msg)
		end)
	end)

	card.removeButton:SetScript("OnClick", function()
		local db = ns.DB
		if db and db.favorites then
			table.remove(db.favorites, dbIndex)
		end
		view:Refresh()
	end)

	-- Pin button: enabled only when valid coordinates are stored
	local loc = vi and vi.location
	local hasPinData = loc and loc.mapID and loc.mapID > 0 and (loc.x > 0 or loc.y > 0)
	card.pinButton:SetEnabled(hasPinData or false)

	if hasPinData then
		card.pinButton:SetScript("OnClick", function()
			local ok = PlaceMapPin(loc.mapID, loc.x, loc.y)
			if ok then
				view.statusLine:SetText(string.format(
					"Pin set: %s  %.1f, %.1f", loc.zoneName or "?", loc.x, loc.y))
			else
				view.statusLine:SetText("Cannot place pin on this map.")
			end
		end)
	else
		card.pinButton:SetScript("OnClick", nil)
	end
end

-- ─── Scroll ───────────────────────────────────────────────────────────────────
function FavoritesView:Scroll(delta)
	local maxOffset = math.max(0, #self._data - MAX_VISIBLE)
	self._offset    = math.max(0, math.min(self._offset + delta, maxOffset))
	self:Refresh()
end
