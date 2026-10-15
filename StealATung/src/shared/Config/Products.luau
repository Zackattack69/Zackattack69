--!strict
-- Robux items (Design Doc: Monetization).
--
-- SETUP: create each Game Pass / Developer Product on the Creator Dashboard at
-- the listed price, then paste its numeric ID into `assetId`. Items left at
-- assetId = 0 show "Coming soon" in the shop and can't be bought.
--
-- Fairness rules: nothing sold lets you steal without risk, and Mythics are
-- never directly buyable (eggs top out at Secret).
--
-- Eggs are paid random items: their odds are shown before buying (see
-- Config/Eggs) and the Eggs tab is hidden where Roblox doesn't allow them.

export type Product = {
	key: string,
	name: string,
	kind: "Gamepass" | "Product",
	price: number,
	assetId: number,
	icon: string,
	description: string,
	shop: string?, -- which Shop tab shows it ("Eggs", "Robux", "Passes")
}

local Products = {}

Products.List = {
	-- Game Passes
	{ key = "DoubleMoney", name = "2x Money", kind = "Gamepass", price = 399, assetId = 0, icon = "💰", description = "Permanently double income from every pad." },
	{ key = "VIP", name = "VIP", kind = "Gamepass", price = 499, assetId = 0, icon = "👑", description = "[VIP] chat tag, gold name, +1 slot and the VIP-only VIP Tung." },
	{ key = "CollectAll", name = "Collect All", kind = "Gamepass", price = 99, assetId = 0, icon = "🧲", description = "Collect All button from the very start." },
	{ key = "AutoLock", name = "Auto Lock", kind = "Gamepass", price = 149, assetId = 0, icon = "🔒", description = "Your base re-locks itself every time the cooldown ends." },
	{ key = "LuckyBelt", name = "Lucky Belt", kind = "Gamepass", price = 299, assetId = 0, icon = "🍀", description = "+25% luck on all your spawns." },
	{ key = "LockMaster", name = "Lock Master", kind = "Gamepass", price = 249, assetId = 0, icon = "🛡️", description = "Your base lock lasts twice as long." },
	{ key = "RainbowTrail", name = "Rainbow Trail", kind = "Gamepass", price = 149, assetId = 0, icon = "🌈", description = "A glowing rainbow trail follows you everywhere." },
	{ key = "DiamondBase", name = "Diamond Base", kind = "Gamepass", price = 199, assetId = 0, icon = "💎", description = "Unlocks the sparkling Diamond base skin at your Skins stand." },
	-- Developer Products
	{ key = "LuckPotion", name = "Server Luck Potion", kind = "Product", price = 49, assetId = 0, icon = "🧪", description = "3x luck for the WHOLE server for 10 minutes. Everyone will thank you!" },
	{ key = "InstantTung", name = "Instant Tung", kind = "Product", price = 99, assetId = 0, icon = "⚡", description = "A random Legendary Tung rides the belt just for you, and it's free to grab." },
	{ key = "SkipRebirth", name = "Skip Rebirth Cost", kind = "Product", price = 149, assetId = 0, icon = "⏩", description = "Rebirth once without paying the money cost (you still need the required Tungs)." },
	-- Cash packs: the amount grows with how much money you have (Economy.CashPackAmount)
	{ key = "Cash1", name = "Stack of Cash", kind = "Product", price = 49, assetId = 0, icon = "💵", description = "A stack of cash." },
	{ key = "Cash2", name = "Pile of Cash", kind = "Product", price = 99, assetId = 0, icon = "💵", description = "A big pile of cash." },
	{ key = "Cash3", name = "Mountain of Cash", kind = "Product", price = 249, assetId = 0, icon = "💰", description = "A mountain of cash." },
	{ key = "Cash4", name = "Bag of Cash", kind = "Product", price = 499, assetId = 0, icon = "💰", description = "A huge bag of cash." },
	{ key = "Cash5", name = "Vault of Cash", kind = "Product", price = 799, assetId = 0, icon = "🏦", description = "A whole vault of cash." },
	{ key = "BaseShield", name = "Base Shield", kind = "Product", price = 79, assetId = 0, icon = "🔰", description = "Locks your base for 5 minutes, even on cooldown. (Waits until Thief Night is over.)" },
	-- Eggs: 1 / 3 / 10 of each (Developer Products; contents and odds in Config/Eggs)
	{ key = "EggTung1", name = "Tung Egg", kind = "Product", price = 49, assetId = 0, icon = "🥚", description = "1 Tung Egg", shop = "Eggs" },
	{ key = "EggTung3", name = "Tung Egg x3", kind = "Product", price = 129, assetId = 0, icon = "🥚", description = "3 Tung Eggs", shop = "Eggs" },
	{ key = "EggTung10", name = "Tung Egg x10", kind = "Product", price = 399, assetId = 0, icon = "🥚", description = "10 Tung Eggs", shop = "Eggs" },
	{ key = "EggGolden1", name = "Golden Egg", kind = "Product", price = 149, assetId = 0, icon = "🥚", description = "1 Golden Egg", shop = "Eggs" },
	{ key = "EggGolden3", name = "Golden Egg x3", kind = "Product", price = 399, assetId = 0, icon = "🥚", description = "3 Golden Eggs", shop = "Eggs" },
	{ key = "EggGolden10", name = "Golden Egg x10", kind = "Product", price = 1199, assetId = 0, icon = "🥚", description = "10 Golden Eggs", shop = "Eggs" },
	{ key = "EggRainbow1", name = "Rainbow Egg", kind = "Product", price = 249, assetId = 0, icon = "🥚", description = "1 Rainbow Egg", shop = "Eggs" },
	{ key = "EggRainbow3", name = "Rainbow Egg x3", kind = "Product", price = 649, assetId = 0, icon = "🥚", description = "3 Rainbow Eggs", shop = "Eggs" },
	{ key = "EggRainbow10", name = "Rainbow Egg x10", kind = "Product", price = 1999, assetId = 0, icon = "🥚", description = "10 Rainbow Eggs", shop = "Eggs" },
	{ key = "EggMoon1", name = "Sahur Moon Egg", kind = "Product", price = 399, assetId = 0, icon = "🥚", description = "1 Sahur Moon Egg", shop = "Eggs" },
	{ key = "EggMoon3", name = "Sahur Moon Egg x3", kind = "Product", price = 1099, assetId = 0, icon = "🥚", description = "3 Sahur Moon Eggs", shop = "Eggs" },
	{ key = "EggMoon10", name = "Sahur Moon Egg x10", kind = "Product", price = 3299, assetId = 0, icon = "🥚", description = "10 Sahur Moon Eggs", shop = "Eggs" },
} :: { Product }

Products.ByKey = {} :: { [string]: Product }
Products.ByAssetId = {} :: { [number]: Product }
Products.Gamepasses = {} :: { Product }
for _, p in Products.List do
	Products.ByKey[p.key] = p
	if p.assetId ~= 0 then
		Products.ByAssetId[p.assetId] = p
	end
	if p.kind == "Gamepass" then
		table.insert(Products.Gamepasses, p)
	end
end

return Products
