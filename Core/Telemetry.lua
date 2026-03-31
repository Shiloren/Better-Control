local _, ns = ...

local Telemetry = {}
ns.Telemetry = Telemetry

-- Current vendor session (accumulates purchases until vendor closes)
local currentSession = nil
local analysisTimer = nil

function Telemetry:Init()
	local db = ns.DB
	if not db.purchaseHistory then db.purchaseHistory = {} end
	if not db.quantityPatterns then db.quantityPatterns = {} end
	if not db.detectedCarts then db.detectedCarts = {} end
	if not db.consumptionRates then db.consumptionRates = {} end
	if not db.telemetry then
		db.telemetry = {
			lastAnalysis = 0,
			totalPurchases = 0,
			totalGoldSpent = 0,
			totalItemsBought = 0,
			vendorOpenCount = 0,
		}
	end
	if not db.insightSettings then
		db.insightSettings = {
			enabled = true,
			autoSuggestQuantity = true,
			showCartSuggestions = true,
			showRestockWarnings = true,
			showAutoPopup = true,
			minOccurrencesForPattern = 3,
			maxHistoryItems = 1000,
			analysisDebounce = 2,
		}
	end
	ns.Debug("Telemetry:Init complete")
end

-- Called when MERCHANT_SHOW fires
function Telemetry:StartSession(vendorName)
	-- Capture vendor location from player position (player must be near the vendor)
	local mapID   = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local pos     = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
	local mapInfo = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)

	currentSession = {
		vendor    = vendorName or "Unknown Vendor",
		cart      = {},
		startTime = time(),
		vendorLocation = {
			mapID    = mapID or 0,
			-- Store as percentage (0–100) with 2-decimal precision — standard WoW display format
			x        = pos and (math.floor((pos.x or 0) * 10000 + 0.5) / 100) or 0,
			y        = pos and (math.floor((pos.y or 0) * 10000 + 0.5) / 100) or 0,
			zoneName = (mapInfo and mapInfo.name) or "Unknown",
		},
	}

	local db = ns.DB
	if db.telemetry then
		db.telemetry.vendorOpenCount = (db.telemetry.vendorOpenCount or 0) + 1
	end
	ns.Debug("Telemetry: session started for " .. (vendorName or "?"))
end

-- Called from PurchaseQueue:Complete() after each item is fully purchased
function Telemetry:TrackItemPurchase(item, quantity)
	if not currentSession then return end
	if not item or not quantity or quantity <= 0 then return end

	local itemId = item.itemID or 0
	if itemId == 0 then return end

	-- Accumulate quantities if same item purchased multiple times in session
	for _, entry in ipairs(currentSession.cart) do
		if entry.itemId == itemId then
			entry.quantity = entry.quantity + quantity
			local unitCost = item.price and item.unitSize and item.unitSize > 0
				and (item.price / item.unitSize) or (item.price or 0)
			entry.totalCost = entry.totalCost + unitCost * quantity
			return
		end
	end

	local unitCost = item.price and item.unitSize and item.unitSize > 0
		and (item.price / item.unitSize) or (item.price or 0)

	table.insert(currentSession.cart, {
		itemId = itemId,
		itemName = item.name or "Unknown",
		quantity = quantity,
		unitCost = unitCost,
		totalCost = unitCost * quantity,
		isConsumable = item.isConsumable or false,
	})
end

-- Called when MERCHANT_CLOSED fires
function Telemetry:FinalizeSession()
	if not currentSession then return end

	local cart = currentSession.cart
	if #cart == 0 then
		currentSession = nil
		return
	end

	local db = ns.DB
	if not (db.insightSettings and db.insightSettings.enabled) then
		currentSession = nil
		return
	end

	-- Calculate totals
	local totalCost = 0
	local totalConsumables = 0
	for _, entry in ipairs(cart) do
		totalCost = totalCost + entry.totalCost
		if entry.isConsumable then
			totalConsumables = totalConsumables + entry.quantity
		end
	end

	-- Temporal context
	local ts = time()
	local d = date("*t", ts)
	local weekday = d.wday - 1  -- 0=Sunday .. 6=Saturday
	local hour = d.hour

	-- Context detection
	local preRaid = totalConsumables > 300

	-- Build record
	local record = {
		purchaseId = string.format("%d-%d-%06x", ts, weekday, math.random(0, 0xFFFFFF)),
		timestamp = ts,
		vendor = currentSession.vendor,
		cart = cart,
		totalCost = totalCost,
		itemCount = #cart,
		weekday = weekday,
		hour = hour,
		context = {
			preRaid = preRaid,
			weeklyRestock = false,
			manualPurchase = true,
		},
	}

	table.insert(db.purchaseHistory, record)

	-- Update metadata
	local tel = db.telemetry
	if tel then
		tel.totalPurchases = (tel.totalPurchases or 0) + 1
		tel.totalGoldSpent = (tel.totalGoldSpent or 0) + totalCost
		tel.totalItemsBought = (tel.totalItemsBought or 0) + #cart
	end

	self:RotateHistory()

	ns.Debug(string.format("Telemetry: session finalized (%d items, %.1fg)", #cart, totalCost / 10000))

	currentSession = nil

	-- Trigger background pattern analysis
	self:TriggerAnalysis()
end

function Telemetry:RotateHistory()
	local db = ns.DB
	local maxItems = db.insightSettings and db.insightSettings.maxHistoryItems or 1000
	while #db.purchaseHistory > maxItems do
		table.remove(db.purchaseHistory, 1)
	end
end

function Telemetry:GetPurchaseHistory(filters)
	local db = ns.DB
	if not db.purchaseHistory then return {} end
	if not filters then return db.purchaseHistory end

	local result = {}
	for _, record in ipairs(db.purchaseHistory) do
		local match = true

		if filters.vendor and record.vendor ~= filters.vendor then
			match = false
		end
		if filters.minDate and record.timestamp < filters.minDate then
			match = false
		end
		if filters.maxDate and record.timestamp > filters.maxDate then
			match = false
		end
		if filters.itemId then
			local found = false
			for _, entry in ipairs(record.cart) do
				if entry.itemId == filters.itemId then
					found = true
					break
				end
			end
			if not found then match = false end
		end

		if match then
			table.insert(result, record)
		end
	end

	return result
end

function Telemetry:GetLastPurchase()
	local db = ns.DB
	if not db.purchaseHistory or #db.purchaseHistory == 0 then return nil end
	return db.purchaseHistory[#db.purchaseHistory]
end

function Telemetry:GetCurrentSession()
	return currentSession
end

function Telemetry:TriggerAnalysis()
	local db = ns.DB
	local debounce = db.insightSettings and db.insightSettings.analysisDebounce or 2

	if analysisTimer then
		ns.JobScheduler:Cancel(analysisTimer)
		analysisTimer = nil
	end

	analysisTimer = ns.JobScheduler:Schedule(debounce, function()
		analysisTimer = nil
		if ns.QuantityAnalyzer then ns.QuantityAnalyzer:AnalyzeQuantityPatterns() end
		if ns.CartRecognizer then ns.CartRecognizer:DetectRecurringCarts() end
		if ns.ConsumptionEstimator then ns.ConsumptionEstimator:EstimateConsumption() end
		local db2 = ns.DB
		if db2.telemetry then db2.telemetry.lastAnalysis = time() end
		ns.Debug("Telemetry: background analysis complete")
	end)
end
