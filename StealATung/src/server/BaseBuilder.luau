--!strict
-- Builds one player base: a closed box building (walls, framed window bands,
-- a roof) whose whole ground-floor front is a laser wall, the only way in or
-- out. Its look comes from the owner's chosen base skin (Config/BaseSkins);
-- rebirths only add floors. Inside: glowing pads, round Collect buttons,
-- stairs along the back wall, the Rebirth Altar with the Skins stand next to
-- it, the lock button, owned traps and (Rebirth 6+) the personal belt. The
-- owner's name floats above the roof.
--
-- Rebuilt from scratch whenever the base grows or changes look. BaseService
-- relies only on these names: Pads/Pad<n>(/PlacePrompt), Buttons/Button<n>,
-- Headline/OwnerGui, DoorStatus/DoorGui, Altar, LockButton, Lasers (Wall +
-- bars), Traps/<Banana|Honey|Alarm>, PersonalBelt, SkinStand.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BaseSkins = require(Shared.Config.BaseSkins)
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Style = require(Shared.Style)

local BaseBuilder = {}

local M = Enum.Material
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local VERT = CFrame.Angles(0, 0, math.rad(90))
local LASER_RED = Color3.fromRGB(255, 40, 50)

export type BuildInfo = {
	index: number,
	slots: number,
	skin: string,
	items: any, -- owned traps
	personalBelt: boolean,
}

type Props = { [string]: any }

local function P(parent: Instance, props: Props): BasePart
	local className = props.ClassName or "Part"
	props.ClassName = nil
	local material = props.Material
	props.Material = nil
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	Style.Apply(p, material)
	p.Parent = parent
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function prompt(parent: Instance, action: string, object: string, attrs: { [string]: any }): ProximityPrompt
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Style = Enum.ProximityPromptStyle.Custom
	for k, v in attrs do
		pr:SetAttribute(k, v)
	end
	pr.Parent = parent
	return pr
end

local function label(parent: Instance, name: string, props: Props): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		(l :: any)[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = Color3.fromRGB(26, 24, 40)
	s.Parent = l
	l.Parent = parent
	return l
end

-- Skin decorations. Everything sits on the roof or just outside the walls.
local function decorate(deco: Instance, kind: string?, L: (number, number, number) -> CFrame, HW: number, D: number, top: number, seed: number)
	if not kind then
		return
	end
	local roofY = top + 0.6
	local rng = Random.new(seed * 31)
	local function part(props: Props): BasePart
		props.CanCollide = if props.CanCollide == nil then false else props.CanCollide
		props.CastShadow = false
		return P(deco, props)
	end
	local gold = Color3.fromRGB(255, 200, 50)
	if kind == "Crown" or kind == "BigCrown" then
		-- a gold crown sitting on the roof
		local size = if kind == "BigCrown" then 1.6 else 1
		local c = L(0, roofY, D / 2)
		local r = 6 * size
		part({ Name = "CrownBand", Shape = CYL, Size = Vector3.new(2.4 * size, r * 2, r * 2), CFrame = c * CFrame.new(0, 1.2 * size, 0) * VERT, Color = gold, Material = M.Foil })
		for n = 0, 7 do
			local a = n / 8 * math.pi * 2
			local spike = c * CFrame.new(math.cos(a) * r * 0.9, 3.8 * size, math.sin(a) * r * 0.9)
			part({ Name = "CrownSpike", Size = Vector3.new(1.4 * size, 2.8 * size, 1.4 * size), CFrame = spike * CFrame.Angles(0, -a, math.rad(45)), Color = gold, Material = M.Foil })
			part({ Name = "CrownGem", Shape = BALL, Size = Vector3.new(0.9, 0.9, 0.9) * size, CFrame = c * CFrame.new(math.cos(a) * r, 1.2 * size, math.sin(a) * r), Color = if n % 2 == 0 then Color3.fromRGB(255, 50, 70) else Color3.fromRGB(60, 160, 255), Material = M.Neon })
		end
		if kind == "BigCrown" then
			for _, sx in { -1, 1 } do
				part({ Name = "Column", Shape = CYL, Size = Vector3.new(12, 2.4, 2.4), CFrame = L(sx * (HW - 3), 6, -3) * VERT, Color = Color3.fromRGB(255, 236, 170), Material = M.Foil, CanCollide = true })
				part({ Name = "ColumnCap", Size = Vector3.new(3.2, 0.8, 3.2), CFrame = L(sx * (HW - 3), 12.3, -3), Color = gold, Material = M.Foil })
			end
		end
	elseif kind == "CatEars" then
		for _, sx in { -1, 1 } do
			local at = L(sx * (HW - 7), roofY + 4.2, 4)
			part({ Name = "Ear", Size = Vector3.new(7, 7, 2), CFrame = at * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(246, 196, 64), Material = M.SmoothPlastic })
			part({ Name = "EarInside", Size = Vector3.new(4.2, 4.2, 2.1), CFrame = at * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(255, 160, 190), Material = M.SmoothPlastic })
		end
	elseif kind == "CandyCanes" then
		for _, sx in { -1, 1 } do
			local x, d = sx * (HW + 2.2), -2.2
			local h = top + 4
			local n = 0
			for y = 0, h - 2, 2 do
				n += 1
				part({ Name = "Cane", Shape = CYL, Size = Vector3.new(2, 1.6, 1.6), CFrame = L(x, y + 1, d) * VERT, Color = if n % 2 == 0 then Color3.fromRGB(230, 40, 52) else Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic, CanCollide = true })
			end
			for m = 0, 4 do
				local a = m / 4 * math.pi
				local pos = L(x - sx * (1.6 - math.cos(a) * 1.6), h + math.sin(a) * 1.6, d)
				part({ Name = "CaneHook", Shape = BALL, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = pos, Color = if m % 2 == 0 then Color3.fromRGB(230, 40, 52) else Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
			end
		end
		-- gumdrops along the front of the roof
		for n = 1, 8 do
			part({ Name = "Gumdrop", Shape = BALL, Size = Vector3.new(1.8, 1.4, 1.8), CFrame = L(-HW + n * HW * 2 / 9, roofY + 2.3, 0.2), Color = Color3.fromHSV((n * 0.13) % 1, 0.6, 1), Material = M.SmoothPlastic })
		end
	elseif kind == "Barrels" then
		for _, at in { { -HW + 2.5, -3 }, { -HW + 5.5, -3.4 }, { HW - 2.5, -3 } } do
			part({ Name = "Barrel", Shape = CYL, Size = Vector3.new(3, 2.4, 2.4), CFrame = L(at[1], 1.5, at[2]) * VERT, Color = Color3.fromRGB(176, 112, 60), Material = M.SmoothPlastic, CanCollide = true })
			part({ Name = "BarrelBand", Shape = CYL, Size = Vector3.new(0.3, 2.5, 2.5), CFrame = L(at[1], 2.2, at[2]) * VERT, Color = Color3.fromRGB(80, 80, 90), Material = M.SmoothPlastic })
		end
		part({ Name = "Crate", Size = Vector3.new(3, 3, 3), CFrame = L(HW - 6, 1.5, -3) * CFrame.Angles(0, 0.3, 0), Color = Color3.fromRGB(196, 150, 96), Material = M.SmoothPlastic, CanCollide = true })
	elseif kind == "Bushes" then
		for n = 0, 9 do
			local x = -HW + 3 + (n // 2) * (HW * 2 - 6) / 4
			part({ Name = "Bush", Shape = BALL, Size = Vector3.new(4, 3, 4), CFrame = L(x, roofY + 1.5, if n % 2 == 0 then 2.5 else D - 2.5), Color = if n % 3 == 0 then Color3.fromRGB(110, 210, 80) else Color3.fromRGB(70, 170, 70), Material = M.SmoothPlastic })
		end
		for _, sx in { -1, 1 } do
			for _, d in { 6, D / 2, D - 6 } do
				part({ Name = "Shrub", Shape = BALL, Size = Vector3.new(3.4, 2.6, 3.4), CFrame = L(sx * (HW + 2), 1, d), Color = Color3.fromRGB(80, 180, 70), Material = M.SmoothPlastic })
			end
		end
	elseif kind == "Ice" then
		part({ Name = "Snow", Size = Vector3.new(HW * 2 - 2, 0.8, D - 2), CFrame = L(0, roofY + 0.4, D / 2), Color = Color3.fromRGB(250, 252, 255), Material = M.SmoothPlastic })
		for n = 0, 12 do
			local x = -HW + 2 + n * (HW * 2 - 4) / 12
			local len = rng:NextNumber(1.5, 3.2)
			part({ Name = "Icicle", Size = Vector3.new(0.6, len, 0.6), CFrame = L(x, top - 0.6 - len / 2, -0.5), Color = Color3.fromRGB(190, 235, 255), Material = M.Glass, Transparency = 0.2 })
		end
	elseif kind == "Crystals" then
		for n = 1, 8 do
			local sx = if n % 2 == 0 then 1 else -1
			local d = if n <= 4 then 3 else D - 3
			part({ Name = "Crystal", Size = Vector3.new(1.6, rng:NextNumber(4, 8), 1.6), CFrame = L(sx * (HW - 2 - (n % 4) * 1.5), roofY + 2.5, d) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = if n % 3 == 0 then Color3.fromRGB(120, 230, 255) else Color3.fromRGB(220, 110, 255), Material = M.Neon })
		end
	elseif kind == "Rainbow" then
		-- a rainbow arch over the roof
		local colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 230, 50), Color3.fromRGB(80, 220, 90), Color3.fromRGB(60, 160, 255), Color3.fromRGB(150, 90, 255) }
		for band, c in colors do
			local r = 14 - band * 1.1
			for n = 0, 10 do
				local a = n / 10 * math.pi
				part({ Name = "Arch", Size = Vector3.new(1.1, 1.1, 2.6), CFrame = L(math.cos(a) * r, roofY + math.sin(a) * r, D / 2) * CFrame.Angles(0, 0, a), Color = c, Material = M.Neon, Transparency = 0.15 })
			end
		end
	elseif kind == "Inferno" then
		for _, sx in { -1, 1 } do
			local at = L(sx * (HW - 4), roofY + 3, 3)
			part({ Name = "Horn", Size = Vector3.new(2.2, 7, 2.2), CFrame = at * CFrame.Angles(0, 0, sx * -0.35), Color = Color3.fromRGB(250, 240, 220), Material = M.SmoothPlastic })
			part({ Name = "HornTip", Size = Vector3.new(1.4, 3, 1.4), CFrame = at * CFrame.Angles(0, 0, sx * -0.35) * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, 0, sx * -0.35), Color = Color3.fromRGB(40, 20, 20), Material = M.SmoothPlastic })
			for _, d in { -3, D + 3 } do
				local bowl = part({ Name = "Brazier", Shape = CYL, Size = Vector3.new(1.2, 3, 3), CFrame = L(sx * (HW + 3), 3.5, d) * VERT, Color = Color3.fromRGB(50, 30, 30), Material = M.SmoothPlastic })
				part({ Name = "BrazierLeg", Size = Vector3.new(0.8, 3, 0.8), CFrame = L(sx * (HW + 3), 1.9, d), Color = Color3.fromRGB(50, 30, 30), Material = M.SmoothPlastic })
				local fire = Instance.new("Fire")
				fire.Color = Color3.fromRGB(255, 120, 20)
				fire.SecondaryColor = Color3.fromRGB(255, 40, 10)
				fire.Size = 5
				fire.Parent = bowl
			end
		end
		-- glowing lava cracks running down the side walls
		for _, sx in { -1, 1 } do
			for _ = 1, 4 do
				part({ Name = "LavaCrack", Size = Vector3.new(0.12, rng:NextNumber(4, 9), 0.5), CFrame = L(sx * (HW + 0.06), rng:NextNumber(3, math.max(4, top - 5)), rng:NextNumber(4, D - 4)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, 0), Color = Color3.fromRGB(255, 110, 20), Material = M.Neon })
			end
		end
	elseif kind == "Temple" then
		for n = 0, 5 do
			local x = -HW + 3 + n * (HW * 2 - 6) / 5
			part({ Name = "Column", Shape = CYL, Size = Vector3.new(top, 2, 2), CFrame = L(x, top / 2, -2.4) * VERT, Color = Color3.fromRGB(250, 246, 236), Material = M.Marble, CanCollide = true })
		end
		-- golden gable on the front of the roof: two wedges (tall face = +Z) meeting in the middle
		for _, sx in { -1, 1 } do
			part({ ClassName = "WedgePart", Name = "Pediment", Size = Vector3.new(3, 8, HW), CFrame = L(sx * HW / 2, roofY + 4, 1.5) * CFrame.Angles(0, -sx * math.pi / 2, 0), Color = gold, Material = M.Foil })
		end
	end
end

function BaseBuilder.Build(parent: Instance, info: BuildInfo): Model
	local i = info.index
	local skin = BaseSkins.Get(info.skin)
	local floors = Layout.Floors(info.slots)
	local D = Layout.BASE_DEPTH
	local HW = Layout.BASE_WIDTH / 2
	local FH = Layout.FLOOR_HEIGHT
	local T = Layout.WALL_THICKNESS
	local IN = HW - T -- inside face of the side walls
	local top = floors * FH
	local trimMat = skin.trimMaterial or M.SmoothPlastic
	local wallMat = skin.wallMaterial or M.SmoothPlastic

	local base = Instance.new("Model")
	base.Name = "Base" .. i
	base:SetAttribute("Index", i)
	base:SetAttribute("Floors", floors)
	base:SetAttribute("Skin", skin.key)

	local function L(x: number, y: number, d: number): CFrame
		return Layout.Local(i, x, y, d)
	end
	-- axis-aligned box in base space (x1..x2, y1..y2, d1..d2)
	local function box(parentInst: Instance, name: string, x1: number, x2: number, y1: number, y2: number, d1: number, d2: number, props: Props): BasePart
		props.Name = name
		props.Size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(d2 - d1))
		props.CFrame = L((x1 + x2) / 2, (y1 + y2) / 2, (d1 + d2) / 2)
		return P(parentInst, props)
	end

	-- Ground floor ---------------------------------------------------------------------------------
	P(base, { Name = "Floor", Size = Vector3.new(HW * 2, 0.8, D), CFrame = L(0, 0, D / 2), Color = skin.floor, Material = M.SmoothPlastic })
	P(base, { Name = "FloorRim", Size = Vector3.new(HW * 2 + 1.2, 0.7, D + 1.2), CFrame = L(0, -0.08, D / 2), Color = skin.accent, Material = M.SmoothPlastic })
	local tile = 9
	for tx = -HW + tile / 2, HW - tile / 2, tile do
		for td = tile / 2, D - tile / 2, tile do
			if (math.floor((tx + HW) / tile) + math.floor(td / tile)) % 2 == 0 then
				P(base, { Name = "Tile", Size = Vector3.new(tile, 0.05, tile), CFrame = L(tx, Layout.FLOOR_TOP + 0.02, td), Color = skin.tile, Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
			end
		end
	end

	-- Upper floor slabs, with an opening above the stairs that lead up to them --------------------
	-- Shell parts don't cast shadows, so daylight still reaches the inside of the box.
	local structure = folder(base, "Structure")
	local holeD = Layout.STAIR_FRONT - 0.5
	for f = 2, floors do
		local y0 = Layout.FloorY(f)
		local s = Layout.StairSide(f - 1)
		local function slabProps(): Props
			return { Color = skin.floor, Material = M.SmoothPlastic, CastShadow = false }
		end
		box(structure, "Slab", -IN, IN, y0 - 0.6, y0 + 0.4, T, holeD, slabProps())
		-- back piece beside the opening
		box(structure, "Slab", -s * IN, s * Layout.STAIR_INNER, y0 - 0.6, y0 + 0.4, holeD, D - T, slabProps())
		-- low railing along the opening so nobody walks into it by accident
		box(structure, "HoleRail", s * Layout.STAIR_INNER, s * IN, y0 + 0.4, y0 + 2.6, holeD - 0.15, holeD + 0.15, { Color = skin.trim, Material = trimMat, CastShadow = false })
	end

	-- Stairs along the inside of the back wall, alternating sides floor by floor ------------------------
	for f = 1, floors - 1 do
		local y0 = Layout.FloorY(f)
		local s = Layout.StairSide(f)
		local run = (Layout.STAIR_OUTER - Layout.STAIR_INNER) / FH -- one 1-stud rise per step
		for k = 1, FH do
			local x = s * (Layout.STAIR_OUTER - (k - 0.5) * run)
			P(structure, {
				Name = "Step",
				Size = Vector3.new(run, k, Layout.STAIR_BACK - Layout.STAIR_FRONT),
				CFrame = L(x, y0 + Layout.FLOOR_TOP + k / 2, (Layout.STAIR_FRONT + Layout.STAIR_BACK) / 2),
				Color = if k % 2 == 0 then skin.wall else skin.wall:Lerp(Color3.new(1, 1, 1), 0.2),
				Material = M.SmoothPlastic,
				CastShadow = false,
			})
		end
		-- handrail on the open side of the flight
		local a = L(s * Layout.STAIR_OUTER, y0 + Layout.FLOOR_TOP + 3, Layout.STAIR_FRONT - 0.2).Position
		local b = L(s * Layout.STAIR_INNER, y0 + Layout.FLOOR_TOP + FH + 3, Layout.STAIR_FRONT - 0.2).Position
		P(structure, { Name = "Handrail", Size = Vector3.new(0.4, 0.4, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = skin.trim, Material = trimMat, CanCollide = false })
	end

	-- The box: framed window bands on every floor, the roof ---------------------------------------------------
	local shell = folder(base, "Shell")
	local WB, WT = Layout.WINDOW_BOTTOM, Layout.WINDOW_TOP
	local function wallProps(): Props
		return { Color = skin.wall, Material = wallMat, Transparency = skin.wallTransparency or 0, CastShadow = false }
	end
	local function frameProps(): Props
		return { Color = skin.frame, Material = M.SmoothPlastic, CastShadow = false }
	end
	-- One piece of a face. `u` runs along the face: depth on the side walls
	-- (0 .. D), x on the front and back walls (between the side walls).
	-- `layer`: nil (full wall thickness), "glass" (thin, set in) or "frame" (sticks out a little).
	local function facePiece(which: string, name: string, u1: number, u2: number, y1: number, y2: number, props: Props, layer: string?)
		if u2 - u1 < 0.05 or y2 - y1 < 0.05 then
			return
		end
		local a, b = 0, T -- from the outside surface inwards
		if layer == "glass" then
			a, b = T * 0.3, T * 0.7
		elseif layer == "frame" then
			a, b = -0.25, T * 0.5
		end
		if which == "L" then
			box(shell, name, -HW + a, -HW + b, y1, y2, u1, u2, props)
		elseif which == "R" then
			box(shell, name, HW - b, HW - a, y1, y2, u1, u2, props)
		elseif which == "F" then
			box(shell, name, u1, u2, y1, y2, a, b, props)
		else
			box(shell, name, u1, u2, y1, y2, D - b, D - a, props)
		end
	end
	-- the window band of one floor: framed glass in `windows`, wall everywhere else along u1 .. u2
	local function windowBand(which: string, y0: number, u1: number, u2: number, windows: { { number } })
		local u = u1
		for _, w in windows do
			local w1, w2 = w[1], w[2]
			facePiece(which, "Wall", u, w1, y0 + WB, y0 + WT, wallProps())
			facePiece(which, "Window", w1, w2, y0 + WB, y0 + WT, { Color = skin.glass, Material = M.Glass, Transparency = 0.45, CastShadow = false }, "glass")
			-- dark frame: header, sill, and mullions every ~6 studs (including both ends)
			facePiece(which, "Frame", w1, w2, y0 + WT - 0.45, y0 + WT, frameProps(), "frame")
			facePiece(which, "Frame", w1, w2, y0 + WB, y0 + WB + 0.45, frameProps(), "frame")
			local panes = math.max(1, math.floor((w2 - w1) / 6 + 0.5))
			for k = 0, panes do
				local mu = w1 + (w2 - w1) * k / panes
				facePiece(which, "Frame", math.max(w1, mu - 0.25), math.min(w2, mu + 0.25), y0 + WB, y0 + WT, frameProps(), "frame")
			end
			u = w2
		end
		facePiece(which, "Wall", u, u2, y0 + WB, y0 + WT, wallProps())
	end
	-- solid wall between the window bands of floor f - 1 and floor f
	local function bandBottom(f: number): number
		return if f == 1 then 0 else Layout.FloorY(f - 1) + WT
	end
	local function bandTop(f: number): number
		return if f > floors then top else Layout.FloorY(f) + WB
	end
	local SIDE_WINDOWS = { { 5, 33 }, { 37, 65 } }
	local FRONT_WINDOWS = { { -21, 21 } }
	for _, which in { "L", "R" } do
		for f = 1, floors + 1 do
			facePiece(which, "Wall", 0, D, bandBottom(f), bandTop(f), wallProps())
		end
		for f = 1, floors do
			windowBand(which, Layout.FloorY(f), 0, D, SIDE_WINDOWS)
		end
	end
	-- front: the ground floor is all laser wall (below), windows on the floors above
	for f = 2, floors + 1 do
		facePiece("F", "Wall", -IN, IN, bandBottom(f), bandTop(f), wallProps())
	end
	for f = 2, floors do
		windowBand("F", Layout.FloorY(f), -IN, IN, FRONT_WINDOWS)
	end
	-- back: solid
	facePiece("B", "Wall", -IN, IN, 0, top, wallProps())

	-- roof with a little parapet
	box(shell, "Roof", -HW, HW, top - 0.6, top + 0.6, 0, D, { Color = skin.roof, Material = wallMat, CastShadow = false })
	box(shell, "Parapet", -HW - 0.3, HW + 0.3, top + 0.6, top + 2.2, -0.3, 0.7, { Color = skin.trim, Material = trimMat, CastShadow = false })
	box(shell, "Parapet", -HW - 0.3, HW + 0.3, top + 0.6, top + 2.2, D - 0.7, D + 0.3, { Color = skin.trim, Material = trimMat, CastShadow = false })
	for _, sx in { -1, 1 } do
		box(shell, "Parapet", sx * (HW + 0.3), sx * (HW - 0.7), top + 0.6, top + 2.2, 0.7, D - 0.7, { Color = skin.trim, Material = trimMat, CastShadow = false })
	end
	-- corner pillars and a trim belt at every floor line
	for _, sx in { -1, 1 } do
		for _, d in { 0, D } do
			P(shell, { Name = "Pillar", Size = Vector3.new(1.8, top + 0.6, 1.8), CFrame = L(sx * HW, (top + 0.6) / 2, d), Color = skin.frame, Material = M.SmoothPlastic, CastShadow = false })
		end
	end
	local RAINBOW = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 230, 50), Color3.fromRGB(80, 220, 90), Color3.fromRGB(60, 160, 255), Color3.fromRGB(150, 90, 255) }
	for f = 2, floors do
		local y = Layout.FloorY(f)
		local function beltProps(k: number): Props
			local rainbow = skin.decor == "Rainbow"
			return { Color = if rainbow then RAINBOW[(k + f) % #RAINBOW + 1] else skin.trim, Material = if rainbow then M.Neon else trimMat, CastShadow = false, CanCollide = false }
		end
		box(shell, "Belt", -HW - 0.3, HW + 0.3, y - 0.5, y + 0.3, -0.3, 0.3, beltProps(1))
		box(shell, "Belt", -HW - 0.3, HW + 0.3, y - 0.5, y + 0.3, D - 0.3, D + 0.3, beltProps(2))
		for k, sx in { -1, 1 } do
			box(shell, "Belt", sx * (HW + 0.3), sx * (HW - 0.3), y - 0.5, y + 0.3, 0.3, D - 0.3, beltProps(2 + k))
		end
	end

	-- The laser wall: the whole ground-floor front ----------------------------------------------------------------
	local LH = Layout.LASER_HEIGHT
	local LX = HW - 0.9 -- between the corner pillars
	-- emitter rail along the top with a red strip, and a dark sill along the floor
	box(shell, "LaserEmitter", -LX, LX, LH - 0.6, LH, -0.35, T, { Color = skin.frame, Material = M.SmoothPlastic, CastShadow = false })
	box(shell, "LaserStrip", -LX, LX, LH - 0.8, LH - 0.6, 0.1, 0.5, { Color = LASER_RED, Material = M.Neon, CanCollide = false, CastShadow = false })
	box(shell, "LaserSill", -LX, LX, 0.3, 0.55, -0.35, T, { Color = skin.frame, Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
	local lasers = folder(base, "Lasers")
	local bars = 0
	for x = -LX + 1, LX - 0.99, 2 do
		bars += 1
		P(lasers, { Name = "Bar" .. bars, Size = Vector3.new(0.24, LH - 1.35, 0.24), CFrame = L(x, 0.55 + (LH - 1.35) / 2, 0.3), Color = LASER_RED, Material = M.Neon, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	end
	-- the invisible wall that actually blocks people: everyone but the owner (collision groups, see BaseService)
	box(lasers, "Wall", -LX, LX, 0, LH, 0, 0.6, { Transparency = 1, CanCollide = false, CanQuery = false, CollisionGroup = "Laser" .. i })

	-- Lock / shield status above the lasers
	local doorAnchor = P(base, { Name = "DoorStatus", Size = Vector3.new(1, 1, 1), CFrame = L(0, LH + 2.4, -1.5), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local door = Instance.new("BillboardGui")
	door.Name = "DoorGui"
	door.Size = UDim2.fromScale(14, 2.4)
	door.MaxDistance = 120
	door.LightInfluence = 0
	door.Enabled = false
	label(door, "Status", { Text = "", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 225, 120) })
	door.Parent = doorAnchor

	-- Owner name floating above the roof ----------------------------------------------------------------------------------
	local anchor = P(base, { Name = "Headline", Size = Vector3.new(1, 1, 1), CFrame = L(0, top + 9, D / 2), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local head = Instance.new("BillboardGui")
	head.Name = "OwnerGui"
	head.Size = UDim2.fromScale(40, 7)
	head.MaxDistance = 700
	head.LightInfluence = 0
	head.Enabled = false
	local nameLabel = label(head, "OwnerName", { Text = "", Size = UDim2.fromScale(1, 1) })
	local nameStroke = nameLabel:FindFirstChildOfClass("UIStroke")
	if nameStroke then
		nameStroke.Thickness = 3
	end
	head.Parent = anchor

	-- Skin decorations (outside the box or on the roof, never in the way) -------------------------------------------------------
	decorate(folder(base, "Decor"), skin.decor, L, HW, D, top, i)

	-- Pads (4 per side wall, per floor) + Collect buttons -------------------------------------------------------
	local pads = folder(base, "Pads")
	local buttons = folder(base, "Buttons")
	for slot = 1, info.slots do
		local x, y0, d, side = Layout.PadLocal(slot, info.slots)
		local pad = P(pads, { Name = "Pad" .. slot, Size = Vector3.new(8, 0.6, 8), CFrame = L(x, y0 + Layout.PAD_TOP - 0.3, d), Color = skin.pad, Material = M.SmoothPlastic })
		pad:SetAttribute("Slot", slot)
		-- shown to the owner only while they're holding one of their Tungs (see PromptUI)
		local place = prompt(pad, "Place Here", "Slot " .. slot, { Action = "Place", Slot = slot, OwnerOnly = true })
		place.Name = "PlacePrompt"
		place.MaxActivationDistance = 7
		CollectionService:AddTag(place, "OwnPrompt")
		P(pad, { Name = "Glow", Size = Vector3.new(8.8, 0.3, 8.8), CFrame = L(x, y0 + Layout.PAD_TOP - 0.5, d), Color = skin.accent, Material = M.SmoothPlastic, Transparency = 0.1, CanCollide = false })
		-- faint Tung outline + "+" shown while the pad is empty
		local ghost = Instance.new("Model")
		ghost.Name = "Ghost"
		P(ghost, { Name = "GhostBody", Shape = CYL, Size = Vector3.new(4.4, 2.6, 2.6), CFrame = L(x, y0 + Layout.PAD_TOP + 4.1, d) * VERT, Color = Color3.new(1, 1, 1), Material = M.ForceField, CanCollide = false, CanQuery = false })
		for _, sd in { -0.55, 0.55 } do
			P(ghost, { Name = "GhostLeg", Shape = CYL, Size = Vector3.new(1.6, 0.6, 0.6), CFrame = L(x, y0 + Layout.PAD_TOP + 0.9, d + sd) * VERT, Color = Color3.new(1, 1, 1), Material = M.ForceField, CanCollide = false, CanQuery = false })
		end
		local plus = Instance.new("BillboardGui")
		plus.Name = "Plus"
		plus.Size = UDim2.fromScale(2.5, 2.5)
		plus.StudsOffset = Vector3.new(0, 1.5, 0)
		plus.MaxDistance = 60
		plus.LightInfluence = 0
		label(plus, "Text", { Text = "+", Size = UDim2.fromScale(1, 1), TextTransparency = 0.25 })
		plus.Parent = ghost:FindFirstChild("GhostBody")
		ghost.Parent = pad

		local bx = side * Layout.BUTTON_X
		local button = P(buttons, { Name = "Button" .. slot, Shape = CYL, Size = Vector3.new(0.5, 4.2, 4.2), CFrame = L(bx, y0 + Layout.FLOOR_TOP + 0.25, d) * VERT, Color = Color3.fromRGB(190, 190, 196), Material = M.SmoothPlastic })
		button:SetAttribute("Slot", slot)
		P(button, { Name = "Rim", Shape = CYL, Size = Vector3.new(0.3, 4.8, 4.8), CFrame = L(bx, y0 + Layout.FLOOR_TOP + 0.15, d) * VERT, Color = skin.accent, Material = M.Neon, Transparency = 0.3, CanCollide = false, CanTouch = false })
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 40
		cd.Parent = button
		local counter = Instance.new("BillboardGui")
		counter.Name = "Counter"
		counter.Size = UDim2.fromOffset(150, 40)
		counter.StudsOffset = Vector3.new(0, 2.6, 0)
		counter.MaxDistance = 55
		counter.LightInfluence = 0
		counter.Enabled = false
		label(counter, "Amount", { Text = "$0", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(120, 255, 120) })
		counter.Parent = button
	end

	-- Rebirth Altar (back middle of the ground floor) ----------------------------------------------------------------
	local altarCf = Layout.Altar(i, info.slots)
	P(base, { Name = "AltarGlow", Shape = CYL, Size = Vector3.new(0.1, 10, 10), CFrame = altarCf * CFrame.new(0, 0.05, 0) * VERT, Color = Color3.fromRGB(255, 220, 80), Material = M.SmoothPlastic, Transparency = 0.2, CanCollide = false })
	local altar = P(base, { Name = "Altar", Shape = CYL, Size = Vector3.new(1.6, 6, 6), CFrame = altarCf * CFrame.new(0, 0.8, 0) * VERT, Color = Color3.fromRGB(240, 240, 250), Material = M.SmoothPlastic })
	P(base, { Name = "AltarStep", Shape = CYL, Size = Vector3.new(0.6, 8, 8), CFrame = altarCf * CFrame.new(0, 0.3, 0) * VERT, Color = Color3.fromRGB(255, 200, 50), Material = M.SmoothPlastic })
	P(base, { Name = "AltarPillar", Shape = CYL, Size = Vector3.new(3, 2, 2), CFrame = altarCf * CFrame.new(0, 3.1, 0) * VERT, Color = Color3.fromRGB(240, 240, 250), Material = M.SmoothPlastic })
	local orb = P(base, { Name = "AltarOrb", Shape = BALL, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = altarCf * CFrame.new(0, 6, 0), Color = Color3.fromRGB(255, 210, 80), Material = M.Neon, CanCollide = false })
	local orbLight = Instance.new("PointLight")
	orbLight.Color = Color3.fromRGB(255, 220, 120)
	orbLight.Range = 12
	orbLight.Brightness = 1
	orbLight.Parent = orb
	P(base, { Name = "AltarRing", Shape = CYL, Size = Vector3.new(0.2, 4.4, 4.4), CFrame = altarCf * CFrame.new(0, 6, 0) * CFrame.Angles(0.5, 0, 0) * VERT, Color = Color3.fromRGB(255, 240, 180), Material = M.SmoothPlastic, CanCollide = false })
	prompt(altar, "Rebirth", "Rebirth Altar", { UI = "Rebirth", OwnerOnly = true })

	-- Skins stand (right of the altar): pick your base's colours and styles ----------------------------------------------
	local skinCf = L(Layout.SKINS_X, Layout.FLOOR_TOP, Layout.SKINS_DEPTH)
	P(base, { Name = "SkinMat", Shape = CYL, Size = Vector3.new(0.1, 8, 8), CFrame = skinCf * CFrame.new(0, 0.05, 0) * VERT, Color = Color3.fromRGB(190, 120, 255), Material = M.SmoothPlastic, Transparency = 0.2, CanCollide = false })
	local stand = P(base, { Name = "SkinStand", Size = Vector3.new(3.4, 3.2, 3.4), CFrame = skinCf * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(250, 248, 240), Material = M.SmoothPlastic })
	P(base, { Name = "SkinStandTop", Size = Vector3.new(3.8, 0.4, 3.8), CFrame = skinCf * CFrame.new(0, 3.4, 0), Color = Color3.fromRGB(150, 90, 255), Material = M.SmoothPlastic })
	-- a paint palette with blobs of colour, tilted towards the aisle
	local palette = skinCf * CFrame.new(0, 4.1, 0) * CFrame.Angles(0, 0, math.rad(-20))
	P(base, { Name = "Palette", Shape = CYL, Size = Vector3.new(0.25, 3.4, 3.4), CFrame = palette * VERT, Color = Color3.fromRGB(226, 176, 112), Material = M.SmoothPlastic, CanCollide = false })
	for n, c in { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 210, 40), Color3.fromRGB(60, 200, 90), Color3.fromRGB(60, 150, 255), Color3.fromRGB(200, 90, 255) } do
		local a = n / 5 * math.pi * 2
		P(base, { Name = "Paint", Shape = BALL, Size = Vector3.new(0.7, 0.35, 0.7), CFrame = palette * CFrame.new(math.cos(a) * 1.05, 0.2, math.sin(a) * 1.05), Color = c, Material = M.SmoothPlastic, CanCollide = false })
	end
	local skinSign = Instance.new("BillboardGui")
	skinSign.Name = "SkinGui"
	skinSign.Size = UDim2.fromScale(6, 1.4)
	skinSign.StudsOffset = Vector3.new(0, 4.6, 0)
	skinSign.MaxDistance = 45
	skinSign.LightInfluence = 0
	label(skinSign, "Text", { Text = "🎨 BASE SKINS", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(230, 200, 255) })
	skinSign.Parent = stand
	prompt(stand, "Base Skins", "Change your base's look", { UI = "Skins", OwnerOnly = true })

	-- Lock button (front right, ground floor) ------------------------------------------------------
	local lockAt = L(HW - 5, Layout.FLOOR_TOP, 6)
	local lockStand = P(base, { Name = "LockButton", Size = Vector3.new(2.4, 3, 2.4), CFrame = lockAt * CFrame.new(0, 1.5, 0), Color = skin.frame, Material = M.SmoothPlastic })
	P(base, { Name = "LockCap", Shape = CYL, Size = Vector3.new(0.6, 2, 2), CFrame = lockAt * CFrame.new(0, 3.2, 0) * VERT, Color = LASER_RED, Material = M.Neon })
	prompt(lockStand, "Lock Base", "Laser Wall", { Action = "Lock", OwnerOnly = true })

	-- Traps (just inside the laser wall) --------------------------------------------------------------------------------
	local traps = folder(base, "Traps")
	if info.items.Banana then
		local at = L(-4, Layout.FLOOR_TOP, 4)
		local m = Instance.new("Model")
		m.Name = "Banana"
		local yellow = Color3.fromRGB(255, 220, 60)
		P(m, { Name = "Peel", Size = Vector3.new(1.4, 0.3, 1.4), CFrame = at * CFrame.new(0, 0.15, 0), Color = yellow, Material = M.SmoothPlastic, CanCollide = false })
		for n = 0, 2 do
			P(m, { Name = "Flap", Size = Vector3.new(0.5, 0.15, 1.6), CFrame = at * CFrame.Angles(0, n * 2.1, 0) * CFrame.new(0, 0.1, 1) * CFrame.Angles(0.15, 0, 0), Color = yellow, Material = M.SmoothPlastic, CanCollide = false })
		end
		local hit = P(m, { Name = "Hit", Size = Vector3.new(3.5, 2, 3.5), CFrame = at * CFrame.new(0, 1, 0), Transparency = 1, CanCollide = false, CanQuery = false })
		hit:SetAttribute("Trap", "Banana")
		m.Parent = traps
	end
	if info.items.Honey then
		local at = L(4, Layout.FLOOR_TOP, 4)
		local m = Instance.new("Model")
		m.Name = "Honey"
		P(m, { Name = "Puddle", Shape = CYL, Size = Vector3.new(0.12, 5, 5), CFrame = at * CFrame.new(0, 0.06, 0) * VERT, Color = Color3.fromRGB(255, 170, 30), Material = M.Glass, Transparency = 0.15, CanCollide = false })
		local hit = P(m, { Name = "Hit", Size = Vector3.new(5, 2, 5), CFrame = at * CFrame.new(0, 1, 0), Transparency = 1, CanCollide = false, CanQuery = false })
		hit:SetAttribute("Trap", "Honey")
		m.Parent = traps
	end
	if info.items.Alarm then
		local m = Instance.new("Model")
		m.Name = "Alarm"
		local siren = P(m, { Name = "Siren", Shape = CYL, Size = Vector3.new(1.2, 1.4, 1.4), CFrame = L(HW - 3, LH + 1.6, -0.6) * VERT, Color = Color3.fromRGB(255, 40, 40), Material = M.Neon })
		local light = Instance.new("SpotLight")
		light.Name = "AlarmLight"
		light.Color = Color3.fromRGB(255, 40, 40)
		light.Range = 30
		light.Brightness = 0
		light.Angle = 70
		light.Face = Enum.NormalId.Top
		light.Parent = siren
		m.Parent = traps
	end

	-- Personal belt (Rebirth 6 perk), along the back wall on the right ---------------------------------------------
	if info.personalBelt then
		local pb = folder(base, "PersonalBelt")
		local a, b = Layout.PersonalBelt(i, info.slots)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 2
		local cf = CFrame.lookAt(mid, b)
		P(pb, { Name = "Frame", Size = Vector3.new(4, 1.2, len), CFrame = cf - Vector3.new(0, 0.8, 0), Color = Color3.fromRGB(62, 62, 84), Material = M.SmoothPlastic })
		P(pb, { Name = "Surface", Size = Vector3.new(3.4, 0.2, len), CFrame = cf - Vector3.new(0, 0.1, 0), Color = Color3.fromRGB(200, 40, 52), Material = M.SmoothPlastic })
		P(pb, { Name = "Spawner", Size = Vector3.new(3.6, 5, 3.6), CFrame = CFrame.new(a + (a - b).Unit * 2.2 + Vector3.new(0, 1, 0)), Color = skin.accent, Material = M.SmoothPlastic })
		P(pb, { Name = "SpawnerTop", Shape = CYL, Size = Vector3.new(0.4, 3, 3), CFrame = CFrame.new(a + (a - b).Unit * 2.2 + Vector3.new(0, 3.7, 0)) * VERT, Color = Color3.fromRGB(255, 255, 255), Material = M.Neon })
	end

	base.PrimaryPart = base:FindFirstChild("Floor") :: BasePart
	base.Parent = parent
	return base
end

-- Max slots this base layout supports (VIP adds one on top of the rebirth slots).
BaseBuilder.MAX_SLOTS = Economy.MAX_SLOTS + 1

return BaseBuilder
