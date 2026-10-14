--!strict
-- Rarity tiers. Order matters: index 1 = lowest. "Iconic" is reserved for the
-- famous, named droids from the films and shows.

export type Rarity = {
	name: string,
	index: number,
	color: Color3,
	color2: Color3, -- secondary gradient color for UI
	multiplier: number,
}

local Rarities = {}

Rarities.List = {
	{ name = "Common", color = Color3.fromRGB(190, 196, 208), color2 = Color3.fromRGB(128, 136, 152), multiplier = 1 },
	{ name = "Uncommon", color = Color3.fromRGB(110, 230, 120), color2 = Color3.fromRGB(40, 160, 75), multiplier = 2.5 },
	{ name = "Rare", color = Color3.fromRGB(80, 170, 255), color2 = Color3.fromRGB(35, 90, 220), multiplier = 6 },
	{ name = "Epic", color = Color3.fromRGB(190, 100, 255), color2 = Color3.fromRGB(110, 40, 200), multiplier = 15 },
	{ name = "Legendary", color = Color3.fromRGB(255, 205, 60), color2 = Color3.fromRGB(240, 125, 20), multiplier = 40 },
	{ name = "Mythic", color = Color3.fromRGB(255, 70, 90), color2 = Color3.fromRGB(170, 20, 60), multiplier = 120 },
	{ name = "Iconic", color = Color3.fromRGB(70, 235, 255), color2 = Color3.fromRGB(255, 225, 90), multiplier = 400 },
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
