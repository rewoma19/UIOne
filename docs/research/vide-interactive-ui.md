# Research: Continue the HealthMeter with interactive Vide settings

Date: 2026-09-25

This walkthrough continues in **UIOne**, alongside the existing HealthMeter. You do not need the tutorial's starting place or its gameplay. The implementation described below is now included in `src`; the steps explain how it fits together.

## What you are building

The Roblox tutorial adds a gear button, an animated settings panel, a close button, and two draggable sliders that independently control effects and background audio. Its implementation uses `StatefulObjectController`, `SliderController`, and a LocalScript; ours uses Vide components, reactive state, and your existing `Main.client.luau`. The original opens the panel with a bounce and closes it immediately. The version below uses a Vide spring for opening and immediately hides the panel on close. These animations have different timing. [Roblox: Create interactive UI](https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/interactive-ui)

Your existing code already gives us:

- A persistent `HealthHUD` ScreenGui mounted in `PlayerGui`.
- A padded `HUDContainer` and responsive HealthMeter.
- Character/respawn handling and health listeners with cleanup.
- Vide **0.4.1**, pinned in [wally.toml](../../wally.toml).
- A working [HealthMeter story](../../src/ReplicatedStorage/UI/HealthMeter.story.luau).

Keep those pieces. Settings will be another child of `HUDContainer`. The audio containers and sounds are absent from this repository, so audio setup is an explicit step below.

## The learning sequence

| Step | Build | Check before continuing |
| --- | --- | --- |
| 1 | Understand the state and file boundaries | Explain what owns each value. |
| 2 | A reusable VolumeSlider | Trace drag → value → fill. |
| 3 | SettingsPanel | Both sliders have different icons and colors. |
| 4 | SettingsUI | Gear toggles; close button closes. |
| 5 | UI Labs story with the HealthMeter | Preview the full composition without audio. |
| 6 | SoundGroups and Main integration | Each slider changes the correct group. |
| 7 | Device, respawn, and cleanup checks | Health and settings continue working together. |

The code blocks are complete new files or precisely located additions. **Inline comments explain each substantive line**; closing braces, parentheses, and `end` simply finish the block they opened. Read one file at a time instead of pasting every file before understanding it.

## 1. Decide who owns the state

A **source** is a value you can read and replace. A **getter** is a function that reads a value. A **callback** is a function another component calls when something happens. Here, the caller owns volume sources; the slider receives a getter plus an `onChanged` callback. Vide properties backed by functions update when their sources change. [Vide: Reactivity core](https://centau.github.io/vide/api/reactivity-core.html), [Vide: Element creation](https://centau.github.io/vide/api/creation.html)

```text
Player drags handle
        ↓
UIDragDetector changes Handle.Position
        ↓
VolumeSlider calls onChanged(number)
        ↓
App updates a volume source
        ├──→ Slider's handle and fill update
        └──→ App's effect updates SoundGroup.Volume
```

This is the same direction as your HealthMeter: a changing value drives the display. The difference is that a slider can request changes too.

Proposed files:

```text
src/ReplicatedStorage/UI/
├── HealthMeter/                     existing; keep it
├── HealthMeter.story.luau           existing; keep it
├── SettingsUI/
│   ├── init.luau                    gear button and open/closed state
│   ├── SettingsPanel.luau           menu layout and two slider instances
│   └── VolumeSlider.luau            dragging, icon, fill
└── SettingsUI.story.luau            combined health/settings preview
src/SoundService/
├── Effects.model.json
└── Background.model.json
src/StarterPlayerScripts/
└── Main.client.luau                 small additions to your existing App
```

Rojo maps an `init.luau` directory to a ModuleScript containing its helper modules; `require(ReplicatedStorage.UI.SettingsUI)` loads its entry point. The existing project already maps `src/SoundService`. [Rojo: Sync details](https://rojo.space/docs/v7/sync-details/), [local project configuration](../../default.project.json)

## 2. Build VolumeSlider

Create `src/ReplicatedStorage/UI/SettingsUI/VolumeSlider.luau`:

```luau
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
```

**Why this has a small amount of imperative code:** native dragging writes `Handle.Position`, so we deliberately observe that property. The initialization happens before the listener is connected. The listener compares values before calling the parent, and the effect compares positions before writing. This prevents a source → position → source cycle from repeatedly writing identical values. Callers must synchronously accept the clamped value, as the examples below do.

The drag constraint is a deliberate adaptation. `BoundingUI` with `HitPoint` bounds the grab point, which can differ from the handle center. Instead, the code constrains the final center to `0–1`, so both endpoints remain reachable when grabbing either side of the handle. `AddConstraintFunction` returns a connection that can be disconnected; absolute relativity and parent space make its input a proposed final position in the track. [Roblox: UI drag detectors](https://create.roblox.com/docs/ui/ui-drag-detectors), [Roblox's UIDragDetector API source](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/UIDragDetector.yaml)

Vide 0.4.1's runtime accepts Roblox class names, but its `create` type mapping does not list `UIDragDetector`. `Instance.new` keeps this part typed without changing packages. The detector is still destroyed with its containing UI; its explicit connections use `Vide.cleanup`. [Installed create implementation](../../Packages/_Index/centau_vide@0.4.1/vide/src/create.luau), [installed cleanup implementation](../../Packages/_Index/centau_vide@0.4.1/vide/src/cleanup.luau)

## 3. Compose the SettingsPanel

Create `src/ReplicatedStorage/UI/SettingsUI/SettingsPanel.luau`:

```luau
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
```

Each slider includes the tutorial's category icon: the effects note/burst (`90019827067389`) and background musical notes (`101125859760167`). The icons identify the categories; the rows display no text labels or numeric values. [Roblox: slider icon and duplicate slider](https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/interactive-ui#slider-icon)

This layout uses a compact width-capped panel in place of the tutorial's minimum-width/aspect-ratio layout. The fixed row heights make the learning example easier to inspect; test small screens before settling on final sizing. `UIListLayout` manages its sibling GuiObjects. [Roblox: UIListLayout](https://create.roblox.com/docs/reference/engine/classes/UIListLayout)

`spring(input, period, dampingRatio)` returns an animated getter. A spring period is not a promise to finish in that many seconds. We animate only the panel's Y position; slider movement stays immediate so the handle follows input. Hiding preserves state between openings; this example is a settings overlay, not a modal dialog that blocks all world input. [Vide: Animation](https://centau.github.io/vide/api/animation.html), [Roblox: GuiObject.Visible](https://create.roblox.com/docs/reference/engine/classes/GuiObject#Visible)

## 4. Add the gear button and open/closed state

Create `src/ReplicatedStorage/UI/SettingsUI/init.luau`:

```luau
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
```

There is one `open` source rather than separate button and menu state that can disagree. `Activated` is the appropriate general button event. The component knows nothing about `SoundService`, which is why the same component can run in UI Labs. [Roblox: GuiButton.Activated](https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated)

## 5. Preview beside the HealthMeter in UI Labs

Create `src/ReplicatedStorage/UI/SettingsUI.story.luau`:

```luau
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
```

Sync with Rojo and open **SettingsUI** in UI Labs. UI Labs creates sources for controls and owns the story's stable scope. Do not add your own `mount()` inside the story. Volume controls feed preview state in one direction: changing a control updates its slider, while dragging updates the slider's handle and fill but does not rewrite the Controls-panel number. The preview changes no game audio. [UI Labs: Vide stories](https://ui-labs.luau.page/docs/stories/advanced/vide)

Check both volume controls at `0`, `0.5`, and `1`; then drag the handles. If an editor tool intercepts dragging, deactivate Studio's Select/Move/Scale/Rotate or UI editing tool and try again. Confirm real dragging in Play mode as well; an editor-plugin preview is not a substitute for runtime input testing. [Roblox: UI drag detectors](https://create.roblox.com/docs/ui/ui-drag-detectors)

## 6. Connect real audio in this project

Roblox now recommends its newer audio objects over legacy `SoundGroup` objects. This walkthrough deliberately retains `Sound`/`SoundGroup` to complete the requested tutorial; the UI's volume getters and callbacks can later connect to a newer audio setup without rewriting the components. [Roblox: Sound groups](https://create.roblox.com/docs/sound/groups)

A **SoundGroup** controls the volume of Sounds assigned to it. Merely parenting a Sound under a group does not establish that assignment: set the Sound's `SoundGroup` property. Its own `Volume` still matters; for example, a sound at `0.6` with group volume `0.5` plays at an effective volume of `0.3`. [Roblox: Sound groups](https://create.roblox.com/docs/sound/groups), [Roblox: Sound.SoundGroup](https://create.roblox.com/docs/reference/engine/classes/Sound#SoundGroup)

### 6a. Add the two groups through Rojo

Create **both** `src/SoundService/Effects.model.json` and `src/SoundService/Background.model.json`, each containing:

```json
{
  "ClassName": "SoundGroup",
  "Properties": {
    "Volume": 0.5
  }
}
```

Line by line: the first brace opens the model; `ClassName` chooses the Roblox class; `Properties` opens its property assignments; `Volume` sets its initial multiplier; the remaining braces close those objects. Each filename supplies its instance name. This JSON-model format is distinct from project-file `$className` syntax. [Rojo: JSON models](https://rojo.space/docs/v7/sync-details/#json-models)

After syncing, Explorer should show `SoundService → Effects` and `SoundService → Background`, each with class `SoundGroup`. Keep one of each.

### 6b. Add imports and group references to Main

In `src/StarterPlayerScripts/Main.client.luau`, add these next to your existing service and component imports:

```luau
local SoundService = game:GetService("SoundService") -- Find our audio groups.
local SettingsUI = require(ReplicatedStorage.UI.SettingsUI) -- Load the settings component.
```

Immediately after the existing `local playerGui = player:WaitForChild("PlayerGui")`, add:

```luau
local effectsGroup = SoundService:WaitForChild("Effects") -- Wait before entering Vide's mounted scope.
local backgroundGroup = SoundService:WaitForChild("Background") -- Wait for the second synced group.
assert(effectsGroup:IsA("SoundGroup"), "SoundService.Effects must be a SoundGroup") -- Catch setup mistakes.
assert(backgroundGroup:IsA("SoundGroup"), "SoundService.Background must be a SoundGroup") -- Check its type too.
```

Complete 6a before playtesting: missing groups would make these waits keep waiting. Vide's stable/reactive scopes must not yield, so these waits belong above `mount(App, playerGui)`, outside `App`. [Vide: Scopes](https://centau.github.io/vide/api/reactivity-core.html#scopes)

Inside `App()`, immediately after your existing `local maxHealth = source(100)`, add:

```luau
local effectsVolume = source(math.clamp(effectsGroup.Volume, 0, 1)) -- Initialize from the actual group.
local backgroundVolume = source(math.clamp(backgroundGroup.Volume, 0, 1)) -- Initialize separately.
effect(function() -- Connect effects UI state to the external Roblox audio object.
	effectsGroup.Volume = effectsVolume() -- Apply immediately and whenever this source changes.
end)
effect(function() -- Use a separate effect for background audio.
	backgroundGroup.Volume = backgroundVolume() -- Leave effects volume independent.
end)
```

Finally, inside the existing `HUDContainer` creation table, directly after the existing `HealthMeter({...}),` entry, add:

```luau
SettingsUI({ -- Add settings as another child of the existing HUDContainer.
	effectsVolume = effectsVolume, -- Supply the caller-owned effects getter.
	backgroundVolume = backgroundVolume, -- Supply the background getter.
	onEffectsChanged = function(value) -- Accept the requested effects value.
		effectsVolume(math.clamp(value, 0, 1)) -- Update state and let its effect apply audio.
	end,
	onBackgroundChanged = function(value) -- Accept only background changes here.
		backgroundVolume(math.clamp(value, 0, 1)) -- Update the independent background source.
	end,
}),
```

Do not add another ScreenGui or mount. Preserve your current health logic, `ResetOnSpawn = false`, safe insets, `ZIndexBehavior.Sibling`, `cleanup(screenGui)`, and `script.Destroying:Once(destroyUI)`. The existing root destroys the new descendants too, and Vide cleanup disconnects their listeners. Your HealthMeter stays connected to the same Humanoid sources. [Existing Main](../../src/StarterPlayerScripts/Main.client.luau), [Vide: Cleanup](https://centau.github.io/vide/api/reactivity-utility.html#cleanup)

The settings values belong to this client session. They survive character respawn with the existing persistent App; they are not saved across leaving and rejoining. This example treats the App as the volume owner: it does not synchronize unrelated scripts changing group volumes behind its back. Persistence and a broader audio manager can be later exercises.

### 6c. Give the groups something audible to control

The groups themselves do not play sound. In Studio's **edit mode**:

1. Insert a `Sound` into `SoundService`; name it `EffectsPreview`.
2. Choose an audio asset your experience is permitted to use and assign its `SoundId`.
3. Set its `SoundGroup` property to `SoundService.Effects`, `Volume` to `0.5`, and `Looped` to `true` temporarily for testing.
4. Add another permitted Sound named `BackgroundPreview`, assigning its `SoundGroup` to `SoundService.Background` and the same testing properties.
5. In a client playtest, start the test sounds by setting their `Playing` properties to `true`. Change one slider at a time and listen.
6. Stop/remove the temporary test sounds when finished, or replace them with your game's actual audio. Assign every future effects/music Sound to the intended group explicitly.

Your project's SoundService mapping preserves unknown Studio instances, so these test Sounds can remain place-owned while the two groups are Rojo-owned. Save your place if you want to keep the test setup. To version the sounds later, add them as Rojo models and arrange the `SoundGroup` references from code. [Local project configuration](../../default.project.json), [Roblox: Sound](https://create.roblox.com/docs/reference/engine/classes/Sound), [Roblox: Audio assets](https://create.roblox.com/docs/audio/assets)

No specific audio asset is assumed here. If a sound does not load, verify its asset permissions and Output messages before debugging the sliders. Watching the corresponding group Volume change on the **client** verifies the UI wiring even before audible assets are available.

## 7. Review and verify the finished feature

| Check | Expected result | What it catches |
| --- | --- | --- |
| UI Labs starts with non-default values | Handle and fill agree immediately | Incorrect initialization or getters passed as numbers |
| Volume control is `-1` or `2` | Handle and fill clamp to empty or full | Missing range protection |
| Grab the left/right edge of a handle and drag to both extremes | Both the empty and full endpoints remain reachable | Grab-point bounding mistakes |
| Drag beyond either end and reverse direction | Handle remains in range and resumes smoothly | Incorrect constraint or response behavior |
| Set Effects to `0`, Background to `1` | Only effects mute | Cross-wired callbacks or SoundGroup assignments |
| Close, reopen, rapidly toggle | Gear and menu agree; volumes remain unchanged | Duplicate state, unwanted remounting, animation races |
| Resize while open | Rows remain inside the panel; handles align with fill | Offset/scale or constraint errors |
| Phone portrait, landscape, tablet, desktop | Settings and HealthMeter fit safe area | Unchecked minimum widths and HUD overlap |
| Mouse, touch, gamepad selection | Buttons activate and sliders can be adjusted | Assumptions that only mouse users exist |
| Character dies and respawns | Health rebinds; one settings UI remains; volume persists | Accidental second mount or character-owned settings |
| Health `0`, `50`, `100`; MaxHealth `0` | Existing meter remains correct | Regression from integration edits |
| Unmount/remount the story several times | One preview remains and no errors appear | Forgotten instance/connection cleanup |

If the fixed 236-pixel panel is too tall for a very short viewport, the next layout improvement is a height-constrained scrolling content area. If the gear and health bar crowd one another on a narrow phone, move the gear to a separate HUD row or reserve a fixed-width button area before resizing the HealthMeter. Treat these as observed layout improvements rather than expanding the first implementation prematurely.

Verification completed while preparing the guide and implementing it:

- All eight Luau blocks passed Studio's syntax compiler; the HUD-child fragment was wrapped in a table for that check.
- The proposed additions were applied to a temporary copy of this project's Main, which also passed Studio's syntax compiler.
- A temporary copy containing all proposed modules, the story, and the two JSON models built successfully with Rojo. Both groups had the expected names and initial volume of `0.5`.
- The implemented project also builds with Rojo, including the settings story and audio groups.
- Sixteen isolated Studio checks passed for initial values, open/close behavior, source-to-handle and handle-to-source updates, independent volume values, range clamping, and instance/listener cleanup. These use detached UI instances and invoke the actual button callbacks; they do not simulate pointer input.
- The repeatable check is [tests/SettingsUI.spec.luau](../../tests/SettingsUI.spec.luau). After syncing with Rojo, run its contents in Studio's edit-mode Command Bar. It requires Studio's source-reading and compilation privileges and is not a gameplay script.

Compilation checks syntax, and a Rojo build checks how files map into a place. The isolated checks exercise state and cleanup. **Native pointer dragging, rendered device layouts, and audible playback still require the playtests above.** Assign permitted Sounds to the two groups before checking audio.

## Code-review feedback and next practice

The current HealthMeter already separates color logic, fill rendering, and composition well. Keep that boundary: volume controls should reuse a general slider, not repurpose HealthFill, whose colors and animation specifically communicate health. Your existing cleanup and respawn handling are worth preserving.

For the new code, the essential review points are:

- Pass `effectsVolume`, not `effectsVolume()`, where a component expects a getter.
- Keep SoundService access in Main so previews remain isolated.
- Keep state writes in input callbacks and external audio writes in effects.
- Initialize handles before connecting their position listeners.
- Keep every manually created connection registered with cleanup.
- Avoid a second script that independently changes the same handle or menu state.

Useful exercises after the first working version: add a **Reset audio** button that writes `0.5` to both volume sources; extract a pure clamping function and test its boundary values if more settings share it; add explicit gamepad focus transitions; then decide whether settings should persist between sessions. Each exercise adds one responsibility to the same state flow rather than requiring another UI framework.
