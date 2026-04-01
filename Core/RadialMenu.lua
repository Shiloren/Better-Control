local _, ns = ...

-- ============================================================================
-- Core/RadialMenu.lua
-- Radial menu activado con hold del botón View (Select/Back en gamepad).
-- Navegado con stick derecho, ejecuta acción al soltar.
-- Fase 7 de la UI Revolucionaria.
-- ============================================================================

local RadialMenu = {}
ns.RadialMenu = RadialMenu

-- Secciones del menú radial (5 opciones equidistantes)
local MENU_SECTIONS = {
	{ angle = 0,   name = "Carrito",   icon = "C", action = "openCart" },
	{ angle = 72,  name = "Favoritos", icon = "F", action = "openFavorites" },
	{ angle = 144, name = "Historial", icon = "H", action = "openHistory" },
	{ angle = 216, name = "Filtros",   icon = "B", action = "openFilters" },
	{ angle = 288, name = "Ajustes",   icon = "A", action = "openSettings" },
}

-- Estado
RadialMenu.isOpen         = false
RadialMenu.selectedSection = nil
RadialMenu.holdStartTime  = 0
RadialMenu.frame          = nil

-- ──────────────────────────────────────────────────────────────────────────────
-- Activación por hold del botón View/Select (PADBACK)
-- ──────────────────────────────────────────────────────────────────────────────

function RadialMenu:OnViewButtonDown()
	self.holdStartTime = GetTime()
	C_Timer.After(0.3, function()
		if self.holdStartTime > 0 then
			self:Open()
		end
	end)
end

function RadialMenu:OnViewButtonUp()
	self.holdStartTime = 0
	if self.isOpen then
		if self.selectedSection then
			self:ExecuteAction(self.selectedSection.section.action)
		end
		self:Close()
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Abrir / Cerrar
-- ──────────────────────────────────────────────────────────────────────────────

function RadialMenu:Open()
	if not self.frame then
		self:CreateFrame()
	end
	self.isOpen = true
	self.selectedSection = nil
	self.frame:Show()
	if self.frame.fadeIn then
		self.frame.fadeIn:Play()
	end
	self.frame:SetScript("OnUpdate", function()
		self:OnStickUpdate()
	end)
end

function RadialMenu:Close()
	self.isOpen = false
	self.selectedSection = nil
	if self.frame then
		self.frame:SetScript("OnUpdate", nil)
		if self.frame.fadeOut then
			self.frame.fadeOut:Play()
		end
		C_Timer.After(0.2, function()
			if self.frame then
				self.frame:Hide()
			end
		end)
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Creación del frame
-- ──────────────────────────────────────────────────────────────────────────────

function RadialMenu:CreateFrame()
	local frame = CreateFrame("Frame", "BCRadialMenu", UIParent)
	frame:SetSize(400, 400)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:Hide()

	-- Fondo semitransparente
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.65)

	-- Círculo central (indicador neutro)
	local center = CreateFrame("Frame", nil, frame)
	center:SetSize(70, 70)
	center:SetPoint("CENTER")

	local centerBg = center:CreateTexture(nil, "ARTWORK")
	centerBg:SetAllPoints()
	centerBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

	local centerLabel = center:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	centerLabel:SetPoint("CENTER")
	centerLabel:SetText("VIEW")
	centerLabel:SetTextColor(0.8, 0.8, 0.8)

	-- Secciones
	frame.sections = {}
	for i, section in ipairs(MENU_SECTIONS) do
		local btn = self:CreateSection(frame, section, i)
		table.insert(frame.sections, btn)
	end

	-- Animación fade in
	local fadeIn = frame:CreateAnimationGroup()
	local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
	fadeInAlpha:SetFromAlpha(0)
	fadeInAlpha:SetToAlpha(1)
	fadeInAlpha:SetDuration(0.15)
	frame.fadeIn = fadeIn

	-- Animación fade out
	local fadeOut = frame:CreateAnimationGroup()
	local fadeOutAlpha = fadeOut:CreateAnimation("Alpha")
	fadeOutAlpha:SetFromAlpha(1)
	fadeOutAlpha:SetToAlpha(0)
	fadeOutAlpha:SetDuration(0.15)
	frame.fadeOut = fadeOut

	self.frame = frame
end

function RadialMenu:CreateSection(parent, section, index)
	local btn = CreateFrame("Frame", nil, parent)
	btn:SetSize(90, 90)

	-- Posición en círculo (radio 140px), 0° = arriba
	local radius    = 140
	local angleRad  = math.rad(section.angle - 90)
	local x         = radius * math.cos(angleRad)
	local y         = radius * math.sin(angleRad)
	btn:SetPoint("CENTER", parent, "CENTER", x, y)

	-- Fondo normal
	btn.bg = btn:CreateTexture(nil, "BACKGROUND")
	btn.bg:SetAllPoints()
	btn.bg:SetColorTexture(0.08, 0.08, 0.08, 0.85)

	-- Highlight de selección
	btn.highlight = btn:CreateTexture(nil, "BORDER")
	btn.highlight:SetAllPoints()
	btn.highlight:SetColorTexture(0.25, 0.45, 0.95, 0.55)
	btn.highlight:Hide()

	-- Ícono (letra representativa)
	btn.icon = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	btn.icon:SetPoint("CENTER", 0, 12)
	btn.icon:SetText(section.icon)

	-- Etiqueta
	btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	btn.label:SetPoint("CENTER", 0, -18)
	btn.label:SetText(section.name)
	btn.label:SetTextColor(0.9, 0.9, 0.9)

	btn.section = section
	return btn
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Tracking del stick (o mouse en modo testing)
-- ──────────────────────────────────────────────────────────────────────────────

function RadialMenu:OnStickUpdate()
	if not self.isOpen or not self.frame then return end

	local centerX, centerY = self.frame:GetCenter()
	if not centerX then return end

	local dx, dy

	-- Intentar usar input de gamepad stick si está disponible
	if GetGamePadAnalogInput then
		local rx = GetGamePadAnalogInput("PADRSTICKRIGHT") or 0
		local ry = GetGamePadAnalogInput("PADRSTICKUP")    or 0
		if math.abs(rx) > 0.2 or math.abs(ry) > 0.2 then
			dx = rx
			dy = ry
		end
	end

	-- Fallback a mouse para testing en modo escritorio
	if not dx then
		local scale    = UIParent:GetEffectiveScale()
		local mx, my   = GetCursorPosition()
		dx = mx / scale - centerX
		dy = my / scale - centerY
	end

	local distance = math.sqrt(dx * dx + dy * dy)
	if distance < 35 then
		self:SetSelectedSection(nil)
		return
	end

	-- Ángulo en grados (0° = arriba)
	local angle = math.deg(math.atan2(dy, dx)) + 90
	if angle < 0 then angle = angle + 360 end

	-- Sección más cercana por ángulo
	local closestBtn = nil
	local minDiff    = 999

	for _, btn in ipairs(self.frame.sections) do
		local sectionAngle = btn.section.angle
		local diff = math.abs(angle - sectionAngle)
		if diff > 180 then diff = 360 - diff end
		if diff < minDiff then
			minDiff    = diff
			closestBtn = btn
		end
	end

	self:SetSelectedSection(closestBtn)
end

function RadialMenu:SetSelectedSection(sectionBtn)
	-- Limpiar selección anterior
	if self.selectedSection and self.selectedSection ~= sectionBtn then
		self.selectedSection.highlight:Hide()
		self.selectedSection.bg:SetColorTexture(0.08, 0.08, 0.08, 0.85)
		self.selectedSection.label:SetTextColor(0.9, 0.9, 0.9)
	end

	self.selectedSection = sectionBtn

	if sectionBtn then
		sectionBtn.highlight:Show()
		sectionBtn.bg:SetColorTexture(0.18, 0.28, 0.5, 0.9)
		sectionBtn.label:SetTextColor(1, 1, 1)

		-- Haptic feedback leve en selección (si ya está implementado)
		if ns.HapticFeedback then
			ns.HapticFeedback:Trigger("selection", 0.08)
		end
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Ejecutar acción
-- ──────────────────────────────────────────────────────────────────────────────

function RadialMenu:ExecuteAction(action)
	local vf = ns.VendorFrame
	local sa = ns.SmartActions

	if action == "openCart" then
		if vf and vf.ShowCart then
			vf:ShowCart()
		end
	elseif action == "openFavorites" then
		if vf then
			vf:SwitchTab("favorites")
		end
	elseif action == "openHistory" then
		if sa and sa.ShowHistoryMenu then
			sa:ShowHistoryMenu()
		end
	elseif action == "openFilters" then
		if vf and vf.ShowFiltersMenu then
			vf:ShowFiltersMenu()
		end
	elseif action == "openSettings" then
		if vf and vf.ShowSettings then
			vf:ShowSettings()
		end
	end

	-- Haptic de confirmación
	if ns.HapticFeedback then
		ns.HapticFeedback:Trigger("confirm", 0.2)
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Integración con InputAdapter: detectar PADBACK hold/release
-- ──────────────────────────────────────────────────────────────────────────────

function RadialMenu:OnAddonLoaded()
	-- Escuchar eventos de botón del gamepad a través de un frame dedicado
	local listener = CreateFrame("Frame")
	listener:EnableGamePadButton(true)

	listener:SetScript("OnGamePadButtonDown", function(_, button)
		if button == "PADBACK" then
			self:OnViewButtonDown()
		end
	end)

	listener:SetScript("OnGamePadButtonUp", function(_, button)
		if button == "PADBACK" then
			self:OnViewButtonUp()
		end
	end)
end

ns.RegisterModule("RadialMenu", RadialMenu)
