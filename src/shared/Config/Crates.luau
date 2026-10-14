--!strict
-- Crate definitions + the weighted RNG (Design Doc §9.2: rarity first, then an
-- independent style roll).

local Droids = require(script.Parent.Droids)
local Rarities = require(script.Parent.Rarities)
local Styles = require(script.Parent.Styles)
local Worlds = require(script.Parent.Worlds)

export type Crate = {
	id: string,
	name: string,
	kind: string, -- "Salvage" | "Nova" | "Relic" | "Guaranteed"
	world: number?, -- nil = use the opener's current world
	currency: string?, -- "Scrap" | "Nova" | nil (free/purchased only)
	cost: number,
	odds: { [string]: number }, -- rarity -> weight
	mythicChance: number, -- extra flat chance to upgrade into a Mythic (0.001 = 0.1%)
	color: Color3,
	description: string,
}

local Crates = {}
Crates.ById = {} :: { [string]: Crate }
Crates.ByWorld = {} :: { [number]: { Crate } }

Crates.MYTHIC_CHANCE = 0.001 -- 0.1% in ANY crate (Design Doc §5.1)

local function register(c: Crate)
	Crates.ById[c.id] = c
	if c.world then
		Crates.ByWorld[c.world] = Crates.ByWorld[c.world] or {}
		table.insert(Crates.ByWorld[c.world], c)
	end
end

for wi, world in Worlds.List do
	register({
		id = "W" .. wi .. "_Salvage",
		name = world.name .. " Salvage Crate",
		kind = "Salvage",
		world = wi,
		currency = "Scrap",
		cost = 60 * 10 ^ (wi - 1),
		odds = { Common = 75, Uncommon = 25 },
		mythicChance = Crates.MYTHIC_CHANCE,
		color = Color3.fromRGB(90, 170, 255),
		description = "Common & Uncommon droids from " .. world.name .. ".",
	})
	register({
		id = "W" .. wi .. "_Nova",
		name = world.name .. " Nova Crate",
		kind = "Nova",
		world = wi,
		currency = "Nova",
		cost = 15 + 10 * (wi - 1),
		odds = { Uncommon = 20, Rare = 60, Epic = 20 },
		mythicChance = Crates.MYTHIC_CHANCE,
		color = Color3.fromRGB(170, 90, 255),
		description = "Rare & Epic droids. Paid with Nova Crystals.",
	})
	register({
		id = "W" .. wi .. "_Relic",
		name = world.name .. " Relic Crate",
		kind = "Relic",
		world = wi,
		currency = "Nova",
		cost = 60 + 30 * (wi - 1),
		odds = { Rare = 40, Epic = 45, Legendary = 15 },
		mythicChance = Crates.MYTHIC_CHANCE,
		color = Color3.fromRGB(255, 190, 40),
		description = "Map-exclusive Legendaries live here.",
	})
end

-- Guaranteed-rarity crates: granted by rebirths and Robux purchases. They roll
-- from the opener's current world (Mythic pulls from the global pool).
for _, rarityName in { "Common", "Rare", "Epic", "Legendary", "Mythic" } do
	local r = Rarities.Get(rarityName)
	register({
		id = "Guaranteed_" .. rarityName,
		name = if rarityName == "Common" then "Salvage Crate" else rarityName .. " Crate",
		kind = "Guaranteed",
		currency = nil,
		cost = 0,
		odds = if rarityName == "Common" then { Common = 75, Uncommon = 25 } else { [rarityName] = 1 },
		mythicChance = if rarityName == "Mythic" then 0 else Crates.MYTHIC_CHANCE,
		color = r.color,
		description = if rarityName == "Common"
			then "A free Salvage Crate from your current world."
			else "Guaranteed " .. rarityName .. " droid!",
	})
end

function Crates.Get(id: string): Crate?
	return Crates.ById[id]
end

-- Returns the effective odds table after luck is applied: every tier above the
-- crate's lowest tier gets its weight multiplied by `luck`.
function Crates.EffectiveOdds(crate: Crate, luck: number): ({ [string]: number }, number)
	local odds = {}
	local total = 0
	local lowest = math.huge
	for rarityName in crate.odds do
		lowest = math.min(lowest, Rarities.Get(rarityName).index)
	end
	for rarityName, weight in crate.odds do
		local r = Rarities.Get(rarityName)
		local wgt = if r.index > lowest then weight * luck else weight
		odds[rarityName] = wgt
		total += wgt
	end
	return odds, total
end

export type RollResult = { droidId: number, rarity: string, style: string }

-- Pure function: no side effects. `world` is the opener's current world (used
-- for Guaranteed crates). `forcedStyle` comes from Style Guarantee Tokens.
function Crates.Roll(crate: Crate, world: number, rng: Random, luck: number?, forcedStyle: string?): RollResult
	local luckMult = luck or 1
	local rarityName: string

	if crate.mythicChance > 0 and rng:NextNumber() < crate.mythicChance * luckMult then
		rarityName = "Mythic"
	else
		local odds, total = Crates.EffectiveOdds(crate, luckMult)
		local roll = rng:NextNumber() * total
		-- iterate in rarity order so results are deterministic for a given seed
		rarityName = "Common"
		for _, r in Rarities.List do
			local wgt = odds[r.name]
			if wgt then
				rarityName = r.name
				if roll < wgt then
					break
				end
				roll -= wgt
			end
		end
	end

	local pool = Droids.Pool(rarityName, crate.world or world)
	if #pool == 0 then
		pool = Droids.Pool(rarityName, nil)
	end
	local droid = pool[rng:NextInteger(1, #pool)]
	local style = forcedStyle or Styles.Roll(rng, if luckMult > 1 then 1.25 else 1)
	return { droidId = droid.id, rarity = rarityName, style = style }
end

return Crates
