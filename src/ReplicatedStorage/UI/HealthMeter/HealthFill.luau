local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create
local getHealthColor = require(script.Parent.getHealthColor)

-- Read the animated fraction through a getter to keep width and color in sync.
local function HealthFill(animatedFraction: () -> number): Frame
	-- selene: allow(mixed_table)
	return create("Frame")({
		Name = "InnerFill",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),

		-- A scale of 1 is full width; 0 is empty.
		Size = function()
			return UDim2.fromScale(animatedFraction(), 1)
		end,

		BackgroundColor3 = function()
			return getHealthColor(animatedFraction())
		end,
		BorderSizePixel = 0,

		create("UICorner")({
			CornerRadius = UDim.new(0.5, 0),
		}),
	})
end

return HealthFill
