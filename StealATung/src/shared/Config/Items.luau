--!strict
-- In-game shop (paid with money): bats, gear, traps and timed boosts.
-- Items are kept through rebirths; only money and Tungs are wiped.

export type Bat = {
	tier: number,
	name: string,
	price: number,
	reach: number, -- studs
	cooldown: number, -- seconds between swings
	knock: number, -- knockback speed
	color: Color3,
	material: Enum.Material,
}

export type Gear = {
	key: string,
	name: string,
	icon: string,
	price: number,
	desc: string,
}

export type Boost = {
	key: string,
	name: string,
	icon: string,
	minutesOfIncome: number, -- price = this many minutes of your current income
	min: number,
	duration: number,
	desc: string,
}

local Items = {}

Items.Bats = {
	{ tier = 1, name = "Wooden Bat", price = 0, reach = 8, cooldown = 1.0, knock = 45, color = Color3.fromRGB(214, 170, 110), material = Enum.Material.Wood },
	{ tier = 2, name = "Stone Bat", price = 25e3, reach = 9, cooldown = 0.9, knock = 55, color = Color3.fromRGB(140, 140, 150), material = Enum.Material.Slate },
	{ tier = 3, name = "Iron Bat", price = 1e6, reach = 10, cooldown = 0.8, knock = 65, color = Color3.fromRGB(190, 196, 206), material = Enum.Material.Metal },
	{ tier = 4, name = "Golden Bat", price = 100e6, reach = 11.5, cooldown = 0.7, knock = 80, color = Color3.fromRGB(255, 200, 45), material = Enum.Material.Foil },
	{ tier = 5, name = "Diamond Bat", price = 10e9, reach = 13, cooldown = 0.6, knock = 95, color = Color3.fromRGB(140, 230, 255), material = Enum.Material.Glass },
} :: { Bat }

Items.Gear = {
	{ key = "SpeedCoil", name = "Speed Coil", icon = "🌀", price = 50e3, desc = "+4 walk speed, forever." },
	{ key = "Banana", name = "Banana Peel Trap", icon = "🍌", price = 10e3, desc = "Intruders slip and drop what they carry. Re-arms after 15 s." },
	{ key = "Honey", name = "Sticky Honey Pad", icon = "🍯", price = 150e3, desc = "Slows intruders by 60% for 3 seconds." },
	{ key = "Alarm", name = "Tung Alarm", icon = "🚨", price = 500e3, desc = "Rings and warns you when someone walks into your base." },
} :: { Gear }

Items.Boosts = {
	{ key = "Money2x", name = "2x Money", icon = "💸", minutesOfIncome = 10, min = 500, duration = 15 * 60, desc = "Double money from every pad for 15 minutes." },
	{ key = "Luck2x", name = "Luck Potion", icon = "🍀", minutesOfIncome = 8, min = 400, duration = 10 * 60, desc = "+100% personal luck for 10 minutes (your personal belt, and the server belt if you're the luckiest)." },
} :: { Boost }

Items.GearByKey = {} :: { [string]: Gear }
for _, g in Items.Gear do
	Items.GearByKey[g.key] = g
end
Items.BoostByKey = {} :: { [string]: Boost }
for _, b in Items.Boosts do
	Items.BoostByKey[b.key] = b
end

function Items.Bat(tier: number): Bat
	return Items.Bats[math.clamp(tier, 1, #Items.Bats)]
end

function Items.BoostPrice(boost: Boost, incomePerSecond: number): number
	local raw = math.max(boost.min, incomePerSecond * 60 * boost.minutesOfIncome)
	if raw < 100 then
		return math.floor(raw)
	end
	local mag = 10 ^ (math.floor(math.log10(raw)) - 1)
	return math.floor(raw / mag) * mag
end

return Items
