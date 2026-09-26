# Research: Roblox custom health meter with Vide UI

Date: 2026-09-24

## Short conclusion

Roblox's tutorial builds a pill-shaped meter from a dark outer `Frame`, a colored inner `Frame`, and a heart `ImageLabel`. The script listens to `Humanoid.HealthChanged`, computes `Health / MaxHealth`, changes the inner frame's width and color, and disables Roblox's built-in health CoreGui. The same design maps naturally to Vide:

1. Roblox events write the current health values into Vide `source`s.
2. A derived function converts those values into a safe fraction from `0` to `1`.
3. Function-valued `Size`, `BackgroundColor3`, and `Text` properties read that fraction, so Vide keeps the UI synchronized.
4. `cleanup()` disconnects character and humanoid listeners when an effect reruns or the mounted UI is destroyed.
5. `spring()` can animate the fraction without manually creating and cancelling `TweenService` tweens.

The repository currently pins `centau/vide@0.4.1`, and its existing entry point mounts into `PlayerGui` from `StarterPlayerScripts`. The implementation below is shaped for that setup.

## What the official Roblox tutorial does

The tutorial first creates a `ScreenGui` configured for safe insets, then makes a meter in the upper-right corner. Its outer `MeterBar` is 35% of the HUD width and 5% of its height, uses a translucent black background, a `UIStroke`, and a `UICorner`. `InnerFill` begins at full width and receives its own `UICorner`. A heart icon is centered on the left edge, and a `UISizeConstraint` caps the meter's height at 20 pixels for better behavior on tablet-like aspect ratios. See [Roblox: Create HUD meters](https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/create-hud-meters).

The tutorial disables the built-in health UI on the client with:

```luau
local StarterGui = game:GetService("StarterGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
```

It then reads the local character's `Humanoid`, listens to `Humanoid.HealthChanged`, computes a health fraction, changes the width of `InnerFill`, and interpolates across red/orange/yellow/lime/green colors. Roblox explicitly says that server-side health changes are available to the client for this display update. See the tutorial's [Replace the default health meter](https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/create-hud-meters#replace-the-default-health-meter) section.

The tutorial puts its update script in `StarterCharacterScripts`, so Roblox restarts it for every spawned character. This repository instead already owns its interface from a persistent `StarterPlayerScripts/Main.client.luau`, so the Vide version should listen for `CharacterAdded` and rebind itself on respawn.

## The Vide ideas, in beginner terms

### `create()` describes the instance tree

Vide's `create()` constructs a Roblox `Instance`. String keys set properties, numeric entries become children, an event property set to a function becomes an event callback, and a non-event property set to a function becomes reactive. See [Vide: Element Creation](https://centau.github.io/vide/api/creation.html).

For example, this `Size` function is rerun whenever `healthFraction()` changes:

```luau
create("Frame")({
	Size = function()
		return UDim2.fromScale(healthFraction(), 1)
	end,
})
```

### `source()` is reactive storage

A source is a small value container. Call it with no argument to read it; call it with one argument to replace its value. An `effect()` runs immediately, remembers the sources it read, and reruns when any of them changes. A `derive()` computes and caches one value from other sources. See [Vide: Reactivity Core](https://centau.github.io/vide/api/reactivity-core.html).

```luau
local health = source(100)

print(health()) -- Read: 100
health(75) -- Write: 75
```

### `cleanup()` owns event lifetimes

Vide's `cleanup()` queues a callback or disconnectable object for cleanup when the current reactive scope reruns or is destroyed. That is ideal for `RBXScriptConnection`s. When the current humanoid changes, the health effect reruns, disconnects the old humanoid's listeners, and connects the new humanoid. See [Vide: Reactivity Utility](https://centau.github.io/vide/api/reactivity-utility.html) and the [Vide cleanup tutorial](https://centau.github.io/vide/tut/crash-course/10-cleanup.html).

```luau
effect(function()
	local currentHumanoid = humanoid()
	if currentHumanoid == nil then
		return
	end

	cleanup(currentHumanoid.HealthChanged:Connect(function(newHealth)
		health(newHealth)
	end))
end)
```

### `mount()` starts the lifetime

`mount(component, target)` runs the component in a stable Vide scope, parents its result to the target, and returns a function that destroys that scope. The returned function is important for tests, hot reload, or replacing one root UI with another. See [Vide: `mount()`](https://centau.github.io/vide/api/creation.html#mount).

Vide warns that code must not yield inside stable or reactive scopes. In practice, do `WaitForChild("PlayerGui")` before calling `mount()`. Inside the mounted component and its effects, use existing-instance checks and events instead of `WaitForChild()`. See [Vide's scope rules](https://centau.github.io/vide/api/reactivity-core.html#scopes).

### `spring()` is the Vide-native animation

Vide's `spring(input, period, dampingRatio)` returns a reactive, animated version of a number, `Color3`, `UDim2`, or other supported value. A damping ratio of `1` is critically damped, which means it reaches the target without overshooting. See [Vide: Animation](https://centau.github.io/vide/api/animation.html).

For a health bar, animate the fraction and derive both width and color from the animated number. This avoids creating a new Roblox tween every time health changes.

## Recommended component

Suggested file: `src/ReplicatedStorage/UI/HealthMeter.luau`

```luau
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create
local derive = Vide.derive
local spring = Vide.spring

-- These functions are getters: call them to read the latest value.
type HealthMeterProps = {
	health: () -> number,
	maxHealth: () -> number,
}

-- These are the same five stages used by Roblox's tutorial.
local HEALTH_COLORS = {
	Color3.fromRGB(225, 50, 0),
	Color3.fromRGB(255, 100, 0),
	Color3.fromRGB(255, 200, 0),
	Color3.fromRGB(150, 225, 0),
	Color3.fromRGB(0, 225, 50),
}

-- Return the blended color at a fraction between 0 and 1.
local function getHealthColor(fraction: number): Color3
	local clampedFraction = math.clamp(fraction, 0, 1)
	local sectionCount = #HEALTH_COLORS - 1
	local scaledPosition = clampedFraction * sectionCount
	local startIndex = math.min(math.floor(scaledPosition) + 1, #HEALTH_COLORS)
	local endIndex = math.min(startIndex + 1, #HEALTH_COLORS)
	local sectionFraction = scaledPosition - math.floor(scaledPosition)

	return HEALTH_COLORS[startIndex]:Lerp(HEALTH_COLORS[endIndex], sectionFraction)
end

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

		create("Frame")({
			Name = "InnerFill",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),

			-- A scale of 1 is full width; 0 is empty.
			Size = function()
				return UDim2.fromScale(animatedFraction(), 1)
			end,

			-- Reading the same animated value keeps color and width in sync.
			BackgroundColor3 = function()
				return getHealthColor(animatedFraction())
			end,
			BorderSizePixel = 0,

			create("UICorner")({
				CornerRadius = UDim.new(0.5, 0),
			}),
		}),

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
```

## Recommended client controller and mount

This version belongs in the repository's existing `src/StarterPlayerScripts/Main.client.luau`. It deliberately handles both the already-present character and later respawns.

```luau
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Vide = require(ReplicatedStorage.Packages.Vide)
local batch = Vide.batch
local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local mount = Vide.mount
local source = Vide.source

local HealthMeter = require(ReplicatedStorage.UI.HealthMeter)

local player = Players.LocalPlayer

-- This can yield, so do it before entering Vide's mounted stable scope.
local playerGui = player:WaitForChild("PlayerGui")

-- Prevent Roblox's default health meter from overlapping ours.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

local function App(): ScreenGui
	-- Character and humanoid may temporarily be nil during spawning.
	local character = source(player.Character)
	local humanoid = source(nil :: Humanoid?)

	-- The visible data starts empty until a Humanoid is found.
	local health = source(0)
	local maxHealth = source(100)

	-- These root-level connections live as long as this mounted App.
	cleanup(player.CharacterAdded:Connect(function(newCharacter)
		character(newCharacter)
	end))

	cleanup(player.CharacterRemoving:Connect(function(removingCharacter)
		if character() == removingCharacter then
			character(nil)
		end
	end))

	-- Find the Humanoid without yielding inside a Vide scope.
	-- This effect reruns whenever the current character changes.
	effect(function()
		local currentCharacter = character()
		humanoid(nil)

		if currentCharacter == nil then
			return
		end

		local existingHumanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
		if existingHumanoid and existingHumanoid:IsA("Humanoid") then
			humanoid(existingHumanoid)
			return
		end

		-- CharacterAdded can happen before all character children exist.
		-- cleanup() disconnects this listener when the character changes.
		cleanup(currentCharacter.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				humanoid(child)
			end
		end))
	end)

	-- Copy Humanoid state into Vide state and own the event connections.
	effect(function()
		local currentHumanoid = humanoid()

		if currentHumanoid == nil then
			batch(function()
				health(0)
				maxHealth(100)
			end)
			return
		end

		local function syncHumanoidValues()
			-- batch() prevents dependents from reacting between these two writes.
			batch(function()
				health(currentHumanoid.Health)
				maxHealth(currentHumanoid.MaxHealth)
			end)
		end

		-- Set correct values immediately instead of waiting for the first event.
		syncHumanoidValues()

		cleanup(currentHumanoid.HealthChanged:Connect(function(newHealth)
			health(newHealth)
		end))

		-- MaxHealth can also change, so observe it separately.
		cleanup(currentHumanoid:GetPropertyChangedSignal("MaxHealth"):Connect(
			syncHumanoidValues
		))
	end)

	-- selene: allow(mixed_table)
	local screenGui = create("ScreenGui")({
		Name = "HealthHUD",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		create("Frame")({
			Name = "HUDContainer",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			create("UIPadding")({
				PaddingTop = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 16),
			}),

			HealthMeter({
				health = health,
				maxHealth = maxHealth,
			}),
		}),
	})

	-- mount() destroys reactive scopes; this also destroys the actual ScreenGui.
	cleanup(screenGui)

	return screenGui
end

local destroyUI = mount(App, playerGui)

-- Helpful if Studio, a test, or a hot-reloader removes this LocalScript.
script.Destroying:Once(destroyUI)
```

## How the data flows

```text
Server changes Humanoid health
           |
           v
Humanoid.HealthChanged fires on this client
           |
           v
health(newHealth) updates a Vide source
           |
           v
healthFraction recomputes and spring moves to the target
           |
           +--> InnerFill.Size changes
           +--> InnerFill.BackgroundColor3 changes
```

This division is useful: Roblox events are the input boundary, sources hold UI state, and the component only describes how state should look.

## Roblox health behavior and practical cautions

- `Humanoid.HealthChanged` supplies the new health as its event argument. It fires at zero when the humanoid dies. Roblox notes that it does not fire when health is increasing from a value already equal to or above `MaxHealth`. Read initial values immediately and separately observe `MaxHealth` if the game can modify it. See [Roblox: `Humanoid.HealthChanged`](https://create.roblox.com/docs/reference/engine/classes/Humanoid#HealthChanged).
- Roblox's default regeneration heals living characters by 1% of `MaxHealth` per second. To disable it, add an empty server `Script` named `Health` under `StarterCharacterScripts`. See [Roblox: Humanoid health regeneration](https://create.roblox.com/docs/reference/engine/classes/Humanoid#Health).
- When health reaches zero, the humanoid enters the dead state and health is locked at zero. Respawning produces a new character and a new humanoid, which is why rebinding through `CharacterAdded` matters. See [Roblox: Humanoid death](https://create.roblox.com/docs/reference/engine/classes/Humanoid#Health).
- The UI is client-side presentation only. Damage, healing, maximum-health rules, and other authoritative gameplay decisions belong on the server; Roblox's security guidance says the server should be the source of truth and the client should render results. See [Roblox: Security and cheat mitigation](https://create.roblox.com/docs/scripting/security/security-tactics#server-authority).
- Clamp the fraction to `0...1` and guard against `MaxHealth <= 0`. This prevents invalid widths if a game temporarily reports unusual values.
- Initialize once immediately, then listen for changes. If code only subscribes to `HealthChanged`, the bar can remain incorrect until the first damage or heal event.

## Testing checklist

1. Start a one-player Studio session and confirm only the custom meter appears.
2. Damage the character and verify both width and color move down smoothly.
3. Heal the character and verify both move back up.
4. Change `MaxHealth` while playing and confirm the fraction recalculates.
5. Reset the character and confirm the new humanoid drives the same persistent UI.
6. Use Studio's Device Emulator for a phone and tablet; verify the safe inset, 16-pixel padding, and 20-pixel height cap.
7. Temporarily print inside the health callback, reset repeatedly, and ensure each health change prints only once. Multiple prints indicate leaked old event connections.

## Primary sources

- [Roblox Creator Hub — Create HUD meters](https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/create-hud-meters)
- [Roblox Creator Hub — Humanoid API](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- [Roblox Creator Hub — Player API](https://create.roblox.com/docs/reference/engine/classes/Player)
- [Roblox Creator Hub — Events](https://create.roblox.com/docs/scripting/events)
- [Roblox Creator Hub — Security and cheat mitigation](https://create.roblox.com/docs/scripting/security/security-tactics)
- [Vide — Reactivity Core](https://centau.github.io/vide/api/reactivity-core.html)
- [Vide — Reactivity Utility](https://centau.github.io/vide/api/reactivity-utility.html)
- [Vide — Element Creation](https://centau.github.io/vide/api/creation.html)
- [Vide — Animation](https://centau.github.io/vide/api/animation.html)
- [Vide — Cleanup tutorial](https://centau.github.io/vide/tut/crash-course/10-cleanup.html)
- [Vide official source repository](https://github.com/centau/vide)
