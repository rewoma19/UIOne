local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Find shared packages.
local Vide = require(ReplicatedStorage.Packages.Vide) -- Load the same Vide instance as the app.
local create = Vide.create -- Shorten UI construction calls.
local VolumeSlider = require(script.Parent.VolumeSlider) -- Reuse our slider component.

export type Props = { -- Define the panel's input contract.
	open: () -> boolean, -- Whether the panel should be visible.
	onClose: () -> (), -- Ask the owner to close it.
	effectsVolume: () -> number, -- Read effects volume.
	backgroundVolume: () -> number, -- Read background volume.
	onEffectsChanged: (number) -> (), -- Request an effects-volume change.
	onBackgroundChanged: (number) -> (), -- Request a background-volume change.
}

local function SettingsPanel(props: Props): Frame -- Build one reusable menu.
	local y = Vide.spring(function() -- Animate a number instead of managing tweens manually.
		return if props.open() then 0.5 else 0.4 -- Move toward center when opening.
	end, 0.35, 1) -- Set spring period and damping; this is not a fixed animation duration.

	local panel = create("Frame")({ -- Group the whole menu under one frame.
		Name = "SettingsMenu", -- Make it easy to locate at runtime.
		AnchorPoint = Vector2.new(0.5, 0.5), -- Position by its center.
		Position = function() -- Follow the animated vertical value.
			return UDim2.fromScale(0.5, y()) -- Stay horizontally centered.
		end,
		Size = UDim2.new(0.9, 0, 0, 236), -- Use available width and a predictable row height.
		Visible = props.open, -- Hide the existing panel on close instead of destroying its sliders.
		BackgroundColor3 = Color3.fromRGB(30, 30, 60), -- Use a dark background.
		BackgroundTransparency = 0.1, -- Keep labels readable over the world.
		BorderSizePixel = 0, -- Replace square borders with rounded corners.
	})
	create("UICorner")({ Parent = panel, CornerRadius = UDim.new(0, 16) }) -- Round the menu.
	local sizeLimit = Instance.new("UISizeConstraint") -- Keep large-screen menus compact.
	sizeLimit.MaxSize = Vector2.new(560, math.huge) -- Cap width without a phone-breaking minimum.
	sizeLimit.Parent = panel -- Apply the constraint to this menu.

	create("TextLabel")({ -- Give the panel a clear heading.
		Parent = panel, -- Put the heading inside the menu.
		AnchorPoint = Vector2.new(0.5, 0), -- Position the heading by its horizontal center.
		Position = UDim2.new(0.5, 0, 0, 12), -- Center it across the panel.
		Size = UDim2.new(1, -112, 0, 32), -- Reserve equal space on both sides for the close button.
		BackgroundTransparency = 1, -- Show the menu behind the heading.
		Text = "Settings", -- Name this menu.
		TextXAlignment = Enum.TextXAlignment.Center, -- Center the text within the heading.
		TextColor3 = Color3.new(1, 1, 1), -- Use bright text.
		Font = Enum.Font.GothamBold, -- Emphasize the heading.
		TextSize = 20, -- Distinguish it from row labels.
	})
	create("TextButton")({ -- Provide a text close action with no external image dependency.
		Name = "CloseButton", -- Identify it in Explorer.
		Parent = panel, -- Keep it attached to the menu.
		AnchorPoint = Vector2.new(1, 0), -- Anchor its right edge.
		Position = UDim2.new(1, -12, 0, 8), -- Place it at the upper-right.
		Size = UDim2.fromOffset(44, 44), -- Give it a generous interaction area.
		BackgroundTransparency = 1, -- Keep the heading area uncluttered.
		Text = "×", -- Show a familiar close symbol.
		TextSize = 28, -- Make the symbol easy to see.
		TextColor3 = Color3.new(1, 1, 1), -- Match the heading.
		Activated = props.onClose, -- Support button activation rather than mouse-only clicks.
	})

	local rows = create("Frame")({ -- Reserve the content area below the heading.
		Parent = panel, -- Keep both sliders inside the menu.
		Position = UDim2.fromOffset(20, 64), -- Start below the close-button area.
		Size = UDim2.new(1, -40, 0, 156), -- Inset both sides equally.
		BackgroundTransparency = 1, -- Let the menu act as the background.
	})
	create("UIListLayout")({ -- Lay out the two slider rows automatically.
		Parent = rows, -- Arrange this container's direct children.
		Padding = UDim.new(0, 16), -- Separate the rows.
		SortOrder = Enum.SortOrder.LayoutOrder, -- Use each slider's explicit order.
	})
	VolumeSlider({ -- Construct the first instance of the reusable slider.
		label = "Effects", -- Identify effects audio.
		iconImage = "rbxassetid://90019827067389", -- Tutorial's musical note and burst icon.
		color = Color3.fromRGB(0, 150, 255), -- Use blue for this category.
		layoutOrder = 1, -- Put effects first.
		value = props.effectsVolume, -- Pass the getter, not a captured number.
		onChanged = props.onEffectsChanged, -- Forward changes to the caller.
	}).Parent =
		rows -- Place the returned row under the list container.
	VolumeSlider({ -- Construct a second instance without duplicating its internals.
		label = "Background", -- Identify background audio.
		iconImage = "rbxassetid://101125859760167", -- Tutorial's background music notes.
		color = Color3.fromRGB(255, 0, 125), -- Use magenta for this category.
		layoutOrder = 2, -- Put background second.
		value = props.backgroundVolume, -- Keep this slider's state independent.
		onChanged = props.onBackgroundChanged, -- Forward only background changes.
	}).Parent =
		rows -- Let the same layout arrange this row.

	return panel -- Return the completed menu to its owner.
end

return SettingsPanel -- Export this component.
