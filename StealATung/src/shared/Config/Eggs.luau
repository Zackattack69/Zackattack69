--!strict
-- Robux eggs: buy 1, 3 or 10 in the Shop and they hatch right away into Tungs
-- that go straight into your base. Every egg has its own list of Tungs with
-- the exact chance of each, shown on the egg before you buy (Roblox requires
-- that for paid random items). Eggs are hidden for players whose country
-- doesn't allow them.
--
-- Fairness (Design Doc): Mythics never come from eggs.

local Mutations = require(script.Parent.Mutations)
local Tungs = require(script.Parent.Tungs)

export type Content = { tung: string, chance: number } -- chance in percent
export type MutOdds = { key: string, chance: number }
export type Bundle = { count: number, product: string } -- product key in Products

export type Egg = {
	key: string,
	name: string,
	color: Color3,
	color2: Color3,
	contents: { Content },
	mutations: { MutOdds }?, -- mutation chances (percent); missing = no mutation
	bundles: { Bundle },
	desc: string,
}

local Eggs = {}

Eggs.List = {
	{
		key = "Tung",
		name = "Tung Egg",
		color = Color3.fromRGB(226, 170, 110),
		color2 = Color3.fromRGB(150, 96, 50),
		contents = {
			{ tung = "LeafyTung", chance = 30 },
			{ tung = "FlowerTung", chance = 22 },
			{ tung = "PirateTung", chance = 18 },
			{ tung = "BeeTung", chance = 13 },
			{ tung = "WizardTung", chance = 9 },
			{ tung = "ClownTung", chance = 5.5 },
			{ tung = "SamuraiTung", chance = 2 },
			{ tung = "DragonTung", chance = 0.5 },
		},
		bundles = { { count = 1, product = "EggTung1" }, { count = 3, product = "EggTung3" }, { count = 10, product = "EggTung10" } },
		desc = "A wooden egg full of Tungs.",
	},
	{
		key = "Golden",
		name = "Golden Egg",
		color = Color3.fromRGB(255, 214, 60),
		color2 = Color3.fromRGB(214, 140, 20),
		contents = {
			{ tung = "ChocoTung", chance = 35 },
			{ tung = "KnightTung", chance = 25 },
			{ tung = "AstroTung", chance = 18 },
			{ tung = "VampireTung", chance = 12 },
			{ tung = "MagicianTung", chance = 7 },
			{ tung = "EmperorTung", chance = 2.5 },
			{ tung = "GoldenBatTung", chance = 0.5 },
		},
		mutations = { { key = "Gold", chance = 25 } },
		bundles = { { count = 1, product = "EggGolden1" }, { count = 3, product = "EggGolden3" }, { count = 10, product = "EggGolden10" } },
		desc = "Shiny! 25% chance the Tung comes out Gold.",
	},
	{
		key = "Rainbow",
		name = "Rainbow Egg",
		color = Color3.fromRGB(255, 120, 200),
		color2 = Color3.fromRGB(110, 140, 255),
		contents = {
			{ tung = "BubblegumTung", chance = 30 },
			{ tung = "DiscoTung", chance = 25 },
			{ tung = "ElectricTung", chance = 20 },
			{ tung = "GhostTung", chance = 14 },
			{ tung = "WitchTung", chance = 8 },
			{ tung = "UnicornTung", chance = 2.6 },
			{ tung = "GlitchTung", chance = 0.4 },
		},
		mutations = { { key = "Gold", chance = 55 }, { key = "Diamond", chance = 32 }, { key = "Rainbow", chance = 12 }, { key = "Cursed", chance = 1 } },
		bundles = { { count = 1, product = "EggRainbow1" }, { count = 3, product = "EggRainbow3" }, { count = 10, product = "EggRainbow10" } },
		desc = "Always hatches a mutated Tung!",
	},
	{
		key = "Moon",
		name = "Sahur Moon Egg",
		color = Color3.fromRGB(70, 80, 170),
		color2 = Color3.fromRGB(24, 26, 70),
		contents = {
			{ tung = "IceKingTung", chance = 30 },
			{ tung = "CyborgTung", chance = 25 },
			{ tung = "DragonTung", chance = 20 },
			{ tung = "PhoenixTung", chance = 12 },
			{ tung = "ThunderTung", chance = 9 },
			{ tung = "ShadowTung", chance = 3 },
			{ tung = "SahurMoonTung", chance = 1 },
		},
		bundles = { { count = 1, product = "EggMoon1" }, { count = 3, product = "EggMoon3" }, { count = 10, product = "EggMoon10" } },
		desc = "Epic or better, every time.",
	},
} :: { Egg }

Eggs.ByKey = {} :: { [string]: Egg }
Eggs.ByProduct = {} :: { [string]: { egg: Egg, count: number } }
for _, e in Eggs.List do
	Eggs.ByKey[e.key] = e
	for _, b in e.bundles do
		Eggs.ByProduct[b.product] = { egg = e, count = b.count }
	end
	for _, c in e.contents do
		local t = Tungs.Get(c.tung)
		assert(t and t.rarity ~= "Mythic", "Egg " .. e.key .. " has a bad Tung: " .. c.tung)
	end
end

-- Rolls one hatch: (tung id, mutation).
function Eggs.Roll(egg: Egg, rng: Random): (string, string)
	local total = 0
	for _, c in egg.contents do
		total += c.chance
	end
	local r = rng:NextNumber() * total
	local id = egg.contents[#egg.contents].tung
	for _, c in egg.contents do
		r -= c.chance
		if r <= 0 then
			id = c.tung
			break
		end
	end
	-- mutation (whatever is left over is "no mutation")
	local mut = Mutations.NONE
	local muts = egg.mutations
	if muts then
		local m = rng:NextNumber() * 100
		for _, o in muts do
			m -= o.chance
			if m <= 0 then
				mut = o.key
				break
			end
		end
	end
	return id, mut
end

return Eggs
