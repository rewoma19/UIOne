local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create
local derive = Vide.derive
local spring = Vide.spring

-- Rojo places the helper modules inside this HealthMeter ModuleScript.
local HealthFill = require(script.HealthFill)

-- These functions are getters: call them to read the latest value.
type HealthMeterProps = {
	health: () -> number,
	maxHealth: () -> number,
}

local function HealthMeter(props: HealthMeterProps): Frame
	-- Convert raw values such as 75/100 into a safe percentage such as 0.75.
	local healthFraction = derive(function()
		local maximum = props.maxHealth()
		if maximum <= 0 then
			return 0
		end

		return math.clamp(props.health() / maximum, 0, 1)
	end)

	-- Smoothly move toward the latest fraction without overshooting it.
	local animatedFraction = spring(healthFraction, 0.35, 1)

	-- selene: allow(mixed_table)
	return create("Frame")({
		Name = "MeterBar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.35, 0.05),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,

		create("UICorner")({
			CornerRadius = UDim.new(0.5, 0),
		}),

		create("UIStroke")({
			Thickness = 3,
			Transparency = 0.25,
		}),

		create("UISizeConstraint")({
			MaxSize = Vector2.new(math.huge, 20),
		}),

		-- Pass the getter so the fill reacts as the spring moves.
		HealthFill(animatedFraction),

		create("ImageLabel")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(2, 2),
			BackgroundTransparency = 1,
			Image = "rbxassetid://91715286435585",
			ZIndex = 2,

			create("UIAspectRatioConstraint")({
				AspectRatio = 1,
			}),
		}),
	})
end

return HealthMeter
