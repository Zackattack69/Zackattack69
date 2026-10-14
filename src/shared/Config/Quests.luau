--!strict
-- Bounty Board quests. Players always have 3 active bounties; finishing one pays
-- Nova Crystals and rolls a new one.

export type QuestTemplate = {
	id: string,
	stat: string, -- which counter in data.stats this quest tracks
	text: string, -- %d is replaced with the goal
	goals: { number },
	reward: { number }, -- Nova reward, same index as goals
}

local Quests = {}

Quests.ACTIVE = 3

Quests.Templates = {
	{ id = "Clicks", stat = "clicks", text = "Salvage scrap %d times", goals = { 100, 300, 800 }, reward = { 5, 10, 20 } },
	{ id = "Crates", stat = "crates", text = "Open %d crates", goals = { 3, 8, 20 }, reward = { 6, 12, 25 } },
	{ id = "Fuse", stat = "fuses", text = "Fuse droids %d times", goals = { 1, 3 }, reward = { 10, 25 } },
	{ id = "Upgrades", stat = "upgrades", text = "Buy %d foundry upgrades", goals = { 5, 15, 30 }, reward = { 6, 12, 20 } },
	{ id = "Rares", stat = "rares", text = "Unbox %d Rare-or-better droids", goals = { 1, 3, 6 }, reward = { 10, 20, 35 } },
	{ id = "Travel", stat = "travels", text = "Make %d hyperspace jumps", goals = { 2, 5 }, reward = { 5, 10 } },
	{ id = "Playtime", stat = "minutes", text = "Run your foundry for %d minutes", goals = { 10, 30 }, reward = { 8, 20 } },
} :: { QuestTemplate }

Quests.ById = {} :: { [string]: QuestTemplate }
for _, q in Quests.Templates do
	Quests.ById[q.id] = q
end

function Quests.Describe(q: any): string
	local t = Quests.ById[q.template]
	return string.format(t.text, q.goal)
end

-- Picks a quest template not already active.
function Quests.Roll(rng: Random, active: { any }, stats: { [string]: number }): any
	local taken = {}
	for _, q in active do
		taken[q.template] = true
	end
	local options = {}
	for _, t in Quests.Templates do
		if not taken[t.id] then
			table.insert(options, t)
		end
	end
	local t = options[rng:NextInteger(1, #options)]
	local tier = rng:NextInteger(1, #t.goals)
	return {
		template = t.id,
		goal = t.goals[tier],
		reward = t.reward[tier],
		start = stats[t.stat] or 0, -- progress is measured from this baseline
	}
end

return Quests
