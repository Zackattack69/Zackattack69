--!strict
-- All economy math in one place so the server (authoritative) and the client
-- (display/predictions) always agree. Tune pacing here (Design Doc §9.5).

local Droids = require(script.Parent.Droids)
local Styles = require(script.Parent.Styles)
local Worlds = require(script.Parent.Worlds)

local Economy = {}

Economy.STARTING_SCRAP = 100
Economy.MAX_INVENTORY = 400
Economy.MAX_FUSE = 5
Economy.FUSE_BONUS = 0.5 -- +50% power per fuse level
Economy.FUSE_COPIES = 3
Economy.MAX_CLICKS_PER_SECOND = 15
Economy.OFFLINE_CAP_SECONDS = 12 * 3600
Economy.OFFLINE_RATE = 0.5 -- Auto-Foundry pays 50% of live income while offline
Economy.SHOWCASE_COUNT = 4 -- droids that follow you around

-- Foundry upgrades (LOST on rebirth) -----------------------------------------
Economy.Upgrades = {
	{
		id = "Claws",
		name = "Salvage Claws",
		icon = "🦾",
		description = "+1 base Scrap per salvage click.",
		baseCost = 25,
		growth = 1.55,
		maxLevel = 100,
	},
	{
		id = "Assembly",
		name = "Assembly Line",
		icon = "🏭",
		description = "+15% droid income per level.",
		baseCost = 150,
		growth = 1.8,
		maxLevel = 50,
	},
	{
		id = "Bay",
		name = "Station Bay",
		icon = "🛰️",
		description = "+1 droid station slot.",
		baseCost = 400,
		growth = 3.2,
		maxLevel = 8,
	},
}
Economy.UpgradesById = {}
for _, u in Economy.Upgrades do
	Economy.UpgradesById[u.id] = u
end

function Economy.UpgradeCost(id: string, level: number, rebirths: number): number
	local u = Economy.UpgradesById[id]
	-- Each rebirth makes the next run's foundry 10x pricier (but you earn far more).
	return math.floor(u.baseCost * u.growth ^ level * 10 ^ rebirths)
end

-- Rebirth (Design Doc §4) ------------------------------------------------------
Economy.REBIRTH_MULT_STEP = 0.5

function Economy.RebirthCost(rebirths: number): number
	return 10_000 * 10 ^ rebirths -- 10K -> 100K -> 1M -> 10M ...
end

function Economy.RebirthMultiplier(rebirths: number): number
	return 1 + Economy.REBIRTH_MULT_STEP * rebirths
end

function Economy.RebirthNovaReward(rebirths: number): number
	return 25 + 10 * rebirths
end

Economy.RebirthTitles = {
	"Rust Aura",
	"Neon Aura",
	"Chrome Aura",
	"Cloud Aura",
	"Forge Aura",
	"Frost Aura",
	"Spire Aura",
}

Economy.RebirthColors = {
	Color3.fromRGB(205, 120, 60),
	Color3.fromRGB(255, 60, 210),
	Color3.fromRGB(220, 230, 240),
	Color3.fromRGB(255, 170, 150),
	Color3.fromRGB(255, 110, 30),
	Color3.fromRGB(120, 210, 255),
	Color3.fromRGB(255, 215, 90),
}

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
function Economy.Roman(n: number): string
	return ROMAN[n] or tostring(n)
end

function Economy.RebirthTitle(rebirths: number): string?
	if rebirths <= 0 then
		return nil
	end
	if rebirths <= #Economy.RebirthTitles then
		return "Rebirth " .. Economy.Roman(rebirths) .. " — " .. Economy.RebirthTitles[rebirths]
	end
	return "Prestige " .. Economy.Roman(rebirths - #Economy.RebirthTitles) .. " — Core Aura"
end

function Economy.RebirthColor(rebirths: number): Color3
	if rebirths <= 0 then
		return Color3.new(1, 1, 1)
	end
	if rebirths <= #Economy.RebirthColors then
		return Economy.RebirthColors[rebirths]
	end
	-- Prestige rebirths cycle hue for unique name-tag colors
	return Color3.fromHSV(((rebirths - 7) * 0.13) % 1, 0.7, 1)
end

-- Stations ----------------------------------------------------------------------
function Economy.StationSlots(data: any): number
	local slots = 6 + math.min(data.rebirths, 6) + (data.upgrades.Bay or 0)
	if Economy.HasPass(data, "VIP") then
		slots += 1
	end
	return slots
end

-- Passes --------------------------------------------------------------------------
-- VIP and Ultimate VIP+ include the effects of the other passes.
local PASS_INCLUDES = {
	DoubleScrap = { "VIP", "UltimateVIP" },
	AutoFoundry = { "VIP", "UltimateVIP" },
	DoubleLuck = { "VIP", "UltimateVIP" },
	VIP = { "UltimateVIP" },
}

function Economy.HasPass(data: any, pass: string): boolean
	if data.passes[pass] then
		return true
	end
	local inc = PASS_INCLUDES[pass]
	if inc then
		for _, p in inc do
			if data.passes[p] then
				return true
			end
		end
	end
	return false
end

function Economy.Luck(data: any): number
	return if Economy.HasPass(data, "DoubleLuck") then 2 else 1
end

function Economy.ScrapPassMult(data: any): number
	local m = 1
	if Economy.HasPass(data, "DoubleScrap") then
		m *= 2
	end
	if data.passes.UltimateVIP then
		m *= 1.5
	end
	return m
end

-- Droid power ----------------------------------------------------------------------
-- Scrap/sec a single owned droid would produce if stationed in `station`.
function Economy.DroidIncome(inst: any, station: number?): number
	local droid = Droids.Get(inst.id)
	if not droid then
		return 0
	end
	local style = Styles.Get(inst.style)
	local v = droid.power * (1 + style.bonus) * (1 + Economy.FUSE_BONUS * (inst.fuse or 0))
	local where = station or inst.station
	if where then
		local world = Worlds.Get(where)
		if world then
			v *= world.incomeMult
			if droid.world == where then
				v *= 1 + Worlds.HomeBonus
			end
		end
	end
	return v
end

-- Raw sort key for "best droid" (ignores where it's stationed)
function Economy.DroidScore(inst: any): number
	local droid = Droids.Get(inst.id)
	if not droid then
		return 0
	end
	return droid.power * (1 + Styles.Get(inst.style).bonus) * (1 + Economy.FUSE_BONUS * (inst.fuse or 0))
end

function Economy.GlobalMultiplier(data: any): number
	return Economy.RebirthMultiplier(data.rebirths)
		* (1 + 0.15 * (data.upgrades.Assembly or 0))
		* Economy.ScrapPassMult(data)
end

function Economy.IncomePerSecond(data: any): number
	local total = 0
	for _, inst in data.droids do
		if inst.station then
			total += Economy.DroidIncome(inst)
		end
	end
	return total * Economy.GlobalMultiplier(data)
end

function Economy.ClickValue(data: any): number
	local base = (1 + (data.upgrades.Claws or 0)) * Economy.RebirthMultiplier(data.rebirths) * Economy.ScrapPassMult(data)
	-- Clicks stay relevant late-game: each click is also worth 10% of a second of income.
	return math.floor(base + Economy.IncomePerSecond(data) * 0.1)
end

-- Scrap packs scale with progression so they're never worthless.
function Economy.ScrapPackAmount(data: any, fraction: number): number
	return math.floor(Economy.RebirthCost(data.rebirths) * fraction)
end

function Economy.RecycleValue(inst: any): number
	return math.floor(Economy.DroidScore(inst) * 20)
end

return Economy
