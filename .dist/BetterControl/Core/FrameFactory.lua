local _, ns = ...

local Factory = {}
ns.FrameFactory = Factory

local tokens = ns.SkinTokens

local function setColor(texture, color)
	texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

function Factory.CreateMainFrame(name, parent, title)
	local frame = CreateFrame("Frame", name, parent, "ButtonFrameTemplate")
	frame:SetSize(tokens.frame.width, tokens.frame.height)
	frame.TitleText:SetText(title)

	local portrait = frame.portrait or (frame.PortraitContainer and frame.PortraitContainer.portrait)
	if portrait then
		portrait:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
	end

	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetFrameStrata("HIGH")
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	if name and UISpecialFrames then
		tinsert(UISpecialFrames, name)
	end

	return frame
end

function Factory.CreateInset(parent, width, height)
	local panel = CreateFrame("Frame", nil, parent, "InsetFrameTemplate3")
	panel:SetSize(width, height)
	return panel
end

function Factory.CreateButton(parent, text, width, height)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 110, height or 22)
	button:SetText(text)
	return button
end

function Factory.CreateTab(parent, id, text, name)
	local button = CreateFrame("Button", name, parent, "PanelTopTabButtonTemplate")
	button:SetID(id)
	button:SetText(text)
	PanelTemplates_TabResize(button, 0)
	return button
end

function Factory.CreateRow(parent, width, height)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(width, height)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

	row.background = row:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()
	setColor(row.background, tokens.colors.row)

	row.selected = row:CreateTexture(nil, "BORDER")
	row.selected:SetAllPoints()
	setColor(row.selected, tokens.colors.rowActive)
	row.selected:Hide()

	row.iconBorder = CreateFrame("Frame", nil, row, "BackdropTemplate")
	row.iconBorder:SetPoint("LEFT", 8, 0)
	row.iconBorder:SetSize(tokens.list.icon + 6, tokens.list.icon + 6)
	row.iconBorder:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 10,
		bgFile = "Interface\\Buttons\\WHITE8X8",
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	row.iconBorder:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
	row.iconBorder:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.8)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetPoint("CENTER", row.iconBorder)
	row.icon:SetSize(tokens.list.icon, tokens.list.icon)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.name:SetPoint("TOPLEFT", row.iconBorder, "TOPRIGHT", 10, -2)
	row.name:SetPoint("RIGHT", row, -120, 0)
	row.name:SetJustifyH("LEFT")

	row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.meta:SetPoint("RIGHT", row, -120, 0)
	row.meta:SetJustifyH("LEFT")

	row.stock = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.stock:SetPoint("RIGHT", row, -12, 8)
	row.stock:SetJustifyH("RIGHT")

	row.price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.price:SetPoint("RIGHT", row, -12, -8)
	row.price:SetJustifyH("RIGHT")

	return row
end

function Factory.SetRowSelected(row, isSelected)
	if isSelected then
		row.selected:Show()
	else
		row.selected:Hide()
	end
end

function Factory.FormatMoney(value)
	if not value or value <= 0 then
		return FREE or "Free"
	end

	return GetMoneyString(value, true)
end

function Factory.SetFontColor(fontString, color)
	if color and color.GetRGBA then
		fontString:SetTextColor(color:GetRGBA())
		return
	end

	fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function Factory.CreateFooter(parent)
	local footer = CreateFrame("Frame", nil, parent, "InsetFrameTemplate3")
	footer:SetHeight(42)
	return footer
end

function Factory.CreateHint(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(112, 18)

	frame.key = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.key:SetPoint("LEFT", 8, 0)
	frame.key:SetJustifyH("LEFT")

	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.text:SetPoint("LEFT", frame.key, "RIGHT", 6, 0)
	frame.text:SetPoint("RIGHT", -8, 0)
	frame.text:SetJustifyH("LEFT")

	return frame
end
