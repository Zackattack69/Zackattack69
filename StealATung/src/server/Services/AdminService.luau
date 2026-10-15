--!strict
-- Admin chat commands, used for weekly Admin Abuse streams and for testing.
--   /spawn <tung> [mutation]     put a Tung on the belt (any rarity, even Mythics)
--   /give <tung> [mutation]      put a Tung straight into your base
--   /event <name|stop>           SahurHour, TungRain, GoldenBelt, SpeedBelt, ThiefNight
--   /adminabuse [minutes|stop]   start or stop Admin Abuse (luck x3, Golden Belt)
--   /luck <mult> [minutes]       server luck multiplier
--   /money <amount>              give yourself money
-- Admins: GameConfig.Admins, the place owner (or group owner), everyone in Studio.
--
-- Admins also get an ADMIN button in the HUD. The panel unlocks with the secret
-- code in AdminConfig (server-only) and can give any amount of money, spawn any
-- Tung (into your base or onto the belt), start events and set the theme song
-- (saved in a DataStore, so it survives new versions of the place file).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)

local AdminConfig = require(script.Parent.Parent.AdminConfig)
local BaseService = require(script.Parent.BaseService)
local BeltService = require(script.Parent.BeltService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local ShopService = require(script.Parent.ShopService)
local Eggs = require(Shared.Config.Eggs)

local AdminService = {}

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(GameConfig.Admins, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return (player :: any):GetRankInGroupAsync(game.CreatorId)
	end)
	if not ok then
		ok, rank = pcall(function()
			return (player :: any):GetRankInGroup(game.CreatorId)
		end)
	end
	return ok and rank == 255
end

local function parseMutation(word: string?): string
	if not word then
		return Mutations.NONE
	end
	local w = string.lower(word)
	for _, m in Mutations.List do
		if string.lower(m.key) == w then
			return m.key
		end
	end
	return Mutations.NONE
end

-- Splits "/spawn mythic red tung gold" into the Tung query + optional mutation.
local function tungAndMutation(args: { string }): (Tungs.Tung?, string)
	local mut = Mutations.NONE
	local last = args[#args]
	if last and parseMutation(last) ~= Mutations.NONE then
		mut = parseMutation(last)
		table.remove(args, #args)
	end
	return Tungs.Find(table.concat(args, " ")), mut
end

local function run(player: Player, msg: string)
	if string.sub(msg, 1, 1) ~= "/" then
		return
	end
	local args = string.split(string.sub(msg, 2), " ")
	local cmd = string.lower(table.remove(args, 1) or "")
	local function reply(text: string)
		EconomyService.Notify(player, "[Admin] " .. text, "info")
	end
	if cmd == "spawn" or cmd == "give" then
		local t, mut = tungAndMutation(args)
		if not t then
			return reply("No Tung called '" .. table.concat(args, " ") .. "'")
		end
		if cmd == "spawn" then
			BeltService.AdminSpawn(t.id, mut)
			reply("Spawned " .. Mutations.Prefix(mut) .. t.name .. " on the belt")
		else
			BaseService.AddTung(player, t.id, mut, { source = "admin" })
			reply("Gave you " .. Mutations.Prefix(mut) .. t.name)
		end
	elseif cmd == "event" then
		local name = string.lower(args[1] or "")
		if name == "stop" then
			EventService.Stop()
			return reply("Event stopped")
		end
		for _, e in Events.List do
			if string.lower(e.key) == name and e.random then
				EventService.Start(e.key)
				return reply("Started " .. e.name)
			end
		end
		reply("Events: SahurHour, TungRain, GoldenBelt, SpeedBelt, ThiefNight, stop")
	elseif cmd == "adminabuse" then
		if string.lower(args[1] or "") == "stop" then
			EventService.StopAdminAbuse()
		else
			EventService.Start("AdminAbuse", (tonumber(args[1]) or 30) * 60)
		end
	elseif cmd == "luck" then
		local mult = tonumber(args[1]) or 2
		local minutes = tonumber(args[2]) or 10
		EventService.AdminLuck(mult, minutes)
		EconomyService.Alert(nil, "🍀 An admin set server luck to x" .. mult .. " for " .. minutes .. " minutes!", Color3.fromRGB(90, 230, 120), "Jackpot", "luck")
	elseif cmd == "money" then
		local amount = tonumber(args[1]) or 0
		EconomyService.AddMoney(player, amount)
		reply("+" .. Format.Money(amount))
	elseif cmd == "help" then
		reply("/spawn <tung> [mutation], /give <tung> [mutation], /event <name|stop>, /adminabuse [min|stop], /luck <x> [min], /money <n>")
	end
end

local lastRun: { [Player]: { msg: string, t: number } } = {}

-- ADMIN panel ---------------------------------------------------------------------------------
local unlocked: { [Player]: boolean } = {}
local attempts: { [Player]: { n: number, t: number } } = {}

function AdminService.Unlock(player: Player, code: any): (boolean, any)
	if not AdminService.IsAdmin(player) then
		return false, "Only the owner and admins can use this"
	end
	local a = attempts[player]
	if a == nil or os.clock() - a.t > 60 then
		a = { n = 0, t = os.clock() }
		attempts[player] = a
	end
	local tries = a :: { n: number, t: number }
	tries.n += 1
	if tries.n > 5 then
		return false, "Too many tries, wait a minute"
	end
	if type(code) ~= "string" or code ~= AdminConfig.Code then
		return false, "Wrong code"
	end
	unlocked[player] = true
	return true, nil
end

local function allowed(player: Player): (boolean, string?)
	if not AdminService.IsAdmin(player) then
		return false, "Only the owner and admins can use this"
	end
	if not unlocked[player] then
		return false, "Enter the admin code first"
	end
	return true, nil
end

function AdminService.GiveMoney(player: Player, amount: any): (boolean, any)
	local ok, why = allowed(player)
	if not ok then
		return false, why
	end
	local n = if type(amount) == "number" then amount elseif type(amount) == "string" then Format.Parse(amount) else nil
	if not n or n ~= n or n <= 0 or n == math.huge then
		return false, "Type an amount like 1000, 2.5M or 1e15"
	end
	n = math.min(n, 1e300)
	EconomyService.AddMoney(player, n)
	EconomyService.Notify(player, "👑 +" .. Format.Money(n), "money")
	return true, n
end

function AdminService.GiveTung(player: Player, id: any, mut: any, where: any): (boolean, any)
	local ok, why = allowed(player)
	if not ok then
		return false, why
	end
	local t = Tungs.Get(tostring(id))
	if not t then
		return false, "Unknown Tung"
	end
	local m = parseMutation(if type(mut) == "string" then mut else nil)
	if where == "belt" then
		BeltService.AdminSpawn(t.id, m)
		return true, "belt"
	end
	BaseService.AddTung(player, t.id, m, { source = "admin" })
	EconomyService.Notify(player, "👑 " .. Mutations.Prefix(m) .. t.name .. " added to your base!", "success")
	return true, "base"
end

function AdminService.StartEvent(player: Player, key: any): (boolean, any)
	local ok, why = allowed(player)
	if not ok then
		return false, why
	end
	if key == "stop" then
		EventService.Stop()
		EventService.StopAdminAbuse()
		return true, nil
	end
	local e = Events.ByKey[tostring(key)]
	if not e then
		return false, "Unknown event"
	end
	EventService.Start(e.key, if e.key == "AdminAbuse" then 30 * 60 else nil)
	return true, nil
end

-- Free test hatch for admins (so eggs can be tried before the Robux products exist).
function AdminService.TestEgg(player: Player, key: any, count: any): (boolean, any)
	local ok, why = allowed(player)
	if not ok then
		return false, why
	end
	local egg = Eggs.ByKey[tostring(key)]
	if not egg then
		return false, "Unknown egg"
	end
	ShopService.Hatch(player, egg, tonumber(count) or 1)
	return true, nil
end

-- Theme song set from the admin panel ---------------------------------------------------------------
local MUSIC_KEY = "ThemeMusicId"
local settingsStore: DataStore? = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName .. "_Settings")
	end)
	if ok then
		settingsStore = store
	end
end

-- Accepts 123456, "rbxassetid://123456" or a Creator Store / library link; returns "rbxassetid://123456".
function AdminService.ParseAssetId(text: string): string?
	local digits = string.match(text, "(%d%d%d%d%d+)")
	return if digits then "rbxassetid://" .. digits else nil
end

function AdminService.SetMusic(player: Player, text: any): (boolean, any)
	local ok, why = allowed(player)
	if not ok then
		return false, why
	end
	local raw = tostring(text or "")
	local id = ""
	if raw ~= "" and string.lower(raw) ~= "off" then
		id = AdminService.ParseAssetId(raw) or ""
		if id == "" then
			return false, "That doesn't look like a sound ID (paste the number from Copy Asset ID)"
		end
	end
	Workspace:SetAttribute("MusicId", id)
	local store = settingsStore
	local saved = false
	if store then
		saved = pcall(function()
			store:SetAsync(MUSIC_KEY, id)
		end)
	end
	if id == "" then
		EconomyService.Notify(player, "🎵 Theme song turned off", "info")
	elseif saved then
		EconomyService.Notify(player, "🎵 Theme song set and saved for every server!", "success")
	else
		EconomyService.Notify(player, "🎵 Theme song set for this server. (To keep it, publish the place and turn on Studio API access, or paste it in GameConfig.MusicId.)", "info")
	end
	return true, id
end

local function loadMusic()
	local store = settingsStore
	if not store then
		return
	end
	local ok, id = pcall(function()
		return store:GetAsync(MUSIC_KEY)
	end)
	if ok and type(id) == "string" and Workspace:GetAttribute("MusicId") == nil then
		Workspace:SetAttribute("MusicId", id)
	end
end

local function handle(player: Player, msg: string)
	if not AdminService.IsAdmin(player) then
		return
	end
	-- the same message can arrive through both TextChatCommand and Player.Chatted
	local last = lastRun[player]
	if last and last.msg == msg and os.clock() - last.t < 1 then
		return
	end
	lastRun[player] = { msg = msg, t = os.clock() }
	local ok, err = pcall(run :: any, player, msg)
	if not ok then
		warn("[AdminService]", err)
	end
end

function AdminService.Init()
	task.spawn(loadMusic)
	-- Register the commands with TextChatService so "/spawn ..." isn't rejected as unknown.
	local folder = Instance.new("Folder")
	folder.Name = "StealATungCommands"
	folder.Parent = TextChatService
	for _, name in { "spawn", "give", "event", "adminabuse", "luck", "money", "help" } do
		local c = Instance.new("TextChatCommand")
		c.Name = "Admin_" .. name
		c.PrimaryAlias = "/" .. name
		c.Parent = folder
		c.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				handle(player, text)
			end
		end)
	end
	local function hook(player: Player)
		player:SetAttribute("IsAdmin", AdminService.IsAdmin(player))
		player.Chatted:Connect(function(msg)
			handle(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRun[player] = nil
		unlocked[player] = nil
		attempts[player] = nil
	end)
end

return AdminService
