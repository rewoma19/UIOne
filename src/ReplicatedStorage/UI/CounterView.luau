local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

local function CounterView()
	local message = Vide.source("Hello again!")

	-- selene: allow(mixed_table)
	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		create("TextLabel")({
			Text = message,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), -- halfway across and down the screen
			Size = UDim2.fromOffset(240, 80),
		}),

		create("TextButton")({
			Text = "Change message",
			Size = UDim2.fromOffset(180, 50),
			Position = UDim2.fromOffset(16, 16),

			Activated = function()
				message("You clicked the button!")
			end,
		}),
	})
end

return CounterView
