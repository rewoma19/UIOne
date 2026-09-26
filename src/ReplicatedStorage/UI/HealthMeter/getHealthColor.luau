-- These are the same five stages used by Roblox's tutorial.
local HEALTH_COLORS = {
	Color3.fromRGB(225, 50, 0),
	Color3.fromRGB(255, 100, 0),
	Color3.fromRGB(255, 200, 0),
	Color3.fromRGB(150, 225, 0),
	Color3.fromRGB(0, 225, 50),
}

-- Clamp the fraction, then blend between the two neighboring color stages.
local function getHealthColor(fraction: number): Color3
	local clampedFraction = math.clamp(fraction, 0, 1)
	local sectionCount = #HEALTH_COLORS - 1
	local scaledPosition = clampedFraction * sectionCount
	local startIndex = math.min(math.floor(scaledPosition) + 1, #HEALTH_COLORS)
	local endIndex = math.min(startIndex + 1, #HEALTH_COLORS)
	local sectionFraction = scaledPosition - math.floor(scaledPosition)

	return HEALTH_COLORS[startIndex]:Lerp(HEALTH_COLORS[endIndex], sectionFraction)
end

return getHealthColor
