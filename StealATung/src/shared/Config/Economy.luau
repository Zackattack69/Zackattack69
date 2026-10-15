--!strict
-- Every number that shapes pacing lives here: rebirth table, multipliers, luck,
-- stealing, base lock, belt timing. Shared so the client can show the same
-- values the server enforces.

local Rarities = require(script.Parent.Rarities)
local Tungs = require(script.Parent.Tungs)
local Mutations = require(script.Parent.Mutations)
local Format = require(script.Parent.Parent.Util.Format)

local Economy = {}

Economy.STARTING_MONEY = 100
Economy.COLLECT_CAP_SECONDS = 3600 -- each pad stores up to 1 hour of its income
Economy.SELL_FRACTION = 0.5
Economy.MAX_SLOTS = 30 -- rebirth slots stop growing here (VIP adds +1 on top)
Economy.PADS_PER_ROW = 6

-- Belt
Economy.BELT_INTERVAL = 3 -- a new Tung every 3 s
Economy.BELT_TRAVEL = 40 -- each Tung rides the full-length belt for 40 s (~10 studs/s, a slow walk)
Economy.SPEED_BELT_MULT = 1.5 -- Speed Belt event: belt speed (it also spawns twice as often)
Economy.PERSONAL_BELT_INTERVAL = 30 -- Rebirth 6 perk
Economy.BUY_HOLD = 0.25 -- short, so you can grab a Tung as it rides past

-- Stealing & defence
Economy.STEAL_HOLD = 1.5
Economy.STEAL_HOLD_THIEF_NIGHT = 0.75
Economy.CARRY_SPEED = 0.7 -- thieves walk 30% slower
Economy.STEAL_COOLDOWN = 8 -- per thief, after a steal ends (success or drop)
Economy.WALK_HOME_TIME = 3
Economy.SHIELD_SECONDS = 600 -- new-player shield: first 10 minutes of playtime
Economy.LOCK_DURATION = 60
Economy.LOCK_DURATION_PERK = 90 -- Rebirth 3 perk
Economy.LOCK_COOLDOWN = 120 -- measured from the moment the lock closes
Economy.BASE_WALKSPEED = 16

-- Social
Economy.FRIEND_BONUS = 0.10
Economy.FRIEND_BONUS_MAX = 0.30
Economy.INDEX_RARITY_BONUS = 0.05

export type RebirthInfo = {
	level: number,
	cost: number,
	needRarity: string?,
	needCount: number,
	mult: number,
	slots: number,
	perk: string?,
}

-- Rebirth table (Design Doc). Level 0 is the starting state.
local TABLE: { RebirthInfo } = {
	{ level = 0, cost = 0, needRarity = nil, needCount = 0, mult = 1, slots = 8, perk = nil },
	{ level = 1, cost = 1e6, needRarity = "Epic", needCount = 1, mult = 1.5, slots = 10, perk = "Collect All button" },
	{ level = 2, cost = 1e7, needRarity = "Legendary", needCount = 1, mult = 2, slots = 12, perk = "+10% walk speed" },
	{ level = 3, cost = 1e8, needRarity = "Legendary", needCount = 2, mult = 3, slots = 14, perk = "Base lock lasts 90 seconds" },
	{ level = 4, cost = 1e9, needRarity = "Secret", needCount = 1, mult = 5, slots = 16, perk = "+5% luck on the belt" },
	{ level = 5, cost = 1e10, needRarity = "Secret", needCount = 2, mult = 8, slots = 18, perk = "Rebirth-only cosmetic trail" },
	{ level = 6, cost = 1e11, needRarity = "Mythic", needCount = 1, mult = 12, slots = 20, perk = "Personal belt: 1 Tung every 30 s, just for you" },
}

function Economy.Rebirth(level: number): RebirthInfo
	if level < #TABLE then
		return TABLE[level + 1]
	end
	-- 7+: cost x10 each time, +5x multiplier, +2 slots
	local extra = level - 6
	return {
		level = level,
		cost = 1e11 * 10 ^ extra,
		needRarity = "Mythic",
		needCount = 1,
		mult = 12 + 5 * extra,
		slots = math.min(Economy.MAX_SLOTS, 20 + 2 * extra),
		perk = nil,
	}
end

Economy.PERKS = {
	[1] = "Collect All button",
	[2] = "+10% walk speed",
	[3] = "Base lock lasts 90 seconds",
	[4] = "+5% luck on the belt",
	[5] = "Rebirth-only cosmetic trail",
	[6] = "Personal belt (1 Tung every 30 s)",
}

function Economy.HasPass(data: any, key: string): boolean
	return data.passes ~= nil and data.passes[key] == true
end

function Economy.Slots(data: any): number
	return Economy.Rebirth(data.rebirths).slots + (if Economy.HasPass(data, "VIP") then 1 else 0)
end

function Economy.CanCollectAll(data: any): boolean
	return data.rebirths >= 1 or Economy.HasPass(data, "CollectAll")
end

function Economy.LockDuration(data: any): number
	local base = if data.rebirths >= 3 then Economy.LOCK_DURATION_PERK else Economy.LOCK_DURATION
	return if Economy.HasPass(data, "LockMaster") then base * 2 else base
end

Economy.SHIELD_DURATION = 300 -- Base Shield (Robux): a 5-minute lock

function Economy.WalkSpeed(data: any): number
	local s = Economy.BASE_WALKSPEED
	if data.rebirths >= 2 then
		s *= 1.1
	end
	if data.items and data.items.SpeedCoil then
		s += 4
	end
	return s
end

-- Index bonus: +5% for each fully completed rarity tab.
function Economy.IndexBonus(data: any): number
	local n = 0
	for _, r in Rarities.List do
		if data.indexRewards and data.indexRewards[r.key] then
			n += 1
		end
	end
	return n * Economy.INDEX_RARITY_BONUS
end

-- Total money multiplier. `friendBonus` is runtime-only (0 .. 0.3).
function Economy.Multiplier(data: any, now: number, friendBonus: number): number
	local m = Economy.Rebirth(data.rebirths).mult
	if Economy.HasPass(data, "DoubleMoney") then
		m *= 2
	end
	if data.boosts and (data.boosts.Money2x or 0) > now then
		m *= 2
	end
	return m * (1 + friendBonus + Economy.IndexBonus(data))
end

function Economy.TungIncome(id: string, mut: string?): number
	local t = Tungs.Get(id)
	if not t then
		return 0
	end
	return t.income * Mutations.Mult(mut)
end

-- Robux cash packs scale with how much money you have right now (and your
-- income), so they're worth it at every stage. Pack 1..5.
Economy.CASH_PACK_MULT = { 1, 8, 32, 160, 330 }
function Economy.CashPackAmount(pack: number, money: number, income: number): number
	local base = math.max(10000, money * 0.25, income * 300)
	return Economy.Nice(base * (Economy.CASH_PACK_MULT[pack] or 1))
end

-- Iconic Tungs earn a share of everything else in your base instead of a fixed amount.
Economy.ICONIC_SHARE = 0.2

function Economy.IsIconic(id: string): boolean
	local t = Tungs.Get(id)
	return t ~= nil and t.rarity == "Iconic"
end

-- Extra share of income an Iconic Tung adds (0.2 = +20%; mutations multiply it).
function Economy.IconicShare(id: string, mut: string?): number
	return if Economy.IsIconic(id) then Economy.ICONIC_SHARE * Mutations.Mult(mut) else 0
end

-- Income/s from a set of slots before multipliers: (fixed income, iconic share).
function Economy.SlotIncome(slots: { [any]: any }): (number, number)
	local fixed, share = 0, 0
	for _, s in slots do
		if Economy.IsIconic(s.id) then
			share += Economy.IconicShare(s.id, s.m)
		else
			fixed += Economy.TungIncome(s.id, s.m)
		end
	end
	return fixed, share
end

-- What a Tung's income looks like on nameplates and cards.
function Economy.IncomeText(id: string, mut: string?): string
	if Economy.IsIconic(id) then
		return "+" .. math.floor(Economy.IconicShare(id, mut) * 100 + 0.5) .. "% income"
	end
	return Format.Money(Economy.TungIncome(id, mut)) .. "/s"
end

function Economy.TungPrice(id: string, mut: string?): number
	local t = Tungs.Get(id)
	if not t then
		return 0
	end
	return t.price * Mutations.Mult(mut)
end

function Economy.SellPrice(id: string, mut: string?): number
	return math.floor(Economy.TungPrice(id, mut) * Economy.SELL_FRACTION)
end

-- Personal luck: Rebirth 4 (+5%), Lucky Belt pass (+25%), personal Luck Potion (+100%).
function Economy.PersonalLuck(data: any, now: number): number
	local l = 1
	if data.rebirths >= 4 then
		l += 0.05
	end
	if Economy.HasPass(data, "LuckyBelt") then
		l += 0.25
	end
	if data.boosts and (data.boosts.Luck2x or 0) > now then
		l += 1
	end
	return l
end

-- Counts placed Tungs at or above a rarity (for rebirth requirements).
function Economy.CountAtLeast(data: any, rarity: string): number
	local need = Rarities.Order(rarity)
	local n = 0
	for _, s in data.slots do
		local t = Tungs.Get(s.id)
		if t and not t.special and t.rarity ~= "Iconic" and Rarities.Order(t.rarity) >= need then
			n += 1
		end
	end
	return n
end

-- Returns (ok, reasonIfNot). `useSkip` ignores the money cost (Skip Rebirth token).
function Economy.CanRebirth(data: any, useSkip: boolean): (boolean, string?)
	local nextInfo = Economy.Rebirth(data.rebirths + 1)
	if not useSkip and data.money < nextInfo.cost then
		return false, "Not enough money"
	end
	if nextInfo.needRarity and Economy.CountAtLeast(data, nextInfo.needRarity) < nextInfo.needCount then
		return false, "You need " .. nextInfo.needCount .. " " .. nextInfo.needRarity .. " Tung" .. (if nextInfo.needCount > 1 then "s" else "") .. " in your base"
	end
	return true, nil
end

-- Rounds to a friendly number (2 significant figures) for quest goals & rewards.
function Economy.Nice(n: number): number
	if n < 100 then
		return math.max(1, math.floor(n))
	end
	local mag = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / mag) * mag
end

return Economy
