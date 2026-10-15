--!strict
-- Robux purchases: Game Passes + Developer Products (ProcessReceipt), eggs
-- that hatch into Tungs, plus the Roblox group reward (free Group Tung).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Eggs = require(Shared.Config.Eggs)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Products = require(Shared.Config.Products)
local Remotes = require(Shared.Remotes)
local Tungs = require(Shared.Config.Tungs)

local Bus = require(script.Parent.Parent.Bus)
local BeltService = require(script.Parent.BeltService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)

local ShopService = {}
local rng = Random.new()

-- Hatches `count` eggs: rolls each Tung, puts them in the base (or the waiting
-- queue when the base is full) and plays the hatch animation for the buyer.
-- Returns a short summary ("Dragon Tung" or "10 Tungs").
function ShopService.Hatch(player: Player, egg: Eggs.Egg, count: number): string
	local results = {}
	for _ = 1, math.clamp(count, 1, 10) do
		local id, mut = Eggs.Roll(egg, rng)
		Bus.Fire("GrantTung", player, id, mut, "egg")
		table.insert(results, { tung = id, mut = mut })
	end
	Remotes.Event("Hatch"):FireClient(player, { egg = egg.key, results = results })
	if #results == 1 then
		local t = Tungs.Get(results[1].tung)
		return Mutations.Prefix(results[1].mut) .. (if t then t.name else "Tung")
	end
	return #results .. " Tungs"
end

local function cashPack(player: Player, data: any, pack: number): string
	local amount = Economy.CashPackAmount(pack, data.money, EconomyService.Income(player, data))
	EconomyService.AddMoney(player, amount)
	return Format.Money(amount)
end

-- One-time side effects of owning a pass.
local function onPassOwned(player: Player, key: string)
	local p = DataService.Get(player)
	if not p then
		return
	end
	local data = p.data
	local isNew = not data.passes[key]
	data.passes[key] = true
	if key == "VIP" and not data.flags.vipTung then
		data.flags.vipTung = true
		Bus.Fire("GrantTung", player, "VIPTung", Mutations.NONE, "VIP")
	end
	DataService.MarkDirty(player, true)
	if isNew then
		Bus.Fire("PassesChanged", player)
	end
end

local GRANTS: { [string]: (Player, any) -> string } = {
	LuckPotion = function(player, _)
		EventService.LuckPotion(player)
		return "a Server Luck Potion (3x luck for 10 minutes)"
	end,
	InstantTung = function(player, _)
		BeltService.InstantTung(player)
		return "an Instant Tung. A Legendary is riding the belt just for you, go grab it!"
	end,
	SkipRebirth = function(_, data)
		data.tokens.SkipRebirth = (data.tokens.SkipRebirth or 0) + 1
		return "a Skip Rebirth token (use it at your Rebirth Altar)"
	end,
	BaseShield = function(_, data)
		-- BaseService uses the token on its next tick (or right after Thief Night)
		data.tokens.Shield = (data.tokens.Shield or 0) + 1
		return "a Base Shield (5-minute lock)"
	end,
}
for pack = 1, #Economy.CASH_PACK_MULT do
	GRANTS["Cash" .. pack] = function(player, data)
		return cashPack(player, data, pack) .. "!"
	end
end
for key, b in Eggs.ByProduct do
	GRANTS[key] = function(player, _)
		local what = ShopService.Hatch(player, b.egg, b.count)
		return (if b.count == 1 then "a " .. b.egg.name else b.count .. " " .. b.egg.name .. "s") .. ". You hatched " .. what .. "!"
	end
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.WaitFor(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.data
	if data.receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = Products.ByAssetId[info.ProductId]
	local grant = product and GRANTS[product.key]
	if not product or not grant then
		warn("[ShopService] No grant for product id", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, what = pcall(grant, player, data)
	if not ok then
		warn("[ShopService] Grant failed", product.key, what)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Record the receipt in the same save as the reward, so a retry can never double-grant.
	DataService.RecordReceipt(profile, info.PurchaseId)
	DataService.MarkDirty(player, true)
	if not DataService.Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	EconomyService.Notify(player, "Thanks! You got " .. what, "purchase")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkGamepasses(player: Player)
	for _, product in Products.Gamepasses do
		if product.assetId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, product.assetId)
			if ok and owns then
				onPassOwned(player, product.key)
			end
		end
	end
	-- passes already in the save still need their side effects (e.g. VIP Tung)
	local p = DataService.Get(player)
	if p then
		for key in p.data.passes do
			onPassOwned(player, key)
		end
	end
end

-- Group reward: join the Roblox group to unlock a free Group Tung (Rare).
function ShopService.ClaimGroup(player: Player): (boolean, any)
	local p = DataService.Get(player)
	if not p then
		return false, "Still loading"
	end
	if GameConfig.GroupId == 0 then
		return false, "The group reward isn't set up yet"
	end
	if p.data.flags.groupTung then
		return false, "You already claimed the Group Tung"
	end
	local ok, inGroup = pcall(function()
		return (player :: any):IsInGroupAsync(GameConfig.GroupId)
	end)
	if not ok then
		ok, inGroup = pcall(function()
			return (player :: any):IsInGroup(GameConfig.GroupId)
		end)
	end
	if not ok or not inGroup then
		return false, "Join the group first, then try again!"
	end
	p.data.flags.groupTung = true
	Bus.Fire("GrantTung", player, "GroupTung", Mutations.NONE, "Group reward")
	DataService.MarkDirty(player, true)
	return true, nil
end

function ShopService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, product in Products.Gamepasses do
			if product.assetId == passId then
				onPassOwned(player, product.key)
				EconomyService.Notify(player, "Unlocked " .. product.name .. "!", "purchase")
			end
		end
	end)

	-- Paid random items (eggs) are hidden for players whose country doesn't allow them.
	local function checkPolicy(player: Player)
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		-- if Roblox can't tell us, play it safe and hide them (except in Studio, for testing)
		local restricted = if ok and info then (info :: any).ArePaidRandomItemsRestricted == true else not RunService:IsStudio()
		player:SetAttribute("NoPaidRandom", restricted)
	end
	Players.PlayerAdded:Connect(checkPolicy)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPolicy, player)
	end

	DataService.OnLoaded(function(profile)
		local player = profile.player
		-- wait until the base exists so granted Tungs land in it
		local start = os.clock()
		while not player:GetAttribute("Base") and player.Parent and os.clock() - start < 20 do
			task.wait(0.2)
		end
		checkGamepasses(player)
		if GameConfig.GroupId ~= 0 and not profile.data.flags.groupTung then
			ShopService.ClaimGroup(player)
		end
	end)
end

return ShopService
