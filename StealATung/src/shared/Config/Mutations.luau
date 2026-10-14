--!strict
-- Mutations: any Tung can spawn with one. It changes the skin and multiplies
-- both income and price. Rolled independently of rarity.

export type Mutation = {
	key: string,
	name: string,
	chance: number,
	mult: number,
	color: Color3,
	look: string,
	icon: string,
}

local Mutations = {}

Mutations.NONE = "None"

Mutations.List = {
	{ key = "Gold", name = "Gold", chance = 0.03, mult = 2, color = Color3.fromRGB(255, 200, 45), look = "Shiny gold skin", icon = "🟡" },
	{ key = "Diamond", name = "Diamond", chance = 0.01, mult = 3, color = Color3.fromRGB(140, 225, 255), look = "Crystal see-through skin", icon = "💎" },
	{ key = "Rainbow", name = "Rainbow", chance = 0.003, mult = 5, color = Color3.fromRGB(255, 110, 210), look = "Colour-cycling skin", icon = "🌈" },
	{ key = "Cursed", name = "Cursed", chance = 0.001, mult = 8, color = Color3.fromRGB(160, 20, 45), look = "Dark skin, red eyes, creepy laugh", icon = "💀" },
} :: { Mutation }

Mutations.ByKey = {} :: { [string]: Mutation }
for _, m in Mutations.List do
	Mutations.ByKey[m.key] = m
end

function Mutations.Get(key: string?): Mutation?
	if not key then
		return nil
	end
	return Mutations.ByKey[key]
end

function Mutations.Mult(key: string?): number
	local m = Mutations.Get(key)
	return if m then m.mult else 1
end

-- Rolls the rarest mutation first. Golden Belt forces at least Gold.
function Mutations.Roll(rng: Random, forceGold: boolean?): string
	local r = rng:NextNumber()
	local acc = 0
	for i = #Mutations.List, 1, -1 do
		local m = Mutations.List[i]
		acc += m.chance
		if r < acc then
			return m.key
		end
	end
	return if forceGold then "Gold" else Mutations.NONE
end

-- "Gold King Tung"
function Mutations.Prefix(key: string?): string
	local m = Mutations.Get(key)
	return if m then m.name .. " " else ""
end

return Mutations
