--!strict
-- The droid roster, generated deterministically from StarWarsNames.luau:
--   * every generic model exists once per planet  ("Hothdog B1 Battle Droid")
--   * 3 named Legendaries per planet
--   * 6 Mythics + 12 Iconics in a global pool
-- Every server and client builds the exact same table, so IDs are stable as
-- long as you only ADD entries to the END of a list in StarWarsNames.luau.

local Names = require(script.Parent.StarWarsNames)
local Rarities = require(script.Parent.Rarities)
local Worlds = require(script.Parent.Worlds)

export type Droid = {
	id: number,
	name: string,
	rarity: string,
	world: number, -- 0 = global pool (Mythic / Iconic) or exclusive
	power: number, -- base Credits/sec before multipliers
	shape: string,
	colors: { Color3 }, -- { body, accent, trim }
	exclusive: boolean?,
}

local MYTHIC_POWER_WORLD = 3 -- a Mythic hits like a planet-3 droid x120
local ICONIC_POWER_WORLD = 4 -- an Iconic hits like a planet-4 droid x400

local Droids = {}
Droids.List = {} :: { Droid }
Droids.ById = {} :: { [number]: Droid }
Droids.ByWorldRarity = {} :: { [number]: { [string]: { Droid } } }
Droids.ByRarity = {} :: { [string]: { Droid } }
Droids.ByName = {} :: { [string]: Droid }

local function add(d: Droid)
	assert(Droids.ByName[d.name] == nil, "Duplicate droid name: " .. d.name)
	table.insert(Droids.List, d)
	Droids.ById[d.id] = d
	Droids.ByName[d.name] = d
	if not d.exclusive then
		Droids.ByRarity[d.rarity] = Droids.ByRarity[d.rarity] or {}
		table.insert(Droids.ByRarity[d.rarity], d)
		if d.world > 0 then
			local wr = Droids.ByWorldRarity[d.world]
			wr[d.rarity] = wr[d.rarity] or {}
			table.insert(wr[d.rarity], d)
		end
	end
end

do
	local nextId = 1
	for wi = 1, Worlds.Count do
		Droids.ByWorldRarity[wi] = {}
	end

	-- Generic models: one per planet
	for _, tier in { "Common", "Uncommon", "Rare", "Epic" } do
		local rarity = Rarities.Get(tier)
		for wi, world in Worlds.List do
			local tag = Names.Planets[wi].tag
			for _, model in Names.Models[tier] do
				add({
					id = nextId,
					name = tag .. " " .. model.name,
					rarity = tier,
					world = wi,
					power = rarity.multiplier * world.power,
					shape = model.shape,
					-- planet variants are tinted towards the planet's colours
					colors = { model.colors[1]:Lerp(world.colors.accent2, 0.25), model.colors[2], model.colors[3] },
				})
				nextId += 1
			end
		end
	end

	local legendary = Rarities.Get("Legendary")
	for _, entry in Names.Legendary do
		add({
			id = nextId,
			name = entry.name,
			rarity = "Legendary",
			world = entry.world,
			power = legendary.multiplier * Worlds.Get(entry.world).power,
			shape = entry.shape,
			colors = entry.colors,
		})
		nextId += 1
	end

	for _, tier in { "Mythic", "Iconic" } do
		local rarity = Rarities.Get(tier)
		local powerWorld = if tier == "Mythic" then MYTHIC_POWER_WORLD else ICONIC_POWER_WORLD
		for _, entry in (Names :: any)[tier] do
			add({
				id = nextId,
				name = entry.name,
				rarity = tier,
				world = 0,
				power = rarity.multiplier * 4 ^ (powerWorld - 1),
				shape = entry.shape,
				colors = entry.colors,
			})
			nextId += 1
		end
	end
	Droids.RosterSize = nextId - 1

	-- Shop / gamepass exclusives live outside the collectible roster.
	add({ id = 1001, name = Names.Founder.name, rarity = "Legendary", world = 0, power = 40 * 4 ^ 4, shape = Names.Founder.shape, colors = Names.Founder.colors, exclusive = true })
	add({ id = 1002, name = Names.VIP.name, rarity = "Epic", world = 0, power = 15 * 4 ^ 3, shape = Names.VIP.shape, colors = Names.VIP.colors, exclusive = true })
end

Droids.FOUNDER_ID = 1001
Droids.VIP_ID = 1002

function Droids.Get(id: number): Droid?
	return Droids.ById[id]
end

-- Pool for a crate. world = nil means "all worlds". Mythic/Iconic are always global.
function Droids.Pool(rarity: string, world: number?): { Droid }
	if rarity == "Mythic" or rarity == "Iconic" or world == nil then
		return Droids.ByRarity[rarity] or {}
	end
	local wr = Droids.ByWorldRarity[world]
	return (wr and wr[rarity]) or {}
end

return Droids
