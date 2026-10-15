--!strict
-- Tung faces: every Tung gets its own expression. A face is eyes + brows +
-- nose + mouth + extras, picked with `look.face` (see FACES; default Classic).
-- Tungs with `look.eyes = "Glow"` get glowing eyes in the same shape.
-- Parts sit on the curved front of the log (front is -Z, log radius 1.3,
-- face area y 3.5 .. 6.1). Returns the eye parts (the Cursed mutation turns
-- them red). The main mouth part is always called "Mouth" (Bubblegum uses it).

local Tungs = require(script.Parent.Config.Tungs)

local TungFace = {}

type Props = { [string]: any }
type PartFn = (parent: Instance, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: Props?) -> Part

export type Face = {
	eyes: string, -- Round | Big | Small | Shock | Narrow | Sleepy | Smug | Happy | Wink | Derp | Star | None
	brows: string, -- Normal | Flat | Angry | Raised | Worried | One | Uneven | None
	mouth: string, -- Open | Grin | Smile | Frown | O | SmallO | Smirk | Tongue | Fangs | Zigzag | Grille | Buck | Evil | Roar
	nose: string?, -- Round (default) | Big | Long | Red | None
	extras: { string }?, -- Blush | Freckles | Mustache | Monocle | Beard | WhiteBeard | Eyepatch | GoldTooth | Sweat | Tear | Drool
}

TungFace.FACES = {
	Classic = { eyes = "Round", brows = "Normal", mouth = "Open" },
	Sleepy = { eyes = "Sleepy", brows = "Flat", mouth = "SmallO", extras = { "Drool" } },
	Cute = { eyes = "Big", brows = "Raised", mouth = "Smile", extras = { "Blush" } },
	Derp = { eyes = "Derp", brows = "Uneven", mouth = "Tongue" },
	Happy = { eyes = "Happy", brows = "Raised", mouth = "Grin", extras = { "Freckles" } },
	Shout = { eyes = "Shock", brows = "Raised", mouth = "O" },
	Wink = { eyes = "Wink", brows = "Normal", mouth = "Smile" },
	Shiver = { eyes = "Shock", brows = "Worried", mouth = "Zigzag", extras = { "Tear" } },
	Angry = { eyes = "Narrow", brows = "Angry", mouth = "Frown" },
	Cool = { eyes = "Small", brows = "Flat", mouth = "Smirk" }, -- small eyes stay hidden behind shades
	Fierce = { eyes = "Narrow", brows = "Angry", mouth = "Fangs" },
	Robot = { eyes = "None", brows = "None", mouth = "Grille", nose = "None" }, -- the visor is its eyes
	Pharaoh = { eyes = "Smug", brows = "One", mouth = "Smirk", extras = { "Beard" } },
	Royal = { eyes = "Round", brows = "One", mouth = "Smile", extras = { "Mustache", "Monocle" } },
	Starry = { eyes = "Star", brows = "Raised", mouth = "Open" },
	Rich = { eyes = "Round", brows = "Raised", mouth = "Grin", nose = "Big", extras = { "GoldTooth" } },
	Evil = { eyes = "Round", brows = "Angry", mouth = "Evil" },
	Glitch = { eyes = "Derp", brows = "Uneven", mouth = "Zigzag" },
	Calm = { eyes = "Small", brows = "Flat", mouth = "Smile" },
	Rage = { eyes = "Narrow", brows = "Angry", mouth = "Roar" },
	Goofy = { eyes = "Round", brows = "Raised", mouth = "Buck", nose = "Long" },
	Boss = { eyes = "Small", brows = "Flat", mouth = "Smirk", extras = { "GoldTooth" } },
	Nervous = { eyes = "Round", brows = "Worried", mouth = "Zigzag", extras = { "Sweat" } },
	Nerd = { eyes = "Big", brows = "Raised", mouth = "Buck" },
	Pirate = { eyes = "Round", brows = "Angry", mouth = "Grin", extras = { "Eyepatch" } },
	Wise = { eyes = "Smug", brows = "Raised", mouth = "Smile", extras = { "WhiteBeard" } },
	Jolly = { eyes = "Happy", brows = "Raised", mouth = "Grin", nose = "Big", extras = { "WhiteBeard", "Blush" } },
	Stache = { eyes = "Round", brows = "Normal", mouth = "Smile", extras = { "Mustache" } },
	Clown = { eyes = "Big", brows = "Raised", mouth = "Grin", nose = "Red", extras = { "Blush" } },
	Boo = { eyes = "Shock", brows = "None", mouth = "O", nose = "None" },
	Grumpy = { eyes = "Smug", brows = "Angry", mouth = "Frown" },
} :: { [string]: Face }

local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block
local CYL = Enum.PartType.Cylinder
local M = Enum.Material
local R = 1.3 -- log radius
local FACING = CFrame.Angles(0, math.pi / 2, 0) -- turns a cylinder's axis to point out of the face

local BLACK = Color3.fromRGB(20, 20, 24)
local WHITE = Color3.fromRGB(250, 250, 250)
local MOUTH = Color3.fromRGB(110, 20, 40)
local TONGUE = Color3.fromRGB(255, 110, 140)
local PINK = Color3.fromRGB(255, 120, 165)
local WATER = Color3.fromRGB(140, 210, 255)
local GOLD = Color3.fromRGB(255, 196, 45)

-- A frame on the log's surface at (x, y), pushed `out` studs outwards, facing out.
-- (The offset is straight forward, -Z, so things stacked at the same x stay lined up.)
local function surf(x: number, y: number, out: number): CFrame
	local xx = math.clamp(x, -1.25, 1.25)
	local zs = -math.sqrt(R * R - xx * xx)
	local n = Vector3.new(xx, 0, zs) / R
	local p = Vector3.new(xx, y, zs - out)
	return CFrame.lookAt(p, p + n)
end

local function tilt(a: number): CFrame
	return CFrame.Angles(0, 0, a) -- positive raises the +X end
end

function TungFace.Build(model: Model, look: Tungs.Look, skinColor: Color3, skinMat: Enum.Material?, part: PartFn): { BasePart }
	local face = TungFace.FACES[look.face or "Classic"] or TungFace.FACES.Classic
	local glow = look.eyes == "Glow"
	local glowColor = look.eyeColor or WHITE
	local eyes: { BasePart } = {}
	local function eye(p: BasePart): BasePart
		table.insert(eyes, p)
		return p
	end
	-- skin-coloured lid over the top of an eye; deep enough to cover the pupil too
	local function lid(sx: number, y: number, a: number)
		part(model, "Eyelid", BLOCK, Vector3.new(1.15, 0.5, 0.8), surf(sx * 0.5, y, 0.15) * tilt(a), skinColor, skinMat)
	end

	-- Eyes ------------------------------------------------------------------------------------------
	local kind = face.eyes
	if look.eyes == "Sleepy" then
		kind = "Sleepy"
	end
	for _, sx in { -1, 1 } do
		local k = kind
		if k == "Wink" then
			k = if sx < 0 then "Round" else "Happy"
		elseif k == "None" then
			continue
		end
		if glow then
			-- glowing eyes in the face's shape
			if k == "Narrow" then
				eye(part(model, "Eye", BLOCK, Vector3.new(0.8, 0.3, 0.25), surf(sx * 0.5, 5.0, 0.05) * tilt(sx * 0.3), glowColor, M.Neon))
			elseif k == "Happy" then
				eye(part(model, "Eye", BLOCK, Vector3.new(0.45, 0.16, 0.15), surf(sx * 0.5 - 0.15, 5.0, 0.04) * tilt(0.6), glowColor, M.Neon))
				eye(part(model, "Eye", BLOCK, Vector3.new(0.45, 0.16, 0.15), surf(sx * 0.5 + 0.15, 5.0, 0.04) * tilt(-0.6), glowColor, M.Neon))
			elseif k == "Derp" then
				local s = if sx < 0 then 0.85 else 0.55
				eye(part(model, "Eye", BALL, Vector3.new(s, s, s), surf(sx * 0.5, if sx < 0 then 5.1 else 4.92, -0.05), glowColor, M.Neon))
			elseif k == "Star" then
				for _, a in { 0, math.pi / 2, math.pi / 4, -math.pi / 4 } do
					local long = if a == 0 or a == math.pi / 2 then 0.8 else 0.5
					eye(part(model, "Eye", BLOCK, Vector3.new(long, 0.14, 0.1), surf(sx * 0.5, 5.0, 0.06) * tilt(a), glowColor, M.Neon))
				end
			else
				local s = if k == "Shock" or k == "Big" then 0.85 elseif k == "Small" then 0.5 else 0.7
				eye(part(model, "Eye", BALL, Vector3.new(s, s, s), surf(sx * 0.5, 5.0, -0.08), glowColor, M.Neon))
			end
			continue
		end
		if k == "Round" or k == "Narrow" or k == "Sleepy" or k == "Smug" then
			part(model, "EyeWhite", BALL, Vector3.new(0.98, 0.98, 0.98), surf(sx * 0.5, 5.0, -0.18), WHITE)
			local px = if k == "Smug" then sx * 0.46 + 0.12 else sx * 0.46
			local py = if k == "Sleepy" or k == "Narrow" then 4.86 else 4.96
			local ps = if k == "Narrow" then 0.42 else 0.5
			eye(part(model, "Pupil", BALL, Vector3.new(ps, ps, ps), surf(px, py, 0.25), BLACK))
			part(model, "Shine", BALL, Vector3.new(0.17, 0.17, 0.17), surf(px - 0.12, py + 0.12, 0.45), WHITE, M.Neon)
			if k == "Narrow" then
				lid(sx, 5.36, sx * 0.4) -- angry lid: inner corner lower
			elseif k == "Sleepy" then
				lid(sx, 5.2, 0)
			elseif k == "Smug" then
				lid(sx, 5.28, 0)
			end
		elseif k == "Big" then
			part(model, "EyeWhite", BALL, Vector3.new(1.25, 1.25, 1.25), surf(sx * 0.55, 5.05, -0.12), WHITE)
			eye(part(model, "Pupil", BALL, Vector3.new(0.68, 0.68, 0.68), surf(sx * 0.52, 5.0, 0.32), BLACK))
			part(model, "Shine", BALL, Vector3.new(0.24, 0.24, 0.24), surf(sx * 0.52 - 0.16, 5.16, 0.6), WHITE, M.Neon)
			part(model, "Shine", BALL, Vector3.new(0.12, 0.12, 0.12), surf(sx * 0.52 + 0.14, 4.86, 0.6), WHITE, M.Neon)
		elseif k == "Small" then
			eye(part(model, "Pupil", BALL, Vector3.new(0.42, 0.42, 0.42), surf(sx * 0.45, 5.0, 0.02), BLACK))
			part(model, "Shine", BALL, Vector3.new(0.12, 0.12, 0.12), surf(sx * 0.45 - 0.08, 5.08, 0.2), WHITE, M.Neon)
		elseif k == "Shock" then
			part(model, "EyeWhite", BALL, Vector3.new(1.2, 1.2, 1.2), surf(sx * 0.55, 5.05, -0.12), WHITE)
			eye(part(model, "Pupil", BALL, Vector3.new(0.28, 0.28, 0.28), surf(sx * 0.55, 5.05, 0.5), BLACK))
		elseif k == "Happy" then
			-- closed, smiling "^" eyes
			eye(part(model, "Pupil", BLOCK, Vector3.new(0.45, 0.14, 0.12), surf(sx * 0.5 - 0.15, 5.0, 0.03) * tilt(0.6), BLACK))
			eye(part(model, "Pupil", BLOCK, Vector3.new(0.45, 0.14, 0.12), surf(sx * 0.5 + 0.15, 5.0, 0.03) * tilt(-0.6), BLACK))
		elseif k == "Derp" then
			-- one big eye looking up, one small eye looking down
			local big = sx < 0
			local s = if big then 1.12 else 0.78
			local y = if big then 5.08 else 4.94
			part(model, "EyeWhite", BALL, Vector3.new(s, s, s), surf(sx * 0.52, y, -0.15), WHITE)
			eye(part(model, "Pupil", BALL, Vector3.new(0.42, 0.42, 0.42), surf(sx * 0.52 + (if big then -0.12 else 0.1), y + (if big then 0.16 else -0.12), s * 0.3), BLACK))
		elseif k == "Star" then
			local yellow = Color3.fromRGB(255, 225, 60)
			for _, a in { 0, math.pi / 2, math.pi / 4, -math.pi / 4 } do
				local long = if a == 0 or a == math.pi / 2 then 0.8 else 0.5
				eye(part(model, "Eye", BLOCK, Vector3.new(long, 0.15, 0.1), surf(sx * 0.5, 5.0, 0.06) * tilt(a), yellow, M.Neon))
			end
		end
	end

	-- Brows --------------------------------------------------------------------------------------------
	local brows = face.brows
	if brows ~= "None" then
		for _, sx in { -1, 1 } do
			local y, a = 5.72, sx * -0.15
			if brows == "Flat" then
				y, a = 5.7, 0
			elseif brows == "Angry" then
				y, a = if face.eyes == "Narrow" then 5.74 else 5.62, sx * 0.45
			elseif brows == "Raised" then
				y, a = 6.0, sx * -0.2
			elseif brows == "Worried" then
				y, a = 5.82, sx * -0.45
			elseif brows == "One" then
				y, a = if sx < 0 then 5.68 else 6.02, if sx < 0 then 0 else -0.25
			elseif brows == "Uneven" then
				y, a = if sx < 0 then 5.98 else 5.66, if sx < 0 then 0.3 else 0.1
			end
			part(model, "Brow", BLOCK, Vector3.new(0.82, 0.22, 0.18), surf(sx * 0.5, y, 0.05) * tilt(a), BLACK)
		end
	end

	-- Nose ---------------------------------------------------------------------------------------------
	local noseColor = skinColor:Lerp(Color3.fromRGB(165, 104, 60), 0.35)
	local nose = face.nose or "Round"
	if nose == "Round" then
		part(model, "Nose", BALL, Vector3.new(0.42, 0.42, 0.42), surf(0, 4.55, 0.05), noseColor, skinMat)
	elseif nose == "Big" then
		part(model, "Nose", BALL, Vector3.new(0.64, 0.64, 0.64), surf(0, 4.52, 0.1), noseColor, skinMat)
	elseif nose == "Red" then
		part(model, "Nose", BALL, Vector3.new(0.72, 0.72, 0.72), surf(0, 4.5, 0.18), Color3.fromRGB(235, 30, 40))
	elseif nose == "Long" then
		part(model, "Nose", CYL, Vector3.new(1, 0.32, 0.32), surf(0, 4.55, 0.45) * FACING, noseColor, skinMat)
		part(model, "NoseTip", BALL, Vector3.new(0.36, 0.36, 0.36), surf(0, 4.55, 0.95), noseColor, skinMat)
	end

	-- Mouth --------------------------------------------------------------------------------------------
	local mouth = face.mouth
	local function bar(name: string, x: number, y: number, w: number, a: number, color: Color3?)
		part(model, name, BLOCK, Vector3.new(w, 0.14, 0.12), surf(x, y, 0.03) * tilt(a), color or BLACK)
	end
	if mouth == "Open" then
		part(model, "Mouth", BLOCK, Vector3.new(1.2, 0.42, 0.2), surf(0, 3.92, 0.02), MOUTH)
		part(model, "Teeth", BLOCK, Vector3.new(0.95, 0.12, 0.1), surf(0, 4.07, 0.1), WHITE)
		part(model, "Tongue", BLOCK, Vector3.new(0.5, 0.14, 0.1), surf(0, 3.77, 0.1), TONGUE)
	elseif mouth == "Grin" then
		part(model, "Mouth", BLOCK, Vector3.new(1.5, 0.48, 0.2), surf(0, 3.9, 0.02), MOUTH)
		part(model, "Teeth", BLOCK, Vector3.new(1.35, 0.2, 0.1), surf(0, 4.05, 0.1), WHITE)
		part(model, "Tongue", BLOCK, Vector3.new(0.6, 0.14, 0.1), surf(0, 3.74, 0.1), TONGUE)
		for _, sx in { -1, 1 } do
			part(model, "MouthCorner", BLOCK, Vector3.new(0.32, 0.22, 0.2), surf(sx * 0.82, 4.02, 0.02) * tilt(sx * 0.6), MOUTH)
		end
	elseif mouth == "Smile" or mouth == "Tongue" or mouth == "Buck" then
		bar("Mouth", 0, 3.86, 0.7, 0)
		for _, sx in { -1, 1 } do
			bar("MouthCorner", sx * 0.48, 3.95, 0.38, sx * 0.55)
		end
		if mouth == "Tongue" then
			part(model, "Tongue", BLOCK, Vector3.new(0.42, 0.5, 0.16), surf(0.15, 3.66, 0.08) * tilt(-0.15), TONGUE)
		elseif mouth == "Buck" then
			for _, sx in { -1, 1 } do
				part(model, "Tooth", BLOCK, Vector3.new(0.22, 0.32, 0.1), surf(sx * 0.12, 3.68, 0.07), WHITE)
			end
		end
	elseif mouth == "Frown" then
		bar("Mouth", 0, 3.94, 0.7, 0)
		for _, sx in { -1, 1 } do
			bar("MouthCorner", sx * 0.48, 3.85, 0.38, sx * -0.55)
		end
	elseif mouth == "O" or mouth == "SmallO" then
		local s = if mouth == "O" then 0.8 else 0.42
		part(model, "Mouth", CYL, Vector3.new(0.12, s, s), surf(0, 3.85, 0.02) * FACING, MOUTH)
		if mouth == "O" then
			part(model, "Tongue", CYL, Vector3.new(0.1, 0.4, 0.4), surf(0, 3.7, 0.06) * FACING, TONGUE)
		end
	elseif mouth == "Smirk" then
		bar("Mouth", 0.1, 3.9, 0.75, 0.18)
		bar("MouthCorner", 0.55, 4.0, 0.22, 0.75)
	elseif mouth == "Fangs" then
		part(model, "Mouth", BLOCK, Vector3.new(1.3, 0.48, 0.2), surf(0, 3.9, 0.02), MOUTH)
		for _, sx in { -1, 1 } do
			part(model, "Fang", BLOCK, Vector3.new(0.18, 0.3, 0.1), surf(sx * 0.36, 3.98, 0.1) * tilt(sx * 0.12), WHITE)
		end
	elseif mouth == "Zigzag" then
		for n, x in { -0.45, -0.15, 0.15, 0.45 } do
			bar(if n == 1 then "Mouth" else "MouthBit", x, 3.88, 0.34, if n % 2 == 0 then 0.55 else -0.55)
		end
	elseif mouth == "Grille" then
		part(model, "Mouth", BLOCK, Vector3.new(1.3, 0.5, 0.2), surf(0, 3.9, 0.02), Color3.fromRGB(40, 42, 50))
		for n = 0, 4 do
			part(model, "GrilleBar", BLOCK, Vector3.new(0.08, 0.42, 0.1), surf(-0.44 + n * 0.22, 3.9, 0.1), Color3.fromRGB(200, 205, 215))
		end
	elseif mouth == "Evil" then
		part(model, "Mouth", BLOCK, Vector3.new(1.7, 0.55, 0.2), surf(0, 3.9, 0.02), Color3.fromRGB(30, 8, 14))
		for n = 0, 5 do
			part(model, "Tooth", BLOCK, Vector3.new(0.17, 0.17, 0.1), surf(-0.66 + n * 0.264, 4.12, 0.1) * tilt(math.pi / 4), WHITE)
		end
		for n = 0, 4 do
			part(model, "Tooth", BLOCK, Vector3.new(0.17, 0.17, 0.1), surf(-0.53 + n * 0.264, 3.68, 0.1) * tilt(math.pi / 4), WHITE)
		end
	elseif mouth == "Roar" then
		part(model, "Mouth", BLOCK, Vector3.new(1.3, 0.75, 0.2), surf(0, 3.85, 0.02), MOUTH)
		part(model, "Teeth", BLOCK, Vector3.new(1.1, 0.16, 0.1), surf(0, 4.15, 0.1), WHITE)
		part(model, "Teeth", BLOCK, Vector3.new(1.0, 0.14, 0.1), surf(0, 3.55, 0.1), WHITE)
		part(model, "Tongue", BLOCK, Vector3.new(0.55, 0.18, 0.1), surf(0, 3.68, 0.08), TONGUE)
	end

	-- Extras ------------------------------------------------------------------------------------------
	local extras: { string } = face.extras or {}
	for _, extra in extras do
		if extra == "Blush" then
			for _, sx in { -1, 1 } do
				part(model, "Blush", CYL, Vector3.new(0.06, 0.5, 0.5), surf(sx * 0.9, 4.4, 0.01) * FACING, PINK)
			end
		elseif extra == "Freckles" then
			for _, sx in { -1, 1 } do
				for n, off in { Vector2.new(-0.12, 0.06), Vector2.new(0.1, 0.1), Vector2.new(0, -0.08) } do
					local _ = n
					part(model, "Freckle", BALL, Vector3.new(0.12, 0.12, 0.12), surf(sx * 0.82 + off.X, 4.45 + off.Y, 0), Color3.fromRGB(150, 90, 50))
				end
			end
		elseif extra == "Mustache" then
			local brown = Color3.fromRGB(70, 40, 24)
			for _, sx in { -1, 1 } do
				part(model, "Mustache", BLOCK, Vector3.new(0.55, 0.2, 0.14), surf(sx * 0.3, 4.27, 0.08) * tilt(sx * 0.25), brown)
				part(model, "MustacheCurl", BALL, Vector3.new(0.22, 0.22, 0.22), surf(sx * 0.6, 4.38, 0.06), brown)
			end
		elseif extra == "Monocle" then
			part(model, "Monocle", CYL, Vector3.new(0.06, 1.15, 1.15), surf(0.5, 5.0, 0.62) * FACING, GOLD, M.Foil)
			part(model, "MonocleGlass", CYL, Vector3.new(0.07, 0.95, 0.95), surf(0.5, 5.0, 0.62) * FACING, Color3.fromRGB(220, 240, 255), M.Glass, { Transparency = 0.6 })
			part(model, "MonocleChain", BLOCK, Vector3.new(0.05, 1.1, 0.05), surf(0.98, 4.2, 0.1), GOLD, M.Foil)
		elseif extra == "Beard" then
			part(model, "Beard", BLOCK, Vector3.new(0.42, 1.0, 0.3), surf(0, 3.15, 0.12) * CFrame.Angles(-0.25, 0, 0), GOLD, M.Foil)
			for _, y in { 3.0, 3.35 } do
				part(model, "BeardStripe", BLOCK, Vector3.new(0.44, 0.08, 0.32), surf(0, y, 0.14) * CFrame.Angles(-0.25, 0, 0), Color3.fromRGB(40, 80, 200))
			end
		elseif extra == "GoldTooth" then
			part(model, "GoldTooth", BLOCK, Vector3.new(0.2, 0.18, 0.1), surf(0.28, if mouth == "Smirk" then 3.84 else 4.05, 0.13), GOLD, M.Foil)
		elseif extra == "Sweat" then
			part(model, "Sweat", BALL, Vector3.new(0.3, 0.3, 0.3), surf(1.02, 5.85, 0), WATER, M.Glass, { Transparency = 0.15 })
			part(model, "Sweat", BALL, Vector3.new(0.18, 0.18, 0.18), surf(1.0, 6.08, 0), WATER, M.Glass, { Transparency = 0.15 })
		elseif extra == "Tear" then
			part(model, "Tear", BALL, Vector3.new(0.24, 0.24, 0.24), surf(-0.66, 4.6, 0.04), WATER, M.Glass, { Transparency = 0.1 })
			part(model, "Tear", BALL, Vector3.new(0.16, 0.16, 0.16), surf(-0.68, 4.38, 0.04), WATER, M.Glass, { Transparency = 0.1 })
		elseif extra == "WhiteBeard" then
			for _, off in { Vector3.new(0, 3.25, 0.12), Vector3.new(-0.55, 3.45, 0.02), Vector3.new(0.55, 3.45, 0.02), Vector3.new(-0.3, 2.85, 0.08), Vector3.new(0.3, 2.85, 0.08), Vector3.new(0, 2.55, 0.1) } do
				part(model, "Beard", BALL, Vector3.new(0.85, 0.85, 0.85), surf(off.X, off.Y, off.Z), WHITE)
			end
		elseif extra == "Eyepatch" then
			part(model, "Eyepatch", CYL, Vector3.new(0.1, 0.95, 0.95), surf(0.5, 5.0, 0.62) * FACING, BLACK)
			part(model, "Strap", BLOCK, Vector3.new(1.5, 0.12, 0.1), surf(0.1, 5.4, 0.05) * tilt(-0.25), BLACK)
		elseif extra == "Drool" then
			part(model, "Drool", BLOCK, Vector3.new(0.1, 0.42, 0.08), surf(0.24, 3.6, 0.05), WATER, M.Glass, { Transparency = 0.2 })
		end
	end
	return eyes
end

return TungFace
