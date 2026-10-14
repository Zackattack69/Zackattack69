--!strict
-- ⚠️ EVERY droid / planet / flavour name in the game lives in THIS file.
-- They're brainrot parodies of famous space-opera droids. Rename anything here
-- and the whole game (roster, shop, UI, announcements) updates automatically.
--
-- shape  = which 3D chassis DroidModel builds (see DroidModel.luau)
-- colors = { body, accent, trim }

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Names = {}

-- Planets, in unlock order (index matches Worlds.luau). `tag` prefixes droid names.
Names.Planets = {
	{ name = "Junkku", tag = "Junkku", theme = "Starship graveyard", blurb = "A desert junkyard full of crashed star destroyers. Scavengers trade scrap for credits. Very cooked." },
	{ name = "Sigmatooine", tag = "Sigmatooine", theme = "Twin-sun desert spaceport", blurb = "Two suns, zero shade. Moisture farms, a cantina, and droids with unmatched aura." },
	{ name = "Hothdog", tag = "Hothdog", theme = "Frozen rebel base", blurb = "An ice planet so cold even the droids are shivering. Watch out for giant walkers." },
	{ name = "Endor, Ohio", tag = "Ohio", theme = "Forest moon", blurb = "Giant redwoods, treetop villages and a shield bunker. Only in Ohio." },
	{ name = "Bespin Bussin", tag = "Bussin", theme = "Cloud City", blurb = "A floating city in the sunset clouds of a gas giant. Absolutely bussin views." },
	{ name = "Mustafanum", tag = "Mustafanum", theme = "Lava planet", blurb = "Rivers of lava and black rock. The Fanum tax here is your eyebrows." },
	{ name = "Coruscan't", tag = "Coruscan't", theme = "Galactic capital city", blurb = "A city covering an entire planet. Traffic is a thousand levels high. You can't." },
	{ name = "The Sigma Star", tag = "Sigma Star", theme = "Moon-sized battle station", blurb = "The endgame. A battle station with a reactor core of pure sigma energy." },
}

-- Generic droid MODELS. Every planet gets its own version ("Hothdog Mouse Droid").
Names.Models = {
	Common = {
		{ name = "Mouse Droid", shape = "Mouse", colors = { c(40, 40, 45), c(200, 200, 205), c(90, 90, 95) } },
		{ name = "Gonk Droid", shape = "Gonk", colors = { c(120, 120, 125), c(220, 190, 80), c(60, 60, 65) } },
		{ name = "Pit Droid", shape = "Pit", colors = { c(200, 120, 60), c(230, 230, 220), c(90, 70, 50) } },
		{ name = "R1 Astromech", shape = "Astromech", colors = { c(200, 200, 205), c(120, 150, 90), c(90, 90, 95) } },
		{ name = "Treadwell Droid", shape = "Spider", colors = { c(150, 140, 120), c(230, 180, 70), c(70, 65, 60) } },
		{ name = "Yapper Droid", shape = "Protocol", colors = { c(200, 205, 215), c(90, 140, 220), c(110, 110, 120) } },
		{ name = "Demolition Droid", shape = "Mouse", colors = { c(200, 160, 50), c(60, 60, 60), c(100, 100, 100) } },
		{ name = "Loadlifter", shape = "Gonk", colors = { c(150, 110, 80), c(220, 200, 150), c(70, 60, 50) } },
		{ name = "NPC Labor Droid", shape = "Protocol", colors = { c(180, 175, 160), c(230, 140, 60), c(90, 85, 80) } },
		{ name = "Monitor Droid", shape = "Seeker", colors = { c(70, 70, 80), c(255, 80, 80), c(140, 140, 150) } },
		{ name = "Courier Droid", shape = "Seeker", colors = { c(230, 230, 235), c(80, 180, 255), c(120, 120, 130) } },
		{ name = "Repair Droid", shape = "Pit", colors = { c(230, 200, 90), c(240, 240, 240), c(90, 80, 60) } },
	},
	Uncommon = {
		{ name = "B1 Battle Droid", shape = "B1", colors = { c(215, 195, 150), c(160, 130, 90), c(120, 105, 80) } },
		{ name = "R4 Astromech", shape = "Astromech", colors = { c(220, 220, 225), c(200, 60, 60), c(100, 100, 105) } },
		{ name = "Medical Droid", shape = "Medical", colors = { c(210, 215, 225), c(120, 200, 255), c(90, 95, 110) } },
		{ name = "Surgical Droid", shape = "Medical", colors = { c(240, 240, 245), c(255, 110, 110), c(110, 110, 120) } },
		{ name = "Buzz Droid", shape = "Seeker", colors = { c(120, 110, 100), c(255, 70, 70), c(70, 65, 60) } },
		{ name = "Power Loader", shape = "Gonk", colors = { c(230, 170, 50), c(60, 60, 60), c(110, 100, 90) } },
		{ name = "Interrogator Droid", shape = "Seeker", colors = { c(25, 25, 30), c(255, 60, 60), c(120, 120, 130) } },
		{ name = "Patrol Droid", shape = "Probe", colors = { c(90, 95, 105), c(255, 200, 80), c(50, 50, 55) } },
		{ name = "Pilot Droid", shape = "B1", colors = { c(90, 120, 200), c(220, 220, 220), c(60, 60, 70) } },
		{ name = "Cantina Droid", shape = "Protocol", colors = { c(150, 90, 60), c(240, 210, 120), c(70, 50, 40) } },
	},
	Rare = {
		{ name = "B2 Super Battle Droid", shape = "B2", colors = { c(105, 115, 140), c(200, 60, 60), c(60, 65, 80) } },
		{ name = "R5 Astromech", shape = "Astromech", colors = { c(225, 225, 230), c(220, 120, 50), c(100, 100, 105) } },
		{ name = "BB Unit", shape = "BB", colors = { c(240, 240, 240), c(90, 170, 90), c(110, 110, 110) } },
		{ name = "Viper Probe Droid", shape = "Probe", colors = { c(40, 40, 45), c(255, 60, 60), c(90, 90, 95) } },
		{ name = "Seeker Droid", shape = "Seeker", colors = { c(180, 180, 190), c(80, 200, 255), c(80, 80, 90) } },
		{ name = "KX Security Droid", shape = "Security", colors = { c(30, 30, 35), c(255, 255, 255), c(60, 60, 65) } },
		{ name = "Commando Droid", shape = "B1", colors = { c(70, 70, 75), c(255, 230, 120), c(40, 40, 45) } },
		{ name = "Dwarf Spider Droid", shape = "Spider", colors = { c(130, 120, 100), c(255, 60, 60), c(70, 65, 60) } },
	},
	Epic = {
		{ name = "Droideka", shape = "Droideka", colors = { c(150, 110, 70), c(120, 200, 255), c(80, 60, 45) } },
		{ name = "IG Assassin Droid", shape = "Assassin", colors = { c(110, 110, 115), c(255, 60, 60), c(60, 60, 65) } },
		{ name = "MagnaGuard", shape = "Security", colors = { c(60, 55, 60), c(140, 80, 200), c(110, 30, 30) } },
		{ name = "Tactical Droid", shape = "Protocol", colors = { c(90, 100, 160), c(255, 210, 90), c(50, 55, 80) } },
		{ name = "BX Commando", shape = "B1", colors = { c(60, 60, 60), c(80, 200, 255), c(30, 30, 35) } },
		{ name = "Octuptarra Droid", shape = "Spider", colors = { c(120, 115, 105), c(255, 80, 40), c(60, 55, 50) } },
	},
}

-- Named LEGENDARY droids, three per planet.
Names.Legendary = {
	{ world = 1, name = "R5-Delulu", shape = "Astromech", colors = { c(235, 235, 235), c(200, 40, 40), c(110, 110, 110) } },
	{ world = 1, name = "Mister Bonesmaxx", shape = "B1", colors = { c(180, 40, 40), c(240, 230, 210), c(80, 20, 20) } },
	{ world = 1, name = "Bro2-EMO", shape = "Gonk", colors = { c(170, 140, 90), c(255, 200, 80), c(90, 75, 55) } },
	{ world = 2, name = "EV-Edge9", shape = "Protocol", colors = { c(110, 90, 80), c(255, 80, 60), c(70, 55, 50) } },
	{ world = 2, name = "8D-Ate", shape = "Protocol", colors = { c(200, 200, 205), c(255, 160, 60), c(110, 110, 115) } },
	{ world = 2, name = "WAC-Sahur", shape = "Pit", colors = { c(220, 90, 60), c(240, 220, 160), c(100, 60, 40) } },
	{ world = 3, name = "FX-NPC", shape = "Medical", colors = { c(220, 225, 235), c(120, 200, 255), c(80, 85, 95) } },
	{ world = 3, name = "R3-Sigma6", shape = "Astromech", colors = { c(255, 210, 60), c(240, 240, 240), c(180, 140, 30) } },
	{ world = 3, name = "IG-Rizzmaster", shape = "Assassin", colors = { c(90, 90, 95), c(255, 200, 80), c(50, 50, 55) } },
	{ world = 4, name = "Roger Roger Ohio", shape = "B1", colors = { c(215, 195, 150), c(255, 140, 60), c(120, 105, 80) } },
	{ world = 4, name = "R7-Aura", shape = "Astromech", colors = { c(235, 235, 235), c(80, 190, 80), c(100, 100, 100) } },
	{ world = 4, name = "AZI-Yap", shape = "Medical", colors = { c(230, 230, 235), c(255, 120, 60), c(100, 100, 110) } },
	{ world = 5, name = "TC-Bussin", shape = "Protocol", colors = { c(215, 220, 230), c(160, 170, 190), c(140, 145, 160) } },
	{ world = 5, name = "CB-Cooked", shape = "BB", colors = { c(240, 240, 240), c(80, 130, 230), c(120, 120, 130) } },
	{ world = 5, name = "R4-Goated", shape = "Astromech", colors = { c(200, 140, 80), c(240, 220, 180), c(120, 80, 45) } },
	{ world = 6, name = "BB-Mid", shape = "BB", colors = { c(25, 25, 30), c(200, 200, 205), c(60, 60, 65) } },
	{ world = 6, name = "4-LOL", shape = "Protocol", colors = { c(120, 110, 90), c(255, 210, 90), c(70, 65, 55) } },
	{ world = 6, name = "Kalani Fanum", shape = "Protocol", colors = { c(70, 80, 140), c(255, 220, 100), c(45, 50, 85) } },
	{ world = 7, name = "Huyapper", shape = "Protocol", colors = { c(210, 190, 150), c(120, 200, 255), c(120, 100, 75) } },
	{ world = 7, name = "ME-Mewing", shape = "Protocol", colors = { c(160, 100, 70), c(255, 220, 120), c(90, 60, 40) } },
	{ world = 7, name = "Q9-NoCap", shape = "Security", colors = { c(110, 120, 130), c(255, 255, 255), c(60, 65, 70) } },
	{ world = 8, name = "AP-Grindset", shape = "Protocol", colors = { c(70, 75, 90), c(255, 240, 200), c(40, 45, 55) } },
	{ world = 8, name = "R4-Skibidi", shape = "Astromech", colors = { c(200, 60, 60), c(220, 220, 225), c(120, 30, 30) } },
	{ world = 8, name = "RA-Aura7", shape = "Protocol", colors = { c(40, 40, 45), c(255, 210, 90), c(80, 80, 85) } },
}

-- MYTHIC: elite war machines. 0.1% in ANY crate, or the Robux Mythic Crate.
Names.Mythic = {
	{ name = "OOM-Skibidi Commander", shape = "B1", colors = { c(225, 205, 110), c(255, 255, 255), c(160, 130, 60) } },
	{ name = "Sigma MagnaGuard", shape = "Security", colors = { c(55, 50, 55), c(255, 60, 60), c(110, 30, 30) } },
	{ name = "TX-Rizzler", shape = "Protocol", colors = { c(80, 95, 170), c(255, 230, 120), c(50, 55, 95) } },
	{ name = "Aut-O Mewer", shape = "Protocol", colors = { c(200, 200, 210), c(255, 70, 70), c(120, 120, 130) } },
	{ name = "Dark Tralalero", shape = "Security", colors = { c(20, 20, 25), c(255, 50, 50), c(70, 70, 75) } },
	{ name = "Brr Brr Patapim-12", shape = "Assassin", colors = { c(150, 140, 120), c(120, 200, 120), c(80, 75, 65) } },
}

-- ICONIC: the famous ones (brainrot edition). 0.02% in ANY crate, or the Robux Iconic Crate.
Names.Iconic = {
	{ name = "R2-67", shape = "Astromech", colors = { c(240, 240, 245), c(30, 90, 200), c(170, 175, 185) } },
	{ name = "TUNG-3PO", shape = "Protocol", colors = { c(255, 200, 60), c(255, 230, 140), c(200, 140, 30) } },
	{ name = "IG-69", shape = "Assassin", colors = { c(130, 130, 135), c(255, 80, 60), c(70, 70, 75) } },
	{ name = "BB-Ate", shape = "BB", colors = { c(245, 245, 245), c(255, 130, 30), c(150, 150, 150) } },
	{ name = "K-2Sigma", shape = "Security", colors = { c(25, 25, 30), c(255, 255, 255), c(70, 70, 75) } },
	{ name = "Fanum-10P", shape = "Astromech", colors = { c(240, 150, 50), c(240, 240, 240), c(110, 110, 115) } },
	{ name = "BD-Rizz", shape = "Pit", colors = { c(240, 240, 240), c(220, 60, 40), c(100, 100, 105) } },
	{ name = "IG-Ohio", shape = "Assassin", colors = { c(170, 160, 140), c(120, 220, 255), c(90, 85, 75) } },
	{ name = "L3-1337", shape = "Protocol", colors = { c(220, 210, 180), c(60, 120, 220), c(140, 120, 90) } },
	{ name = "0-0-Mew", shape = "Protocol", colors = { c(25, 25, 30), c(255, 60, 60), c(60, 60, 65) } },
	{ name = "BT-Crocodilo", shape = "Astromech", colors = { c(25, 25, 30), c(255, 60, 60), c(80, 80, 85) } },
	{ name = "D-OHIO", shape = "BB", colors = { c(240, 240, 240), c(220, 50, 50), c(120, 120, 120) } },
}

-- Shop / gamepass exclusives (outside the collection count)
Names.Founder = { name = "Founder's Gold Battle Droid", shape = "B1", colors = { c(255, 205, 60), c(255, 255, 255), c(200, 140, 30) } }
Names.VIP = { name = "VIP Drip Mouse Droid", shape = "Mouse", colors = { c(230, 235, 245), c(255, 215, 80), c(150, 155, 170) } }

-- Currencies & flavour
Names.Currency = { Scrap = "Credits", Nova = "Aura" }
Names.CurrencyIcon = { Scrap = "🪙", Nova = "💎" }
Names.RebirthTitles = { "Scavenger", "Sigma Smuggler", "Bounty Rizzler", "Rebel GOAT", "Jedi Sigma", "Jedi Rizz Master", "Grand Sigma Master" }
Names.PrestigeTitle = "The Chosen Rizz"
Names.GameTitle = "DROID FOUNDRY"
Names.Crawl = {
	"A long time ago in a galaxy far, far away....",
	"BRAINROT has spread across the galaxy. Droids everywhere have lost their aura.",
	"On the junk planet JUNKKU, scavengers search the wrecks for lost droids, hoping to rebuild a mighty FOUNDRY.",
	"Collect them all. Jump to hyperspace. Find the legendary R2-67....",
}

return Names
