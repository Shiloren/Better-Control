local _, ns = ...

-- ============================================================================
-- Core/GestureRecognizer.lua
-- Detecta flicks (movimientos rápidos) de los sticks del gamepad y los
-- mapea a acciones contextuales del vendor.
-- Fase 8 de la UI Revolucionaria.
-- ============================================================================

local GestureRecognizer = {}
ns.GestureRecognizer = GestureRecognizer

-- Configuración
local GESTURE_THRESHOLD = 0.65  -- Magnitud mínima del delta para considerar flick
local COOLDOWN_TIME     = 0.2   -- Segundos entre gestos consecutivos

-- Estado de los sticks
GestureRecognizer.leftStick  = { x = 0, y = 0, lastX = 0, lastY = 0 }
GestureRecognizer.rightStick = { x = 0, y = 0, lastX = 0, lastY = 0 }
GestureRecognizer.lastGesture = 0

-- ──────────────────────────────────────────────────────────────────────────────
-- Loop de detección (OnUpdate)
-- ──────────────────────────────────────────────────────────────────────────────

function GestureRecognizer:OnUpdate()
	local now = GetTime()
	if now - self.lastGesture < COOLDOWN_TIME then return end

	local leftX,  leftY  = self:GetLeftStickPosition()
	local rightX, rightY = self:GetRightStickPosition()

	-- Guardar posición anterior y actualizar
	local ls = self.leftStick
	ls.lastX, ls.lastY = ls.x, ls.y
	ls.x, ls.y         = leftX, leftY

	local rs = self.rightStick
	rs.lastX, rs.lastY = rs.x, rs.y
	rs.x, rs.y         = rightX, rightY

	self:DetectGesture("left",  ls)
	self:DetectGesture("right", rs)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Detección de dirección
-- ──────────────────────────────────────────────────────────────────────────────

function GestureRecognizer:DetectGesture(stickName, stick)
	local dx = stick.x - stick.lastX
	local dy = stick.y - stick.lastY
	local magnitude = math.sqrt(dx * dx + dy * dy)

	if magnitude < GESTURE_THRESHOLD then return end

	-- Ángulo en grados: 0° = derecha, 90° = arriba
	local angle = math.deg(math.atan2(dy, dx))
	local direction

	if angle >= -45 and angle < 45 then
		direction = "right"
	elseif angle >= 45 and angle < 135 then
		direction = "up"
	elseif angle >= 135 or angle < -135 then
		direction = "left"
	else
		direction = "down"
	end

	self:ExecuteGesture(stickName, direction, magnitude)
	self.lastGesture = GetTime()
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Mapa de acciones
-- ──────────────────────────────────────────────────────────────────────────────

local GESTURE_ACTIONS = {
	-- Right stick en Catalog View
	right_up = function()
		local vf = ns.VendorFrame
		if vf and vf.views and vf.views.catalog then
			local cv = vf.views.catalog
			if cv.AddSelectedToCart then cv:AddSelectedToCart() end
		end
	end,
	right_down = function()
		local vf = ns.VendorFrame
		if vf and vf.views and vf.views.catalog then
			local cv = vf.views.catalog
			if cv.RemoveSelectedFromCart then cv:RemoveSelectedFromCart() end
		end
	end,
	right_left = function()
		local vf = ns.VendorFrame
		if vf and vf.ScrollList then vf:ScrollList(-5) end
	end,
	right_right = function()
		local vf = ns.VendorFrame
		if vf and vf.ScrollList then vf:ScrollList(5) end
	end,

	-- Left stick en BuyFlow (detail view)
	left_up = function()
		local vf = ns.VendorFrame
		if vf and vf.views and vf.views.buyFlow then
			local bf = vf.views.buyFlow
			if bf.AdjustQuantity then bf:AdjustQuantity(10) end
		end
	end,
	left_down = function()
		local vf = ns.VendorFrame
		if vf and vf.views and vf.views.buyFlow then
			local bf = vf.views.buyFlow
			if bf.AdjustQuantity then bf:AdjustQuantity(-10) end
		end
	end,
	left_left = function()
		local vf = ns.VendorFrame
		if vf and vf.views and vf.views.buyFlow then
			local bf = vf.views.buyFlow
			if bf.AdjustQuantity then bf:AdjustQuantity(-100) end
		end
	end,
	left_right = function()
		local vf = ns.VendorFrame
		if vf and vf.views and vf.views.buyFlow then
			local bf = vf.views.buyFlow
			if bf.AdjustQuantity then bf:AdjustQuantity(100) end
		end
	end,
}

function GestureRecognizer:ExecuteGesture(stick, direction, magnitude)
	local key    = stick .. "_" .. direction
	local action = GESTURE_ACTIONS[key]
	if not action then return end

	action()
	self:ShowGestureFeedback(direction)

	if ns.HapticFeedback then
		ns.HapticFeedback:Trigger("gesture", math.min(magnitude * 0.3, 0.4))
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Feedback visual
-- ──────────────────────────────────────────────────────────────────────────────

local DIRECTION_ARROWS = { up = "^", down = "v", left = "<", right = ">" }

function GestureRecognizer:ShowGestureFeedback(direction)
	if not self.feedbackFrame then
		local f = CreateFrame("Frame", nil, UIParent)
		f:SetSize(80, 80)
		f:SetPoint("CENTER", 0, 120)
		f:SetFrameStrata("TOOLTIP")

		f.arrow = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		f.arrow:SetPoint("CENTER")
		f.arrow:SetTextColor(0.4, 0.8, 1)

		self.feedbackFrame = f
	end

	self.feedbackFrame.arrow:SetText(DIRECTION_ARROWS[direction] or "o")
	self.feedbackFrame:Show()

	C_Timer.After(0.45, function()
		if self.feedbackFrame then
			self.feedbackFrame:Hide()
		end
	end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Lectura de sticks (API real + fallback teclado para testing)
-- ──────────────────────────────────────────────────────────────────────────────

function GestureRecognizer:GetLeftStickPosition()
	if GetGamePadAnalogInput then
		local x = (GetGamePadAnalogInput("PADLSTICKRIGHT") or 0) - (GetGamePadAnalogInput("PADLSTICKLEFT") or 0)
		local y = (GetGamePadAnalogInput("PADLSTICKUP")    or 0) - (GetGamePadAnalogInput("PADLSTICKDOWN") or 0)
		return x, y
	end
	-- Fallback teclado
	local x, y = 0, 0
	if IsKeyDown and IsKeyDown("A") then x = x - 1 end
	if IsKeyDown and IsKeyDown("D") then x = x + 1 end
	if IsKeyDown and IsKeyDown("W") then y = y + 1 end
	if IsKeyDown and IsKeyDown("S") then y = y - 1 end
	return x, y
end

function GestureRecognizer:GetRightStickPosition()
	if GetGamePadAnalogInput then
		local x = (GetGamePadAnalogInput("PADRSTICKRIGHT") or 0) - (GetGamePadAnalogInput("PADRSTICKLEFT") or 0)
		local y = (GetGamePadAnalogInput("PADRSTICKUP")    or 0) - (GetGamePadAnalogInput("PADRSTICKDOWN") or 0)
		return x, y
	end
	-- Fallback teclas de flecha
	local x, y = 0, 0
	if IsKeyDown and IsKeyDown("RIGHT") then x = x + 1 end
	if IsKeyDown and IsKeyDown("LEFT")  then x = x - 1 end
	if IsKeyDown and IsKeyDown("UP")    then y = y + 1 end
	if IsKeyDown and IsKeyDown("DOWN")  then y = y - 1 end
	return x, y
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Inicialización
-- ──────────────────────────────────────────────────────────────────────────────

function GestureRecognizer:OnAddonLoaded()
	self.tickerFrame = CreateFrame("Frame", "BCGestureRecognizerTicker")
	self.tickerFrame:SetScript("OnUpdate", function()
		self:OnUpdate()
	end)
end

ns.RegisterModule("GestureRecognizer", GestureRecognizer)
