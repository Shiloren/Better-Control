-- Core\Compat.lua
-- Capa de compatibilidad para WoW Midnight (12.0.0+) y versiones anteriores

local _, ns = ...
local Compat = {}
ns.Compat = Compat

-- 1. Funciones de Comercio (Merchant / Vendor)
-- Blizzard movió estas funciones globales a C_MerchantFrame en la versión 12.0.0 (Midnight)

function Compat.GetNumItems()
	if C_MerchantFrame and C_MerchantFrame.GetNumItems then
		return C_MerchantFrame.GetNumItems()
	elseif GetMerchantNumItems then
		return GetMerchantNumItems()
	end
	return 0
end

function Compat.GetItemInfo(index)
	local result
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		result = C_MerchantFrame.GetItemInfo(index)
		if type(result) == "table" then
			if not Compat.modeLogged then
				ns.Debug("API Mode: C_MerchantFrame (Table)")
				Compat.modeLogged = true
			end
			return result
		end
	end

	-- Fallback: If result exists but isn't a table, it likely returned multiple values 
	-- and we only captured the first one. We re-fetch with legacy global to be safe.
	local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost = (GetMerchantItemInfo(index))
	if not name then return nil end
	
	if not Compat.modeLogged then
		ns.Debug("API Mode: Legacy Globals (Multi-return)")
		Compat.modeLogged = true
	end

	return {
		name = name,
		texture = texture,
		price = price,
		stackCount = stackCount,
		numAvailable = numAvailable,
		isPurchasable = isPurchasable,
		isUsable = isUsable,
		hasExtendedCost = hasExtendedCost
	}
end

function Compat.GetItemLink(index)
	if C_MerchantFrame and C_MerchantFrame.GetItemLink then
		return C_MerchantFrame.GetItemLink(index)
	elseif GetMerchantItemLink then
		return GetMerchantItemLink(index)
	end
end

function Compat.BuyItem(index, quantity)
	if C_MerchantFrame and C_MerchantFrame.BuyItem then
		C_MerchantFrame.BuyItem(index, quantity)
	elseif BuyMerchantItem then
		BuyMerchantItem(index, quantity)
	end
end

function Compat.GetItemMaxStack(index)
	if C_MerchantFrame and C_MerchantFrame.GetItemMaxStack then
		return C_MerchantFrame.GetItemMaxStack(index)
	elseif GetMerchantItemMaxStack then
		return GetMerchantItemMaxStack(index)
	end
	return 1
end

function Compat.GetItemCostInfo(index)
	if C_MerchantFrame and C_MerchantFrame.GetItemCostInfo then
		return C_MerchantFrame.GetItemCostInfo(index)
	elseif GetMerchantItemCostInfo then
		return GetMerchantItemCostInfo(index)
	end
	return 0
end

function Compat.GetItemCostItem(index, costIndex)
	if C_MerchantFrame and C_MerchantFrame.GetItemCostItem then
		return C_MerchantFrame.GetItemCostItem(index, costIndex)
	elseif GetMerchantItemCostItem then
		return GetMerchantItemCostItem(index, costIndex)
	end
end

function Compat.CanAffordItem(index)
	if C_MerchantFrame and C_MerchantFrame.CanAffordItem then
		return C_MerchantFrame.CanAffordItem(index)
	elseif CanAffordMerchantItem then
		return CanAffordMerchantItem(index)
	end
	return true
end

-- 2. Funciones de Buyback (Recuperar)
function Compat.GetNumBuybackItems()
	if C_MerchantFrame and C_MerchantFrame.GetNumBuybackItems then
		return C_MerchantFrame.GetNumBuybackItems()
	elseif GetNumBuybackItems then
		return GetNumBuybackItems()
	end
	return 0
end

function Compat.GetBuybackItemInfo(index)
	if C_MerchantFrame and C_MerchantFrame.GetBuybackItemInfo then
		local result = C_MerchantFrame.GetBuybackItemInfo(index)
		if result then
			return result
		end
	elseif GetBuybackItemInfo then
		local name, texture, price, quantity, numAvailable, isUsable, isBound = GetBuybackItemInfo(index)
		if not name then return nil end
		return {
			name = name,
			texture = texture,
			price = price,
			quantity = quantity,
			numAvailable = numAvailable,
			isUsable = isUsable,
			isBound = isBound
		}
	end
end

function Compat.GetBuybackItemLink(index)
	if C_MerchantFrame and C_MerchantFrame.GetBuybackItemLink then
		return C_MerchantFrame.GetBuybackItemLink(index)
	elseif GetBuybackItemLink then
		return GetBuybackItemLink(index)
	end
end

function Compat.BuybackItem(index)
	if C_MerchantFrame and C_MerchantFrame.BuybackItem then
		C_MerchantFrame.BuybackItem(index)
	elseif BuybackMerchantItem then
		BuybackMerchantItem(index)
	end
end

-- 3. Visual Semantics Helpers
function Compat.GetItemQualityColor(quality)
	local q = tonumber(quality) or 1
	
	-- Internal helper to extract RGB from various WoW color formats
	local function extract(c)
		if not c then return nil end
		if type(c.GetRGB) == "function" then
			local r, g, b = c:GetRGB()
			if r and g and b then return r, g, b end
		elseif type(c) == "table" and c.r and c.g and c.b then
			return c.r, c.g, c.b
		end
		return nil
	end

	-- 1. Try C_Item (Retail 9.0+)
	if C_Item and C_Item.GetItemQualityColor then
		local r, g, b = extract(C_Item.GetItemQualityColor(q))
		if r then return r, g, b end
	end

	-- 2. Fallback to global table ITEM_QUALITY_COLORS
	if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
		local r, g, b = extract(ITEM_QUALITY_COLORS[q])
		if r then return r, g, b end
	end

	-- 3. Hardcoded fallbacks for standard qualities if everything else fails
	local fallbacks = {
		[0] = {0.62, 0.62, 0.62}, -- Poor
		[1] = {1, 1, 1},          -- Common
		[2] = {0.12, 1, 0},       -- Uncommon
		[3] = {0, 0.44, 0.87},    -- Rare
		[4] = {0.64, 0.21, 0.93}, -- Epic
		[5] = {1, 0.5, 0},        -- Legendary
	}
	local f = fallbacks[q]
	if f then return f[1], f[2], f[3] end

	-- Ultimate fallback (White)
	return 1, 1, 1
end

function Compat.IsConsumable(itemInfo)
	if not itemInfo then return false end
	
	-- 1. Fast path: Direct property check
	if type(itemInfo) == "table" then
		if itemInfo.classID == (Enum.ItemClass.Consumable or 0) then return true end
		if itemInfo.isConsumable == true then return true end
	end

	-- 2. Identification path: hyperlink or ID
	local identifier
	if type(itemInfo) == "table" then
		identifier = itemInfo.itemLink or itemInfo.itemID
	elseif type(itemInfo) == "string" or type(itemInfo) == "number" then
		identifier = itemInfo
	end

	if not identifier then return false end

	-- 3. Resolve using WoW APIs with safety checks
	-- Attempt C_Item.GetItemInfoInstant first (Synchronous, does not wait for cache)
	if C_Item and C_Item.GetItemInfoInstant then
		local ok, info = pcall(C_Item.GetItemInfoInstant, identifier)
		if ok and info and info.classID == (Enum.ItemClass.Consumable or 0) then
			return true
		end
	end

	-- Fallback to legacy GetItemInfo (Asynchronous/Cache-dependent)
	local ok, _, _, _, _, _, _, _, _, _, _, _, classID = pcall(GetItemInfo, identifier)
	if ok and classID == (Enum.ItemClass.Consumable or 0) then
		return true
	end

	return false
end

-- 4. Otras utilidades
if not GetMoneyString then
	_G.GetMoneyString = function(amount, separateThousands)
		return GetCoinTextureString(amount)
	end
end

return Compat
