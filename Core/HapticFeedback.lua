local _, ns = ...

-- ============================================================================
-- Core/HapticFeedback.lua
-- Feedback háptico (vibración del mando) para reforzar acciones del usuario.
-- Usa C_GamePad.SetVibration si está disponible; de lo contrario es no-op.
-- Fase 10 de la UI Revolucionaria.
-- ============================================================================

local HapticFeedback = {}
ns.HapticFeedback = HapticFeedback

-- Patrones: lista de pulsos { duration, intensity } intercalados con { pause }
local PATTERNS = {
	selection = {
		{ duration = 0.05, intensity = 0.3 },
	},
	confirm = {
		{ duration = 0.08, intensity = 0.5 },
		{ pause    = 0.05 },
		{ duration = 0.08, intensity = 0.5 },
	},
	error = {
		{ duration = 0.30, intensity = 0.8 },
	},
	success = {
		{ duration = 0.06, intensity = 0.6 },
		{ pause    = 0.04 },
		{ duration = 0.06, intensity = 0.6 },
		{ pause    = 0.04 },
		{ duration = 0.06, intensity = 0.6 },
	},
	gesture = {
		{ duration = 0.12, intensity = 0.4 },
	},
	batchAction = {
		{ duration = 0.15, intensity = 0.5 },
	},
}

-- ──────────────────────────────────────────────────────────────────────────────
-- API pública
-- ──────────────────────────────────────────────────────────────────────────────

-- patternName  : clave en PATTERNS
-- intensityMul : multiplicador de intensidad (default 1.0)
function HapticFeedback:Trigger(patternName, intensityMul)
	-- Respetar preferencia del usuario
	local settings = ns.DB and ns.DB.insightSettings
	if settings and settings.enableHapticFeedback == false then return end

	local pattern = PATTERNS[patternName]
	if not pattern then return end

	intensityMul = intensityMul or 1.0
	local t = 0

	for _, pulse in ipairs(pattern) do
		if pulse.duration then
			local dur = pulse.duration
			local int = math.min(pulse.intensity * intensityMul, 1.0)
			C_Timer.After(t, function()
				self:Vibrate(dur, int)
			end)
			t = t + dur
		elseif pulse.pause then
			t = t + pulse.pause
		end
	end
end

-- Vibrar el mando físico
function HapticFeedback:Vibrate(duration, intensity)
	-- WoW 10.x+ expone C_GamePad.SetVibration(motor, intensity)
	-- "LeftTrigger", "RightTrigger", "LeftMotor", "RightMotor"
	if C_GamePad and C_GamePad.SetVibration then
		C_GamePad.SetVibration("LeftMotor",  intensity)
		C_GamePad.SetVibration("RightMotor", intensity)

		-- Detener vibración al finalizar la duración
		C_Timer.After(duration, function()
			C_GamePad.SetVibration("LeftMotor",  0)
			C_GamePad.SetVibration("RightMotor", 0)
		end)
	end
	-- Si la API no existe, la llamada es silenciosa (no-op intencional)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Configuración por defecto añadida a ns.DEFAULTS en Addon.lua
-- Se lee desde ns.DB.insightSettings.enableHapticFeedback
-- ──────────────────────────────────────────────────────────────────────────────

function HapticFeedback:OnAddonLoaded()
	-- Asegurar que el campo existe en los defaults
	if ns.DEFAULTS and ns.DEFAULTS.insightSettings then
		if ns.DEFAULTS.insightSettings.enableHapticFeedback == nil then
			ns.DEFAULTS.insightSettings.enableHapticFeedback = true
		end
	end
end

ns.RegisterModule("HapticFeedback", HapticFeedback)
