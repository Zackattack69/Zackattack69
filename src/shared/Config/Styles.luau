--!strict
-- Cosmetic style layer (Design Doc §5.2). Rolled independently AFTER rarity.

export type Style = {
	name: string,
	chance: number, -- 1 in N; 0 = default
	bonus: number, -- additive multiplier bonus (0.25 = +25%)
	color: Color3,
	badge: string, -- small glyph shown in inventory card corner
	material: Enum.Material,
}

local Styles = {}

-- Ordered rarest first so the roll checks the rarest style first.
Styles.List = {
	{ name = "Rainbow", chance = 1000, bonus = 1.5, color = Color3.fromRGB(255, 120, 220), badge = "🌈", material = Enum.Material.Neon },
	{ name = "Neon", chance = 300, bonus = 0.75, color = Color3.fromRGB(0, 255, 230), badge = "⚡", material = Enum.Material.Neon },
	{ name = "Shadow", chance = 150, bonus = 0.5, color = Color3.fromRGB(40, 20, 60), badge = "🌑", material = Enum.Material.SmoothPlastic },
	{ name = "Diamond", chance = 150, bonus = 0.5, color = Color3.fromRGB(170, 240, 255), badge = "💎", material = Enum.Material.Glass },
	{ name = "Gold", chance = 40, bonus = 0.25, color = Color3.fromRGB(255, 200, 40), badge = "⭐", material = Enum.Material.Foil },
	{ name = "Standard", chance = 0, bonus = 0, color = Color3.fromRGB(255, 255, 255), badge = "", material = Enum.Material.SmoothPlastic },
} :: { Style }

Styles.ByName = {} :: { [string]: Style }
for _, s in Styles.List do
	Styles.ByName[s.name] = s
end

-- Tokens that can be bought to force a style (shop "Guarantee Tokens")
Styles.TokenStyles = { "Gold", "Diamond", "Shadow", "Neon", "Rainbow" }

-- rng: a Random object. luckMult only nudges style odds slightly (styles are the
-- "pure flex" layer, so luck passes give x1.25 rather than x2).
function Styles.Roll(rng: Random, luckMult: number?): string
	local luck = luckMult or 1
	local roll = rng:NextNumber()
	local acc = 0
	for _, s in Styles.List do
		if s.chance > 0 then
			acc += (1 / s.chance) * luck
			if roll < acc then
				return s.name
			end
		end
	end
	return "Standard"
end

function Styles.Get(name: string): Style
	return Styles.ByName[name] or Styles.ByName.Standard
end

return Styles
