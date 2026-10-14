--!strict
-- Player data: load / autosave / session lock / sync to client.
-- Falls back to in-memory data when DataStores are unavailable (e.g. Studio
-- without "Enable Studio Access to API Services"), so the game is always playable.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Quests = require(Shared.Config.Quests)
local Remotes = require(Shared.Remotes)

local STORE_NAME = "DroidFoundry_v1"
local AUTOSAVE_INTERVAL = 90
local LOCK_EXPIRY = 300
local MAX_RECEIPTS = 60

local DataService = {}

export type Profile = {
	player: Player,
	data: any,
	key: string,
	dirtyStats: boolean,
	dirtyFull: boolean,
	clickWindow: { number },
	lastSave: number,
	released: boolean,
}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Profile) -> () } = {}
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, using session-only data:", result)
	end
end

local function defaultData(): any
	return {
		version = 1,
		scrap = Economy.STARTING_SCRAP,
		totalScrap = 0,
		nova = 0,
		rebirths = 0,
		upgrades = { Claws = 0, Assembly = 0, Bay = 0 },
		droids = {}, -- [uid string] = { id, style, fuse, station?, t }
		nextUid = 1,
		discovered = {}, -- [tostring(droidId)] = true
		tokens = { RebirthSkip = 0, Gold = 0, Diamond = 0, Shadow = 0, Neon = 0, Rainbow = 0 },
		freeCrates = { Guaranteed_Common = 1 }, -- first crate is free (onboarding)
		passes = {},
		allMaps = false,
		autoClickUntil = 0,
		world = 1,
		quests = {},
		stats = { clicks = 0, crates = 0, fuses = 0, upgrades = 0, rares = 0, travels = 0, minutes = 0 },
		titles = {},
		equippedTitle = "",
		flags = {},
		lastOnline = 0,
		lastMonthly = "",
		onboarded = false,
		receipts = {},
		receiptOrder = {},
	}
end

-- Fill in any keys added in later versions without touching existing values.
local function reconcile(target: any, template: any)
	for k, v in template do
		if target[k] == nil then
			target[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(target[k], v)
		end
	end
end

local function ensureQuests(data: any)
	local rng = Random.new()
	while #data.quests < Quests.ACTIVE do
		table.insert(data.quests, Quests.Roll(rng, data.quests, data.stats))
	end
end

local function withRetries<T>(fn: () -> T, attempts: number): (boolean, T | string)
	local lastErr
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(i * 2)
	end
	return false, tostring(lastErr)
end

local function load(player: Player): any?
	local key = "Player_" .. player.UserId
	if not store then
		return defaultData()
	end
	local ds = store :: DataStore
	for attempt = 1, 5 do
		local lockedByOther = false
		local ok, result = withRetries(function()
			return ds:UpdateAsync(key, function(old)
				old = old or defaultData()
				local lock = old.lock
				if lock and lock.job ~= game.JobId and os.time() - lock.t < LOCK_EXPIRY and attempt < 5 then
					lockedByOther = true
					return nil -- don't write; another server still owns this session
				end
				old.lock = { job = game.JobId, t = os.time() }
				return old
			end)
		end, 3)
		if not ok then
			warn("[DataService] Failed to load", player.Name, result)
			return nil
		end
		if not lockedByOther then
			return result
		end
		task.wait(4) -- previous server is probably still saving
	end
	return nil
end

function DataService.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or profile.released then
		return false
	end
	profile.data.lastOnline = os.time()
	if not store then
		return true
	end
	local ds = store :: DataStore
	local snapshot = profile.data
	local ok, err = withRetries(function()
		return ds:UpdateAsync(profile.key, function(old)
			if old and old.lock and old.lock.job ~= game.JobId then
				-- Another server stole the lock (we were too slow); don't clobber it.
				return nil
			end
			snapshot.lock = if release then nil else { job = game.JobId, t = os.time() }
			return snapshot
		end)
	end, 3)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
	profile.lastSave = os.clock()
	return ok
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

-- Yields until the profile loads (or the player leaves).
function DataService.WaitFor(player: Player, timeout: number?): Profile?
	local start = os.clock()
	while not profiles[player] and player.Parent and os.clock() - start < (timeout or 30) do
		task.wait(0.2)
	end
	return profiles[player]
end

function DataService.OnLoaded(cb: (Profile) -> ())
	table.insert(loadedCallbacks, cb)
	for _, p in profiles do
		task.spawn(cb, p)
	end
end

function DataService.MarkDirty(player: Player, full: boolean?)
	local p = profiles[player]
	if p then
		p.dirtyStats = true
		if full then
			p.dirtyFull = true
		end
	end
end

function DataService.RecordReceipt(profile: Profile, purchaseId: string)
	local data = profile.data
	data.receipts[purchaseId] = os.time()
	table.insert(data.receiptOrder, purchaseId)
	while #data.receiptOrder > MAX_RECEIPTS do
		local old = table.remove(data.receiptOrder, 1)
		data.receipts[old] = nil
	end
end

function DataService.NewUid(data: any): string
	local uid = "d" .. data.nextUid
	data.nextUid += 1
	return uid
end

-- Snapshots sent to the client ---------------------------------------------------
local function statsSnapshot(data: any): any
	return {
		scrap = data.scrap,
		nova = data.nova,
		rebirths = data.rebirths,
		income = Economy.IncomePerSecond(data),
		clickValue = Economy.ClickValue(data),
		autoClickUntil = data.autoClickUntil,
		stats = data.stats,
	}
end

local function fullSnapshot(data: any): any
	local snap = statsSnapshot(data)
	snap.upgrades = data.upgrades
	snap.droids = data.droids
	snap.discovered = data.discovered
	snap.tokens = data.tokens
	snap.freeCrates = data.freeCrates
	snap.passes = data.passes
	snap.allMaps = data.allMaps
	snap.world = data.world
	snap.quests = data.quests
	snap.titles = data.titles
	snap.equippedTitle = data.equippedTitle
	snap.onboarded = data.onboarded
	snap.slots = Economy.StationSlots(data)
	return snap
end

function DataService.Flush(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	if p.dirtyFull then
		Remotes.Event("State"):FireClient(player, fullSnapshot(p.data))
	elseif p.dirtyStats then
		Remotes.Event("Stats"):FireClient(player, statsSnapshot(p.data))
	end
	p.dirtyFull = false
	p.dirtyStats = false
end

-- Lifecycle -------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local data = load(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("Couldn't load your foundry data. Please rejoin in a moment!")
		return
	end
	reconcile(data, defaultData())
	ensureQuests(data)

	local profile: Profile = {
		player = player,
		data = data,
		key = "Player_" .. player.UserId,
		dirtyStats = true,
		dirtyFull = true,
		clickWindow = {},
		lastSave = os.clock(),
		released = false,
	}
	profiles[player] = profile
	player:SetAttribute("Loaded", true)
	for _, cb in loadedCallbacks do
		task.spawn(cb, profile)
	end
	DataService.Flush(player)
end

local function onPlayerRemoving(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	DataService.Save(player, true)
	p.released = true
	profiles[player] = nil
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Batched client sync (~5x/sec) keeps remote traffic low.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in profiles do
				DataService.Flush(player)
			end
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, p in profiles do
				if os.clock() - p.lastSave >= AUTOSAVE_INTERVAL then
					task.spawn(DataService.Save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
