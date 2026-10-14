--!strict
-- The game's art direction in one place: bright, flat, toy-like Roblox plastic.
-- Every builder runs its materials through Style.Material, so realistic
-- textures (wood grain, cobblestone, fabric...) become smooth plastic, while
-- Neon / Glass / ForceField stay as they are for glows and crystals.
-- Metallic materials keep a bit of shine through Style.Reflectance.

local Style = {}

local M = Enum.Material

local KEEP: { [Enum.Material]: boolean } = {
	[M.SmoothPlastic] = true,
	[M.Plastic] = true,
	[M.Neon] = true,
	[M.Glass] = true,
	[M.ForceField] = true,
}

local SHINY: { [Enum.Material]: number } = {
	[M.Foil] = 0.3,
	[M.Metal] = 0.2,
	[M.DiamondPlate] = 0.15,
	[M.Ice] = 0.2,
	[M.Marble] = 0.08,
}

function Style.Material(m: Enum.Material?): Enum.Material
	if m == nil then
		return M.SmoothPlastic
	end
	return if KEEP[m] then m else M.SmoothPlastic
end

-- Reflectance to give a part whose original material was metallic.
function Style.Reflectance(m: Enum.Material?): number
	return if m then SHINY[m] or 0 else 0
end

-- Applies the toon look to a part that was given a (possibly realistic) material.
function Style.Apply(p: BasePart, m: Enum.Material?)
	p.Material = Style.Material(m)
	local r = Style.Reflectance(m)
	if r > 0 and p.Reflectance == 0 then
		p.Reflectance = r
	end
end

-- Bright, saturated world palette.
Style.Colors = {
	Grass = Color3.fromRGB(106, 214, 74),
	Grass2 = Color3.fromRGB(88, 196, 62),
	GrassOuter = Color3.fromRGB(96, 204, 68),
	Path = Color3.fromRGB(255, 226, 160),
	Hedge = Color3.fromRGB(64, 182, 70),
	HedgeLight = Color3.fromRGB(96, 214, 84),
	Fence = Color3.fromRGB(255, 255, 255),
	Trunk = Color3.fromRGB(150, 96, 58),
	Belt = Color3.fromRGB(226, 40, 52),
	BeltDark = Color3.fromRGB(170, 22, 34),
	Frame = Color3.fromRGB(62, 62, 84),
	Yellow = Color3.fromRGB(255, 214, 40),
	Gold = Color3.fromRGB(255, 196, 30),
	Purple = Color3.fromRGB(130, 76, 240),
	Pink = Color3.fromRGB(255, 100, 190),
	Blue = Color3.fromRGB(60, 160, 255),
	Cyan = Color3.fromRGB(60, 230, 245),
	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(26, 24, 40),
}

return Style
