local _, ns = ...

local ConsumptionEstimator = {}
ns.ConsumptionEstimator = ConsumptionEstimator

function ConsumptionEstimator:EstimateConsumption()
	local db = ns.DB
	if not db or not db.quantityPatterns then return end
	if not db.consumptionRates then db.consumptionRates = {} end

	local now = time()

	for itemId, pattern in pairs(db.quantityPatterns) do
		if pattern.avgDaysBetween and pattern.avgDaysBetween > 0 and pattern.typical > 0 then
			local avgPerDay = pattern.typical / pattern.avgDaysBetween
			local daysSince = (now - (pattern.lastPurchase or now)) / 86400
			local estConsumed = avgPerDay * daysSince
			local estRemaining = math.max(0, pattern.typical - estConsumed)
			local needsRestock = estRemaining < (pattern.typical * 0.3)

			-- Reduce confidence if pattern is stale (>3 cycles old)
			local confidence = pattern.confidence
			if daysSince > pattern.avgDaysBetween * 3 then
				confidence = confidence * 0.5
			end

			db.consumptionRates[itemId] = {
				itemName = pattern.itemName,
				avgConsumptionPerDay = avgPerDay,
				lastStockLevel = pattern.typical,
				lastStockDate = pattern.lastPurchase,
				daysSinceLastPurchase = daysSince,
				estimatedConsumed = math.min(estConsumed, pattern.typical),
				estimatedRemaining = estRemaining,
				needsRestock = needsRestock,
				confidence = confidence,
			}
		end
	end
end

-- Returns a restock info table or nil if no restock needed / insufficient data
function ConsumptionEstimator:GetRestockMessage(itemId)
	local db = ns.DB
	if not db then return nil end

	local rate = db.consumptionRates and db.consumptionRates[itemId]
	if not rate then return nil end
	if not rate.needsRestock then return nil end
	if rate.confidence < 0.5 then return nil end

	local pattern = db.quantityPatterns and db.quantityPatterns[itemId]
	if not pattern then return nil end

	local remaining = math.floor(rate.estimatedRemaining)
	local days = math.floor(rate.daysSinceLastPurchase)
	local suggested = math.floor(pattern.typical)

	local ratio = pattern.typical > 0 and (rate.estimatedRemaining / pattern.typical) or 0
	local severity
	if ratio < 0.3 then
		severity = "high"
	elseif ratio < 0.5 then
		severity = "medium"
	else
		severity = "low"
	end

	local message
	if remaining <= 0 then
		message = string.format("Est. ~0 remaining (bought %d, %dd ago)", suggested, days)
	else
		message = string.format("Est. ~%d remaining (bought %d, %dd ago)", remaining, suggested, days)
	end

	return {
		severity = severity,
		message = message,
		suggestedQuantity = suggested,
		estimatedRemaining = remaining,
	}
end
