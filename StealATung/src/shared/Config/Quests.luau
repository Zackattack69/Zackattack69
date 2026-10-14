--!strict
-- Daily quests (3 per UTC day) and the 7-day login streak calendar.

local Economy = require(script.Parent.Economy)

export type Quest = {
	id: string,
	stat: string,
	text: string,
	goal: number,
	progress: number,
	reward: string, -- "money" | "luck"
	amount: number, -- money reward (0 for luck potions)
	claimed: boolean,
}

export type Context = { income: number, rebirths: number }

type Template = {
	id: string,
	weight: number,
	make: (Context) -> (string, string, number), -- stat, text, goal
}

local Quests = {}

Quests.PER_DAY = 3

local function tierFor(ctx: Context): string
	if ctx.rebirths >= 3 then
		return "Secret"
	elseif ctx.rebirths >= 1 then
		return "Legendary"
	elseif ctx.income >= 300 then
		return "Epic"
	end
	return "Rare"
end

local TEMPLATES: { Template } = {
	{ id = "Steal", weight = 3, make = function(_)
		return "steal", "Steal 3 Tungs", 3
	end },
	{ id = "Collect", weight = 3, make = function(ctx)
		local goal = Economy.Nice(math.max(1000, ctx.income * 1200))
		return "collectMoney", "Collect $" .. Quests.Short(goal), goal
	end },
	{ id = "BuyTier", weight = 3, make = function(ctx)
		local tier = tierFor(ctx)
		local n = if tier == "Rare" or tier == "Epic" then 2 else 1
		return "buy" .. tier, "Buy " .. n .. " " .. tier .. (if n > 1 then "s" else "") .. " (or better)", n
	end },
	{ id = "Buy", weight = 2, make = function(_)
		return "buy", "Buy 8 Tungs from the belt", 8
	end },
	{ id = "Bonk", weight = 2, make = function(_)
		return "bonk", "Bonk 2 thieves with your bat", 2
	end },
	{ id = "Sell", weight = 1, make = function(_)
		return "sell", "Sell 3 Tungs at the sell stand", 3
	end },
	{ id = "Collects", weight = 2, make = function(_)
		return "collects", "Press Collect 30 times", 30
	end },
}

-- Compact number for quest text (avoids requiring Format from config).
function Quests.Short(n: number): string
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local tier = math.clamp(math.floor(math.log10(math.max(n, 1)) / 3), 0, #suffixes - 1)
	local v = n / 10 ^ (tier * 3)
	local s = if v == math.floor(v) then tostring(math.floor(v)) else string.format("%.1f", v)
	return s .. suffixes[tier + 1]
end

function Quests.Roll(rng: Random, ctx: Context): { Quest }
	local pool = table.clone(TEMPLATES)
	local out: { Quest } = {}
	while #out < Quests.PER_DAY and #pool > 0 do
		local total = 0
		for _, t in pool do
			total += t.weight
		end
		local roll = rng:NextNumber() * total
		local pick = 1
		for i, t in pool do
			roll -= t.weight
			if roll <= 0 then
				pick = i
				break
			end
		end
		local t = table.remove(pool, pick) :: Template
		local stat, text, goal = t.make(ctx)
		local luck = rng:NextNumber() < 0.35
		table.insert(out, {
			id = t.id,
			stat = stat,
			text = text,
			goal = goal,
			progress = 0,
			reward = if luck then "luck" else "money",
			amount = if luck then 0 else Economy.Nice(math.max(500, ctx.income * 900)),
			claimed = false,
		})
	end
	return out
end

-- 7-day login calendar; day 7 gives a free Legendary.
export type LoginReward = { day: number, kind: string, minutes: number, min: number, icon: string, text: string }

Quests.Login = {
	{ day = 1, kind = "money", minutes = 5, min = 100, icon = "💵", text = "Cash" },
	{ day = 2, kind = "luck", minutes = 0, min = 0, icon = "🍀", text = "Luck Potion" },
	{ day = 3, kind = "money", minutes = 15, min = 500, icon = "💰", text = "Big Cash" },
	{ day = 4, kind = "money2x", minutes = 0, min = 0, icon = "💸", text = "2x Money 15m" },
	{ day = 5, kind = "money", minutes = 30, min = 2000, icon = "🤑", text = "Huge Cash" },
	{ day = 6, kind = "luck", minutes = 0, min = 0, icon = "🍀", text = "Luck Potion" },
	{ day = 7, kind = "legendary", minutes = 0, min = 0, icon = "👑", text = "FREE Legendary!" },
} :: { LoginReward }

function Quests.LoginMoney(r: LoginReward, income: number): number
	return Economy.Nice(math.max(r.min, income * 60 * r.minutes))
end

function Quests.Day(unixTime: number): number
	return unixTime // 86400
end

return Quests
