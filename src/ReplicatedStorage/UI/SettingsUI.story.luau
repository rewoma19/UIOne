local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Find packages.
local Vide = require(ReplicatedStorage.Packages.Vide) -- Provide UI Labs with our Vide version.
local HealthMeter = require(script.Parent.HealthMeter) -- Reuse the existing component.
local SettingsUI = require(script.Parent.SettingsUI) -- Load the new settings component.

return { -- Export a Vide story definition.
	vide = Vide, -- Let UI Labs create and destroy the reactive scope.
	controls = { -- Add editable preview inputs.
		Health = 75, -- Start the existing meter partly full.
		MaxHealth = 100, -- Define its maximum.
		EffectsVolume = 0.5, -- Allow testing volume endpoints without dragging.
		BackgroundVolume = 0.5, -- Keep the second category independent.
	},
	story = function(props) -- UI Labs calls this inside a stable Vide scope.
		local effects = Vide.source(0.5) -- Own interactive effects state for this preview.
		local background = Vide.source(0.5) -- Own interactive background state.
		Vide.effect(function() -- Apply control-panel changes to effects state.
			effects(math.clamp(props.controls.EffectsVolume(), 0, 1)) -- Clamp preview inputs too.
		end)
		Vide.effect(function() -- Independently apply background control changes.
			background(math.clamp(props.controls.BackgroundVolume(), 0, 1)) -- Keep a valid volume.
		end)
		local preview = Vide.create("Frame")({ -- Create a full-size preview canvas.
			Name = "SettingsPreview", -- Identify its temporary instances.
			Size = UDim2.fromScale(1, 1), -- Fill UI Labs' target frame.
			BackgroundTransparency = 1, -- Leave the preview background to UI Labs.
		})
		Vide.create("UIPadding")({ -- Match the game's existing HUD margins.
			Parent = preview, -- Apply padding to the preview canvas.
			PaddingTop = UDim.new(0, 16), -- Inset the top.
			PaddingRight = UDim.new(0, 16), -- Inset the right.
			PaddingBottom = UDim.new(0, 16), -- Inset the bottom.
			PaddingLeft = UDim.new(0, 16), -- Inset the left.
		})
		HealthMeter({ -- Preview the old and new UI together.
			health = props.controls.Health, -- Pass the reactive health getter.
			maxHealth = props.controls.MaxHealth, -- Pass the reactive maximum getter.
		}).Parent = preview -- Keep the original meter as a sibling of settings.
		SettingsUI({ -- Construct a fully interactive, silent settings preview.
			initiallyOpen = true, -- Show the panel immediately for inspection.
			effectsVolume = effects, -- Read preview-only effects state.
			backgroundVolume = background, -- Read preview-only background state.
			onEffectsChanged = function(value) -- Accept a drag from the effects slider.
				effects(value) -- Synchronously update its source.
			end,
			onBackgroundChanged = function(value) -- Accept a background-slider drag.
				background(value) -- Update only that source.
			end,
		}).Parent = preview -- Attach the settings tree to this preview.
		Vide.cleanup(preview) -- Destroy all preview instances when this story unmounts.
		return preview -- Give UI Labs the instance it should display.
	end,
}
