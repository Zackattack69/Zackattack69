--!strict
-- Player data: load / autosave every 60 s / save on leave / session lock / sync
-- to client. Falls back to in-memory data when DataStores are unavailable (e.g.
-- Studio without "Enable Studio Access to API Services"), so the game always runs.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BaseSkins = require(Shared.Config.BaseSkins)
local Economy = require(Shared.Config.Economy)
local GameConfig = require(Shared.Config.GameConfig)
local Tungs = require(Shared.Config.Tungs)
local Remotes = require(Shared.Remotes)

local AUTOSAVE_INTERVAL = 60
local LOCK_EXPIRY = 300
local MAX_RECEIPTS = 60

local DataService = {}

export type Profile = {
	player: Player,
	data: any,
	key: string,
	dirtyStats: boolean,
	dirtyFull: boolean,
	lastSave: number,
	released: boolean,
}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Profile) -> () } = {}
local releasingCallbacks: { (Profile) -> () } = {}
local store: DataStore? = nil

-- Extra fields merged into every snapshot (income, multiplier, base index...).
-- Set by EconomyService so this module stays free of gameplay logic.
DataService.Decorate = nil :: ((Player, any, any) -> ())?

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
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
		money = Economy.STARTING_MONEY,
		totalEarned = 0,
		rebirths = 0,
		slots = {}, -- ["1".."31"] = { id, m (mutation), u (uid), s (stored money) }
		pending = {}, -- Tungs waiting for a free slot: { {id, m, u} }
		nextUid = 1,
		index = {}, -- [tungId] = { t = first found (unix), m = { [mutation] = true } }
		indexRewards = {}, -- [rarity] = true, Mut_<key> = true, Master = true
		aura = "", -- equipped mutation aura cosmetic
		baseSkin = BaseSkins.DEFAULT, -- chosen base look (Config/BaseSkins)
		collected = {}, -- [rarity] = Tungs of that rarity ever collected (unlocks rarity base styles)
		items = { Bat = 1, SpeedCoil = false, Banana = false, Honey = false, Alarm = false },
		boosts = { Money2x = 0, Luck2x = 0 }, -- unix time the boost ends
		tokens = { SkipRebirth = 0 },
		passes = {},
		stats = { steals = 0, stolen = 0, bought = 0, sold = 0, collected = 0, bonks = 0 },
		playtime = 0,
		login = { streak = 0, lastDay = -1 },
		quests = { day = -1, list = {} },
		settings = { music = 0.5, sfx = 0.8, low = false, hideAuras = false },
		flags = {},
		receipts = {},
		receiptOrder = {},
		lastOnline = 0,
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
		task.wait(4) -- the previous server is probably still saving
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
				return nil -- another server took the lock; don't clobber it
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

function DataService.All(): { [Player]: Profile }
	return profiles
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

-- Runs (synchronously) just before a leaving player's data is saved.
function DataService.OnReleasing(cb: (Profile) -> ())
	table.insert(releasingCallbacks, cb)
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
	local uid = "t" .. data.nextUid
	data.nextUid += 1
	return uid
end

-- Snapshots sent to the client ---------------------------------------------------
local function statsSnapshot(player: Player, data: any): any
	local snap = {
		money = data.money,
		totalEarned = data.totalEarned,
		rebirths = data.rebirths,
		playtime = data.playtime,
		boosts = data.boosts,
		stats = data.stats,
	}
	if DataService.Decorate then
		DataService.Decorate(player, data, snap)
	end
	return snap
end

local function fullSnapshot(player: Player, data: any): any
	local snap = statsSnapshot(player, data)
	snap.slots = data.slots
	snap.pending = data.pending
	snap.index = data.index
	snap.indexRewards = data.indexRewards
	snap.aura = data.aura
	snap.baseSkin = data.baseSkin
	snap.collected = data.collected
	snap.items = data.items
	snap.tokens = data.tokens
	snap.passes = data.passes
	snap.login = data.login
	snap.quests = data.quests
	snap.settings = data.settings
	snap.flags = data.flags
	snap.full = true
	return snap
end

function DataService.Flush(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	if p.dirtyFull then
		Remotes.Event("State"):FireClient(player, fullSnapshot(player, p.data))
	elseif p.dirtyStats then
		Remotes.Event("Stats"):FireClient(player, statsSnapshot(player, p.data))
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
		player:Kick("Couldn't load your Tung data. Please rejoin in a moment!")
		return
	end
	reconcile(data, defaultData())
	-- saves from before base skins: count each Tung already in the Index once
	if not data.flags.collectedSeeded then
		data.flags.collectedSeeded = true
		for id in data.index do
			local t = Tungs.Get(id)
			if t then
				data.collected[t.rarity] = (data.collected[t.rarity] or 0) + 1
			end
		end
	end

	local profile: Profile = {
		player = player,
		data = data,
		key = "Player_" .. player.UserId,
		dirtyStats = true,
		dirtyFull = true,
		lastSave = os.clock(),
		released = false,
	}
	profiles[player] = profile
	for _, cb in loadedCallbacks do
		task.spawn(cb, profile)
	end
	player:SetAttribute("Loaded", true)
	DataService.Flush(player)
end

local function onPlayerRemoving(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	for _, cb in releasingCallbacks do
		local ok, err = pcall(cb :: any, p)
		if not ok then
			warn("[DataService] release callback failed:", err)
		end
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

	-- Autosave every 60 seconds.
	task.spawn(function()
		while true do
			task.wait(5)
			for player, p in profiles do
				if os.clock() - p.lastSave >= AUTOSAVE_INTERVAL then
					p.lastSave = os.clock()
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
		for player, p in profiles do
			pending += 1
			task.spawn(function()
				for _, cb in releasingCallbacks do
					pcall(cb, p)
				end
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
