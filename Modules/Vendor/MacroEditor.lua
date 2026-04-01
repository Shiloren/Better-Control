local _, ns = ...

-- ============================================================================
-- Modules/Vendor/MacroEditor.lua
-- Editor visual para crear, ver y ejecutar macros de compra.
-- Se abre con L3+R3 (ambos sticks).
-- Fase 11 de la UI Revolucionaria.
-- ============================================================================

local MacroEditor = {}
ns.MacroEditor = MacroEditor

MacroEditor.frame     = nil
MacroEditor.isVisible = false

-- ──────────────────────────────────────────────────────────────────────────────
-- Toggle
-- ──────────────────────────────────────────────────────────────────────────────

function MacroEditor:Toggle()
	if self.isVisible then
		self:Hide()
	else
		self:Show()
	end
end

function MacroEditor:Show()
	if not self.frame then
		self:BuildFrame()
	end
	self:Refresh()
	self.frame:Show()
	self.isVisible = true
end

function MacroEditor:Hide()
	if self.frame then
		self.frame:Hide()
	end
	self.isVisible = false
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Construcción del frame
-- ──────────────────────────────────────────────────────────────────────────────

function MacroEditor:BuildFrame()
	local Factory = ns.FrameFactory
	local frame = CreateFrame("Frame", "BCMacroEditor", UIParent, "BasicFrameTemplate")
	frame:SetSize(480, 380)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)

	-- Título
	if frame.TitleText then
		frame.TitleText:SetText("Macro Editor")
	end

	-- Botón cerrar custom (por si BasicFrameTemplate no lo tiene)
	frame:SetScript("OnHide", function()
		self.isVisible = false
	end)

	-- ── Panel izquierdo: lista de macros ──────────────────────────────────────
	local listPanel = CreateFrame("Frame", nil, frame)
	listPanel:SetSize(180, 310)
	listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -30)

	local listBg = listPanel:CreateTexture(nil, "BACKGROUND")
	listBg:SetAllPoints()
	listBg:SetColorTexture(0.05, 0.05, 0.08, 0.9)

	local listLabel = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	listLabel:SetPoint("TOPLEFT", 6, -6)
	listLabel:SetText("Macros guardados")
	listLabel:SetTextColor(0.7, 0.7, 0.7)

	-- ScrollFrame para la lista
	local scroll = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
	scroll:SetSize(160, 260)
	scroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -22)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scrollChild:SetSize(155, 1)
	scroll:SetScrollChild(scrollChild)

	frame.macroListScroll = scroll
	frame.macroListChild  = scrollChild
	frame.macroRows        = {}

	-- ── Panel derecho: detalle / acciones ────────────────────────────────────
	local detailPanel = CreateFrame("Frame", nil, frame)
	detailPanel:SetSize(270, 310)
	detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 6, 0)

	local detailBg = detailPanel:CreateTexture(nil, "BACKGROUND")
	detailBg:SetAllPoints()
	detailBg:SetColorTexture(0.05, 0.05, 0.08, 0.9)

	-- Nombre del macro seleccionado
	frame.detailName = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.detailName:SetPoint("TOPLEFT", 8, -8)
	frame.detailName:SetText("Selecciona un macro")
	frame.detailName:SetTextColor(1, 1, 1)

	frame.detailDesc = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.detailDesc:SetPoint("TOPLEFT", 8, -28)
	frame.detailDesc:SetText("")
	frame.detailDesc:SetTextColor(0.7, 0.7, 0.7)

	-- Lista de pasos
	frame.detailSteps = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.detailSteps:SetPoint("TOPLEFT", 8, -48)
	frame.detailSteps:SetSize(250, 200)
	frame.detailSteps:SetJustifyH("LEFT")
	frame.detailSteps:SetJustifyV("TOP")
	frame.detailSteps:SetText("")
	frame.detailSteps:SetTextColor(0.85, 0.85, 0.85)

	-- Stats
	frame.detailStats = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.detailStats:SetPoint("BOTTOMLEFT", detailPanel, "BOTTOMLEFT", 8, 38)
	frame.detailStats:SetText("")
	frame.detailStats:SetTextColor(0.6, 0.8, 0.6)

	-- ── Botones de acción ─────────────────────────────────────────────────────

	-- Botón Ejecutar
	local btnRun = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	btnRun:SetSize(100, 26)
	btnRun:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
	btnRun:SetText("Ejecutar")
	btnRun:SetScript("OnClick", function()
		local macro = self.selectedMacro
		if macro and ns.MacroSystem then
			ns.MacroSystem:Play(macro.macroId)
			self:Hide()
		end
	end)
	frame.btnRun = btnRun

	-- Botón Nuevo
	local btnNew = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	btnNew:SetSize(80, 26)
	btnNew:SetPoint("LEFT", btnRun, "RIGHT", 6, 0)
	btnNew:SetText("Nuevo")
	btnNew:SetScript("OnClick", function()
		if ns.MacroSystem then
			ns.MacroSystem:StartRecording("Macro " .. (date("%H:%M")))
			self:Hide()
		end
	end)

	-- Botón Eliminar
	local btnDelete = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	btnDelete:SetSize(80, 26)
	btnDelete:SetPoint("LEFT", btnNew, "RIGHT", 6, 0)
	btnDelete:SetText("Eliminar")
	btnDelete:SetScript("OnClick", function()
		local macro = self.selectedMacro
		if macro and ns.MacroSystem then
			ns.MacroSystem:DeleteMacro(macro.macroId)
			self.selectedMacro = nil
			self:Refresh()
		end
	end)

	-- Botón Cerrar
	local btnClose = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	btnClose:SetSize(70, 26)
	btnClose:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
	btnClose:SetText("Cerrar")
	btnClose:SetScript("OnClick", function() self:Hide() end)

	self.frame        = frame
	self.selectedMacro = nil
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Refrescar lista de macros
-- ──────────────────────────────────────────────────────────────────────────────

function MacroEditor:Refresh()
	if not self.frame then return end

	local macros = ns.MacroSystem and ns.MacroSystem:GetAllMacros() or {}

	-- Limpiar filas anteriores
	for _, row in ipairs(self.frame.macroRows) do
		row:Hide()
		row:SetParent(nil)
	end
	self.frame.macroRows = {}

	local child  = self.frame.macroListChild
	local rowH   = 28

	for i, macro in ipairs(macros) do
		local row = CreateFrame("Button", nil, child)
		row:SetSize(150, rowH - 2)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)

		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.1, 0.1, 0.12, 0.8)

		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(0.2, 0.4, 0.8, 0.4)

		local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		lbl:SetPoint("LEFT", 6, 0)
		lbl:SetText(macro.name)
		lbl:SetWidth(140)

		local capturedMacro = macro
		row:SetScript("OnClick", function()
			self.selectedMacro = capturedMacro
			self:RefreshDetail(capturedMacro)
		end)

		table.insert(self.frame.macroRows, row)
	end

	child:SetHeight(math.max(#macros * rowH, 10))

	-- Actualizar detalle si hay uno seleccionado
	if self.selectedMacro then
		self:RefreshDetail(self.selectedMacro)
	else
		self.frame.detailName:SetText("Selecciona un macro")
		self.frame.detailDesc:SetText("")
		self.frame.detailSteps:SetText("")
		self.frame.detailStats:SetText("")
	end
end

function MacroEditor:RefreshDetail(macro)
	if not self.frame or not macro then return end

	self.frame.detailName:SetText(macro.name)
	self.frame.detailDesc:SetText(macro.description or "")

	-- Listar pasos
	local lines = {}
	for i, step in ipairs(macro.steps or {}) do
		local desc = ""
		if step.type == "loadCart"  then desc = "Cargar carrito: " .. (step.cartId or "?")
		elseif step.type == "execute" then desc = "Ejecutar: "     .. (step.action or "?")
		elseif step.type == "wait"    then desc = "Esperar: "      .. (step.duration or 1) .. "s"
		elseif step.type == "notify"  then desc = "Notificar: "    .. (step.message or "")
		else desc = step.type end
		table.insert(lines, i .. ". " .. desc)
	end
	self.frame.detailSteps:SetText(table.concat(lines, "\n"))

	self.frame.detailStats:SetText(string.format(
		"Usos: %d  |  Ultimo: %s",
		macro.useCount or 0,
		macro.lastUsed and macro.lastUsed > 0 and date("%d/%m %H:%M", macro.lastUsed) or "Nunca"
	))
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Inicialización
-- ──────────────────────────────────────────────────────────────────────────────

function MacroEditor:OnAddonLoaded()
	-- El frame se crea bajo demanda la primera vez que se abre
end

ns.RegisterModule("MacroEditor", MacroEditor)
