--!strict
-- Rarity tiers (Design Doc §5.1). Order matters: index 1 = lowest.

export type Rarity = {
	name: string,
	index: number,
	color: Color3,
	color2: Color3, -- secondary gradient color for UI
	count: number, -- how many droids of this rarity exist in the 300 roster
	multiplier: number,
}

local Rarities = {}

Rarities.List = {
	{ name = "Common", color = Color3.fromRGB(176, 182, 192), color2 = Color3.fromRGB(120, 126, 138), count = 90, multiplier = 1 },
	{ name = "Uncommon", color = Color3.fromRGB(92, 220, 110), color2 = Color3.fromRGB(34, 150, 70), count = 75, multiplier = 2.5 },
	{ name = "Rare", color = Color3.fromRGB(70, 160, 255), color2 = Color3.fromRGB(30, 80, 210), count = 60, multiplier = 6 },
	{ name = "Epic", color = Color3.fromRGB(180, 90, 255), color2 = Color3.fromRGB(100, 30, 190), count = 45, multiplier = 15 },
	{ name = "Legendary", color = Color3.fromRGB(255, 200, 50), color2 = Color3.fromRGB(230, 120, 20), count = 24, multiplier = 40 },
	{ name = "Mythic", color = Color3.fromRGB(255, 60, 80), color2 = Color3.fromRGB(255, 120, 255), count = 6, multiplier = 120 },
} :: { any }

Rarities.ByName = {} :: { [string]: Rarity }
for i, r in Rarities.List do
	r.index = i
	Rarities.ByName[r.name] = r
end

function Rarities.Get(name: string): Rarity
	return Rarities.ByName[name]
end

return Rarities
