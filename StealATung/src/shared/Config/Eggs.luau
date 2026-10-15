--!strict
-- Robux eggs: buy one in the Shop (Eggs tab) and it hatches right away into a
-- random Tung that goes straight into your base. The odds are shown on every
-- egg before you buy (Roblox requires that for paid random items), and eggs
-- are hidden for players whose country doesn't allow them.
--
-- Fairness (Design Doc): Mythics never come from eggs.

local Mutations = require(script.Parent.Mutations)
local Tungs = require(script.Parent.Tungs)

export type Odds = { rarity: string, chance: number }
export type MutOdds = { key: string, chance: number }

export type Egg = {
	key: string,
	name: string,
	product: string, -- key in Products
	color: Color3,
	color2: Color3,
	odds: { Odds }, -- rarity chances (percent)
	mutations: { MutOdds }?, -- mutation chances (percent); missing = no mutation
	desc: string,
}

local Eggs = {}

Eggs.List = {
	{
		key = "Tung",
		name = "Tung Egg",
		product = "EggTung",
		color = Color3.fromRGB(226, 170, 110),
		color2 = Color3.fromRGB(170, 110, 60),
		odds = { { rarity = "Uncommon", chance = 55 }, { rarity = "Rare", chance = 35 }, { rarity = "Epic", chance = 9 }, { rarity = "Legendary", chance = 1 } },
		desc = "A wooden egg with a Tung inside.",
	},
	{
		key = "Golden",
		name = "Golden Egg",
		product = "EggGolden",
		color = Color3.fromRGB(255, 210, 60),
		color2 = Color3.fromRGB(220, 150, 20),
		odds = { { rarity = "Rare", chance = 50 }, { rarity = "Epic", chance = 35 }, { rarity = "Legendary", chance = 13 }, { rarity = "Secret", chance = 2 } },
		mutations = { { key = "Gold", chance = 25 } },
		desc = "Shiny! 25% chance the Tung comes out Gold.",
	},
	{
		key = "Rainbow",
		name = "Rainbow Egg",
		product = "EggRainbow",
		color = Color3.fromRGB(255, 120, 200),
		color2 = Color3.fromRGB(110, 140, 255),
		odds = { { rarity = "Rare", chance = 45 }, { rarity = "Epic", chance = 38 }, { rarity = "Legendary", chance = 15 }, { rarity = "Secret", chance = 2 } },
		mutations = { { key = "Gold", chance = 55 }, { key = "Diamond", chance = 32 }, { key = "Rainbow", chance = 12 }, { key = "Cursed", chance = 1 } },
		desc = "Always hatches a mutated Tung!",
	},
	{
		key = "Moon",
		name = "Sahur Moon Egg",
		product = "EggMoon",
		color = Color3.fromRGB(60, 70, 160),
		color2 = Color3.fromRGB(24, 26, 70),
		odds = { { rarity = "Epic", chance = 55 }, { rarity = "Legendary", chance = 37 }, { rarity = "Secret", chance = 8 } },
		desc = "The rarest egg. Epic or better, every time.",
	},
} :: { Egg }

Eggs.ByKey = {} :: { [string]: Egg }
Eggs.ByProduct = {} :: { [string]: Egg }
for _, e in Eggs.List do
	Eggs.ByKey[e.key] = e
	Eggs.ByProduct[e.product] = e
end

-- "Uncommon 55% · Rare 35% · ..." (+ mutation odds)
function Eggs.OddsText(egg: Egg): string
	local parts = {}
	for _, o in egg.odds do
		table.insert(parts, o.rarity .. " " .. o.chance .. "%")
	end
	local text = table.concat(parts, " · ")
	local muts = egg.mutations
	if muts then
		local m = {}
		for _, o in muts do
			table.insert(m, o.key .. " " .. o.chance .. "%")
		end
		text ..= "\nMutation: " .. table.concat(m, " · ")
	end
	return text
end

-- Rolls what hatches: (tung id, mutation).
function Eggs.Roll(egg: Egg, rng: Random): (string, string)
	local total = 0
	for _, o in egg.odds do
		total += o.chance
	end
	local r = rng:NextNumber() * total
	local rarity = egg.odds[#egg.odds].rarity
	for _, o in egg.odds do
		r -= o.chance
		if r <= 0 then
			rarity = o.rarity
			break
		end
	end
	-- a Tung of that rarity, weighted like the belt
	local pool = Tungs.ByRarity[rarity] or Tungs.ByRarity.Rare
	local weight = 0
	for _, t in pool do
		weight += t.weight
	end
	local pick = rng:NextNumber() * weight
	local tung = pool[#pool]
	for _, t in pool do
		pick -= t.weight
		if pick <= 0 then
			tung = t
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
	return tung.id, mut
end

return Eggs
