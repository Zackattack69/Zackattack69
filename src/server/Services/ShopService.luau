--!strict
-- Robux purchases: Developer Products (ProcessReceipt) + Game Passes (Design Doc §7).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Droids = require(Shared.Config.Droids)
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Util.Format)

local Bus = require(script.Parent.Parent.Bus)
local DataService = require(script.Parent.DataService)
local DroidService = require(script.Parent.DroidService)
local EconomyService = require(script.Parent.EconomyService)

local ShopService = {}
local rng = Random.new()

local GAMEPASS_KEYS = { "DoubleScrap", "AutoFoundry", "DoubleLuck", "VIP", "UltimateVIP" }

local function addCrates(data: any, crateId: string, n: number)
	data.freeCrates[crateId] = (data.freeCrates[crateId] or 0) + n
end

local function addScrapPack(player: Player, data: any, fraction: number)
	local amount = Economy.ScrapPackAmount(data, fraction)
	EconomyService.AddScrap(data, amount)
	return Format.Number(amount) .. " Scrap"
end

local function randomMythic(): number
	local pool = Droids.Pool("Mythic", nil)
	return pool[rng:NextInteger(1, #pool)].id
end

-- Pass side-effects that happen once (exclusive droids, etc.)
local function onPassOwned(player: Player, key: string)
	local p = DataService.Get(player)
	if not p then
		return
	end
	local data = p.data
	data.passes[key] = true
	if Economy.HasPass(data, "VIP") and not data.flags.vipDroid then
		data.flags.vipDroid = true
		DroidService.Grant(player, Droids.VIP_ID, "Standard", true)
	end
	if data.passes.UltimateVIP then
		local now = os.date("!*t")
		local month = now.year .. "-" .. now.month
		if data.lastMonthly ~= month then
			data.lastMonthly = month
			data.nova += 500
			addCrates(data, "Guaranteed_Mythic", 1)
			EconomyService.Notify(player, "Ultimate VIP+ monthly perks: +500 Nova and a Mythic Crate!", "nova")
		end
	end
	DataService.MarkDirty(player, true)
	Bus.Fire("PassesChanged", player)
end

-- Returns a human-readable description of what was granted.
local GRANTS: { [string]: (Player, any) -> string } = {
	CommonCrate3 = function(_, data)
		addCrates(data, "Guaranteed_Common", 3)
		return "3 Salvage Crates (see your Crate Vault)"
	end,
	ScrapSmall = function(player, data)
		return addScrapPack(player, data, 0.1)
	end,
	ScrapMedium = function(player, data)
		return addScrapPack(player, data, 0.75)
	end,
	ScrapLarge = function(player, data)
		return addScrapPack(player, data, 2)
	end,
	AutoClicker15 = function(_, data)
		data.autoClickUntil = math.max(data.autoClickUntil, os.time()) + 15 * 60
		return "15 minutes of Auto-Salvage"
	end,
	NovaSmall = function(_, data)
		data.nova += 25
		return "25 Nova Crystals"
	end,
	NovaMedium = function(_, data)
		data.nova += 100
		return "100 Nova Crystals"
	end,
	NovaLarge = function(_, data)
		data.nova += 300
		return "300 Nova Crystals"
	end,
	RebirthSkip = function(_, data)
		data.tokens.RebirthSkip += 1
		return "a Rebirth Skip Token"
	end,
	TokenGold = function(_, data)
		data.tokens.Gold += 1
		return "a Gold Style Token"
	end,
	TokenDiamond = function(_, data)
		data.tokens.Diamond += 1
		return "a Diamond Style Token"
	end,
	TokenShadow = function(_, data)
		data.tokens.Shadow += 1
		return "a Shadow Style Token"
	end,
	TokenRainbow = function(_, data)
		data.tokens.Rainbow += 1
		return "a Rainbow Style Token"
	end,
	StarterPack = function(player, data)
		local s = addScrapPack(player, data, 0.25)
		addCrates(data, "Guaranteed_Common", 3)
		data.tokens.Gold += 1
		return "the Starter Pack (" .. s .. ", 3 crates, Gold Token)"
	end,
	RareCrate = function(_, data)
		addCrates(data, "Guaranteed_Rare", 1)
		return "a Rare Crate (see your Crate Vault)"
	end,
	EpicCrate = function(_, data)
		addCrates(data, "Guaranteed_Epic", 1)
		return "an Epic Crate (see your Crate Vault)"
	end,
	LegendaryCrate = function(_, data)
		addCrates(data, "Guaranteed_Legendary", 1)
		return "a Legendary Crate (see your Crate Vault)"
	end,
	MythicCrate = function(_, data)
		addCrates(data, "Guaranteed_Mythic", 1)
		return "a Mythic Crate (see your Crate Vault)"
	end,
	MythicCrate3 = function(_, data)
		addCrates(data, "Guaranteed_Mythic", 3)
		return "3 Mythic Crates (see your Crate Vault)"
	end,
	FounderPack = function(player, _)
		DroidService.Grant(player, Droids.FOUNDER_ID, "Standard")
		return "Founder's Vanguard"
	end,
	MegaBundle = function(player, data)
		local s = addScrapPack(player, data, 6)
		data.nova += 1000
		return s .. " + 1,000 Nova Crystals"
	end,
	AllMaps = function(player, data)
		data.allMaps = true
		Bus.Fire("Rebirthed", player)
		return "access to every world"
	end,
	ArchitectPack = function(player, _)
		DroidService.Grant(player, Droids.ARCHITECT_ID, "Standard")
		return "The Architect"
	end,
	GenesisVault = function(player, _)
		local id = randomMythic()
		DroidService.Grant(player, id, "Rainbow")
		return "a RAINBOW " .. (Droids.Get(id) :: any).name
	end,
	WhaleVault = function(player, data)
		for _, key in GAMEPASS_KEYS do
			data.passes[key] = true
		end
		addCrates(data, "Guaranteed_Mythic", 10)
		if not table.find(data.titles, "Founding Whale") then
			table.insert(data.titles, "Founding Whale")
		end
		data.equippedTitle = "Founding Whale"
		task.defer(onPassOwned, player, "UltimateVIP")
		Bus.Fire("Rebirthed", player)
		return "the Founder's Whale Vault"
	end,
}

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
	EconomyService.Notify(player, "Thanks! You got " .. what .. "!", "purchase")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkGamepasses(player: Player)
	for _, key in GAMEPASS_KEYS do
		local product = Products.ByKey[key]
		if product.assetId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, product.assetId)
			if ok and owns then
				onPassOwned(player, key)
			end
		end
	end
	-- Passes granted through bundles (Whale Vault) still need their side effects.
	local p = DataService.Get(player)
	if p then
		for key in p.data.passes do
			onPassOwned(player, key)
		end
	end
end

function ShopService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, key in GAMEPASS_KEYS do
			if Products.ByKey[key].assetId == passId then
				onPassOwned(player, key)
				EconomyService.Notify(player, "Unlocked " .. Products.ByKey[key].name .. "!", "purchase")
			end
		end
	end)

	DataService.OnLoaded(function(profile)
		checkGamepasses(profile.player)
	end)
end

return ShopService
