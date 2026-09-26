local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Find shared modules.
local Vide = require(ReplicatedStorage.Packages.Vide) -- Use the installed Vide package.
local create = Vide.create -- Short name for constructing UI instances.

export type Props = { -- Describe everything a slider needs from its caller.
	label: string, -- Category name used to identify the row in Explorer.
	iconImage: string, -- Image asset identifying the audio category.
	color: Color3, -- The fill and handle-outline color.
	layoutOrder: number, -- Which row comes first in the panel.
	value: () -> number, -- Getter for a volume between zero and one.
	onChanged: (number) -> (), -- Callback requesting a new volume.
}

local function VolumeSlider(props: Props): Frame -- Construct one slider row.
	local function fraction(): number -- Keep display values inside the allowed range.
		return math.clamp(props.value(), 0, 1) -- 0 means muted; 1 means full group volume.
	end

	local row = create("Frame")({ -- Hold the icon and track together.
		Name = props.label .. "VolumeSlider", -- Make Explorer easy to understand.
		Size = UDim2.new(1, 0, 0, 70), -- Fill the available width with a 70-pixel row.
		BackgroundTransparency = 1, -- Show the panel behind this container.
		LayoutOrder = props.layoutOrder, -- Let UIListLayout order the rows.
	})

	create("ImageLabel")({ -- Show the category icon beside the slider track.
		Name = "Icon", -- Identify the decorative image in Explorer.
		Parent = row, -- Keep the icon in the same row as its slider.
		AnchorPoint = Vector2.new(0, 0.5), -- Position the icon by its vertical center.
		Position = UDim2.fromScale(0, 0.5), -- Center it within the row.
		Size = UDim2.fromOffset(32, 32), -- Reserve a square area for the icon.
		BackgroundTransparency = 1, -- Show only the image over the panel.
		Image = props.iconImage, -- Use the category's image supplied by the panel.
		ScaleType = Enum.ScaleType.Fit, -- Preserve the artwork's proportions.
	})

	local track = create("Frame")({ -- Draw the slider's horizontal range.
		Name = "SliderFrame", -- Match the role of the tutorial's range frame.
		Parent = row, -- Keep the track in its row.
		AnchorPoint = Vector2.new(0, 0.5), -- Align the track's center with the icon.
		Position = UDim2.new(0, 58, 0.5, 0), -- Reserve the icon, gap, and half the handle.
		Size = UDim2.new(1, -76, 0, 18), -- Keep an 18-pixel handle margin on the right too.
		BackgroundColor3 = Color3.new(0, 0, 0), -- Use a dark track.
		BackgroundTransparency = 0.5, -- Let some panel color show through.
		BorderSizePixel = 0, -- Remove the default rectangular border.
	})
	create("UICorner")({ Parent = track, CornerRadius = UDim.new(0.5, 0) }) -- Round both ends.

	local fill = create("Frame")({ -- Draw the filled portion of the track.
		Name = "InnerFill", -- Identify the changing fill in Explorer.
		Parent = track, -- Size the fill relative to the track.
		Size = function() -- Keep the fill synchronized with the current volume.
			return UDim2.fromScale(fraction(), 1) -- Fill the chosen percentage of the width.
		end,
		BackgroundColor3 = props.color, -- Identify this audio category by color.
		BorderSizePixel = 0, -- Keep the rounded edge clean.
	})
	create("UICorner")({ Parent = fill, CornerRadius = UDim.new(0.5, 0) }) -- Round the fill.

	local handle = create("Frame")({ -- Give UIDragDetector a visible object to move.
		Name = "Handle", -- Identify the drag target.
		Parent = track, -- Express movement relative to the track.
		AnchorPoint = Vector2.new(0.5, 0.5), -- Center the handle on its position.
		Position = UDim2.fromScale(fraction(), 0.5), -- Set the correct initial position first.
		Size = UDim2.fromOffset(28, 28), -- Use a circular handle slightly taller than the track.
		BackgroundColor3 = Color3.new(1, 1, 1), -- Make the handle clearly visible.
		BorderSizePixel = 0, -- Use UIStroke for its outline instead.
		ZIndex = 3, -- Keep the handle above the fill.
		Active = true, -- Allow the handle to receive input.
		Selectable = true, -- Allow selection-based interaction to reach it.
	})
	create("UICorner")({ Parent = handle, CornerRadius = UDim.new(0.5, 0) }) -- Make a circle.
	create("UIStroke")({ Parent = handle, Color = props.color, Thickness = 4 }) -- Outline it.

	local detector = Instance.new("UIDragDetector") -- Use a typed native instance for this class.
	detector.DragStyle = Enum.UIDragDetectorDragStyle.TranslateLine -- Restrict motion to a line.
	detector.DragAxis = Vector2.new(1, 0) -- Choose the horizontal axis.
	detector.ResponseStyle = Enum.UIDragDetectorResponseStyle.Scale -- Move using relative width.
	detector.DragRelativity = Enum.UIDragDetectorDragRelativity.Absolute -- Constrain final positions.
	detector.DragSpace = Enum.UIDragDetectorDragSpace.Parent -- Interpret them in the track's space.
	detector.Parent = handle -- Activate dragging on this handle.

	Vide.cleanup(detector:AddConstraintFunction(1, function(position: UDim2, rotation: number)
		return UDim2.fromScale(math.clamp(position.X.Scale, 0, 1), 0.5), rotation -- Limit center to endpoints.
	end)) -- Remove the constraint callback when this UI is unmounted.

	Vide.cleanup(handle:GetPropertyChangedSignal("Position"):Connect(function()
		local nextValue = math.clamp(handle.Position.X.Scale, 0, 1) -- Read the latest actual position.
		if nextValue ~= fraction() then -- Ignore positions already reflected in the source.
			props.onChanged(nextValue) -- Tell the caller which value the player requested.
		end
	end)) -- Disconnect this listener during cleanup.

	Vide.effect(function() -- Also follow changes made by the caller, such as preview controls.
		local desiredPosition = UDim2.fromScale(fraction(), 0.5) -- Convert value to position.
		if handle.Position ~= desiredPosition then -- Avoid writing back the same property repeatedly.
			handle.Position = desiredPosition -- Synchronize the handle when an external value changes.
		end
	end)

	return row -- Let the caller place the complete slider in its panel.
end

return VolumeSlider -- Export the constructor for other modules to require.
