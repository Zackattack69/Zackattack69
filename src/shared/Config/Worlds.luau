--!strict
-- The 8 planets. Each one is reached by a hyperspace jump and is built at
-- server start from the terrain + set-piece settings below (see WorldBuilder).

export type TerrainSpec = {
	kind: "terrain" | "platform", -- terrain = generated landscape, platform = built floor (city / station / clouds)
	top: Enum.Material?, -- surface material
	base: Enum.Material?, -- material underneath / on slopes
	peak: Enum.Material?, -- material on the highest ground
	amplitude: number?, -- how tall the hills get
	frequency: number?, -- smaller = wider hills
	flatRadius: number?, -- the play area in the middle stays flat
	waterLevel: number?, -- fill valleys below this height with water
	lava: boolean?, -- valleys glow with lava instead of water
}

export type World = {
	index: number,
	name: string,
	theme: string,
	planet: string,
	unlockRebirth: number,
	incomeMult: number,
	power: number,
	origin: Vector3,
	colors: { ground: Color3, accent: Color3, accent2: Color3, fog: Color3, ambient: Color3, sky: Color3 },
	terrain: TerrainSpec,
	clockTime: number,
	fogEnd: number,
	haze: number,
	clouds: { cover: number, density: number, color: Color3 }?,
	starCount: number,
	icon: string,
}

local Names = require(script.Parent.StarWarsNames)

local SPACING = 3000

local function w(index: number, data: any): World
	local names = Names.Planets[index]
	data.name = names.name
	data.theme = names.theme
	data.planet = names.blurb
	data.index = index
	data.unlockRebirth = index - 1
	data.origin = Vector3.new((index - 1) * SPACING, 0, 0)
	data.power = 4 ^ (index - 1)
	return data :: World
end

local M = Enum.Material

local Worlds = {}

Worlds.List = {
	w(1, {
		icon = "🏜️",
		incomeMult = 1,
		colors = {
			ground = Color3.fromRGB(214, 170, 112),
			accent = Color3.fromRGB(255, 160, 60),
			accent2 = Color3.fromRGB(150, 155, 165),
			fog = Color3.fromRGB(235, 195, 150),
			ambient = Color3.fromRGB(150, 120, 90),
			sky = Color3.fromRGB(240, 200, 150),
		},
		terrain = { kind = "terrain", top = M.Sand, base = M.Sandstone, peak = M.Sandstone, amplitude = 34, frequency = 1 / 140, flatRadius = 230 },
		clockTime = 15.5,
		fogEnd = 1400,
		haze = 2.2,
		starCount = 0,
	}),
	w(2, {
		icon = "☀️",
		incomeMult = 1.5,
		colors = {
			ground = Color3.fromRGB(232, 200, 140),
			accent = Color3.fromRGB(255, 130, 50),
			accent2 = Color3.fromRGB(225, 205, 170),
			fog = Color3.fromRGB(255, 225, 175),
			ambient = Color3.fromRGB(190, 155, 110),
			sky = Color3.fromRGB(140, 190, 240),
		},
		terrain = { kind = "terrain", top = M.Sand, base = M.Sandstone, peak = M.Rock, amplitude = 55, frequency = 1 / 110, flatRadius = 170 },
		clockTime = 13.5,
		fogEnd = 2200,
		haze = 1.4,
		starCount = 0,
	}),
	w(3, {
		icon = "❄️",
		incomeMult = 2,
		colors = {
			ground = Color3.fromRGB(240, 248, 255),
			accent = Color3.fromRGB(110, 200, 255),
			accent2 = Color3.fromRGB(200, 205, 215),
			fog = Color3.fromRGB(215, 232, 250),
			ambient = Color3.fromRGB(175, 195, 225),
			sky = Color3.fromRGB(200, 220, 240),
		},
		terrain = { kind = "terrain", top = M.Snow, base = M.Glacier, peak = M.Ice, amplitude = 70, frequency = 1 / 120, flatRadius = 170 },
		clockTime = 11,
		fogEnd = 700,
		haze = 3,
		starCount = 0,
	}),
	w(4, {
		icon = "🌲",
		incomeMult = 3,
		colors = {
			ground = Color3.fromRGB(80, 120, 60),
			accent = Color3.fromRGB(255, 190, 90),
			accent2 = Color3.fromRGB(120, 95, 70),
			fog = Color3.fromRGB(150, 185, 150),
			ambient = Color3.fromRGB(100, 130, 95),
			sky = Color3.fromRGB(150, 200, 230),
		},
		terrain = { kind = "terrain", top = M.LeafyGrass, base = M.Mud, peak = M.Grass, amplitude = 40, frequency = 1 / 100, flatRadius = 160, waterLevel = -6 },
		clockTime = 9.5,
		fogEnd = 650,
		haze = 1.8,
		clouds = { cover = 0.55, density = 0.6, color = Color3.fromRGB(240, 245, 240) },
		starCount = 0,
	}),
	w(5, {
		icon = "☁️",
		incomeMult = 4.5,
		colors = {
			ground = Color3.fromRGB(240, 235, 240),
			accent = Color3.fromRGB(255, 150, 110),
			accent2 = Color3.fromRGB(255, 205, 180),
			fog = Color3.fromRGB(255, 190, 170),
			ambient = Color3.fromRGB(220, 170, 160),
			sky = Color3.fromRGB(255, 170, 130),
		},
		terrain = { kind = "platform", top = M.Marble },
		clockTime = 17.7,
		fogEnd = 2500,
		haze = 2.5,
		clouds = { cover = 0.85, density = 0.8, color = Color3.fromRGB(255, 200, 185) },
		starCount = 0,
	}),
	w(6, {
		icon = "🌋",
		incomeMult = 7,
		colors = {
			ground = Color3.fromRGB(45, 35, 35),
			accent = Color3.fromRGB(255, 90, 20),
			accent2 = Color3.fromRGB(80, 75, 80),
			fog = Color3.fromRGB(120, 40, 20),
			ambient = Color3.fromRGB(150, 70, 50),
			sky = Color3.fromRGB(120, 30, 15),
		},
		terrain = { kind = "terrain", top = M.Basalt, base = M.CrackedLava, peak = M.Basalt, amplitude = 60, frequency = 1 / 90, flatRadius = 150, waterLevel = -4, lava = true },
		clockTime = 19,
		fogEnd = 600,
		haze = 3,
		starCount = 1000,
	}),
	w(7, {
		icon = "🏙️",
		incomeMult = 10,
		colors = {
			ground = Color3.fromRGB(110, 115, 130),
			accent = Color3.fromRGB(90, 180, 255),
			accent2 = Color3.fromRGB(255, 210, 120),
			fog = Color3.fromRGB(80, 95, 140),
			ambient = Color3.fromRGB(110, 120, 160),
			sky = Color3.fromRGB(60, 70, 130),
		},
		terrain = { kind = "platform", top = M.Concrete },
		clockTime = 19.6,
		fogEnd = 2600,
		haze = 1.6,
		starCount = 3000,
	}),
	w(8, {
		icon = "🌑",
		incomeMult = 15,
		colors = {
			ground = Color3.fromRGB(70, 72, 80),
			accent = Color3.fromRGB(255, 60, 60),
			accent2 = Color3.fromRGB(150, 155, 165),
			fog = Color3.fromRGB(10, 10, 20),
			ambient = Color3.fromRGB(110, 110, 130),
			sky = Color3.fromRGB(5, 5, 15),
		},
		terrain = { kind = "platform", top = M.DiamondPlate },
		clockTime = 0,
		fogEnd = 3000,
		haze = 0,
		starCount = 5000,
	}),
} :: { World }

Worlds.Count = #Worlds.List

-- Droids stationed on the planet they were salvaged from get a home bonus.
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
