--!strict
-- Monetization (Design Doc §7). 30 items, cheap -> expensive.
--
-- SETUP: create each Developer Product / Game Pass on the Creator Dashboard at
-- the listed price, then paste its numeric ID into `assetId` below. Items with
-- assetId = 0 still show in the shop but display "Coming Soon" and can't be bought.

export type Product = {
	key: string,
	name: string,
	kind: "Product" | "Gamepass",
	price: number,
	assetId: number,
	tab: string, -- "Gamepasses" | "Crates" | "Currency" | "Styles" | "Bundles"
	icon: string,
	ribbon: string?, -- "BEST VALUE" | "LIMITED" | "POPULAR"
	description: string,
}

local Products = {}

Products.List = {
	{ key = "CommonCrate3", name = "Salvage Crate x3", kind = "Product", price = 25, assetId = 0, tab = "Crates", icon = "📦", description = "3 free Salvage Crates for your current world." },
	{ key = "ScrapSmall", name = "Credits Pack — Small", kind = "Product", price = 49, assetId = 0, tab = "Currency", icon = "🔩", description = "Credits worth 10% of your next Rebirth." },
	{ key = "AutoClicker15", name = "15-Min Auto-Salvager", kind = "Product", price = 79, assetId = 0, tab = "Bundles", icon = "🤖", description = "Salvages for you 4x a second for 15 minutes." },
	{ key = "NovaSmall", name = "Aura x25", kind = "Product", price = 99, assetId = 0, tab = "Currency", icon = "💎", description = "+25 Aura." },
	{ key = "RebirthSkip", name = "Rebirth Skip Token", kind = "Product", price = 149, assetId = 0, tab = "Bundles", icon = "⏩", description = "Rebirth once without reaching the Scrap goal." },
	{ key = "TokenGold", name = "Gold Style Token", kind = "Product", price = 199, assetId = 0, tab = "Styles", icon = "⭐", description = "Coat any droid in Gold (+25%)." },
	{ key = "StarterPack", name = "Starter Pack", kind = "Product", price = 249, assetId = 0, tab = "Bundles", icon = "🎁", ribbon = "POPULAR", description = "Credits (25% of next Rebirth) + 3 Salvage Crates + Gold Style Token." },
	{ key = "ScrapMedium", name = "Credits Pack — Medium", kind = "Product", price = 349, assetId = 0, tab = "Currency", icon = "🔩", description = "Credits worth 75% of your next Rebirth." },
	{ key = "RareCrate", name = "Rare Crate", kind = "Product", price = 399, assetId = 0, tab = "Crates", icon = "🔷", description = "Guaranteed Rare droid from your current world." },
	{ key = "DoubleScrap", name = "2x Credits", kind = "Gamepass", price = 449, assetId = 0, tab = "Gamepasses", icon = "💰", description = "Permanently double all Credits." },
	{ key = "NovaMedium", name = "Aura x100", kind = "Product", price = 499, assetId = 0, tab = "Currency", icon = "💎", description = "+100 Aura." },
	{ key = "AutoFoundry", name = "Auto-Foundry", kind = "Gamepass", price = 599, assetId = 0, tab = "Gamepasses", icon = "🌙", description = "Earn 50% of your income while offline (up to 12h)." },
	{ key = "TokenDiamond", name = "Diamond Style Token", kind = "Product", price = 699, assetId = 0, tab = "Styles", icon = "💎", description = "Coat any droid in Diamond (+50%)." },
	{ key = "DoubleLuck", name = "2x Luck", kind = "Gamepass", price = 799, assetId = 0, tab = "Gamepasses", icon = "🍀", description = "Double the odds of Rare+, Mythic and Iconic droids." },
	{ key = "EpicCrate", name = "Epic Crate", kind = "Product", price = 899, assetId = 0, tab = "Crates", icon = "🔮", description = "Guaranteed Epic droid from your current world." },
	{ key = "ScrapLarge", name = "Credits Pack — Large", kind = "Product", price = 999, assetId = 0, tab = "Currency", icon = "🔩", ribbon = "BEST VALUE", description = "Credits worth 200% of your next Rebirth." },
	{ key = "VIP", name = "VIP", kind = "Gamepass", price = 1299, assetId = 0, tab = "Gamepasses", icon = "👑", ribbon = "BEST VALUE", description = "2x Credits + 2x Luck + Auto-Foundry + 1 extra station + exclusive VIP Drip Mouse Droid." },
	{ key = "NovaLarge", name = "Aura x300", kind = "Product", price = 1499, assetId = 0, tab = "Currency", icon = "💎", ribbon = "BEST VALUE", description = "+300 Aura." },
	{ key = "LegendaryCrate", name = "Legendary Crate", kind = "Product", price = 1799, assetId = 0, tab = "Crates", icon = "🌟", description = "Guaranteed Legendary droid from your current world." },
	{ key = "TokenShadow", name = "Shadow Style Token", kind = "Product", price = 1999, assetId = 0, tab = "Styles", icon = "🌑", description = "Coat any droid in Shadow (+50%)." },
	{ key = "FounderPack", name = "Founder's Droid Pack", kind = "Product", price = 2499, assetId = 0, tab = "Bundles", icon = "🛡️", ribbon = "LIMITED", description = "Exclusive limited-time Legendary: Founder's Gold Battle Droid." },
	{ key = "TokenRainbow", name = "Rainbow Style Token", kind = "Product", price = 3499, assetId = 0, tab = "Styles", icon = "🌈", description = "Coat any droid in Rainbow (+150%)." },
	{ key = "MythicCrate", name = "Mythic Crate", kind = "Product", price = 3999, assetId = 0, tab = "Crates", icon = "🔴", description = "Guaranteed Mythic droid!" },
	{ key = "MegaBundle", name = "Mega Credits + Aura Bundle", kind = "Product", price = 4999, assetId = 0, tab = "Bundles", icon = "🧰", description = "Credits worth 600% of your next Rebirth + 1,000 Aura." },
	{ key = "AllMaps", name = "All-Maps Instant Unlock", kind = "Product", price = 5999, assetId = 0, tab = "Bundles", icon = "🗺️", description = "Travel to every world right now." },
	{ key = "MythicCrate3", name = "Mythic Crate x3", kind = "Product", price = 8999, assetId = 0, tab = "Crates", icon = "🔴", ribbon = "BEST VALUE", description = "Three guaranteed Mythic droids." },
	{ key = "UltimateVIP", name = "Ultimate VIP+", kind = "Gamepass", price = 9999, assetId = 0, tab = "Gamepasses", icon = "💫", description = "Everything VIP has, +50% more Credits, and monthly perks (500 Aura + Mythic Crate)." },
	{ key = "IconicCrate", name = "Iconic Crate", kind = "Product", price = 12999, assetId = 0, tab = "Crates", icon = "🌟", ribbon = "LIMITED", description = "Guaranteed ICONIC droid like R2-67, TUNG-3PO or IG-69!" },
	{ key = "GenesisVault", name = "Genesis Vault", kind = "Product", price = 17999, assetId = 0, tab = "Bundles", icon = "🌌", description = "Guaranteed Mythic in RAINBOW style." },
	{ key = "WhaleVault", name = "Founder's Whale Vault", kind = "Product", price = 24999, assetId = 0, tab = "Bundles", icon = "🐋", ribbon = "LIMITED", description = "Every gamepass, 10 Mythic Crates, and the 'Founding Whale' title." },
} :: { Product }

Products.ByKey = {} :: { [string]: Product }
Products.ByAssetId = {} :: { [number]: Product }
for _, p in Products.List do
	Products.ByKey[p.key] = p
	if p.assetId ~= 0 then
		Products.ByAssetId[p.assetId] = p
	end
end

Products.Tabs = { "Featured", "Gamepasses", "Crates", "Currency", "Styles", "Bundles" }

-- Deal of the Day rotates daily (UTC) through these keys.
Products.DealRotation = { "StarterPack", "RareCrate", "DoubleLuck", "NovaMedium", "EpicCrate", "TokenDiamond", "LegendaryCrate", "IconicCrate" }
Products.DealDiscountText = "DEAL OF THE DAY"

function Products.DealOfTheDay(unixTime: number): (Product, number)
	local day = unixTime // 86400
	local key = Products.DealRotation[(day % #Products.DealRotation) + 1]
	local secondsLeft = 86400 - (unixTime % 86400)
	return Products.ByKey[key], secondsLeft
end

return Products
