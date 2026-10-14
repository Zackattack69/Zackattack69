--!strict
-- Scrap: clicking, passive income, foundry upgrades, rebirths, bounty quests.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Quests = require(Shared.Config.Quests)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Bus = require(script.Parent.Parent.Bus)
local DataService = require(script.Parent.DataService)

local EconomyService = {}
local rng = Random.new()

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, { text = text, kind = kind or "info" })
end
EconomyService.Notify = notify

function EconomyService.AddScrap(data: any, amount: number)
	data.scrap += amount
	data.totalScrap += amount
end

function EconomyService.BumpStat(player: Player, stat: string, amount: number?)
	local p = DataService.Get(player)
	if not p then
		return
	end
	p.data.stats[stat] = (p.data.stats[stat] or 0) + (amount or 1)
	DataService.MarkDirty(player, true)
end

-- Salvage clicks (HUD button, scrap piles, auto-salvager) --------------------------
-- Returns the Scrap gained, or 0 if rate-limited.
function EconomyService.Click(player: Player): number
	local p = DataService.Get(player)
	if not p then
		return 0
	end
	local now = os.clock()
	local window = p.clickWindow
	while window[1] and now - window[1] > 1 do
		table.remove(window, 1)
	end
	if #window >= Economy.MAX_CLICKS_PER_SECOND then
		return 0
	end
	table.insert(window, now)

	local value = Economy.ClickValue(p.data)
	EconomyService.AddScrap(p.data, value)
	p.data.stats.clicks += 1
	DataService.MarkDirty(player)
	return value
end

-- Upgrades --------------------------------------------------------------------------
function EconomyService.BuyUpgrade(player: Player, id: string): (boolean, string?)
	local p = DataService.Get(player)
	local u = Economy.UpgradesById[id]
	if not p or not u then
		return false, "Unknown upgrade"
	end
	local data = p.data
	local level = data.upgrades[id] or 0
	if level >= u.maxLevel then
		return false, "Max level!"
	end
	local cost = Economy.UpgradeCost(id, level, data.rebirths)
	if data.scrap < cost then
		return false, "Not enough Credits"
	end
	data.scrap -= cost
	data.upgrades[id] = level + 1
	data.stats.upgrades += 1
	DataService.MarkDirty(player, true)
	Bus.Fire("UpgradesChanged", player)
	return true
end

-- Rebirth (Design Doc §4) ------------------------------------------------------------
function EconomyService.Rebirth(player: Player, useSkip: boolean?): (boolean, string?)
	local p = DataService.Get(player)
	if not p then
		return false, "Not loaded"
	end
	local data = p.data
	local cost = Economy.RebirthCost(data.rebirths)
	if useSkip then
		if (data.tokens.RebirthSkip or 0) <= 0 then
			return false, "No Rebirth Skip Tokens"
		end
		data.tokens.RebirthSkip -= 1
	elseif data.scrap < cost then
		return false, "Need " .. Format.Number(cost) .. " Credits"
	end

	local novaReward = Economy.RebirthNovaReward(data.rebirths)
	-- LOSE: scrap + foundry upgrades
	data.scrap = 0
	data.upgrades = { Claws = 0, Assembly = 0, Bay = 0 }
	-- GAIN: multiplier (derived from count), next map, title, free Rare crate, Nova
	data.rebirths += 1
	data.nova += novaReward
	data.freeCrates.Guaranteed_Rare = (data.freeCrates.Guaranteed_Rare or 0) + 1
	local title = Economy.RebirthTitle(data.rebirths)
	if title then
		table.insert(data.titles, title)
		data.equippedTitle = title
	end

	-- Station slots may have shrunk (Bay reset) – unstation the weakest overflow.
	EconomyService.TrimStations(data)

	DataService.MarkDirty(player, true)
	Bus.Fire("Rebirthed", player)
	Bus.Fire("UpgradesChanged", player)
	Bus.Fire("DroidsChanged", player)

	local unlocked = Worlds.Get(data.rebirths + 1)
	local msg = "REBIRTH " .. Economy.Roman(data.rebirths) .. "! +" .. novaReward .. " Aura, free Rare Crate"
	if unlocked and not data.allMaps then
		msg ..= ", and " .. unlocked.name .. " unlocked!"
	end
	notify(player, msg, "rebirth")
	return true
end

function EconomyService.TrimStations(data: any)
	local slots = Economy.StationSlots(data)
	local stationed = {}
	for uid, inst in data.droids do
		if inst.station then
			table.insert(stationed, { uid = uid, v = Economy.DroidIncome(inst) })
		end
	end
	if #stationed <= slots then
		return
	end
	table.sort(stationed, function(a, b)
		return a.v > b.v
	end)
	for i = slots + 1, #stationed do
		data.droids[stationed[i].uid].station = nil
	end
end

-- Quests --------------------------------------------------------------------------------
function EconomyService.ClaimQuest(player: Player, index: number): (boolean, string?)
	local p = DataService.Get(player)
	if not p then
		return false
	end
	local data = p.data
	local q = data.quests[index]
	if not q then
		return false, "No such bounty"
	end
	local t = Quests.ById[q.template]
	local progress = (data.stats[t.stat] or 0) - q.start
	if progress < q.goal then
		return false, "Bounty not complete yet"
	end
	data.nova += q.reward
	table.remove(data.quests, index)
	table.insert(data.quests, index, Quests.Roll(rng, data.quests, data.stats))
	DataService.MarkDirty(player, true)
	notify(player, "Bounty complete! +" .. q.reward .. " Aura", "nova")
	return true
end

function EconomyService.FinishOnboarding(player: Player)
	local p = DataService.Get(player)
	if p then
		p.data.onboarded = true
		DataService.MarkDirty(player, true)
	end
end

function EconomyService.EquipTitle(player: Player, title: string): boolean
	local p = DataService.Get(player)
	if not p then
		return false
	end
	if title ~= "" and not table.find(p.data.titles, title) then
		return false
	end
	p.data.equippedTitle = title
	DataService.MarkDirty(player, true)
	Bus.Fire("Rebirthed", player) -- refresh name tag
	return true
end

-- Leaderstats ----------------------------------------------------------------------------
local function setupLeaderstats(profile: DataService.Profile)
	local player = profile.player
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local scrap = Instance.new("StringValue")
	scrap.Name = "Credits"
	scrap.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = ls
	ls.Parent = player
end

local function updateLeaderstats(player: Player, data: any)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	(ls:FindFirstChild("Credits") :: StringValue).Value = Format.Number(data.scrap);
	(ls:FindFirstChild("Rebirths") :: IntValue).Value = data.rebirths
	player:SetAttribute("Income", Economy.IncomePerSecond(data))
	player:SetAttribute("TotalScrap", data.totalScrap)
	player:SetAttribute("Rebirths", data.rebirths)
end

-- Offline earnings + monthly perks, run once per join ------------------------------------
local function onLoaded(profile: DataService.Profile)
	local player, data = profile.player, profile.data
	setupLeaderstats(profile)

	if Economy.HasPass(data, "AutoFoundry") and data.lastOnline > 0 then
		local away = math.min(os.time() - data.lastOnline, Economy.OFFLINE_CAP_SECONDS)
		if away > 60 then
			local earned = math.floor(Economy.IncomePerSecond(data) * Economy.OFFLINE_RATE * away)
			if earned > 0 then
				EconomyService.AddScrap(data, earned)
				task.delay(4, notify, player, "Auto-Foundry earned " .. Format.Number(earned) .. " Credits while you were away!", "scrap")
			end
		end
	end
	data.lastOnline = os.time()
	DataService.MarkDirty(player, true)
end

function EconomyService.Init()
	DataService.OnLoaded(onLoaded)

	-- Passive income tick
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local p = DataService.Get(player)
				if p then
					local data = p.data
					local income = Economy.IncomePerSecond(data)
					if income > 0 then
						EconomyService.AddScrap(data, income)
					end
					if data.autoClickUntil > now then
						local v = Economy.ClickValue(data) * 4
						EconomyService.AddScrap(data, v)
						data.stats.clicks += 4
					end
					if tick % 60 == 0 then
						data.stats.minutes += 1
						p.dirtyFull = true
					end
					p.dirtyStats = true
					updateLeaderstats(player, data)
				end
			end
		end
	end)
end

return EconomyService
