--!strict
-- The Tung roster: 22 original Tungs across 7 rarities, plus 2 bound specials
-- (Group Tung, VIP Tung) that never appear on the belt or in the Index.
--
-- Every Tung is the wooden-log-with-a-bat character, changed by outfit, material,
-- colour and a signature effect. `look` drives TungModel; `effect` drives the
-- client-side signature animation in WorldFx.
--
-- Adding a Tung: append an entry with a unique id. Its rarity decides which
-- belt pool it joins; `weight` is its share inside that rarity.

local Rarities = require(script.Parent.Rarities)

export type Look = {
	body: Color3?, -- skin colour (default: wood)
	material: Enum.Material?,
	hat: string?, -- Nightcap | Bucket | Leaves | NinjaBand | Afro | Antenna | Nemes | Crown | Cap | TopHat | Horns
	props: { string }?, -- Drum | Scarf | DiscoBall | Cape | Wraps | Visor | Shades | Cracks | MoonHalo | Cheeks | Stars
	eyes: string?, -- Sleepy | Glow
	eyeColor: Color3?,
	bat: Color3?,
	batMaterial: Enum.Material?,
	accent: Color3?, -- cracks, visor, trims
}

export type Tung = {
	id: string,
	name: string,
	rarity: string,
	price: number,
	income: number, -- $ per second (before mutation / multipliers)
	weight: number, -- share inside its rarity when the belt picks a Tung
	effect: string, -- signature effect key (see WorldFx)
	desc: string,
	look: Look,
	scale: number?,
	tier: number?, -- Mythic sub-tier: 1 Blue, 2 Purple, 3 Red
	color: Color3?, -- overrides the rarity colour (Mythic sub-tiers)
	special: boolean?, -- not on the belt, not in the Index
	bound: boolean?, -- can't be stolen, traded or sold
	order: number?, -- filled in below (roster position)
}

local M = Enum.Material
local GOLD = Color3.fromRGB(255, 196, 45)

local Tungs = {}

Tungs.List = {
	-- Common ----------------------------------------------------------------------------
	{ id = "TungClassic", name = "Tung Classic", rarity = "Common", price = 10, income = 1, weight = 40, effect = "BatTap", desc = "Taps its bat on the ground every few seconds", look = {} },
	{ id = "SleepyTung", name = "Sleepy Tung", rarity = "Common", price = 25, income = 2, weight = 30, effect = "Zzz", desc = 'Floating "Zzz" bubbles', look = { hat = "Nightcap", eyes = "Sleepy" } },
	{ id = "MiniTung", name = "Mini Tung", rarity = "Common", price = 50, income = 3, weight = 20, effect = "Squeak", desc = "Half size, squeaky footsteps", look = { body = Color3.fromRGB(196, 140, 92) }, scale = 0.5 },
	{ id = "BucketHatTung", name = "Tung with a Bucket Hat", rarity = "Common", price = 90, income = 5, weight = 10, effect = "HatBounce", desc = "Hat bounces when it walks", look = { hat = "Bucket" } },

	-- Uncommon --------------------------------------------------------------------------
	{ id = "LeafyTung", name = "Leafy Tung", rarity = "Uncommon", price = 250, income = 8, weight = 45, effect = "Leaves", desc = "Leaves fall off it slowly", look = { hat = "Leaves", body = Color3.fromRGB(150, 118, 72) } },
	{ id = "DrummerTung", name = "Tung the Drummer", rarity = "Uncommon", price = 500, income = 15, weight = 35, effect = "Drum", desc = "Plays a tiny drum beat", look = { props = { "Drum" } } },
	{ id = "BubblegumTung", name = "Bubblegum Tung", rarity = "Uncommon", price = 800, income = 25, weight = 20, effect = "Bubble", desc = "Blows a pink bubble that pops", look = { body = Color3.fromRGB(236, 150, 186), props = { "Cheeks" } } },

	-- Rare ------------------------------------------------------------------------------
	{ id = "FrostyTung", name = "Frosty Tung", rarity = "Rare", price = 2500, income = 40, weight = 45, effect = "Frost", desc = "Icy breath, frost on the ground", look = { body = Color3.fromRGB(175, 222, 255), material = M.Ice, props = { "Scarf" }, accent = Color3.fromRGB(220, 50, 60) } },
	{ id = "NinjaTung", name = "Ninja Tung", rarity = "Rare", price = 5000, income = 75, weight = 35, effect = "Ninja", desc = "Turns half-invisible every 10 seconds", look = { body = Color3.fromRGB(46, 46, 56), hat = "NinjaBand", accent = Color3.fromRGB(220, 40, 50) } },
	{ id = "DiscoTung", name = "Disco Tung", rarity = "Rare", price = 9000, income = 120, weight = 20, effect = "Disco", desc = "Spinning disco light above its head", look = { body = Color3.fromRGB(150, 92, 220), hat = "Afro", props = { "DiscoBall", "Shades" } } },

	-- Epic ------------------------------------------------------------------------------
	{ id = "LavaTung", name = "Lava Tung", rarity = "Epic", price = 30000, income = 200, weight = 45, effect = "Lava", desc = "Glowing cracks, drips lava sparks", look = { body = Color3.fromRGB(58, 42, 38), material = M.Basalt, props = { "Cracks" }, accent = Color3.fromRGB(255, 120, 20) } },
	{ id = "RoboTung", name = "Robo-Tung 3000", rarity = "Epic", price = 60000, income = 380, weight = 35, effect = "Robo", desc = "Metal body, beeps, laser-eye scan", look = { body = Color3.fromRGB(172, 178, 190), material = M.DiamondPlate, hat = "Antenna", props = { "Visor" }, accent = Color3.fromRGB(255, 40, 40), bat = Color3.fromRGB(120, 125, 135), batMaterial = M.Metal } },
	{ id = "PharaohTung", name = "Pharaoh Tung", rarity = "Epic", price = 100000, income = 600, weight = 20, effect = "Sand", desc = "Golden wraps, sand swirls at its feet", look = { hat = "Nemes", props = { "Wraps" }, accent = GOLD } },

	-- Legendary -------------------------------------------------------------------------
	{ id = "KingTung", name = "King Tung", rarity = "Legendary", price = 400000, income = 1000, weight = 55, effect = "Fanfare", desc = "Crown, red cape, trumpet fanfare when placed", look = { hat = "Crown", props = { "Cape" }, accent = Color3.fromRGB(200, 25, 40) } },
	{ id = "GalaxyTung", name = "Galaxy Tung", rarity = "Legendary", price = 900000, income = 2000, weight = 30, effect = "Stars", desc = "Body full of moving stars", look = { body = Color3.fromRGB(44, 30, 98), material = M.Glass, props = { "Stars" } } },
	{ id = "GoldenBatTung", name = "Golden Bat Tung", rarity = "Legendary", price = 1.5e6, income = 3500, weight = 15, effect = "Coins", desc = "Solid gold, coins pop out every hit", look = { body = GOLD, material = M.Foil, bat = GOLD, batMaterial = M.Foil } },

	-- Secret ----------------------------------------------------------------------------
	{ id = "ShadowTung", name = "Shadow Tung", rarity = "Secret", price = 8e6, income = 8000, weight = 55, effect = "Shadow", desc = "Leaves a smoke trail, eyes glow white", look = { body = Color3.fromRGB(22, 22, 28), eyes = "Glow", eyeColor = Color3.new(1, 1, 1), bat = Color3.fromRGB(30, 30, 36) } },
	{ id = "GlitchTung", name = "Glitch Tung", rarity = "Secret", price = 15e6, income = 14000, weight = 30, effect = "Glitch", desc = "Flickers and teleports a few studs at random", look = { body = Color3.fromRGB(255, 40, 200), material = M.Neon, eyes = "Glow", eyeColor = Color3.fromRGB(40, 255, 240) } },
	{ id = "SahurMoonTung", name = "Sahur Moon Tung", rarity = "Secret", price = 25e6, income = 25000, weight = 15, effect = "Moon", desc = "Crescent moon halo, glows brighter at night", look = { body = Color3.fromRGB(34, 44, 104), props = { "MoonHalo" }, eyes = "Glow", eyeColor = Color3.fromRGB(255, 236, 140) } },

	-- Mythic (rarity inside the rarity) ---------------------------------------------------
	{ id = "MythicBlueTung", name = "Mythic Blue Tung", rarity = "Mythic", tier = 1, color = Color3.fromRGB(40, 160, 255), price = 250e6, income = 100000, weight = 70, effect = "Ripples", desc = "Blue fire aura, water ripples spread from its feet", look = { body = Color3.fromRGB(30, 90, 200), eyes = "Glow", eyeColor = Color3.fromRGB(150, 230, 255), props = { "Cracks" }, accent = Color3.fromRGB(60, 200, 255) } },
	{ id = "MythicPurpleTung", name = "Mythic Purple Tung", rarity = "Mythic", tier = 2, color = Color3.fromRGB(185, 70, 255), price = 750e6, income = 350000, weight = 25, effect = "Runes", desc = "Purple fire aura, floating runes orbit it, lightning crackles", look = { body = Color3.fromRGB(95, 35, 170), eyes = "Glow", eyeColor = Color3.fromRGB(240, 190, 255), hat = "Horns", props = { "Cracks" }, accent = Color3.fromRGB(200, 100, 255) } },
	{ id = "MythicRedTung", name = "Mythic Red Tung", rarity = "Mythic", tier = 3, color = Color3.fromRGB(255, 45, 45), price = 2.5e9, income = 1000000, weight = 5, effect = "Quake", desc = "Red fire aura, ground cracks with lava, screen shakes when it bangs its bat", look = { body = Color3.fromRGB(120, 18, 22), material = M.Basalt, eyes = "Glow", eyeColor = Color3.fromRGB(255, 220, 80), hat = "Horns", props = { "Cracks" }, accent = Color3.fromRGB(255, 70, 20), bat = Color3.fromRGB(60, 20, 20) } },

	-- Bound specials ----------------------------------------------------------------------
	{ id = "GroupTung", name = "Group Tung", rarity = "Rare", price = 5000, income = 60, weight = 0, effect = "BatTap", desc = "A thank-you for joining the group", special = true, bound = true, look = { hat = "Cap", accent = Color3.fromRGB(60, 150, 255) } },
	{ id = "VIPTung", name = "VIP Tung", rarity = "Epic", price = 100000, income = 450, weight = 0, effect = "Sparkle", desc = "VIP-only. Dripped out in black and gold", special = true, bound = true, look = { body = Color3.fromRGB(30, 30, 36), hat = "TopHat", props = { "Shades" }, accent = GOLD, bat = GOLD, batMaterial = M.Foil } },
} :: { Tung }

Tungs.ById = {} :: { [string]: Tung }
Tungs.ByRarity = {} :: { [string]: { Tung } } -- belt pools (no specials)
Tungs.IndexList = {} :: { Tung } -- everything collectable, in Index order

for i, t in Tungs.List do
	t.order = i
	Tungs.ById[t.id] = t
	if not t.special then
		Tungs.ByRarity[t.rarity] = Tungs.ByRarity[t.rarity] or {}
		table.insert(Tungs.ByRarity[t.rarity], t)
		table.insert(Tungs.IndexList, t)
	end
end

function Tungs.Get(id: string): Tung?
	return Tungs.ById[id]
end

-- The colour used for this Tung everywhere (Mythic sub-tiers have their own).
function Tungs.Color(t: Tung): Color3
	return t.color or Rarities.Get(t.rarity).color
end

function Tungs.Color2(t: Tung): Color3
	if t.color then
		return t.color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	return Rarities.Get(t.rarity).color2
end

-- "MYTHIC 🔥🔥" style label with the sub-tier flame badge.
function Tungs.RarityLabel(t: Tung): string
	if t.tier then
		return string.upper(t.rarity) .. " " .. string.rep("🔥", t.tier)
	end
	return string.upper(t.rarity)
end

-- Picks a Tung of the given rarity using the in-rarity weights.
function Tungs.PickFromRarity(rng: Random, rarity: string): Tung
	local pool = Tungs.ByRarity[rarity] or Tungs.ByRarity.Common
	local total = 0
	for _, t in pool do
		total += t.weight
	end
	local roll = rng:NextNumber() * total
	for _, t in pool do
		roll -= t.weight
		if roll <= 0 then
			return t
		end
	end
	return pool[#pool]
end

-- Find by id or (loosely) by name; used by admin commands.
function Tungs.Find(query: string): Tung?
	local q = string.lower((query:gsub("[%s%-_]", "")))
	for _, t in Tungs.List do
		if string.lower(t.id) == q or string.lower((t.name:gsub("[%s%-_]", ""))) == q then
			return t
		end
	end
	for _, t in Tungs.List do
		if string.find(string.lower((t.name:gsub("[%s%-_]", ""))), q, 1, true) then
			return t
		end
	end
	return nil
end

return Tungs
