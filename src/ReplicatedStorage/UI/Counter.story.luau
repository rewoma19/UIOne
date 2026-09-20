local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CounterView = require(script.Parent.CounterView)

return {
	vide = Vide,
	story = function()
		return CounterView()
	end,
}
