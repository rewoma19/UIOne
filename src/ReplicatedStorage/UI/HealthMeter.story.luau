local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local HealthMeter = require(script.Parent.HealthMeter)

return {
	vide = Vide,

	-- These numbers become editable fields in UI Labs' Controls panel.
	controls = {
		Health = 75,
		MaxHealth = 100,
	},

	story = function(props)
		-- Give the meter a full preview area, like its in-game HUD container.
		-- selene: allow(mixed_table)
		local preview = Vide.create("Frame")({
			Name = "HealthMeterPreview",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			-- Leave space around the meter for its heart icon and outline.
			Vide.create("UIPadding")({
				PaddingTop = UDim.new(0, 24),
				PaddingRight = UDim.new(0, 24),
				PaddingBottom = UDim.new(0, 24),
				PaddingLeft = UDim.new(0, 24),
			}),

			HealthMeter({
				-- UI Labs supplies Vide sources: pass the getters, not their values.
				health = props.controls.Health,
				maxHealth = props.controls.MaxHealth,
			}),
		})

		-- Remove the preview instances when UI Labs unmounts this story.
		Vide.cleanup(preview)
		return preview
	end,
}
