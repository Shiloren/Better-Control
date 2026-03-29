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

-- 3. Otras utilidades
if not GetMoneyString then
	_G.GetMoneyString = function(amount, separateThousands)
		return GetCoinTextureString(amount)
	end
end

return Compat
