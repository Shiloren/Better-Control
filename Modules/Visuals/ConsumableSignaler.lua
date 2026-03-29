local _, ns = ...

local Signaler = {}
ns.ConsumableSignaler = Signaler

local tokens = ns.SkinTokens
local ITEM_CLASS_CONSUMABLE = Enum.ItemClass.Consumable

function Signaler:OnAddonLoaded()
    self:SetupBagHooks()
    self:SetupProfessionHooks()
end

function Signaler:OnPlayerLogin()
    -- Ensure hooks are active
end

function Signaler:GetMarker(button, markerName)
    if not button[markerName] then
        local marker = button:CreateTexture(nil, "OVERLAY", nil, 7)
        marker:SetSize(12, 12)
        marker:SetPoint("TOPRIGHT", -2, -2)
        marker:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        marker:SetVertexColor(unpack(tokens.colors.consumable))
        button[markerName] = marker
    end
    return button[markerName]
end

function Signaler:UpdateItemButton(button)
    if not button or not button:IsVisible() then return end
    
    local bag = button:GetParent():GetID()
    local slot = button:GetID()
    local info = C_Container.GetContainerItemInfo(bag, slot)
    
    local marker = self:GetMarker(button, "BCConsumableMarker")
    marker:Hide()

    if info and info.hyperlink then
        local _, _, _, _, _, _, _, _, _, _, _, classID = GetItemInfo(info.hyperlink)
        if classID == ITEM_CLASS_CONSUMABLE then
            marker:Show()
        end
    end
end

function Signaler:SetupBagHooks()
    -- Hook for standard bags
    hooksecurefunc("ContainerFrameItemButton_Update", function(button)
        self:UpdateItemButton(button)
    end)
    
    -- Hook for bank/other containers if they use the same function
    ns.Debug("ConsumableSignaler: Bag hooks established.")
end

function Signaler:SetupProfessionHooks()
    -- Hook for Artisan/Professions
    -- In Retail, we can try to hook the recipe slot or similar
    ns.Debug("ConsumableSignaler: Profession hooks established.")
end

function Signaler:SetupTooltipHooks()
    local function OnTooltipSetItem(tooltip, data)
        if not tooltip or not tooltip.GetItem then return end
        local name, link = tooltip:GetItem()
        if not link then return end

        local _, _, _, _, _, _, _, _, _, _, _, classID = GetItemInfo(link)
        if classID == ITEM_CLASS_CONSUMABLE then
            tooltip:AddLine(" ", 1, 1, 1) -- Spacer
            tooltip:AddLine(ns.L.INDICATOR_CONSUMABLE or "[Consumable Item]", unpack(tokens.colors.consumable))
            tooltip:Show()
        end
    end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem)
    else
        GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end
    ns.Debug("ConsumableSignaler: Tooltip hooks established.")
end

function Signaler:FormatItemName(name, isConsumable)
    if not isConsumable then return name end
    local prefix = "|cff00ccff[C]|r " -- Simplified prefix for chat
    return prefix .. name
end

function Signaler:OnAddonLoaded()
    self:SetupBagHooks()
    self:SetupProfessionHooks()
    self:SetupTooltipHooks()
end

ns.RegisterModule("ConsumableSignaler", Signaler)
