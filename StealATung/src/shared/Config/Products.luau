--!strict
-- Robux items (Design Doc: Monetization).
--
-- SETUP: create each Game Pass / Developer Product on the Creator Dashboard at
-- the listed price, then paste its numeric ID into `assetId`. Items left at
-- assetId = 0 show "Coming soon" in the shop and can't be bought.
--
-- Fairness rules: nothing sold lets you steal without risk, and Mythics are
-- never directly buyable.

export type Product = {
	key: string,
	name: string,
	kind: "Gamepass" | "Product",
	price: number,
	assetId: number,
	icon: string,
	description: string,
}

local Products = {}

Products.List = {
	-- Game Passes
	{ key = "DoubleMoney", name = "2x Money", kind = "Gamepass", price = 399, assetId = 0, icon = "💰", description = "Permanently double income from every pad." },
	{ key = "VIP", name = "VIP", kind = "Gamepass", price = 499, assetId = 0, icon = "👑", description = "[VIP] chat tag, gold name, +1 slot and the VIP-only VIP Tung." },
	{ key = "CollectAll", name = "Collect All", kind = "Gamepass", price = 99, assetId = 0, icon = "🧲", description = "Collect All button from the very start." },
	{ key = "AutoLock", name = "Auto Lock", kind = "Gamepass", price = 149, assetId = 0, icon = "🔒", description = "Your base re-locks itself every time the cooldown ends." },
	{ key = "LuckyBelt", name = "Lucky Belt", kind = "Gamepass", price = 299, assetId = 0, icon = "🍀", description = "+25% luck on all your spawns." },
	-- Developer Products
	{ key = "LuckPotion", name = "Server Luck Potion", kind = "Product", price = 49, assetId = 0, icon = "🧪", description = "3x luck for the WHOLE server for 10 minutes. Everyone will thank you!" },
	{ key = "InstantTung", name = "Instant Tung", kind = "Product", price = 99, assetId = 0, icon = "⚡", description = "A random Legendary Tung rides the belt just for you, and it's free to grab." },
	{ key = "SkipRebirth", name = "Skip Rebirth Cost", kind = "Product", price = 149, assetId = 0, icon = "⏩", description = "Rebirth once without paying the money cost (you still need the required Tungs)." },
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
