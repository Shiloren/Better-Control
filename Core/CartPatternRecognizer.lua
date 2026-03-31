local _, ns = ...

local CartRecognizer = {}
ns.CartRecognizer = CartRecognizer

local WEEKDAY_NAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

-- Generate a stable fingerprint for a cart (array of {itemId, quantity})
function CartRecognizer:GenerateCartFingerprint(cart)
	local items = {}
	for _, entry in ipairs(cart) do
		local id = entry.itemId or entry.itemID
		if id and id > 0 then
			-- Bucket quantities to nearest 10 to tolerate small variations
			local qtyBucket = math.floor((entry.quantity or entry.typicalQuantity or 0) / 10) * 10
			table.insert(items, { id = id, qty = qtyBucket })
		end
	end

	table.sort(items, function(a, b) return a.id < b.id end)

	local parts = {}
	for _, item in ipairs(items) do
		table.insert(parts, string.format("%d:%d", item.id, item.qty))
	end

	return table.concat(parts, "|")
end

local function parseFingerprint(fp)
	local set = {}
	for part in fp:gmatch("[^|]+") do
		set[part] = true
	end
	return set
end

local function calculateJaccard(fp1, fp2)
	local set1 = parseFingerprint(fp1)
	local set2 = parseFingerprint(fp2)

	local intersection = 0
	local union = 0

	for k in pairs(set1) do
		if set2[k] then intersection = intersection + 1 end
		union = union + 1
	end
	for k in pairs(set2) do
		if not set1[k] then union = union + 1 end
	end

	if union == 0 then return 0 end
	return intersection / union
end

local function generateCartName(records)
	local weekdayCounts = {}
	local totalConsumables = 0

	for _, record in ipairs(records) do
		local wd = record.weekday or 0
		weekdayCounts[wd] = (weekdayCounts[wd] or 0) + 1
		for _, entry in ipairs(record.cart) do
			if entry.isConsumable then
				totalConsumables = totalConsumables + (entry.quantity or 0)
			end
		end
	end

	-- Find dominant weekday
	local maxCount = 0
	local dominantDay = nil
	for wd, count in pairs(weekdayCounts) do
		if count > maxCount then
			maxCount = count
			dominantDay = wd
		end
	end

	local dominantRatio = maxCount / #records
	local avgConsumables = totalConsumables / #records

	if dominantDay ~= nil and dominantRatio >= 0.8 then
		local dayName = WEEKDAY_NAMES[(dominantDay % 7) + 1]
		if avgConsumables > 100 then
			return dayName .. " Raid Prep"
		else
			return dayName .. " Restock"
		end
	end

	if avgConsumables > 200 then
		return "Raid Night Supplies"
	end

	return "Weekly Restock"
end

function CartRecognizer:DetectRecurringCarts()
	local db = ns.DB
	if not db or not db.purchaseHistory then return end

	local settings = db.insightSettings
	local minOccurrences = settings and settings.minOccurrencesForPattern or 3

	-- Group purchase records by fingerprint
	local groups = {}  -- [fingerprint] = { records = {}, baseCart = {} }
	for _, record in ipairs(db.purchaseHistory) do
		if record.cart and #record.cart > 0 then
			local fp = self:GenerateCartFingerprint(record.cart)
			if fp and fp ~= "" then
				if not groups[fp] then
					groups[fp] = { records = {}, baseCart = record.cart }
				end
				table.insert(groups[fp].records, record)
			end
		end
	end

	if not db.detectedCarts then db.detectedCarts = {} end

	-- Preserve custom names from previous detection
	local customNames = {}
	for _, existing in ipairs(db.detectedCarts) do
		if existing.userNamed and existing.fingerprint then
			customNames[existing.fingerprint] = {
				customName = existing.customName,
				isFavorite = existing.isFavorite or false,
			}
		end
	end

	local newDetected = {}
	for fp, group in pairs(groups) do
		if #group.records >= minOccurrences then
			local records = group.records
			local weekdayCounts = {}
			local hourCounts = {}
			local totalCost = 0
			local lastUsed = 0

			for _, rec in ipairs(records) do
				local wd = rec.weekday or 0
				local hr = rec.hour or 0
				weekdayCounts[wd] = (weekdayCounts[wd] or 0) + 1
				hourCounts[hr] = (hourCounts[hr] or 0) + 1
				totalCost = totalCost + (rec.totalCost or 0)
				if rec.timestamp > lastUsed then lastUsed = rec.timestamp end
			end

			-- Build typical items with median quantities
			local typicalItems = {}
			for _, baseEntry in ipairs(group.baseCart) do
				local quantities = {}
				for _, rec in ipairs(records) do
					for _, entry in ipairs(rec.cart) do
						if entry.itemId == baseEntry.itemId then
							table.insert(quantities, entry.quantity)
							break
						end
					end
				end

				local typicalQty = baseEntry.quantity or baseEntry.typicalQuantity or 1
				if #quantities > 0 then
					table.sort(quantities)
					typicalQty = quantities[math.ceil(#quantities / 2)]
				end

				table.insert(typicalItems, {
					itemId = baseEntry.itemId,
					itemName = baseEntry.itemName,
					typicalQuantity = typicalQty,
				})
			end

			local saved = customNames[fp]
			local autoName = generateCartName(records)

			table.insert(newDetected, {
				cartId = string.format("auto-%d-%d", lastUsed, #group.records),
				name = (saved and saved.customName) or autoName,
				fingerprint = fp,
				items = typicalItems,
				occurrences = #records,
				lastUsed = lastUsed,
				avgCost = totalCost / #records,
				context = {
					weekdays = weekdayCounts,
					hours = hourCounts,
				},
				userNamed = saved ~= nil,
				customName = saved and saved.customName or nil,
				isFavorite = saved and saved.isFavorite or false,
			})
		end
	end

	-- Sort by usage (most used first)
	table.sort(newDetected, function(a, b)
		return a.occurrences > b.occurrences
	end)

	db.detectedCarts = newDetected
end

-- Returns matches sorted by similarity (highest first), each with cart, similarity, missingItems
function CartRecognizer:MatchCurrentCart(currentCart)
	local db = ns.DB
	if not db or not db.detectedCarts or #currentCart == 0 then return {} end

	local currentFP = self:GenerateCartFingerprint(currentCart)
	if currentFP == "" then return {} end

	local matches = {}
	for _, detected in ipairs(db.detectedCarts) do
		local sim = calculateJaccard(currentFP, detected.fingerprint)
		if sim >= 0.7 then
			-- Find items in detected cart missing from current
			local currentIds = {}
			for _, entry in ipairs(currentCart) do
				currentIds[entry.itemId or entry.itemID] = true
			end

			local missing = {}
			for _, item in ipairs(detected.items) do
				if not currentIds[item.itemId] then
					table.insert(missing, item)
				end
			end

			table.insert(matches, {
				cart = detected,
				similarity = sim,
				missingItems = missing,
				message = string.format("%.0f%% similar to '%s'", sim * 100, detected.name),
			})
		end
	end

	table.sort(matches, function(a, b) return a.similarity > b.similarity end)
	return matches
end

-- Returns detected carts relevant to a given weekday (0-6) and hour (0-23)
function CartRecognizer:GetCartsByContext(weekday, hour)
	local db = ns.DB
	if not db or not db.detectedCarts then return {} end

	local scored = {}
	for _, cart in ipairs(db.detectedCarts) do
		local score = 0
		local ctx = cart.context
		if ctx then
			if ctx.weekdays and ctx.weekdays[weekday] then
				score = score + ctx.weekdays[weekday] * 2
			end
			if ctx.hours then
				for h = math.max(0, hour - 2), math.min(23, hour + 2) do
					if ctx.hours[h] then
						score = score + ctx.hours[h]
					end
				end
			end
		end
		if score > 0 then
			table.insert(scored, { cart = cart, score = score })
		end
	end

	table.sort(scored, function(a, b) return a.score > b.score end)

	local result = {}
	for _, item in ipairs(scored) do
		table.insert(result, item.cart)
	end
	return result
end
