local _, ns = ...

local QuantityAnalyzer = {}
ns.QuantityAnalyzer = QuantityAnalyzer

local function calculateMedian(values)
	if #values == 0 then return 0 end
	local sorted = {}
	for _, v in ipairs(values) do table.insert(sorted, v) end
	table.sort(sorted)
	local n = #sorted
	if n % 2 == 0 then
		return (sorted[n / 2] + sorted[n / 2 + 1]) / 2
	else
		return sorted[math.ceil(n / 2)]
	end
end

local function calculateMean(values)
	if #values == 0 then return 0 end
	local sum = 0
	for _, v in ipairs(values) do sum = sum + v end
	return sum / #values
end

local function calculateStdDev(values, mean)
	if #values < 2 then return 0 end
	local sum = 0
	for _, v in ipairs(values) do
		sum = sum + (v - mean) ^ 2
	end
	return math.sqrt(sum / #values)
end

function QuantityAnalyzer:AnalyzeQuantityPatterns()
	local db = ns.DB
	if not db or not db.purchaseHistory then return end

	-- Collect quantities and timestamps per itemId
	local itemData = {}
	for _, record in ipairs(db.purchaseHistory) do
		for _, entry in ipairs(record.cart) do
			local id = entry.itemId
			if id and id > 0 then
				if not itemData[id] then
					itemData[id] = {
						name = entry.itemName,
						quantities = {},
						timestamps = {},
					}
				end
				table.insert(itemData[id].quantities, entry.quantity)
				table.insert(itemData[id].timestamps, record.timestamp)
			end
		end
	end

	local settings = db.insightSettings
	local minOccurrences = settings and settings.minOccurrencesForPattern or 3

	if not db.quantityPatterns then db.quantityPatterns = {} end

	for itemId, data in pairs(itemData) do
		if #data.quantities >= minOccurrences then
			local quantities = data.quantities
			local timestamps = data.timestamps

			local median = calculateMedian(quantities)
			local mean = calculateMean(quantities)
			local stdDev = calculateStdDev(quantities, mean)

			-- Confidence via Coefficient of Variation: low CV → high confidence
			local cv = mean > 0 and (stdDev / mean) or 1
			local confidence = math.max(0, 1 - math.min(cv, 1))

			-- Average days between purchases
			local totalDays = 0
			local dayCount = 0
			for i = 2, #timestamps do
				totalDays = totalDays + (timestamps[i] - timestamps[i - 1]) / 86400
				dayCount = dayCount + 1
			end
			local avgDaysBetween = dayCount > 0 and (totalDays / dayCount) or 7

			-- Keep only last 10 quantities for storage
			local recentQties = {}
			local startIdx = math.max(1, #quantities - 9)
			for i = startIdx, #quantities do
				table.insert(recentQties, quantities[i])
			end

			db.quantityPatterns[itemId] = {
				itemName = data.name,
				purchases = recentQties,
				typical = median,
				mean = mean,
				stdDev = stdDev,
				confidence = confidence,
				lastPurchase = timestamps[#timestamps],
				avgDaysBetween = math.max(1, avgDaysBetween),
				totalPurchases = #quantities,
			}
		end
	end
end

function QuantityAnalyzer:GetPattern(itemId)
	local db = ns.DB
	if not db or not db.quantityPatterns then return nil end
	return db.quantityPatterns[itemId]
end

-- Returns suggestion table or nil if no reliable pattern
function QuantityAnalyzer:GetSuggestedQuantity(itemId)
	local pattern = self:GetPattern(itemId)
	if not pattern then return nil end
	if pattern.confidence < 0.6 then return nil end

	local qty = math.floor(pattern.typical)
	if qty <= 0 then return nil end

	return {
		quantity = qty,
		range = {
			min = math.max(1, math.floor(pattern.typical - pattern.stdDev)),
			max = math.ceil(pattern.typical + pattern.stdDev),
		},
		confidence = pattern.confidence,
		message = string.format("Usually buy ~%d (±%d)", qty, math.ceil(pattern.stdDev)),
	}
end
