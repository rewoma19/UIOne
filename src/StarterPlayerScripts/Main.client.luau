-- Get the Roblox service that holds our shared packages
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create
local mount = Vide.mount

local CounterView = require(ReplicatedStorage.UI.CounterView)

local function App()
	-- selene: allow(mixed_table)
	return create("ScreenGui")({
		Name = "MyFirstUI",
		CounterView(),
	})
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
mount(App, playerGui)
