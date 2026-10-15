--!strict
-- Steal a Tung: server entry point.
--
-- All money, buying, stealing and rebirth logic runs on the server. Every
-- client action comes through the single `Request` RemoteFunction below; the
-- handlers re-validate everything and never trust amounts, prices or odds sent
-- by the client.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local ArenaBuilder = require(script.Parent.ArenaBuilder)
local Services = script.Parent.Services
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)
local PlayerService = require(Services.PlayerService)
local BaseService = require(Services.BaseService)
local StealService = require(Services.StealService)
local BeltService = require(Services.BeltService)
local EventService = require(Services.EventService)
local ShopService = require(Services.ShopService)
local TradeService = require(Services.TradeService)
local LeaderboardService = require(Services.LeaderboardService)
local AdminService = require(Services.AdminService)

ArenaBuilder.Build() -- the arena exists before anyone loads in
EconomyService.Init()
PlayerService.Init()
BaseService.Init()
StealService.Init()
BeltService.Init()
EventService.Init()
ShopService.Init()
TradeService.Init()
LeaderboardService.Init()
AdminService.Init()
DataService.Init() -- last, so every OnLoaded hook is registered first

type Handler = (Player, ...any) -> (boolean, any?)

local function num(v: any): number
	return tonumber(v) or 0
end

local handlers: { [string]: Handler } = {
	Buy = function(player, entryId)
		return BeltService.Buy(player, num(entryId))
	end,
	Collect = function(player, slot)
		local amount = BaseService.Collect(player, num(slot))
		return amount > 0, amount
	end,
	CollectAll = function(player)
		return BaseService.CollectAll(player)
	end,
	Lock = function(player)
		return BaseService.Lock(player)
	end,
	Sell = function(player, slot)
		return BaseService.Sell(player, num(slot))
	end,
	Rebirth = function(player, useSkip)
		return BaseService.Rebirth(player, useSkip == true)
	end,
	Swing = function(player)
		return StealService.Swing(player)
	end,
	BuyItem = function(player, key)
		return EconomyService.BuyItem(player, tostring(key))
	end,
	ClaimQuest = function(player, index)
		return EconomyService.ClaimQuest(player, num(index))
	end,
	ClaimLogin = function(player)
		return EconomyService.ClaimLogin(player)
	end,
	ClaimGroup = function(player)
		return ShopService.ClaimGroup(player)
	end,
	SetSkin = function(player, key)
		return BaseService.SetSkin(player, tostring(key or ""))
	end,
	EquipAura = function(player, key)
		return EconomyService.EquipAura(player, tostring(key or ""))
	end,
	Settings = function(player, s)
		return EconomyService.SaveSettings(player, s)
	end,
	TradeRequest = function(player, userId)
		return TradeService.Request(player, num(userId))
	end,
	TradeRespond = function(player, userId, accept)
		return TradeService.Respond(player, num(userId), accept == true)
	end,
	TradeOffer = function(player, slots)
		return TradeService.SetOffer(player, slots)
	end,
	TradeAccept = function(player)
		return TradeService.Accept(player)
	end,
	TradeCancel = function(player)
		return TradeService.Cancel(player)
	end,
	AdminUnlock = function(player, code)
		return AdminService.Unlock(player, code)
	end,
	AdminMoney = function(player, amount)
		return AdminService.GiveMoney(player, amount)
	end,
	AdminTung = function(player, id, mut, where)
		return AdminService.GiveTung(player, id, mut, where)
	end,
	AdminEvent = function(player, key)
		return AdminService.StartEvent(player, key)
	end,
	AdminEgg = function(player, key, count)
		return AdminService.TestEgg(player, key, count)
	end,
	AdminMusic = function(player, id)
		return AdminService.SetMusic(player, id)
	end,
	Sync = function(player)
		DataService.MarkDirty(player, true)
		BeltService.SyncTo(player)
		return true, nil
	end,
}

-- Actions that may run while another request from the same player is in flight.
local CONCURRENT = { Swing = true, Collect = true, Settings = true, Sync = true }

local busy: { [Player]: boolean } = {}
local rate: { [Player]: { t: number, n: number } } = {}

Remotes.Function("Request").OnServerInvoke = function(player: Player, action: any, ...: any)
	local handler = if type(action) == "string" then handlers[action] else nil
	if not handler then
		return { ok = false, msg = "Unknown action" }
	end
	if not DataService.Get(player) then
		return { ok = false, msg = "Still loading..." }
	end
	-- simple flood protection: 30 requests per second max
	local t = os.clock()
	local r = rate[player]
	if r == nil or t - r.t > 1 then
		r = { t = t, n = 0 }
		rate[player] = r
	end
	local window = r :: { t: number, n: number }
	window.n += 1
	if window.n > 30 then
		return { ok = false }
	end
	-- one state-changing action at a time per player (prevents double-spend races)
	local concurrent = CONCURRENT[action] == true
	if busy[player] and not concurrent then
		return { ok = false, msg = "Slow down!" }
	end
	if not concurrent then
		busy[player] = true
	end
	local ok, success, result = pcall(handler, player, ...)
	if not concurrent then
		busy[player] = nil
	end
	if not ok then
		warn("[Request]", action, success)
		return { ok = false, msg = "Something went wrong" }
	end
	if success then
		return { ok = true, data = result }
	end
	return { ok = false, msg = result }
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	rate[player] = nil
end)
