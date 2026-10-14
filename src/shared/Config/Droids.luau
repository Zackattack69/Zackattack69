--!strict
-- The full 300-droid roster, generated deterministically from the naming
-- framework in Design Doc §5.1 (biome prefix + rarity suffix). Every server and
-- client builds the exact same table, so droid IDs are stable forever.
--
-- To hand-tune a droid, add an entry to OVERRIDES (keyed by generated id).

local Rarities = require(script.Parent.Rarities)
local Worlds = require(script.Parent.Worlds)

export type Droid = {
	id: number,
	name: string,
	rarity: string,
	world: number, -- 0 = global (Mythics) / exclusives
	power: number, -- base Scrap/sec before multipliers
	shape: string, -- visual chassis: "Dome" | "Humanoid" | "Orb" | "Walker" | "Tank"
	exclusive: boolean?,
}

local SUFFIXES = {
	Common = { "Bolt", "Scraplet", "Sprocket", "Rivet", "Gizmo", "Cogling", "Bleeper", "Servo", "Widget", "Puttergear", "Nubbin", "Clanker" },
	Uncommon = { "Sentinel", "Runner", "Clamp", "Loader", "Patroller", "Welder", "Scout", "Hauler", "Tracker", "Mender" },
	Rare = { "Warden", "Interceptor", "Nightwire", "Enforcer", "Gunner", "Seeker", "Marauder", "Vanguard" },
	Epic = { "Anchor", "Prime", "Voidframe", "Juggernaut", "Overseer", "Reaver" },
	Legendary = { "Titan", "Eclipse", "Matriarch" },
}

-- Hand-written names from the design doc for The Scrapyard (world 1).
local WORLD1_NAMES = {
	Common = { "Rust Bolt", "Scraplet", "Wrench-E", "Tinbit", "Puttergear" },
	Uncommon = { "Cog Sentinel", "Volt Runner", "Ironclamp" },
	Rare = { "Plasma Warden", "Skyhauler", "Nightwire" },
	Epic = { "Dread Anchor", "Solaris Prime", "Voidframe" },
	Legendary = { "Titan Core", "Eclipse Warden", "The Forgemother" },
}

local MYTHICS = { "Genesis Unit", "The Last Custodian", "Starforge Sovereign", "Omega Chassis", "The Architect", "Null Prime" }
local MYTHIC_POWER_WORLD = 3 -- mythics hit as hard as a world-3 droid ×120

local SHAPES = { "Dome", "Humanoid", "Orb", "Walker", "Tank" }

local OVERRIDES: { [number]: { [string]: any } } = {}

local Droids = {}
Droids.List = {} :: { Droid }
Droids.ById = {} :: { [number]: Droid }
Droids.ByWorldRarity = {} :: { [number]: { [string]: { Droid } } }
Droids.ByRarity = {} :: { [string]: { Droid } }
Droids.ByName = {} :: { [string]: Droid }

local function add(d: Droid)
	local o = OVERRIDES[d.id]
	if o then
		for k, v in o do
			(d :: any)[k] = v
		end
	end
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

-- Build roster ----------------------------------------------------------------
do
	local nextId = 1
	for wi = 1, Worlds.Count do
		Droids.ByWorldRarity[wi] = {}
	end

	for _, rarity in Rarities.List do
		if rarity.name ~= "Mythic" then
			-- Spread this rarity's count across the 8 worlds; earlier worlds take the remainder.
			local base = rarity.count // Worlds.Count
			local extra = rarity.count % Worlds.Count
			for wi, world in Worlds.List do
				local n = base + (if wi <= extra then 1 else 0)
				for i = 1, n do
					local name
					local w1 = WORLD1_NAMES[rarity.name]
					if wi == 1 and w1 and w1[i] then
						name = w1[i]
					else
						local prefix = world.prefixes[((i - 1) % #world.prefixes) + 1]
						name = prefix .. " " .. SUFFIXES[rarity.name][i]
					end
					add({
						id = nextId,
						name = name,
						rarity = rarity.name,
						world = wi,
						power = rarity.multiplier * world.power,
						shape = SHAPES[((nextId * 7) % #SHAPES) + 1],
					})
					nextId += 1
				end
			end
		end
	end

	local mythic = Rarities.Get("Mythic")
	for i, name in MYTHICS do
		add({
			id = nextId,
			name = name,
			rarity = "Mythic",
			world = 0,
			power = mythic.multiplier * (4 ^ (MYTHIC_POWER_WORLD - 1)),
			shape = SHAPES[((i - 1) % #SHAPES) + 1],
		})
		nextId += 1
	end
	Droids.RosterSize = nextId - 1

	-- Shop / gamepass exclusives live outside the 300 collectible roster.
	add({ id = 1001, name = "Founder's Vanguard", rarity = "Legendary", world = 0, power = 40 * 4 ^ 4, shape = "Humanoid", exclusive = true })
	add({ id = 1002, name = "Holo-Courier VIP", rarity = "Epic", world = 0, power = 15 * 4 ^ 3, shape = "Orb", exclusive = true })
end

Droids.FOUNDER_ID = 1001
Droids.VIP_ID = 1002
Droids.ARCHITECT_ID = Droids.ByName["The Architect"].id

function Droids.Get(id: number): Droid?
	return Droids.ById[id]
end

-- Pool for a crate. world = nil means "all worlds".
function Droids.Pool(rarity: string, world: number?): { Droid }
	if rarity == "Mythic" or world == nil then
		return Droids.ByRarity[rarity] or {}
	end
	local wr = Droids.ByWorldRarity[world]
	return (wr and wr[rarity]) or {}
end

return Droids
