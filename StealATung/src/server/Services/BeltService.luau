--!strict
-- The conveyor belt. A new Tung spawns every 3 s and rides the belt for 25 s,
-- then drops into the hole. The server only keeps a list of entries (what,
-- when, from where to where); every client renders and animates the models
-- itself, so nothing moves over the network. Buying is validated here against
-- the entry's computed position.
--
-- Also: the Rebirth 6 personal belt, Instant Tung (Robux), admin spawns, rare
-- spawn hype, and the cross-server Mythic broadcast.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local GameConfig = require(Shared.Config.GameConfig)
local Layout = require(Shared.Config.Layout)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local BeltService = {}

export type Entry = {
	id: number,
	tung: string,
	mut: string,
	a: Vector3,
	b: Vector3,
	t0: number,
	dur: number,
	owner: number?, -- only this UserId may buy it
	free: boolean?,
	belt: string, -- "main" | "p<base>"
}

local entries: { [number]: Entry } = {}
local nextId = 0
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function eventIs(key: string): boolean
	return Workspace:GetAttribute("Event") == key
end

local function serverLuck(): number
	return (Workspace:GetAttribute("ServerLuck") :: number?) or 1
end

-- The main belt uses the best personal luck in the server (Rebirth 4, Lucky Belt,
-- Luck Potions), times server-wide luck (Server Luck Potion, Admin Abuse).
local function bestPersonalLuck(): number
	local best = 1
	local t = os.time()
	for _, p in DataService.All() do
		best = math.max(best, Economy.PersonalLuck(p.data, t))
	end
	return best
end

local function roll(luck: number): (string, string)
	local sahur = if eventIs("SahurHour") then 3 else 1
	local rarity = Rarities.Roll(rng, luck, sahur)
	local t = Tungs.PickFromRarity(rng, rarity)
	local golden = eventIs("GoldenBelt") or Workspace:GetAttribute("AdminAbuse") == true
	return t.id, Mutations.Roll(rng, golden)
end

local function serialize(e: Entry): any
	return { id = e.id, tung = e.tung, mut = e.mut, a = e.a, b = e.b, t0 = e.t0, dur = e.dur, owner = e.owner, free = e.free, belt = e.belt }
end

local function hype(e: Entry)
	local t = Tungs.Get(e.tung)
	if not t then
		return
	end
	local order = Rarities.Order(t.rarity)
	if order < Rarities.Order("Legendary") then
		return
	end
	Remotes.Event("Hype"):FireAllClients({ level = t.rarity, tung = e.tung, mut = e.mut, entry = e.id, tier = t.tier })
	if t.rarity == "Mythic" then
		local text = Mutations.Prefix(e.mut) .. t.name .. " just spawned in a Steal a Tung server!"
		task.spawn(function()
			pcall(function()
				MessagingService:PublishAsync(GameConfig.GlobalTopic, { text = text, color = Tungs.Color(t):ToHex(), job = game.JobId })
			end)
		end)
	end
end

export type SpawnOpts = { owner: number?, free: boolean?, a: Vector3?, b: Vector3?, dur: number?, belt: string? }

function BeltService.Spawn(id: string, mut: string, opts: SpawnOpts?): Entry
	local o: SpawnOpts = opts or {}
	nextId += 1
	local speedMult = if eventIs("SpeedBelt") and o.belt == nil then Economy.SPEED_BELT_MULT else 1
	local e: Entry = {
		id = nextId,
		tung = id,
		mut = mut,
		a = o.a or Layout.BELT_START,
		b = o.b or Layout.BELT_END,
		t0 = now(),
		dur = (o.dur or Economy.BELT_TRAVEL) / speedMult,
		owner = o.owner,
		free = o.free,
		belt = o.belt or "main",
	}
	entries[e.id] = e
	Remotes.Event("BeltAdd"):FireAllClients(serialize(e))
	if e.belt == "main" then
		hype(e)
	end
	return e
end

function BeltService.Remove(entryId: number, buyer: number?)
	if entries[entryId] then
		entries[entryId] = nil
		Remotes.Event("BeltRemove"):FireAllClients(entryId, buyer)
	end
end

local function positionOf(e: Entry): Vector3
	local a = math.clamp((now() - e.t0) / e.dur, 0, 1)
	return e.a:Lerp(e.b, a)
end

function BeltService.Buy(player: Player, entryId: number): (boolean, any)
	local e = entries[entryId]
	if not e or now() > e.t0 + e.dur then
		return false, "Too late, it's gone!"
	end
	if e.owner and e.owner ~= player.UserId then
		return false, "That Tung is reserved for someone else"
	end
	local p = DataService.Get(player)
	if not p then
		return false, "Still loading"
	end
	if player:GetAttribute("Carrying") then
		return false, "Your hands are full!"
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- generous range: the Tung keeps moving while the request travels to the server
	if not hrp or (hrp.Position - positionOf(e)).Magnitude > 32 then
		return false, "Get closer to the Tung"
	end
	if BaseService.FreeSlotCount(player) <= 0 then
		return false, "Base full"
	end
	local t = Tungs.Get(e.tung)
	if not t then
		return false, "Unknown Tung"
	end
	local price = if e.free then 0 else Economy.TungPrice(e.tung, e.mut)
	if not EconomyService.Spend(player, price) then
		return false, "Not enough money (" .. Format.Money(price) .. ")"
	end
	BeltService.Remove(e.id, player.UserId)
	BaseService.AddTung(player, e.tung, e.mut, { arriving = true, source = "belt" })
	p.data.stats.bought += 1
	EconomyService.Stat(player, "buy", 1, t.rarity)
	if Rarities.Order(t.rarity) >= Rarities.Order("Legendary") then
		EconomyService.Alert(nil, "💸 " .. player.DisplayName .. " bought " .. Mutations.Prefix(e.mut) .. t.name .. "!", Tungs.Color(t), "Purchase", "buy")
	end
	return true, { tung = e.tung, mut = e.mut }
end

-- Instant Tung (Robux): a random Legendary rides the belt just for the buyer, free.
function BeltService.InstantTung(player: Player)
	local t = Tungs.PickFromRarity(rng, "Legendary")
	local mut = Mutations.Roll(rng, false)
	BeltService.Spawn(t.id, mut, { owner = player.UserId, free = true })
end

-- Admin spawn on the main belt.
function BeltService.AdminSpawn(id: string, mut: string)
	BeltService.Spawn(id, mut)
end

local function spawnMain()
	local id, mut = roll(serverLuck() * bestPersonalLuck())
	BeltService.Spawn(id, mut)
end

-- Personal belts (Rebirth 6): 1 Tung every 30 s, only its owner can buy it.
local personalNext: { [Player]: number } = {}
local function tickPersonal()
	local t = os.clock()
	for _, player in Players:GetPlayers() do
		local p = DataService.Get(player)
		local i = BaseService.IndexOf(player)
		local st = i and BaseService.Get(i)
		if not p or not i or not st or p.data.rebirths < 6 then
			continue
		end
		if t < (personalNext[player] or 0) then
			continue
		end
		personalNext[player] = t + Economy.PERSONAL_BELT_INTERVAL
		local a, b = Layout.PersonalBelt(i, st.slots)
		local id, mut = roll(serverLuck() * Economy.PersonalLuck(p.data, os.time()))
		BeltService.Spawn(id, mut, { owner = player.UserId, a = a, b = b, dur = Economy.PERSONAL_BELT_INTERVAL, belt = "p" .. i })
	end
end

function BeltService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		local list = {}
		for _, e in entries do
			table.insert(list, serialize(e))
		end
		Remotes.Event("BeltSync"):FireClient(player, list)
	end)
	Players.PlayerRemoving:Connect(function(player)
		personalNext[player] = nil
		-- personal-belt Tungs vanish with their owner
		for id, e in entries do
			if e.owner == player.UserId then
				BeltService.Remove(id, nil)
			end
		end
	end)

	-- Re-sync on request (e.g. after the client finished loading its UI)
	task.spawn(function()
		local lastSpawn = 0
		while true do
			task.wait(0.25)
			local interval = Economy.BELT_INTERVAL / (if eventIs("SpeedBelt") then 2 else 1)
			if os.clock() - lastSpawn >= interval then
				lastSpawn = os.clock()
				local ok, err = pcall(spawnMain :: any)
				if not ok then
					warn("[BeltService] spawn failed:", err)
				end
			end
			pcall(tickPersonal :: any)
			-- expire finished entries (clients drop them on their own)
			local t = now()
			for id, e in entries do
				if t > e.t0 + e.dur + 1 then
					entries[id] = nil
				end
			end
		end
	end)

	-- Mythic broadcasts from other servers
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(GameConfig.GlobalTopic, function(msg)
				local d = msg.Data
				if type(d) == "table" and d.job ~= game.JobId and type(d.text) == "string" then
					Remotes.Event("Global"):FireAllClients({ text = d.text, color = d.color })
				end
			end)
		end)
	end)
end

function BeltService.SyncTo(player: Player)
	local list = {}
	for _, e in entries do
		table.insert(list, serialize(e))
	end
	Remotes.Event("BeltSync"):FireClient(player, list)
end

return BeltService
