--!strict
-- Scrapyard: Droid Foundry — server entry point.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)
local DroidService = require(Services.DroidService)
local ShopService = require(Services.ShopService)
local WorldService = require(Services.WorldService)

WorldService.Init() -- build worlds before anyone loads in
EconomyService.Init()
DroidService.Init()
ShopService.Init()
DataService.Init()

-- Every client action is routed through here. Handlers validate everything;
-- the client is never trusted with amounts, odds, or prices.
type Handler = (Player, ...any) -> (boolean, any?)

local handlers: { [string]: Handler } = {
	Click = function(player)
		local v = EconomyService.Click(player)
		return v > 0, v
	end,
	BuyUpgrade = function(player, id)
		return EconomyService.BuyUpgrade(player, tostring(id))
	end,
	Rebirth = function(player, useSkip)
		return EconomyService.Rebirth(player, useSkip == true)
	end,
	ClaimQuest = function(player, index)
		return EconomyService.ClaimQuest(player, tonumber(index) or 0)
	end,
	FinishOnboarding = function(player)
		EconomyService.FinishOnboarding(player)
		return true
	end,
	EquipTitle = function(player, title)
		return EconomyService.EquipTitle(player, tostring(title))
	end,
	OpenCrate = function(player, crateId, useFree)
		return DroidService.OpenCrate(player, tostring(crateId), useFree == true)
	end,
	Station = function(player, uid, world)
		return DroidService.Station(player, tostring(uid), tonumber(world))
	end,
	EquipBest = function(player)
		return DroidService.EquipBest(player)
	end,
	Fuse = function(player, uid)
		return DroidService.Fuse(player, tostring(uid))
	end,
	ApplyToken = function(player, uid, style)
		return DroidService.ApplyToken(player, tostring(uid), tostring(style))
	end,
	Recycle = function(player, uids)
		if type(uids) ~= "table" then
			return false
		end
		return DroidService.Recycle(player, uids)
	end,
	Sync = function(player)
		DataService.MarkDirty(player, true)
		return true
	end,
	Travel = function(player, world)
		return WorldService.Travel(player, tonumber(world) or 0)
	end,
}

local busy: { [Player]: boolean } = {}

Remotes.Function("Request").OnServerInvoke = function(player: Player, action: any, ...: any)
	local handler = if type(action) == "string" then handlers[action] else nil
	if not handler then
		return { ok = false, msg = "Unknown action" }
	end
	if not DataService.Get(player) then
		return { ok = false, msg = "Still loading..." }
	end
	-- One action at a time per player (prevents double-spend races).
	if busy[player] and action ~= "Click" then
		return { ok = false, msg = "Slow down!" }
	end
	busy[player] = true
	local ok, success, result = pcall(handler, player, ...)
	busy[player] = nil
	if not ok then
		warn("[Request]", action, success)
		return { ok = false, msg = "Something went wrong" }
	end
	if success then
		return { ok = true, data = result }
	end
	return { ok = false, msg = result }
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
