--!strict
-- Crates, droid inventory, stationing, fusing, style tokens, recycling.

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crates = require(Shared.Config.Crates)
local Droids = require(Shared.Config.Droids)
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local Styles = require(Shared.Config.Styles)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Bus = require(script.Parent.Parent.Bus)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local DroidService = {}
local rng = Random.new()

local function countDroids(data: any): number
	local n = 0
	for _ in data.droids do
		n += 1
	end
	return n
end

local function stationedCount(data: any): number
	local n = 0
	for _, inst in data.droids do
		if inst.station then
			n += 1
		end
	end
	return n
end

local function announce(player: Player, droidId: number, style: string)
	local droid = Droids.Get(droidId)
	if not droid then
		return
	end
	local isMythic = droid.rarity == "Mythic"
	local isRainbow = style == "Rainbow"
	if not (isMythic or isRainbow or (droid.rarity == "Legendary" and style ~= "Standard")) then
		return
	end
	local label = (if style ~= "Standard" then string.upper(style) .. " " else "") .. droid.name
	Remotes.Event("Announce"):FireAllClients({
		player = player.DisplayName,
		userId = player.UserId,
		text = player.DisplayName .. " just unboxed a " .. label .. "!",
		rarity = droid.rarity,
		style = style,
		epic = isMythic and isRainbow, -- full-screen fireworks for everyone
	})
end

-- Adds a droid to the player's inventory and returns its uid.
function DroidService.Grant(player: Player, droidId: number, style: string, silent: boolean?): string?
	local p = DataService.Get(player)
	if not p then
		return nil
	end
	local data = p.data
	local uid = DataService.NewUid(data)
	local inst = { id = droidId, style = style, fuse = 0, t = os.time() }
	data.droids[uid] = inst
	data.discovered[tostring(droidId)] = true

	-- Quality of life: auto-station into the current world while slots are free.
	if stationedCount(data) < Economy.StationSlots(data) then
		inst.station = data.world
	end

	DataService.MarkDirty(player, true)
	Bus.Fire("DroidsChanged", player)
	if not silent then
		announce(player, droidId, style)
	end
	return uid
end

function DroidService.OpenCrate(player: Player, crateId: string, useFree: boolean): (boolean, any)
	local p = DataService.Get(player)
	local crate = Crates.Get(crateId)
	if not p or not crate then
		return false, "Unknown crate"
	end
	local data = p.data

	if countDroids(data) >= Economy.MAX_INVENTORY then
		return false, "Droid bay full! Recycle some droids first."
	end
	if crate.world and crate.world ~= data.world then
		return false, "Travel to " .. Worlds.Get(crate.world).name .. " to open this crate"
	end

	if useFree or crate.kind == "Guaranteed" then
		if (data.freeCrates[crateId] or 0) <= 0 then
			return false, "You don't have that crate"
		end
		data.freeCrates[crateId] -= 1
	elseif crate.currency == "Scrap" then
		if data.scrap < crate.cost then
			return false, "Not enough Scrap"
		end
		data.scrap -= crate.cost
	elseif crate.currency == "Nova" then
		if data.nova < crate.cost then
			return false, "Not enough Nova Crystals"
		end
		data.nova -= crate.cost
	else
		return false, "Can't buy that crate"
	end

	local result = Crates.Roll(crate, data.world, rng, Economy.Luck(data))
	local isNew = not data.discovered[tostring(result.droidId)]
	local uid = DroidService.Grant(player, result.droidId, result.style)

	data.stats.crates += 1
	if Rarities.Get(result.rarity).index >= 3 then
		data.stats.rares += 1
	end

	-- Rare drop: Salvage crates occasionally cough up a few Nova Crystals.
	local bonusNova = 0
	if crate.kind == "Salvage" and rng:NextNumber() < 0.05 then
		bonusNova = rng:NextInteger(1, 3)
		data.nova += bonusNova
	end

	DataService.MarkDirty(player, true)
	return true, {
		uid = uid,
		droidId = result.droidId,
		rarity = result.rarity,
		style = result.style,
		isNew = isNew,
		bonusNova = bonusNova,
		crateColor = crate.color,
	}
end

-- Stationing -----------------------------------------------------------------------
function DroidService.Station(player: Player, uid: string, world: number?): (boolean, string?)
	local p = DataService.Get(player)
	if not p then
		return false
	end
	local data = p.data
	local inst = data.droids[uid]
	if not inst then
		return false, "Droid not found"
	end
	if world == nil then
		inst.station = nil
	else
		if not Worlds.IsUnlocked(world, data.rebirths, data.allMaps) then
			return false, "World locked"
		end
		if not inst.station and stationedCount(data) >= Economy.StationSlots(data) then
			return false, "All station slots are full"
		end
		inst.station = world
	end
	DataService.MarkDirty(player, true)
	Bus.Fire("DroidsChanged", player)
	return true
end

-- Puts the strongest droids in the most lucrative unlocked worlds.
function DroidService.EquipBest(player: Player): boolean
	local p = DataService.Get(player)
	if not p then
		return false
	end
	local data = p.data
	local candidates = {}
	for uid, inst in data.droids do
		inst.station = nil
		local bestWorld, bestValue = 1, 0
		for wi in Worlds.List do
			if Worlds.IsUnlocked(wi, data.rebirths, data.allMaps) then
				local v = Economy.DroidIncome(inst, wi)
				if v > bestValue then
					bestWorld, bestValue = wi, v
				end
			end
		end
		table.insert(candidates, { inst = inst, world = bestWorld, v = bestValue })
	end
	table.sort(candidates, function(a, b)
		return a.v > b.v
	end)
	for i = 1, math.min(#candidates, Economy.StationSlots(data)) do
		candidates[i].inst.station = candidates[i].world
	end
	DataService.MarkDirty(player, true)
	Bus.Fire("DroidsChanged", player)
	return true
end

-- Fuse: 3 identical droids (same droid + style + fuse level) -> one at fuse+1.
function DroidService.Fuse(player: Player, uid: string): (boolean, string?)
	local p = DataService.Get(player)
	if not p then
		return false
	end
	local data = p.data
	local target = data.droids[uid]
	if not target then
		return false, "Droid not found"
	end
	if target.fuse >= Economy.MAX_FUSE then
		return false, "Already max fuse level"
	end
	local copies = {}
	for otherUid, inst in data.droids do
		if otherUid ~= uid and inst.id == target.id and inst.style == target.style and inst.fuse == target.fuse then
			table.insert(copies, { uid = otherUid, stationed = inst.station ~= nil })
		end
	end
	if #copies < Economy.FUSE_COPIES - 1 then
		return false, "Need " .. Economy.FUSE_COPIES .. " identical copies"
	end
	-- consume unstationed copies first
	table.sort(copies, function(a, b)
		return (not a.stationed) and b.stationed
	end)
	for i = 1, Economy.FUSE_COPIES - 1 do
		data.droids[copies[i].uid] = nil
	end
	target.fuse += 1
	data.stats.fuses += 1
	DataService.MarkDirty(player, true)
	Bus.Fire("DroidsChanged", player)
	return true
end

function DroidService.ApplyToken(player: Player, uid: string, style: string): (boolean, string?)
	local p = DataService.Get(player)
	if not p then
		return false
	end
	local data = p.data
	local inst = data.droids[uid]
	if not inst then
		return false, "Droid not found"
	end
	if not table.find(Styles.TokenStyles, style) then
		return false, "Invalid style"
	end
	if (data.tokens[style] or 0) <= 0 then
		return false, "No " .. style .. " tokens"
	end
	if inst.style == style then
		return false, "Already " .. style
	end
	data.tokens[style] -= 1
	inst.style = style
	DataService.MarkDirty(player, true)
	Bus.Fire("DroidsChanged", player)
	announce(player, inst.id, style)
	return true
end

function DroidService.Recycle(player: Player, uids: { string }): (boolean, string?)
	local p = DataService.Get(player)
	if not p or type(uids) ~= "table" or #uids > Economy.MAX_INVENTORY then
		return false
	end
	local data = p.data
	local total = 0
	for _, uid in uids do
		local inst = data.droids[uid]
		if inst and typeof(uid) == "string" then
			total += Economy.RecycleValue(inst) * Economy.RebirthMultiplier(data.rebirths)
			data.droids[uid] = nil
		end
	end
	total = math.floor(total)
	EconomyService.AddScrap(data, total)
	DataService.MarkDirty(player, true)
	Bus.Fire("DroidsChanged", player)
	return true, "Recycled for " .. Format.Number(total) .. " Scrap"
end

-- Showcase: the top droids that visibly follow the player (rendered client-side).
function DroidService.TopStationed(data: any, n: number): { any }
	local list = {}
	for _, inst in data.droids do
		if inst.station then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		return Economy.DroidScore(a) > Economy.DroidScore(b)
	end)
	local out = {}
	for i = 1, math.min(n, #list) do
		table.insert(out, { id = list[i].id, style = list[i].style })
	end
	return out
end

local function refreshShowcase(player: Player)
	local p = DataService.Get(player)
	if p then
		player:SetAttribute("Showcase", HttpService:JSONEncode(DroidService.TopStationed(p.data, Economy.SHOWCASE_COUNT)))
	end
end

function DroidService.Init()
	Bus.On("DroidsChanged", refreshShowcase)
	DataService.OnLoaded(function(profile)
		refreshShowcase(profile.player)
	end)
end

return DroidService
