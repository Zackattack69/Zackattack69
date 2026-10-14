--!strict
-- Trading Tungs with friends through a trade window. Both sides pick up to 6
-- Tungs from their base; any change resets the accepts; both players must
-- press Accept and then Confirm ("accept twice") before anything moves.
-- Everything is re-validated at the moment of the swap.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local Remotes = require(Shared.Remotes)

local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local TradeService = {}

local MAX_ITEMS = 6
local REQUEST_TTL = 30

type Item = { slot: number, uid: string, id: string, m: string }
type Side = { player: Player, offer: { Item }, accepted: boolean }
type Trade = { a: Side, b: Side, stage: number } -- stage 1 = Accept, stage 2 = Confirm

local trades: { [Player]: Trade } = {}
local requests: { [Player]: { [Player]: number } } = {} -- target -> requester -> time

local function sideOf(trade: Trade, player: Player): (Side, Side)
	if trade.a.player == player then
		return trade.a, trade.b
	end
	return trade.b, trade.a
end

local function serializeOffer(offer: { Item }): any
	local out = {}
	for _, it in offer do
		table.insert(out, { slot = it.slot, id = it.id, m = it.m })
	end
	return out
end

local function push(trade: Trade)
	for _, player in { trade.a.player, trade.b.player } do
		local me, them = sideOf(trade, player)
		Remotes.Event("Trade"):FireClient(player, {
			type = "update",
			stage = trade.stage,
			me = { offer = serializeOffer(me.offer), accepted = me.accepted },
			them = { offer = serializeOffer(them.offer), accepted = them.accepted, name = them.player.DisplayName, userId = them.player.UserId },
		})
	end
end

local function close(trade: Trade, reason: string?)
	for _, side in { trade.a, trade.b } do
		trades[side.player] = nil
		if side.player.Parent then
			Remotes.Event("Trade"):FireClient(side.player, { type = "close", reason = reason })
		end
	end
end

local function canTradeWith(a: Player, b: Player): boolean
	if not GameConfig.TradeFriendsOnly or RunService:IsStudio() then
		return true
	end
	return EconomyService.IsFriend(a, b)
end

function TradeService.Request(from: Player, toUserId: number): (boolean, any)
	local to = Players:GetPlayerByUserId(toUserId)
	if not to or to == from then
		return false, "That player isn't here"
	end
	if trades[from] then
		return false, "You're already trading"
	end
	if trades[to] then
		return false, to.DisplayName .. " is busy trading"
	end
	if not canTradeWith(from, to) then
		return false, "You can only trade with friends"
	end
	-- they already asked us? then this is an accept
	local mine = requests[from]
	if mine and mine[to] and os.clock() - mine[to] < REQUEST_TTL then
		return TradeService.Respond(from, to.UserId, true)
	end
	requests[to] = requests[to] or {}
	requests[to][from] = os.clock()
	Remotes.Event("Trade"):FireClient(to, { type = "request", from = from.UserId, name = from.DisplayName })
	return true, "Trade request sent to " .. to.DisplayName
end

function TradeService.Respond(player: Player, fromUserId: number, accept: boolean): (boolean, any)
	local from = Players:GetPlayerByUserId(fromUserId)
	local mine = requests[player]
	if not from or not mine or not mine[from] or os.clock() - mine[from] > REQUEST_TTL then
		return false, "That request expired"
	end
	mine[from] = nil
	if not accept then
		EconomyService.Notify(from, player.DisplayName .. " declined your trade", "info")
		return true, nil
	end
	if trades[from] or trades[player] then
		return false, "Someone is already trading"
	end
	local trade: Trade = {
		a = { player = from, offer = {}, accepted = false },
		b = { player = player, offer = {}, accepted = false },
		stage = 1,
	}
	trades[from] = trade
	trades[player] = trade
	for _, pl in { from, player } do
		Remotes.Event("Trade"):FireClient(pl, { type = "open" })
	end
	push(trade)
	return true, nil
end

function TradeService.SetOffer(player: Player, slots: any): (boolean, any)
	local trade = trades[player]
	if not trade or type(slots) ~= "table" then
		return false, "You're not trading"
	end
	local me = sideOf(trade, player)
	local offer: { Item } = {}
	local seen: { [number]: boolean } = {}
	local i = BaseService.IndexOf(player)
	for _, raw in slots do
		local slot = tonumber(raw)
		if not slot or seen[slot] then
			continue
		end
		seen[slot] = true
		local entry = BaseService.Entry(player, slot)
		local t = entry and Tungs.Get(entry.id)
		if not entry or not t then
			continue
		end
		if t.bound then
			return false, t.name .. " can't be traded"
		end
		local st = i and BaseService.Get(i)
		if st and (st.stolen[slot] or st.arriving[slot]) then
			return false, "That Tung isn't on its pad"
		end
		table.insert(offer, { slot = slot, uid = entry.u, id = entry.id, m = entry.m or Mutations.NONE })
		if #offer >= MAX_ITEMS then
			break
		end
	end
	me.offer = offer
	trade.a.accepted = false
	trade.b.accepted = false
	trade.stage = 1
	push(trade)
	return true, nil
end

local function stillValid(side: Side): boolean
	for _, it in side.offer do
		local entry = BaseService.Entry(side.player, it.slot)
		if not entry or entry.u ~= it.uid then
			return false
		end
		local i = BaseService.IndexOf(side.player)
		local st = i and BaseService.Get(i)
		if st and (st.stolen[it.slot] or st.arriving[it.slot]) then
			return false
		end
	end
	return true
end

local function execute(trade: Trade)
	local a, b = trade.a, trade.b
	if not stillValid(a) or not stillValid(b) then
		close(trade, "A Tung in the trade moved, so the trade was cancelled")
		return
	end
	if BaseService.FreeSlotCount(a.player) + #a.offer < #b.offer then
		close(trade, a.player.DisplayName .. " doesn't have enough free slots")
		return
	end
	if BaseService.FreeSlotCount(b.player) + #b.offer < #a.offer then
		close(trade, b.player.DisplayName .. " doesn't have enough free slots")
		return
	end
	local fromA, fromB = {}, {}
	for _, it in a.offer do
		local e = BaseService.RemoveTung(a.player, it.slot)
		if e then
			table.insert(fromA, e)
		end
	end
	for _, it in b.offer do
		local e = BaseService.RemoveTung(b.player, it.slot)
		if e then
			table.insert(fromB, e)
		end
	end
	for _, e in fromA do
		BaseService.AddTung(b.player, e.id, e.m, { source = "trade" })
	end
	for _, e in fromB do
		BaseService.AddTung(a.player, e.id, e.m, { source = "trade" })
	end
	for _, side in { a, b } do
		trades[side.player] = nil
		Remotes.Event("Trade"):FireClient(side.player, { type = "close", reason = "done" })
		EconomyService.Notify(side.player, "🤝 Trade complete!", "success")
		DataService.MarkDirty(side.player, true)
	end
end

function TradeService.Accept(player: Player): (boolean, any)
	local trade = trades[player]
	if not trade then
		return false, "You're not trading"
	end
	if #trade.a.offer == 0 and #trade.b.offer == 0 then
		return false, "Add a Tung first"
	end
	local me = sideOf(trade, player)
	me.accepted = true
	if trade.a.accepted and trade.b.accepted then
		if trade.stage == 1 then
			trade.stage = 2
			trade.a.accepted = false
			trade.b.accepted = false
		else
			execute(trade)
			return true, nil
		end
	end
	push(trade)
	return true, nil
end

function TradeService.Cancel(player: Player): (boolean, any)
	local trade = trades[player]
	if trade then
		close(trade, player.DisplayName .. " cancelled the trade")
	end
	return true, nil
end

function TradeService.Init()
	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			close(trade, player.DisplayName .. " left")
		end
		requests[player] = nil
		for _, list in requests do
			list[player] = nil
		end
	end)
end

return TradeService
