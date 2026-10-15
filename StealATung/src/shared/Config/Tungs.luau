--!strict
-- The Tung roster: 22 original Tungs across 7 rarities, plus 2 bound specials
-- (Group Tung, VIP Tung) that never appear on the belt or in the Index.
--
-- Every Tung is the wooden-log-with-a-bat character, changed by outfit, material,
-- colour and a signature effect. `look` drives TungModel; `effect` drives the
-- client-side signature animation in WorldFx.
--
-- Adding a Tung: append an entry with a unique id. Its rarity decides which
-- belt pool it joins; `weight` is its share inside that rarity.

local Rarities = require(script.Parent.Rarities)

export type Look = {
	body: Color3?, -- skin colour (default: wood)
	material: Enum.Material?,
	hat: string?, -- Nightcap | Bucket | Leaves | NinjaBand | Afro | Antenna | Nemes | Crown | Cap | TopHat | Horns
	-- | Chef | Party | Wizard | Santa | Cowboy | Sombrero | Beanie | Propeller | Halo | Pirate | Flower | Mushroom
	-- | Headphones | Bow | Mohawk | Graduation | Viking | Sweatband | Topknot | SpaceHelmet | Knight | Cherry | Stem | Unicorn
	props: { string }?, -- Drum | Scarf | DiscoBall | Cape | Wraps | Visor | Shades | Cracks | MoonHalo | Cheeks | Stars
	-- | Glasses | Bowtie | Tie | Wings | Backpack | Spots | Stitches | Spines | Stripes | Pacifier
	eyes: string?, -- Sleepy | Glow
	face: string?, -- expression preset (see TungFace.FACES), default Classic
	eyeColor: Color3?,
	bat: Color3?,
	batMaterial: Enum.Material?,
	accent: Color3?, -- cracks, visor, trims
}

export type Tung = {
	id: string,
	name: string,
	rarity: string,
	price: number,
	income: number, -- $ per second (before mutation / multipliers)
	weight: number, -- share inside its rarity when the belt picks a Tung
	effect: string, -- signature effect key (see WorldFx)
	desc: string,
	look: Look,
	scale: number?,
	tier: number?, -- Mythic sub-tier: 1 Blue, 2 Purple, 3 Red
	color: Color3?, -- overrides the rarity colour (Mythic sub-tiers)
	special: boolean?, -- not on the belt, not in the Index
	bound: boolean?, -- can't be stolen, traded or sold
	order: number?, -- filled in below (roster position)
}

local M = Enum.Material
local GOLD = Color3.fromRGB(255, 196, 45)

local Tungs = {}

Tungs.List = {
	-- Common ----------------------------------------------------------------------------
	{ id = "TungClassic", name = "Tung Classic", rarity = "Common", price = 10, income = 1, weight = 40, effect = "BatTap", desc = "Taps its bat on the ground every few seconds", look = { face = "Classic" } },
	{ id = "SleepyTung", name = "Sleepy Tung", rarity = "Common", price = 25, income = 2, weight = 30, effect = "Zzz", desc = 'Floating "Zzz" bubbles', look = { face = "Sleepy", hat = "Nightcap", eyes = "Sleepy" } },
	{ id = "MiniTung", name = "Mini Tung", rarity = "Common", price = 50, income = 3, weight = 20, effect = "Squeak", desc = "Half size, squeaky footsteps", look = { face = "Cute", body = Color3.fromRGB(196, 140, 92) }, scale = 0.5 },
	{ id = "BucketHatTung", name = "Tung with a Bucket Hat", rarity = "Common", price = 90, income = 5, weight = 10, effect = "HatBounce", desc = "Hat bounces when it walks", look = { face = "Derp", hat = "Bucket" } },
	{ id = "ChefTung", name = "Chef Tung", rarity = "Common", price = 30, income = 2, weight = 14, effect = "HatBounce", desc = "Puffy chef hat, smells like toast", look = { face = "Happy", hat = "Chef" } },
	{ id = "PartyTung", name = "Party Tung", rarity = "Common", price = 40, income = 2, weight = 14, effect = "Sparkle", desc = "Always ready to celebrate", look = { face = "Grin", hat = "Party" } },
	{ id = "BeanieTung", name = "Beanie Tung", rarity = "Common", price = 35, income = 2, weight = 14, effect = "HatBounce", desc = "Cosy knitted beanie with a pompom", look = { face = "Calm", hat = "Beanie", accent = Color3.fromRGB(60, 120, 230) } },
	{ id = "CowboyTung", name = "Cowboy Tung", rarity = "Common", price = 60, income = 3, weight = 12, effect = "BatTap", desc = "Yeehaw! Taps its bat like a horseshoe", look = { face = "Cool", hat = "Cowboy" } },
	{ id = "NerdTung", name = "Nerd Tung", rarity = "Common", price = 45, income = 3, weight = 12, effect = "BatTap", desc = "Big glasses, bigger brain", look = { face = "Nerd", props = { "Glasses" } } },
	{ id = "BabyTung", name = "Baby Tung", rarity = "Common", price = 20, income = 1, weight = 16, effect = "Squeak", desc = "Tiny, squeaky and very cute", look = { face = "Cute", props = { "Pacifier" }, body = Color3.fromRGB(236, 186, 130) }, scale = 0.6 },
	{ id = "MuddyTung", name = "Muddy Tung", rarity = "Common", price = 30, income = 2, weight = 14, effect = "BatTap", desc = "Rolled around in the mud", look = { face = "Derp", props = { "Spots" }, accent = Color3.fromRGB(110, 72, 40), body = Color3.fromRGB(176, 120, 72) } },
	{ id = "BirchTung", name = "Birch Tung", rarity = "Common", price = 55, income = 3, weight = 12, effect = "Leaves", desc = "Made from white birch wood", look = { face = "Calm", props = { "Spots" }, body = Color3.fromRGB(236, 232, 220) } },
	{ id = "MushroomTung", name = "Mushroom Tung", rarity = "Common", price = 80, income = 4, weight = 10, effect = "HatBounce", desc = "A big spotty mushroom cap", look = { face = "Happy", hat = "Mushroom" } },
	{ id = "GrumpyTung", name = "Grumpy Tung", rarity = "Common", price = 25, income = 2, weight = 14, effect = "BatTap", desc = "Woke up on the wrong side of the log", look = { face = "Grumpy" } },
	{ id = "OfficeTung", name = "Office Tung", rarity = "Common", price = 65, income = 4, weight = 10, effect = "BatTap", desc = "Late for a meeting again", look = { face = "Nervous", props = { "Tie" }, accent = Color3.fromRGB(40, 80, 200) } },
	{ id = "GymTung", name = "Gym Tung", rarity = "Common", price = 75, income = 4, weight = 10, effect = "BatTap", desc = "Never skips log day", look = { face = "Nervous", hat = "Sweatband" } },
	{ id = "BowTung", name = "Bow Tung", rarity = "Common", price = 50, income = 3, weight = 12, effect = "HatBounce", desc = "A big pink bow on top", look = { face = "Cute", hat = "Bow" } },
	{ id = "CamoTung", name = "Camo Tung", rarity = "Common", price = 95, income = 5, weight = 8, effect = "Ninja", desc = "You can't see me!", look = { face = "Angry", hat = "Cap", props = { "Spots" }, accent = Color3.fromRGB(70, 96, 52), body = Color3.fromRGB(130, 150, 90) } },
	{ id = "PineTung", name = "Pine Tung", rarity = "Common", price = 85, income = 5, weight = 8, effect = "Leaves", desc = "Smells like a fresh forest", look = { face = "Classic", hat = "Leaves", body = Color3.fromRGB(206, 160, 104) } },

	-- Uncommon --------------------------------------------------------------------------
	{ id = "LeafyTung", name = "Leafy Tung", rarity = "Uncommon", price = 250, income = 8, weight = 45, effect = "Leaves", desc = "Leaves fall off it slowly", look = { face = "Happy", hat = "Leaves", body = Color3.fromRGB(150, 118, 72) } },
	{ id = "DrummerTung", name = "Tung the Drummer", rarity = "Uncommon", price = 500, income = 15, weight = 35, effect = "Drum", desc = "Plays a tiny drum beat", look = { face = "Shout", props = { "Drum" } } },
	{ id = "BubblegumTung", name = "Bubblegum Tung", rarity = "Uncommon", price = 800, income = 25, weight = 20, effect = "Bubble", desc = "Blows a pink bubble that pops", look = { face = "Wink", body = Color3.fromRGB(236, 150, 186), props = { "Cheeks" } } },
	{ id = "PirateTung", name = "Pirate Tung", rarity = "Uncommon", price = 300, income = 9, weight = 14, effect = "BatTap", desc = "Arr! Steals Tungs for fun", look = { face = "Pirate", hat = "Pirate" } },
	{ id = "WizardTung", name = "Wizard Tung", rarity = "Uncommon", price = 600, income = 18, weight = 10, effect = "Sparkle", desc = "Knows every spell (mostly)", look = { face = "Wise", hat = "Wizard" } },
	{ id = "VikingTung", name = "Viking Tung", rarity = "Uncommon", price = 450, income = 14, weight = 12, effect = "BatTap", desc = "Sails the belt looking for loot", look = { face = "Angry", hat = "Viking" } },
	{ id = "DJTung", name = "DJ Tung", rarity = "Uncommon", price = 700, income = 20, weight = 9, effect = "Disco", desc = "Drops the sickest beats", look = { face = "Cool", hat = "Headphones", props = { "Shades", "DiscoBall" } } },
	{ id = "SantaTung", name = "Santa Tung", rarity = "Uncommon", price = 650, income = 19, weight = 9, effect = "Sparkle", desc = "Ho ho ho! Brings Tungs for everyone", look = { face = "Jolly", hat = "Santa" } },
	{ id = "GraduateTung", name = "Graduate Tung", rarity = "Uncommon", price = 350, income = 11, weight = 13, effect = "HatBounce", desc = "Graduated top of the log class", look = { face = "Calm", hat = "Graduation", props = { "Glasses" } } },
	{ id = "SombreroTung", name = "Sombrero Tung", rarity = "Uncommon", price = 550, income = 16, weight = 11, effect = "HatBounce", desc = "The biggest hat on the map", look = { face = "Stache", hat = "Sombrero" } },
	{ id = "PropellerTung", name = "Propeller Tung", rarity = "Uncommon", price = 400, income = 12, weight = 12, effect = "HatBounce", desc = "Tries to fly. Never works", look = { face = "Derp", hat = "Propeller" } },
	{ id = "FlowerTung", name = "Flower Tung", rarity = "Uncommon", price = 280, income = 8, weight = 15, effect = "Leaves", desc = "Blooms every spring", look = { face = "Cute", hat = "Flower" } },
	{ id = "AngelTung", name = "Angel Tung", rarity = "Uncommon", price = 900, income = 25, weight = 7, effect = "Sparkle", desc = "A tiny halo and fluffy wings", look = { face = "Calm", hat = "Halo", props = { "Wings" } } },
	{ id = "MooTung", name = "Moo Tung", rarity = "Uncommon", price = 380, income = 12, weight = 13, effect = "BatTap", desc = "Moo. That's it. Moo", look = { face = "Cute", props = { "Spots" }, body = Color3.fromRGB(245, 245, 240) } },
	{ id = "ZombieTung", name = "Zombie Tung", rarity = "Uncommon", price = 500, income = 15, weight = 11, effect = "Shadow", desc = "Braaains... and logs", look = { face = "Derp", props = { "Stitches" }, body = Color3.fromRGB(140, 170, 120) } },
	{ id = "BeeTung", name = "Bee Tung", rarity = "Uncommon", price = 420, income = 13, weight = 12, effect = "Sparkle", desc = "Buzzes around the base", look = { face = "Happy", props = { "Stripes", "Wings" }, body = Color3.fromRGB(250, 210, 60) } },
	{ id = "RockerTung", name = "Rocker Tung", rarity = "Uncommon", price = 750, income = 22, weight = 8, effect = "BatTap", desc = "Shreds on its bat like a guitar", look = { face = "Rage", hat = "Mohawk" } },
	{ id = "ExplorerTung", name = "Explorer Tung", rarity = "Uncommon", price = 600, income = 17, weight = 10, effect = "BatTap", desc = "Has seen every corner of the map", look = { face = "Happy", hat = "Cap", props = { "Backpack" }, accent = Color3.fromRGB(170, 140, 80) } },

	-- Rare ------------------------------------------------------------------------------
	{ id = "FrostyTung", name = "Frosty Tung", rarity = "Rare", price = 2500, income = 40, weight = 45, effect = "Frost", desc = "Icy breath, frost on the ground", look = { face = "Shiver", body = Color3.fromRGB(175, 222, 255), material = M.Ice, props = { "Scarf" }, accent = Color3.fromRGB(220, 50, 60) } },
	{ id = "NinjaTung", name = "Ninja Tung", rarity = "Rare", price = 5000, income = 75, weight = 35, effect = "Ninja", desc = "Turns half-invisible every 10 seconds", look = { face = "Angry", body = Color3.fromRGB(46, 46, 56), hat = "NinjaBand", accent = Color3.fromRGB(220, 40, 50) } },
	{ id = "DiscoTung", name = "Disco Tung", rarity = "Rare", price = 9000, income = 120, weight = 20, effect = "Disco", desc = "Spinning disco light above its head", look = { face = "Cool", body = Color3.fromRGB(150, 92, 220), hat = "Afro", props = { "DiscoBall", "Shades" } } },
	{ id = "SamuraiTung", name = "Samurai Tung", rarity = "Rare", price = 6000, income = 85, weight = 12, effect = "Ninja", desc = "Silent, swift and very wooden", look = { face = "Angry", hat = "Topknot" } },
	{ id = "AstroTung", name = "Astro Tung", rarity = "Rare", price = 7000, income = 95, weight = 10, effect = "Stars", desc = "The first Tung on the moon", look = { face = "Shout", hat = "SpaceHelmet", props = { "Backpack" }, accent = Color3.fromRGB(240, 240, 245) } },
	{ id = "ClownTung", name = "Clown Tung", rarity = "Rare", price = 3000, income = 45, weight = 20, effect = "Bubble", desc = "Honk honk!", look = { face = "Clown", hat = "Party", props = { "Bowtie" } } },
	{ id = "ScientistTung", name = "Scientist Tung", rarity = "Rare", price = 4000, income = 60, weight = 16, effect = "Glitch", desc = "Its experiments always explode", look = { face = "Shiver", hat = "Afro", props = { "Glasses" }, accent = Color3.fromRGB(240, 240, 240) } },
	{ id = "FireTung", name = "Fire Tung", rarity = "Rare", price = 8000, income = 110, weight = 8, effect = "Lava", desc = "Too hot to hold", look = { face = "Fierce", props = { "Cracks" }, accent = Color3.fromRGB(255, 220, 60), body = Color3.fromRGB(220, 80, 30) } },
	{ id = "KnightTung", name = "Knight Tung", rarity = "Rare", price = 5500, income = 80, weight = 12, effect = "BatTap", desc = "Defends its base with honour", look = { face = "Angry", hat = "Knight" } },
	{ id = "ChocoTung", name = "Choco Tung", rarity = "Rare", price = 2800, income = 42, weight = 20, effect = "Sparkle", desc = "Sweet chocolate with a cherry on top", look = { face = "Happy", hat = "Cherry", body = Color3.fromRGB(116, 70, 44) } },
	{ id = "CactusTung", name = "Cactus Tung", rarity = "Rare", price = 3500, income = 52, weight = 18, effect = "Sand", desc = "Please don't hug it", look = { face = "Grumpy", hat = "Flower", props = { "Spines" }, accent = Color3.fromRGB(255, 90, 140), body = Color3.fromRGB(80, 160, 70) } },
	{ id = "ElectricTung", name = "Electric Tung", rarity = "Rare", price = 9500, income = 120, weight = 7, effect = "Glitch", desc = "Crackling with lightning", look = { face = "Shock", props = { "Cracks" }, accent = Color3.fromRGB(80, 220, 255), body = Color3.fromRGB(255, 214, 60) } },
	{ id = "PumpkinTung", name = "Pumpkin Tung", rarity = "Rare", price = 4500, income = 68, weight = 14, effect = "Shadow", desc = "Spooky jack-o-lantern grin", look = { face = "Evil", hat = "Stem", body = Color3.fromRGB(240, 140, 40) } },

	-- Epic ------------------------------------------------------------------------------
	{ id = "LavaTung", name = "Lava Tung", rarity = "Epic", price = 30000, income = 200, weight = 45, effect = "Lava", desc = "Glowing cracks, drips lava sparks", look = { face = "Fierce", body = Color3.fromRGB(58, 42, 38), material = M.Basalt, props = { "Cracks" }, accent = Color3.fromRGB(255, 120, 20) } },
	{ id = "RoboTung", name = "Robo-Tung 3000", rarity = "Epic", price = 60000, income = 380, weight = 35, effect = "Robo", desc = "Metal body, beeps, laser-eye scan", look = { face = "Robot", body = Color3.fromRGB(172, 178, 190), material = M.DiamondPlate, hat = "Antenna", props = { "Visor" }, accent = Color3.fromRGB(255, 40, 40), bat = Color3.fromRGB(120, 125, 135), batMaterial = M.Metal } },
	{ id = "PharaohTung", name = "Pharaoh Tung", rarity = "Epic", price = 100000, income = 600, weight = 20, effect = "Sand", desc = "Golden wraps, sand swirls at its feet", look = { face = "Pharaoh", hat = "Nemes", props = { "Wraps" }, accent = GOLD } },
	{ id = "DragonTung", name = "Dragon Tung", rarity = "Epic", price = 90000, income = 540, weight = 8, effect = "Lava", desc = "Breathes fire on thieves", look = { face = "Fierce", hat = "Horns", props = { "Wings" }, accent = Color3.fromRGB(255, 140, 40), body = Color3.fromRGB(50, 130, 70) } },
	{ id = "IceKingTung", name = "Ice King Tung", rarity = "Epic", price = 70000, income = 430, weight = 10, effect = "Frost", desc = "Rules the frozen belt", look = { face = "Calm", hat = "Crown", material = M.Ice, body = Color3.fromRGB(170, 220, 255) } },
	{ id = "VampireTung", name = "Vampire Tung", rarity = "Epic", price = 50000, income = 320, weight = 12, effect = "Shadow", desc = "Only comes out at night", look = { face = "Fierce", props = { "Cape" }, accent = Color3.fromRGB(130, 10, 30), body = Color3.fromRGB(205, 205, 222) } },
	{ id = "SkellyTung", name = "Skelly Tung", rarity = "Epic", price = 40000, income = 260, weight = 14, effect = "BatTap", desc = "Spooky, scary, skeleton log", look = { face = "Evil", props = { "Stripes" }, accent = Color3.fromRGB(60, 56, 64), body = Color3.fromRGB(240, 235, 220) } },
	{ id = "GhostTung", name = "Ghost Tung", rarity = "Epic", price = 45000, income = 290, weight = 13, effect = "Ninja", desc = "Boo! Fades in and out", look = { face = "Boo", material = M.Glass, body = Color3.fromRGB(235, 240, 255) } },
	{ id = "CyborgTung", name = "Cyborg Tung", rarity = "Epic", price = 80000, income = 480, weight = 9, effect = "Robo", desc = "Half Tung, half machine", look = { face = "Robot", props = { "Visor" }, accent = Color3.fromRGB(60, 220, 255), material = M.DiamondPlate, body = Color3.fromRGB(150, 155, 170) } },
	{ id = "WitchTung", name = "Witch Tung", rarity = "Epic", price = 55000, income = 350, weight = 11, effect = "Runes", desc = "Brews potions in a tiny drum", look = { face = "Evil", hat = "Wizard", accent = Color3.fromRGB(40, 30, 50), body = Color3.fromRGB(130, 190, 100) } },
	{ id = "OfficerTung", name = "Officer Tung", rarity = "Epic", price = 35000, income = 220, weight = 15, effect = "BatTap", desc = "Catches thieves red-handed", look = { face = "Boss", hat = "Cap", props = { "Shades" }, accent = Color3.fromRGB(40, 60, 140) } },
	{ id = "SurferTung", name = "Surfer Tung", rarity = "Epic", price = 38000, income = 240, weight = 14, effect = "Ripples", desc = "Rides every wave on the belt", look = { face = "Cool", props = { "Shades" }, body = Color3.fromRGB(236, 190, 130) } },
	{ id = "MagicianTung", name = "Magician Tung", rarity = "Epic", price = 65000, income = 400, weight = 10, effect = "Sparkle", desc = "Pulls Tungs out of its hat", look = { face = "Royal", hat = "TopHat", props = { "Bowtie", "Cape" }, accent = Color3.fromRGB(170, 20, 40) } },

	-- Legendary -------------------------------------------------------------------------
	{ id = "KingTung", name = "King Tung", rarity = "Legendary", price = 400000, income = 1000, weight = 55, effect = "Fanfare", desc = "Crown, red cape, trumpet fanfare when placed", look = { face = "Royal", hat = "Crown", props = { "Cape" }, accent = Color3.fromRGB(200, 25, 40) } },
	{ id = "GalaxyTung", name = "Galaxy Tung", rarity = "Legendary", price = 900000, income = 2000, weight = 30, effect = "Stars", desc = "Body full of moving stars", look = { face = "Starry", body = Color3.fromRGB(44, 30, 98), material = M.Glass, props = { "Stars" } } },
	{ id = "GoldenBatTung", name = "Golden Bat Tung", rarity = "Legendary", price = 1.5e6, income = 3500, weight = 15, effect = "Coins", desc = "Solid gold, coins pop out every hit", look = { face = "Rich", body = GOLD, material = M.Foil, bat = GOLD, batMaterial = M.Foil } },
	{ id = "PhoenixTung", name = "Phoenix Tung", rarity = "Legendary", price = 1200000.0, income = 2800, weight = 10, effect = "Lava", desc = "Rises from its own ashes", look = { face = "Fierce", props = { "Wings", "Cracks" }, accent = Color3.fromRGB(255, 150, 40), body = Color3.fromRGB(220, 70, 30) } },
	{ id = "EmperorTung", name = "Emperor Tung", rarity = "Legendary", price = 1000000.0, income = 2400, weight = 12, effect = "Fanfare", desc = "Rules every belt in the land", look = { face = "Royal", hat = "Crown", props = { "Cape" }, accent = Color3.fromRGB(120, 40, 180) } },
	{ id = "UnicornTung", name = "Unicorn Tung", rarity = "Legendary", price = 800000, income = 1900, weight = 14, effect = "Sparkle", desc = "A magical horn and a rainbow mane", look = { face = "Cute", hat = "Unicorn", body = Color3.fromRGB(250, 236, 245) } },
	{ id = "CrystalTung", name = "Crystal Tung", rarity = "Legendary", price = 1100000.0, income = 2600, weight = 11, effect = "Stars", desc = "Carved from one giant crystal", look = { face = "Calm", props = { "Stars" }, material = M.Glass, body = Color3.fromRGB(120, 220, 255) } },
	{ id = "ThunderTung", name = "Thunder Tung", rarity = "Legendary", price = 1400000.0, income = 3300, weight = 8, effect = "Glitch", desc = "Every bat swing is a thunderclap", look = { face = "Rage", hat = "Horns", props = { "Cracks" }, accent = Color3.fromRGB(255, 230, 60), body = Color3.fromRGB(40, 50, 110) } },

	-- Secret ----------------------------------------------------------------------------
	{ id = "ShadowTung", name = "Shadow Tung", rarity = "Secret", price = 8e6, income = 8000, weight = 55, effect = "Shadow", desc = "Leaves a smoke trail, eyes glow white", look = { face = "Evil", body = Color3.fromRGB(22, 22, 28), eyes = "Glow", eyeColor = Color3.new(1, 1, 1), bat = Color3.fromRGB(30, 30, 36) } },
	{ id = "GlitchTung", name = "Glitch Tung", rarity = "Secret", price = 15e6, income = 14000, weight = 30, effect = "Glitch", desc = "Flickers and teleports a few studs at random", look = { face = "Glitch", body = Color3.fromRGB(255, 40, 200), material = M.Neon, eyes = "Glow", eyeColor = Color3.fromRGB(40, 255, 240) } },
	{ id = "SahurMoonTung", name = "Sahur Moon Tung", rarity = "Secret", price = 25e6, income = 25000, weight = 15, effect = "Moon", desc = "Crescent moon halo, glows brighter at night", look = { face = "Calm", body = Color3.fromRGB(34, 44, 104), props = { "MoonHalo" }, eyes = "Glow", eyeColor = Color3.fromRGB(255, 236, 140) } },

	-- Mythic (rarity inside the rarity) ---------------------------------------------------
	{ id = "MythicBlueTung", name = "Mythic Blue Tung", rarity = "Mythic", tier = 1, color = Color3.fromRGB(40, 160, 255), price = 250e6, income = 100000, weight = 45, effect = "Ripples", desc = "Blue fire aura, water ripples spread from its feet", look = { face = "Shout", body = Color3.fromRGB(30, 90, 200), eyes = "Glow", eyeColor = Color3.fromRGB(150, 230, 255), props = { "Cracks" }, accent = Color3.fromRGB(60, 200, 255) } },
	{ id = "MythicPurpleTung", name = "Mythic Purple Tung", rarity = "Mythic", tier = 2, color = Color3.fromRGB(185, 70, 255), price = 750e6, income = 350000, weight = 15, effect = "Runes", desc = "Purple fire aura, floating runes orbit it, lightning crackles", look = { face = "Fierce", body = Color3.fromRGB(95, 35, 170), eyes = "Glow", eyeColor = Color3.fromRGB(240, 190, 255), hat = "Horns", props = { "Cracks" }, accent = Color3.fromRGB(200, 100, 255) } },
	{ id = "MythicGreenTung", name = "Mythic Green Tung", rarity = "Mythic", tier = 1, color = Color3.fromRGB(60, 230, 100), price = 400e6, income = 160000, weight = 25, effect = "Leaves", desc = "Green fire aura, a storm of glowing leaves", look = { face = "Shout", body = Color3.fromRGB(30, 130, 60), eyes = "Glow", eyeColor = Color3.fromRGB(190, 255, 200), hat = "Leaves", props = { "Cracks" }, accent = Color3.fromRGB(90, 255, 130) } },
	{ id = "MythicGoldTung", name = "Mythic Gold Tung", rarity = "Mythic", tier = 2, color = Color3.fromRGB(255, 205, 40), price = 1.2e9, income = 500000, weight = 10, effect = "Coins", desc = "Golden fire aura, rains coins with every swing", look = { face = "Rage", body = GOLD, material = M.Foil, eyes = "Glow", eyeColor = Color3.new(1, 1, 1), hat = "Crown", props = { "Cape", "Cracks" }, accent = Color3.fromRGB(255, 240, 150), bat = GOLD, batMaterial = M.Foil } },
	{ id = "MythicRedTung", name = "Mythic Red Tung", rarity = "Mythic", tier = 3, color = Color3.fromRGB(255, 45, 45), price = 2.5e9, income = 1000000, weight = 5, effect = "Quake", desc = "Red fire aura, ground cracks with lava, shock rings when it bangs its bat", look = { face = "Rage", body = Color3.fromRGB(120, 18, 22), material = M.Basalt, eyes = "Glow", eyeColor = Color3.fromRGB(255, 220, 80), hat = "Horns", props = { "Cracks" }, accent = Color3.fromRGB(255, 70, 20), bat = Color3.fromRGB(60, 20, 20) } },

	-- Iconic: no normal rarity. Each one earns 20% of everything else in your base, and they're huge.
	{ id = "OGTung", name = "OG Tung Sahur", rarity = "Iconic", price = 250000, income = 0, weight = 40, effect = "BatTap", desc = "The one that started it all. Earns 20% of your income", look = { face = "Shout" } },
	{ id = "QuadTung", name = "Tung Tung Tung Tung Sahur", rarity = "Iconic", price = 1e6, income = 0, weight = 28, effect = "Drum", desc = "One extra Tung for extra power. Earns 20% of your income", look = { face = "Rage", props = { "Drum" }, body = Color3.fromRGB(210, 140, 80) } },
	{ id = "GigaTung", name = "Giga Tung", rarity = "Iconic", price = 5e6, income = 0, weight = 18, effect = "Quake", desc = "Absolute unit. Earns 20% of your income", look = { face = "Boss", props = { "Shades" }, body = Color3.fromRGB(160, 100, 60) } },
	{ id = "SahurKingTung", name = "Sahur King Tung", rarity = "Iconic", price = 25e6, income = 0, weight = 10, effect = "Fanfare", desc = "King of every Sahur. Earns 20% of your income", look = { face = "Royal", hat = "Crown", props = { "Cape" }, accent = Color3.fromRGB(40, 200, 190) } },
	{ id = "GoldenSahurTung", name = "Golden Sahur Tung", rarity = "Iconic", price = 100e6, income = 0, weight = 4, effect = "Coins", desc = "Solid gold legend. Earns 20% of your income", look = { face = "Starry", hat = "Halo", props = { "Wings" }, body = GOLD, material = M.Foil, accent = Color3.fromRGB(255, 240, 170), bat = GOLD, batMaterial = M.Foil } },

	-- Bound specials ----------------------------------------------------------------------
	{ id = "GroupTung", name = "Group Tung", rarity = "Rare", price = 5000, income = 60, weight = 0, effect = "BatTap", desc = "A thank-you for joining the group", special = true, bound = true, look = { face = "Goofy", hat = "Cap", accent = Color3.fromRGB(60, 150, 255) } },
	{ id = "VIPTung", name = "VIP Tung", rarity = "Epic", price = 100000, income = 450, weight = 0, effect = "Sparkle", desc = "VIP-only. Dripped out in black and gold", special = true, bound = true, look = { face = "Boss", body = Color3.fromRGB(30, 30, 36), hat = "TopHat", props = { "Shades" }, accent = GOLD, bat = GOLD, batMaterial = M.Foil } },
} :: { Tung }

Tungs.ById = {} :: { [string]: Tung }
Tungs.ByRarity = {} :: { [string]: { Tung } } -- belt pools (no specials)
Tungs.IndexList = {} :: { Tung } -- everything collectable, in Index order

for i, t in Tungs.List do
	t.order = i
	Tungs.ById[t.id] = t
	if not t.special then
		Tungs.ByRarity[t.rarity] = Tungs.ByRarity[t.rarity] or {}
		table.insert(Tungs.ByRarity[t.rarity], t)
		table.insert(Tungs.IndexList, t)
	end
end

function Tungs.Get(id: string): Tung?
	return Tungs.ById[id]
end

-- The colour used for this Tung everywhere (Mythic sub-tiers have their own).
function Tungs.Color(t: Tung): Color3
	return t.color or Rarities.Get(t.rarity).color
end

function Tungs.Color2(t: Tung): Color3
	if t.color then
		return t.color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	return Rarities.Get(t.rarity).color2
end

-- "MYTHIC 🔥🔥" style label with the sub-tier flame badge.
function Tungs.RarityLabel(t: Tung): string
	if t.tier then
		return string.upper(t.rarity) .. " " .. string.rep("🔥", t.tier)
	end
	return string.upper(t.rarity)
end

-- Picks a Tung of the given rarity using the in-rarity weights.
function Tungs.PickFromRarity(rng: Random, rarity: string): Tung
	local pool = Tungs.ByRarity[rarity] or Tungs.ByRarity.Common
	local total = 0
	for _, t in pool do
		total += t.weight
	end
	local roll = rng:NextNumber() * total
	for _, t in pool do
		roll -= t.weight
		if roll <= 0 then
			return t
		end
	end
	return pool[#pool]
end

-- Find by id or (loosely) by name; used by admin commands.
function Tungs.Find(query: string): Tung?
	local q = string.lower((query:gsub("[%s%-_]", "")))
	for _, t in Tungs.List do
		if string.lower(t.id) == q or string.lower((t.name:gsub("[%s%-_]", ""))) == q then
			return t
		end
	end
	for _, t in Tungs.List do
		if string.find(string.lower((t.name:gsub("[%s%-_]", ""))), q, 1, true) then
			return t
		end
	end
	return nil
end

return Tungs
