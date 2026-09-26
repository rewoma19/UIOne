local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Find shared packages.
local Vide = require(ReplicatedStorage.Packages.Vide) -- Load Vide once for this module.
local create = Vide.create -- Short name for constructing instances.
local SettingsPanel = require(script.SettingsPanel) -- Load the child menu module.

export type Props = { -- Describe caller-owned audio state.
	effectsVolume: () -> number, -- Getter for effects volume.
	backgroundVolume: () -> number, -- Getter for background volume.
	onEffectsChanged: (number) -> (), -- Callback for effects changes.
	onBackgroundChanged: (number) -> (), -- Callback for background changes.
	initiallyOpen: boolean?, -- Optional starting state for previews.
}

local function SettingsUI(props: Props): Frame -- Build the settings portion of the HUD.
	local open = Vide.source(props.initiallyOpen == true) -- Keep one shared open/closed value.
	local rotation = Vide.spring(function() -- Animate the gear from that same state.
		return if open() then 45 else 0 -- Rotate when open; restore when closed.
	end, 0.3, 1) -- Choose a responsive, damped spring.

	local root = create("Frame")({ -- Fill the existing HUD container.
		Name = "SettingsUI", -- Separate settings from the HealthMeter in Explorer.
		Size = UDim2.fromScale(1, 1), -- Use all available HUD space.
		BackgroundTransparency = 1, -- Leave the world and health meter visible.
		ZIndex = 5, -- Put settings above the health subtree with Sibling ZIndexBehavior.
	})
	create("ImageButton")({ -- Add the tutorial's gear-shaped entry point.
		Name = "SettingsButton", -- Identify the toggle button.
		Parent = root, -- Position it relative to the settings area.
		AnchorPoint = Vector2.new(0.5, 0), -- Anchor at its top-center.
		Position = UDim2.fromScale(0.5, 0), -- Place it at the HUD's top-center.
		Size = UDim2.fromOffset(44, 44), -- Use a stable button size for the first version.
		BackgroundTransparency = 1, -- Show only the icon.
		Image = "rbxassetid://104919049969988", -- Gear asset from the Roblox tutorial.
		Rotation = rotation, -- Pass the animated getter so rotation keeps updating.
		Activated = function() -- Handle mouse, touch, or selected-button activation.
			open(not open()) -- Toggle the one shared boolean value.
		end,
	})
	SettingsPanel({ -- Give the menu the same open state as the gear.
		open = open, -- Keep visibility and animation synchronized.
		onClose = function() -- Handle the menu's close button.
			open(false) -- Set closed explicitly instead of toggling accidentally.
		end,
		effectsVolume = props.effectsVolume, -- Forward the effects getter.
		backgroundVolume = props.backgroundVolume, -- Forward the background getter.
		onEffectsChanged = props.onEffectsChanged, -- Forward effects requests.
		onBackgroundChanged = props.onBackgroundChanged, -- Forward background requests.
	}).Parent = root -- Attach the completed menu next to the gear.

	return root -- Let the existing HUD or the story parent this component.
end

return SettingsUI -- Export the public settings component.
