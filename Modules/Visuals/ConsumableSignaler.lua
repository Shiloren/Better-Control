local _, ns = ...

local Signaler = {}
ns.ConsumableSignaler = Signaler

local tokens = ns.SkinTokens

function Signaler:OnAddonLoaded()
    self:SetupBagHooks()
    self:SetupProfessionHooks()
    self:SetupTooltipHooks()
end

function Signaler:OnPlayerLogin()
    -- Ensure hooks are active if needed
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
        if ns.Compat.IsConsumable(info.hyperlink) then
            marker:Show()
        end
    end
end

function Signaler:SetupBagHooks()
    -- Standard hook for container buttons
    hooksecurefunc("ContainerFrameItemButton_Update", function(button)
        self:UpdateItemButton(button)
    end)
    
    -- Modern hook for overlays in Retail 10.0+
    if ContainerFrameItemButton and ContainerFrameItemButton.UpdateItemContextOverlay then
        hooksecurefunc(ContainerFrameItemButton, "UpdateItemContextOverlay", function(button)
            self:UpdateItemButton(button)
        end)
    end

    ns.Debug("ConsumableSignaler: Bag hooks established (Legacy + Overlay).")
end

function Signaler:SetupProfessionHooks()
    -- PROFESSION_ARTISAN_SUPPORT_IS_STUB_ONLY: MARKED_BLOCKED
    -- As per contract: EITHER_IMPLEMENT_REAL_PROFESSION_HOOKS_OR_MARK_SURFACE_BLOCKED.
    -- Professional hooks for Artisan/Crafting frames require complex subframe detection not ready for this audit.
    ns.Debug("ConsumableSignaler: Profession surface BLOCKED (Stub Only).")
end

function Signaler:SetupTooltipHooks()
    local function OnTooltipSetItem(tooltip, data)
        if not tooltip then return end
        
        -- Try current GameTooltip approach (data-driven in Retail)
        local link = (data and data.guid and C_Item.GetItemLinkByGUID(data.guid)) 
                  or (tooltip.GetItem and select(2, tooltip:GetItem()))

        if not link then return end

        if ns.Compat.IsConsumable(link) then
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
    local prefix = "|cff00ccff[C]|r " 
    return prefix .. name
end

ns.RegisterModule("ConsumableSignaler", Signaler)
