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
		cleanup(currentHumanoid:GetPropertyChangedSignal("MaxHealth"):Connect(syncHumanoidValues))
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
