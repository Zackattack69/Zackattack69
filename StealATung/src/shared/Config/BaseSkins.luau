--!strict
-- Base skins: how your base looks. Rebirths never change it; you pick a skin at
-- the Skins stand next to the Rebirth Altar.
--   Colours: free for everyone.
--   Rarity styles: collect enough Tungs of that rarity (bought, stolen or won;
--     trades don't count) and that rarity's base design unlocks.
--   Tung Master: complete the whole Index.

export type Skin = {
	key: string,
	name: string,
	kind: string, -- "Color" | "Rarity" | "Special"
	order: number?, -- filled in below (list position)
	wall: Color3,
	wallMaterial: Enum.Material?,
	wallTransparency: number?,
	frame: Color3, -- window frames, corner pillars
	trim: Color3, -- roof edge, floor-line belts, stair rails
	trimMaterial: Enum.Material?,
	glass: Color3,
	floor: Color3,
	tile: Color3,
	pad: Color3,
	accent: Color3, -- pad glow, floor rim
	roof: Color3,
	decor: string?, -- extra decoration (see BaseBuilder)
	rarity: string?, -- Rarity styles: collect `need` Tungs of this rarity
	need: number?,
	index: boolean?, -- Tung Master: 100% Index
	desc: string?,
}

local M = Enum.Material
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local BaseSkins = {}

BaseSkins.DEFAULT = "Classic"

BaseSkins.List = {
	-- Colours (free) ---------------------------------------------------------------------------------
	{ key = "Classic", name = "Classic", kind = "Color", wall = rgb(118, 122, 140), frame = rgb(44, 46, 58), trim = rgb(70, 74, 92), glass = rgb(110, 175, 255), floor = rgb(200, 202, 212), tile = rgb(184, 186, 198), pad = rgb(226, 228, 236), accent = rgb(90, 160, 255), roof = rgb(84, 88, 104) },
	{ key = "Red", name = "Red", kind = "Color", wall = rgb(214, 52, 48), frame = rgb(40, 30, 34), trim = rgb(255, 196, 50), glass = rgb(120, 190, 255), floor = rgb(232, 206, 170), tile = rgb(218, 188, 150), pad = rgb(245, 228, 200), accent = rgb(255, 196, 50), roof = rgb(170, 36, 36), decor = "Crown" },
	{ key = "Yellow", name = "Yellow", kind = "Color", wall = rgb(246, 196, 64), frame = rgb(48, 40, 30), trim = rgb(255, 245, 220), glass = rgb(120, 190, 255), floor = rgb(240, 226, 190), tile = rgb(226, 208, 168), pad = rgb(250, 240, 214), accent = rgb(255, 160, 40), roof = rgb(220, 160, 40), decor = "CatEars" },
	{ key = "Blue", name = "Blue", kind = "Color", wall = rgb(56, 120, 230), frame = rgb(26, 34, 70), trim = rgb(230, 240, 255), glass = rgb(150, 215, 255), floor = rgb(206, 220, 240), tile = rgb(188, 204, 230), pad = rgb(230, 238, 250), accent = rgb(80, 200, 255), roof = rgb(40, 90, 190) },
	{ key = "Green", name = "Green", kind = "Color", wall = rgb(70, 176, 84), frame = rgb(30, 54, 34), trim = rgb(240, 236, 210), glass = rgb(150, 220, 255), floor = rgb(222, 214, 176), tile = rgb(206, 196, 156), pad = rgb(240, 236, 214), accent = rgb(130, 230, 90), roof = rgb(50, 140, 64) },
	{ key = "Purple", name = "Purple", kind = "Color", wall = rgb(142, 82, 220), frame = rgb(40, 26, 66), trim = rgb(255, 200, 255), glass = rgb(170, 200, 255), floor = rgb(220, 206, 236), tile = rgb(204, 188, 226), pad = rgb(236, 226, 248), accent = rgb(220, 120, 255), roof = rgb(110, 60, 180) },
	{ key = "Pink", name = "Pink", kind = "Color", wall = rgb(246, 132, 190), frame = rgb(70, 30, 54), trim = rgb(255, 245, 250), glass = rgb(170, 220, 255), floor = rgb(250, 226, 236), tile = rgb(240, 208, 222), pad = rgb(255, 240, 246), accent = rgb(255, 90, 170), roof = rgb(220, 96, 160) },
	{ key = "Orange", name = "Orange", kind = "Color", wall = rgb(250, 140, 50), frame = rgb(60, 36, 24), trim = rgb(255, 236, 200), glass = rgb(140, 200, 255), floor = rgb(240, 220, 190), tile = rgb(226, 200, 166), pad = rgb(250, 238, 220), accent = rgb(255, 200, 60), roof = rgb(210, 100, 30) },
	{ key = "White", name = "White", kind = "Color", wall = rgb(236, 238, 244), frame = rgb(60, 64, 80), trim = rgb(110, 170, 255), glass = rgb(140, 200, 255), floor = rgb(214, 218, 228), tile = rgb(198, 202, 214), pad = rgb(240, 242, 248), accent = rgb(110, 170, 255), roof = rgb(200, 204, 216) },
	{ key = "Black", name = "Black", kind = "Color", wall = rgb(44, 44, 54), frame = rgb(14, 14, 18), trim = rgb(255, 70, 90), glass = rgb(90, 140, 220), floor = rgb(90, 90, 104), tile = rgb(76, 76, 90), pad = rgb(150, 150, 166), accent = rgb(255, 70, 90), roof = rgb(30, 30, 38) },
	{ key = "Candy", name = "Candy Cane", kind = "Color", wall = rgb(250, 248, 244), frame = rgb(200, 40, 52), trim = rgb(220, 40, 52), glass = rgb(160, 225, 255), floor = rgb(250, 230, 236), tile = rgb(240, 210, 220), pad = rgb(255, 244, 248), accent = rgb(80, 210, 110), roof = rgb(220, 40, 52), decor = "CandyCanes" },

	-- Rarity styles (collect Tungs of that rarity) ------------------------------------------------------------
	{ key = "CommonStyle", name = "Common", kind = "Rarity", rarity = "Common", need = 25, wall = rgb(150, 150, 158), frame = rgb(96, 70, 48), trim = rgb(160, 112, 70), glass = rgb(170, 210, 240), floor = rgb(196, 170, 130), tile = rgb(180, 152, 112), pad = rgb(222, 206, 176), accent = rgb(200, 200, 210), roof = rgb(120, 86, 58), decor = "Barrels", desc = "Stone and wood workshop" },
	{ key = "UncommonStyle", name = "Uncommon", kind = "Rarity", rarity = "Uncommon", need = 15, wall = rgb(96, 186, 90), frame = rgb(70, 50, 30), trim = rgb(150, 110, 64), glass = rgb(170, 230, 210), floor = rgb(206, 196, 150), tile = rgb(190, 178, 130), pad = rgb(232, 230, 200), accent = rgb(110, 220, 90), roof = rgb(60, 140, 60), decor = "Bushes", desc = "Leafy treehouse with bushes on the roof" },
	{ key = "RareStyle", name = "Rare", kind = "Rarity", rarity = "Rare", need = 10, wall = rgb(80, 150, 240), frame = rgb(220, 240, 255), trim = rgb(200, 236, 255), glass = rgb(190, 235, 255), floor = rgb(214, 232, 250), tile = rgb(196, 220, 246), pad = rgb(236, 246, 255), accent = rgb(60, 150, 255), roof = rgb(200, 236, 255), decor = "Ice", desc = "Frosty ice palace with icicles" },
	{ key = "EpicStyle", name = "Epic", kind = "Rarity", rarity = "Epic", need = 6, wall = rgb(110, 54, 190), frame = rgb(220, 120, 255), trim = rgb(220, 120, 255), trimMaterial = M.Neon, glass = rgb(200, 160, 255), floor = rgb(70, 50, 110), tile = rgb(60, 42, 96), pad = rgb(190, 170, 230), accent = rgb(200, 90, 255), roof = rgb(80, 36, 140), decor = "Crystals", desc = "Neon purple with glowing crystals" },
	{ key = "LegendaryStyle", name = "Legendary", kind = "Rarity", rarity = "Legendary", need = 3, wall = rgb(250, 196, 40), wallMaterial = M.Foil, frame = rgb(255, 250, 230), trim = rgb(255, 250, 230), glass = rgb(255, 236, 170), floor = rgb(250, 240, 210), tile = rgb(240, 222, 180), pad = rgb(255, 248, 226), accent = rgb(255, 200, 40), roof = rgb(255, 210, 60), decor = "BigCrown", desc = "Solid gold with a giant crown" },
	{ key = "SecretStyle", name = "Secret", kind = "Rarity", rarity = "Secret", need = 1, wall = rgb(26, 24, 34), frame = rgb(255, 255, 255), trim = rgb(255, 80, 200), trimMaterial = M.Neon, glass = rgb(60, 50, 90), floor = rgb(40, 38, 52), tile = rgb(30, 28, 40), pad = rgb(90, 86, 110), accent = rgb(255, 80, 200), roof = rgb(18, 16, 24), decor = "Rainbow", desc = "Shadow base with rainbow neon" },
	{ key = "MythicStyle", name = "Mythic", kind = "Rarity", rarity = "Mythic", need = 1, wall = rgb(110, 20, 24), frame = rgb(255, 120, 30), trim = rgb(255, 90, 20), trimMaterial = M.Neon, glass = rgb(255, 140, 80), floor = rgb(60, 30, 30), tile = rgb(48, 22, 22), pad = rgb(150, 90, 80), accent = rgb(255, 80, 30), roof = rgb(70, 14, 18), decor = "Inferno", desc = "Volcanic fortress with horns and flames" },

	-- Special --------------------------------------------------------------------------------------------------------------
	{ key = "TungMaster", name = "Tung Master", kind = "Special", index = true, wall = rgb(248, 244, 232), wallMaterial = M.Marble, frame = rgb(255, 200, 50), trim = rgb(255, 200, 50), trimMaterial = M.Foil, glass = rgb(255, 236, 180), floor = rgb(240, 232, 214), tile = rgb(226, 214, 190), pad = rgb(255, 248, 230), accent = rgb(255, 200, 50), roof = rgb(255, 200, 50), decor = "Temple", desc = "Golden temple for finishing the Index" },
} :: { Skin }

BaseSkins.ByKey = {} :: { [string]: Skin }
for i, s in BaseSkins.List do
	s.order = i
	BaseSkins.ByKey[s.key] = s
end

function BaseSkins.Get(key: string?): Skin
	return (key and BaseSkins.ByKey[key]) or BaseSkins.ByKey[BaseSkins.DEFAULT]
end

-- How many of a rarity the player has collected (lifetime).
function BaseSkins.Collected(data: any, rarity: string): number
	return (data.collected and data.collected[rarity]) or 0
end

-- Is this skin unlocked? Returns (unlocked, progress text).
function BaseSkins.Unlocked(data: any, skin: Skin): (boolean, string)
	if skin.kind == "Color" then
		return true, "Free"
	elseif skin.rarity and skin.need then
		local have = BaseSkins.Collected(data, skin.rarity)
		return have >= skin.need, "Collect " .. skin.need .. " " .. skin.rarity .. " Tung" .. (if skin.need == 1 then "" else "s") .. " (" .. math.min(have, skin.need) .. "/" .. skin.need .. ")"
	elseif skin.index then
		local done = data.indexRewards ~= nil and data.indexRewards.Master == true
		return done, "Complete the whole Index"
	end
	return false, "Locked"
end

return BaseSkins
