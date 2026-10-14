--!strict
-- The 8 worlds (Design Doc §3). A galaxy-spanning salvage run — each world is a
-- different planet/station reached by a hyperspace jump.

export type World = {
	index: number,
	name: string,
	theme: string,
	planet: string, -- flavour text shown on the map card
	unlockRebirth: number,
	incomeMult: number, -- multiplier for droids STATIONED here
	power: number, -- base strength of droids that ORIGINATE here
	prefixes: { string }, -- droid name prefixes for this biome
	origin: Vector3, -- where the world is built in Workspace
	colors: { ground: Color3, accent: Color3, accent2: Color3, fog: Color3, ambient: Color3 },
	groundMaterial: Enum.Material,
	clockTime: number,
	fogEnd: number,
}

local SPACING = 3000

local function w(index: number, data: any): World
	data.index = index
	data.unlockRebirth = index - 1
	data.origin = Vector3.new((index - 1) * SPACING, 0, 0)
	data.power = 4 ^ (index - 1)
	return data :: World
end

local Worlds = {}

Worlds.List = {
	w(1, {
		name = "The Scrapyard",
		theme = "Ship graveyard",
		planet = "Rust-belt moon of the Kessra system. Crashed freighters as far as the eye can see.",
		incomeMult = 1,
		prefixes = { "Rust", "Scrap", "Junk", "Grit", "Slag", "Tin" },
		colors = {
			ground = Color3.fromRGB(150, 105, 70),
			accent = Color3.fromRGB(255, 150, 60),
			accent2 = Color3.fromRGB(110, 90, 80),
			fog = Color3.fromRGB(210, 150, 100),
			ambient = Color3.fromRGB(120, 90, 70),
		},
		groundMaterial = Enum.Material.Ground,
		clockTime = 16.5,
		fogEnd = 900,
	}),
	w(2, {
		name = "Undercroft",
		theme = "Underground neon city",
		planet = "A smuggler's warren carved beneath the crust, lit only by neon.",
		incomeMult = 1.5,
		prefixes = { "Neon", "Glow", "Volt", "Hex", "Pulse", "Wire" },
		colors = {
			ground = Color3.fromRGB(30, 28, 45),
			accent = Color3.fromRGB(255, 50, 200),
			accent2 = Color3.fromRGB(40, 220, 255),
			fog = Color3.fromRGB(40, 15, 60),
			ambient = Color3.fromRGB(80, 50, 120),
		},
		groundMaterial = Enum.Material.Slate,
		clockTime = 0,
		fogEnd = 500,
	}),
	w(3, {
		name = "Duneport",
		theme = "Desert trading outpost",
		planet = "A twin-sun desert spaceport. Traders, scavengers, and very warm droids.",
		incomeMult = 2,
		prefixes = { "Dune", "Sirocco", "Sand", "Mirage", "Ember", "Dust" },
		colors = {
			ground = Color3.fromRGB(230, 195, 130),
			accent = Color3.fromRGB(255, 120, 40),
			accent2 = Color3.fromRGB(200, 160, 110),
			fog = Color3.fromRGB(255, 220, 170),
			ambient = Color3.fromRGB(180, 140, 100),
		},
		groundMaterial = Enum.Material.Sand,
		clockTime = 13,
		fogEnd = 1200,
	}),
	w(4, {
		name = "Cloud Reach",
		theme = "Floating gas-mining platform",
		planet = "A mining city drifting through the pastel clouds of a gas giant.",
		incomeMult = 3,
		prefixes = { "Sky", "Zephyr", "Gale", "Nimbus", "Aero", "Cirrus" },
		colors = {
			ground = Color3.fromRGB(235, 225, 240),
			accent = Color3.fromRGB(255, 160, 120),
			accent2 = Color3.fromRGB(150, 190, 255),
			fog = Color3.fromRGB(255, 200, 190),
			ambient = Color3.fromRGB(200, 170, 180),
		},
		groundMaterial = Enum.Material.Marble,
		clockTime = 17.8,
		fogEnd = 1500,
	}),
	w(5, {
		name = "The Hatchery",
		theme = "Fabrication facility",
		planet = "A hive-world foundry where droids are grown in rows of glowing pods.",
		incomeMult = 4.5,
		prefixes = { "Hive", "Forge", "Brood", "Molt", "Chitin", "Spawn" },
		colors = {
			ground = Color3.fromRGB(140, 70, 50),
			accent = Color3.fromRGB(255, 90, 30),
			accent2 = Color3.fromRGB(255, 200, 80),
			fog = Color3.fromRGB(170, 80, 50),
			ambient = Color3.fromRGB(140, 70, 50),
		},
		groundMaterial = Enum.Material.Rock,
		clockTime = 18.3,
		fogEnd = 700,
	}),
	w(6, {
		name = "Frostspire",
		theme = "Ice planet",
		planet = "A frozen outpost where the wind howls and the droids never stop shivering.",
		incomeMult = 7,
		prefixes = { "Frost", "Rime", "Glacia", "Hail", "Tundra", "Floe" },
		colors = {
			ground = Color3.fromRGB(235, 245, 255),
			accent = Color3.fromRGB(120, 200, 255),
			accent2 = Color3.fromRGB(180, 230, 255),
			fog = Color3.fromRGB(210, 230, 250),
			ambient = Color3.fromRGB(170, 190, 220),
		},
		groundMaterial = Enum.Material.Snow,
		clockTime = 10,
		fogEnd = 600,
	}),
	w(7, {
		name = "Undercity Spire",
		theme = "Vertical mega-city",
		planet = "A planet-wide city. Air-traffic lanes stack a thousand levels high.",
		incomeMult = 10,
		prefixes = { "Spire", "Holo", "Chrome", "Sector", "Vertex", "Transit" },
		colors = {
			ground = Color3.fromRGB(70, 75, 90),
			accent = Color3.fromRGB(80, 170, 255),
			accent2 = Color3.fromRGB(255, 210, 90),
			fog = Color3.fromRGB(60, 70, 110),
			ambient = Color3.fromRGB(90, 100, 140),
		},
		groundMaterial = Enum.Material.Concrete,
		clockTime = 20,
		fogEnd = 1400,
	}),
	w(8, {
		name = "The Core Vault",
		theme = "Endgame reactor facility",
		planet = "A sealed reactor at the heart of a dead star. Only the bold salvage here.",
		incomeMult = 15,
		prefixes = { "Core", "Reactor", "Fusion", "Quasar", "Nova", "Singular" },
		colors = {
			ground = Color3.fromRGB(45, 45, 50),
			accent = Color3.fromRGB(255, 60, 60),
			accent2 = Color3.fromRGB(255, 255, 255),
			fog = Color3.fromRGB(80, 10, 10),
			ambient = Color3.fromRGB(120, 50, 50),
		},
		groundMaterial = Enum.Material.DiamondPlate,
		clockTime = 0,
		fogEnd = 800,
	}),
} :: { World }

Worlds.Count = #Worlds.List

-- Droids stationed in the world they were salvaged from get a home bonus.
Worlds.HomeBonus = 0.25

function Worlds.Get(index: number): World
	return Worlds.List[index]
end

function Worlds.IsUnlocked(index: number, rebirths: number, allMaps: boolean?): boolean
	if allMaps then
		return true
	end
	local world = Worlds.List[index]
	return world ~= nil and rebirths >= world.unlockRebirth
end

return Worlds
