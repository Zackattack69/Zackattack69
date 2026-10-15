--!strict
-- The 7 rarity tiers. A rarity's colour is its aura AND its UI colour everywhere
-- (belt nameplates, Index, pads, collect buttons), so a player can read a Tung's
-- rarity from across the map.

export type Rarity = {
	key: string,
	order: number,
	color: Color3,
	color2: Color3, -- darker shade for gradients / outlines
	weight: number, -- base % chance per belt spawn (before luck)
	aura: string, -- description shown in the Index
	incomeRange: string,
	scale: number, -- model size multiplier: rarer Tungs are bigger
	rainbow: boolean?,
	iconic: boolean?, -- outside the normal ladder: earns a share of your income (Economy.ICONIC_SHARE)
}

local Rarities = {}

Rarities.List = {
	{ key = "Common", order = 1, color = Color3.fromRGB(178, 182, 192), color2 = Color3.fromRGB(110, 114, 126), weight = 55, aura = "None, small dust puff when placed", incomeRange = "1–5", scale = 1 },
	{ key = "Uncommon", order = 2, color = Color3.fromRGB(90, 210, 80), color2 = Color3.fromRGB(35, 135, 45), weight = 25, aura = "Faint green ring at the feet", incomeRange = "8–25", scale = 1 },
	{ key = "Rare", order = 3, color = Color3.fromRGB(60, 150, 255), color2 = Color3.fromRGB(25, 80, 200), weight = 12, aura = "Soft glow + floating sparkles", incomeRange = "40–120", scale = 1.05 },
	{ key = "Epic", order = 4, color = Color3.fromRGB(175, 85, 255), color2 = Color3.fromRGB(105, 35, 190), weight = 5, aura = "Pulsing outline + orbiting particles", incomeRange = "200–600", scale = 1.1 },
	{ key = "Legendary", order = 5, color = Color3.fromRGB(255, 200, 40), color2 = Color3.fromRGB(225, 130, 15), weight = 2.2, aura = "Gold light beam + glitter trail", incomeRange = "1,000–3,500", scale = 1.18 },
	{ key = "Secret", order = 6, color = Color3.fromRGB(38, 36, 46), color2 = Color3.fromRGB(10, 10, 14), weight = 0.6, aura = "Shifting rainbow outline + shadow smoke", incomeRange = "8,000–25,000", scale = 1.25, rainbow = true },
	{ key = "Mythic", order = 7, color = Color3.fromRGB(255, 60, 60), color2 = Color3.fromRGB(150, 15, 25), weight = 0.2, aura = "Full-body flame aura + ground cracks + sky beam", incomeRange = "100,000–1,000,000", scale = 1.4 },
	-- Iconic: no normal rarity. Each one earns 20% of everything else you make, and they're huge.
	{ key = "Iconic", order = 8, color = Color3.fromRGB(40, 225, 210), color2 = Color3.fromRGB(10, 130, 150), weight = 0.25, aura = "Spinning star ring + turquoise sparkles", incomeRange = "+20% of your income", scale = 1.65, iconic = true },
} :: { Rarity }

Rarities.ByKey = {} :: { [string]: Rarity }
for _, r in Rarities.List do
	Rarities.ByKey[r.key] = r
end

-- Rainbow used for Secret UI and the Rainbow mutation.
Rarities.RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 230, 90)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 190, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
})

function Rarities.Get(key: string): Rarity
	return Rarities.ByKey[key] or Rarities.List[1]
end

function Rarities.Order(key: string): number
	return Rarities.Get(key).order
end

-- Spawn weights after luck. `luck` multiplies every tier from Rare upward (so
-- Common/Uncommon become relatively rarer); `sahur` multiplies Secret + Mythic
-- again (Sahur Hour triples them).
function Rarities.Weights(luck: number, sahur: number): { [string]: number }
	local w = {}
	for _, r in Rarities.List do
		local x = r.weight
		if r.order >= 3 then
			x *= luck
		end
		if r.key == "Secret" or r.key == "Mythic" then
			x *= sahur
		end
		w[r.key] = x
	end
	return w
end

function Rarities.Roll(rng: Random, luck: number, sahur: number): string
	local w = Rarities.Weights(luck, sahur)
	local total = 0
	for _, r in Rarities.List do
		total += w[r.key]
	end
	local roll = rng:NextNumber() * total
	for _, r in Rarities.List do
		roll -= w[r.key]
		if roll <= 0 then
			return r.key
		end
	end
	return "Common"
end

return Rarities
