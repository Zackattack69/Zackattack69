--!strict
-- Money, multipliers, the Index (and its rewards), daily quests, the 7-day
-- login streak, the in-game shop (bats, gear, boosts), settings and messages.
-- Everything is computed here from config; the client never sends amounts.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Quests = require(Shared.Config.Quests)
local Rarities = require(Shared.Config.Rarities)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Bus = require(script.Parent.Parent.Bus)
local DataService = require(script.Parent.DataService)

local EconomyService = {}
local rng = Random.new()

-- Messages ----------------------------------------------------------------------------
function EconomyService.Notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, { text = text, kind = kind or "info" })
end

-- Big centre banner. player = nil sends it to everyone.
function EconomyService.Alert(player: Player?, text: string, color: Color3?, sound: string?, kind: string?)
	local payload = { text = text, color = color or Color3.fromRGB(255, 200, 60), sound = sound, kind = kind or "info" }
	if player then
		Remotes.Event("Alert"):FireClient(player, payload)
	else
		Remotes.Event("Alert"):FireAllClients(payload)
	end
end

-- Money ---------------------------------------------------------------------------------
function EconomyService.FriendBonus(player: Player): number
	return (player:GetAttribute("FriendBoost") :: number?) or 0
end

function EconomyService.Multiplier(player: Player, data: any): number
	return Economy.Multiplier(data, os.time(), EconomyService.FriendBonus(player))
end

-- Income/s of everything in the base (what the HUD shows).
function EconomyService.Income(player: Player, data: any): number
	local mult = EconomyService.Multiplier(player, data)
	local total = 0
	for _, s in data.slots do
		total += Economy.TungIncome(s.id, s.m)
	end
	return total * mult
end

function EconomyService.AddMoney(player: Player, amount: number)
	local p = DataService.Get(player)
	if not p or amount <= 0 then
		return
	end
	p.data.money += amount
	p.data.totalEarned += amount
	DataService.MarkDirty(player)
end

function EconomyService.Spend(player: Player, amount: number): boolean
	local p = DataService.Get(player)
	if not p or p.data.money < amount then
		return false
	end
	p.data.money -= amount
	DataService.MarkDirty(player)
	return true
end

-- Stats & daily quests ---------------------------------------------------------------------
local function ensureQuests(player: Player, data: any)
	local today = Quests.Day(os.time())
	if data.quests.day ~= today then
		data.quests.day = today
		data.quests.list = Quests.Roll(rng, { income = EconomyService.Income(player, data), rebirths = data.rebirths })
		DataService.MarkDirty(player, true)
	end
end

-- stat: "steal" | "collectMoney" | "collects" | "buy" | "sell" | "bonk"; rarity for buys.
function EconomyService.Stat(player: Player, stat: string, amount: number, rarity: string?)
	local p = DataService.Get(player)
	if not p then
		return
	end
	local data = p.data
	ensureQuests(player, data)
	local changed = false
	for _, q in data.quests.list do
		if q.claimed or q.progress >= q.goal then
			continue
		end
		local match = q.stat == stat
		if not match and rarity and stat == "buy" and string.sub(q.stat, 1, 3) == "buy" and #q.stat > 3 then
			local tier = string.sub(q.stat, 4)
			match = Rarities.ByKey[tier] ~= nil and Rarities.Order(rarity) >= Rarities.Order(tier)
		end
		if match then
			q.progress = math.min(q.goal, q.progress + amount)
			changed = true
			if q.progress >= q.goal then
				EconomyService.Notify(player, "📜 Quest complete: " .. q.text .. "! Claim it in Quests.", "success")
			end
		end
	end
	if changed then
		DataService.MarkDirty(player, true)
	end
end

function EconomyService.GiveLuckPotion(player: Player, data: any, seconds: number)
	local now = os.time()
	data.boosts.Luck2x = math.max(data.boosts.Luck2x or 0, now) + seconds
	DataService.MarkDirty(player, true)
end

function EconomyService.ClaimQuest(player: Player, index: number): (boolean, any)
	local p = DataService.Get(player)
	if not p then
		return false, "Still loading"
	end
	local data = p.data
	ensureQuests(player, data)
	local q = data.quests.list[index]
	if not q then
		return false, "No such quest"
	end
	if q.claimed then
		return false, "Already claimed"
	end
	if q.progress < q.goal then
		return false, "Not finished yet"
	end
	q.claimed = true
	if q.reward == "luck" then
		EconomyService.GiveLuckPotion(player, data, 600)
		EconomyService.Notify(player, "🍀 Luck Potion active for 10 minutes!", "success")
	else
		EconomyService.AddMoney(player, q.amount)
		EconomyService.Notify(player, "💵 +" .. Format.Money(q.amount), "money")
	end
	DataService.MarkDirty(player, true)
	return true, nil
end

-- 7-day login streak ------------------------------------------------------------------------
function EconomyService.LoginState(data: any): (boolean, number)
	local today = Quests.Day(os.time())
	local canClaim = data.login.lastDay ~= today
	local nextDay = if data.login.lastDay == today - 1 then (data.login.streak % 7) + 1 else 1
	if not canClaim then
		nextDay = data.login.streak
	end
	return canClaim, nextDay
end

function EconomyService.ClaimLogin(player: Player): (boolean, any)
	local p = DataService.Get(player)
	if not p then
		return false, "Still loading"
	end
	local data = p.data
	local canClaim, day = EconomyService.LoginState(data)
	if not canClaim then
		return false, "Come back tomorrow!"
	end
	data.login.lastDay = Quests.Day(os.time())
	data.login.streak = day
	local reward = Quests.Login[day]
	local income = EconomyService.Income(player, data)
	local text
	if reward.kind == "money" then
		local amount = Quests.LoginMoney(reward, income)
		EconomyService.AddMoney(player, amount)
		text = Format.Money(amount)
	elseif reward.kind == "luck" then
		EconomyService.GiveLuckPotion(player, data, 600)
		text = "a 10-minute Luck Potion"
	elseif reward.kind == "money2x" then
		data.boosts.Money2x = math.max(data.boosts.Money2x or 0, os.time()) + 900
		text = "15 minutes of 2x Money"
	else
		local t = Tungs.PickFromRarity(rng, "Legendary")
		Bus.Fire("GrantTung", player, t.id, Mutations.NONE, "Day 7 reward")
		text = "a FREE " .. t.name .. "!"
	end
	EconomyService.Notify(player, "📅 Day " .. day .. " reward: " .. text, "success")
	DataService.MarkDirty(player, true)
	return true, day
end

-- Index -------------------------------------------------------------------------------------
local function award(player: Player, key: string)
	local id = GameConfig.Badges[key]
	if id and id ~= 0 then
		task.spawn(function()
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		end)
	end
end

local function checkIndexRewards(player: Player, data: any)
	local found = 0
	for _, r in Rarities.List do
		local all = true
		for _, t in Tungs.IndexList do
			if t.rarity == r.key and not data.index[t.id] then
				all = false
			end
		end
		if all and not data.indexRewards[r.key] then
			data.indexRewards[r.key] = true
			award(player, r.key)
			EconomyService.Alert(player, "📖 " .. r.key .. " tab complete! +5% money forever", r.color, "Jackpot", "index")
		end
	end
	for _, t in Tungs.IndexList do
		if data.index[t.id] then
			found += 1
		end
	end
	for _, m in Mutations.List do
		local key = "Mut_" .. m.key
		if not data.indexRewards[key] then
			local all = true
			for _, t in Tungs.IndexList do
				local e = data.index[t.id]
				if not e or not e.m[m.key] then
					all = false
					break
				end
			end
			if all then
				data.indexRewards[key] = true
				EconomyService.Alert(player, m.icon .. " Every " .. m.name .. " Tung found! " .. m.name .. " avatar aura unlocked", m.color, "Jackpot", "index")
			end
		end
	end
	if found >= #Tungs.IndexList and not data.indexRewards.Master then
		data.indexRewards.Master = true
		award(player, "TungMaster")
		EconomyService.Alert(nil, "🏆 " .. player.DisplayName .. " completed the Index and became a TUNG MASTER!", Color3.fromRGB(255, 200, 40), "Jackpot", "index")
		Bus.Fire("AppearanceChanged", player)
		Bus.Fire("BaseChanged", player)
	end
end

-- Records a Tung (and its mutation) in the Index. Returns true if it's a new Tung.
function EconomyService.Discover(player: Player, id: string, mut: string?): boolean
	local p = DataService.Get(player)
	local t = Tungs.Get(id)
	if not p or not t or t.special then
		return false
	end
	local data = p.data
	local entry = data.index[id]
	local isNew = entry == nil
	if not entry then
		entry = { t = os.time(), m = {} }
		data.index[id] = entry
		EconomyService.Notify(player, "📖 New in your Index: " .. t.name .. "!", "success")
	end
	entry.m[mut or Mutations.NONE] = true
	checkIndexRewards(player, data)
	DataService.MarkDirty(player, true)
	return isNew
end

function EconomyService.EquipAura(player: Player, key: string): (boolean, any)
	local p = DataService.Get(player)
	if not p then
		return false, "Still loading"
	end
	if key ~= "" and not p.data.indexRewards["Mut_" .. key] then
		return false, "Find every " .. key .. " Tung to unlock this aura"
	end
	p.data.aura = if p.data.aura == key then "" else key
	DataService.MarkDirty(player, true)
	Bus.Fire("AppearanceChanged", player)
	return true, p.data.aura
end

-- In-game shop -------------------------------------------------------------------------------
function EconomyService.BuyItem(player: Player, key: string): (boolean, any)
	local p = DataService.Get(player)
	if not p then
		return false, "Still loading"
	end
	local data = p.data
	if key == "Bat" then
		local nextBat = Items.Bats[data.items.Bat + 1]
		if not nextBat then
			return false, "You have the best bat!"
		end
		if not EconomyService.Spend(player, nextBat.price) then
			return false, "Not enough money"
		end
		data.items.Bat = nextBat.tier
		Bus.Fire("AppearanceChanged", player)
		EconomyService.Notify(player, "🏏 Upgraded to the " .. nextBat.name .. "!", "success")
	elseif Items.GearByKey[key] then
		local gear = Items.GearByKey[key]
		if data.items[key] then
			return false, "You already own this"
		end
		if not EconomyService.Spend(player, gear.price) then
			return false, "Not enough money"
		end
		data.items[key] = true
		if key == "SpeedCoil" then
			Bus.Fire("AppearanceChanged", player)
		else
			Bus.Fire("BaseChanged", player)
		end
		EconomyService.Notify(player, gear.icon .. " " .. gear.name .. " installed!", "success")
	elseif Items.BoostByKey[key] then
		local boost = Items.BoostByKey[key]
		local price = Items.BoostPrice(boost, EconomyService.Income(player, data))
		if not EconomyService.Spend(player, price) then
			return false, "Not enough money"
		end
		data.boosts[key] = math.max(data.boosts[key] or 0, os.time()) + boost.duration
		EconomyService.Notify(player, boost.icon .. " " .. boost.name .. " active!", "success")
	else
		return false, "Unknown item"
	end
	DataService.MarkDirty(player, true)
	return true, nil
end

function EconomyService.SaveSettings(player: Player, s: any): (boolean, any)
	local p = DataService.Get(player)
	if not p or type(s) ~= "table" then
		return false, nil
	end
	local st = p.data.settings
	if type(s.music) == "number" then
		st.music = math.clamp(s.music, 0, 1)
	end
	if type(s.sfx) == "number" then
		st.sfx = math.clamp(s.sfx, 0, 1)
	end
	if type(s.low) == "boolean" then
		st.low = s.low
	end
	if type(s.hideAuras) == "boolean" then
		st.hideAuras = s.hideAuras
	end
	return true, nil
end

-- Friend boost: +10% per friend in the server, up to +30% --------------------------------------
local friendCache: { [Player]: { [number]: boolean } } = {}

local function refreshFriendBoosts()
	for _, a in Players:GetPlayers() do
		local n = 0
		local cache = friendCache[a]
		if cache then
			for _, b in Players:GetPlayers() do
				if b ~= a and cache[b.UserId] then
					n += 1
				end
			end
		end
		local bonus = math.min(Economy.FRIEND_BONUS_MAX, n * Economy.FRIEND_BONUS)
		if a:GetAttribute("FriendBoost") ~= bonus then
			a:SetAttribute("FriendBoost", bonus)
			DataService.MarkDirty(a)
		end
	end
end

local function cacheFriends(player: Player)
	local cache: { [number]: boolean } = {}
	friendCache[player] = cache
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return (player :: any):IsFriendsWithAsync(other.UserId)
			end)
			if not ok then
				ok, isFriend = pcall(function()
					return (player :: any):IsFriendsWith(other.UserId)
				end)
			end
			if ok and isFriend then
				cache[other.UserId] = true
				local otherCache = friendCache[other]
				if otherCache then
					otherCache[player.UserId] = true
				end
			end
		end
	end
	refreshFriendBoosts()
end

function EconomyService.IsFriend(a: Player, b: Player): boolean
	local cache = friendCache[a]
	return cache ~= nil and cache[b.UserId] == true
end

function EconomyService.Init()
	-- Extra values every client snapshot carries.
	DataService.Decorate = function(player, data, snap)
		local now = os.time()
		snap.income = EconomyService.Income(player, data)
		snap.mult = EconomyService.Multiplier(player, data)
		snap.luck = Economy.PersonalLuck(data, now)
		snap.serverLuck = (Workspace:GetAttribute("ServerLuck") :: number?) or 1
		snap.friendBoost = EconomyService.FriendBonus(player)
		snap.slotsMax = Economy.Slots(data)
		snap.base = player:GetAttribute("Base")
		snap.shieldLeft = math.max(0, Economy.SHIELD_SECONDS - data.playtime)
		snap.carrying = player:GetAttribute("Carrying")
		local canClaim, day = EconomyService.LoginState(data)
		snap.loginCanClaim = canClaim
		snap.loginDay = day
	end

	DataService.OnLoaded(function(profile)
		ensureQuests(profile.player, profile.data)
	end)

	Players.PlayerAdded:Connect(cacheFriends)
	for _, pl in Players:GetPlayers() do
		task.spawn(cacheFriends, pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player] = nil
		task.defer(refreshFriendBoosts)
	end)

	Bus.On("Stat", function(player: Player, stat: string, amount: number, rarity: string?)
		EconomyService.Stat(player, stat, amount, rarity)
	end)
end

return EconomyService
