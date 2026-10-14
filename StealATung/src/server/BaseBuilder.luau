--!strict
-- Builds one player base: a closed box building (walls, window bands, a roof)
-- whose only way in or out is the laser door at the front. Its colours depend
-- on the rebirth level (wood -> stone -> bamboo dojo -> crystal -> sky -> volcano
-- -> space station -> golden temple). Inside: glowing pads, round Collect
-- buttons, stairs, the Rebirth Altar, the lock button, owned traps and
-- (Rebirth 6+) the personal belt. The owner's name floats above the roof.
--
-- Rebuilt from scratch whenever the base grows or changes look. BaseService
-- relies only on these names: Pads/Pad<n>(/PlacePrompt), Buttons/Button<n>,
-- Headline/OwnerGui, DoorStatus/DoorGui, Altar, LockButton, Lasers,
-- Traps/<Banana|Honey|Alarm>, PersonalBelt.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Style = require(Shared.Style)

local BaseBuilder = {}

local M = Enum.Material
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local VERT = CFrame.Angles(0, 0, math.rad(90))

export type Theme = {
	floor: Color3,
	floorMat: Enum.Material,
	wall: Color3,
	wallMat: Enum.Material,
	post: Color3,
	postMat: Enum.Material,
	postRound: boolean?,
	cap: Color3,
	capMat: Enum.Material,
	pad: Color3,
	accent: Color3,
	wallTransparency: number?,
}

BaseBuilder.THEMES = {
	-- toy-plastic palettes, toned down so nothing glares; materials go through Style.Material
	Wood = { floor = Color3.fromRGB(214, 170, 118), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(196, 120, 62), wallMat = M.SmoothPlastic, post = Color3.fromRGB(150, 88, 44), postMat = M.SmoothPlastic, cap = Color3.fromRGB(232, 176, 70), capMat = M.SmoothPlastic, pad = Color3.fromRGB(226, 210, 176), accent = Color3.fromRGB(232, 176, 40) },
	Stone = { floor = Color3.fromRGB(168, 174, 192), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(140, 148, 172), wallMat = M.SmoothPlastic, post = Color3.fromRGB(100, 108, 138), postMat = M.SmoothPlastic, cap = Color3.fromRGB(70, 150, 230), capMat = M.SmoothPlastic, pad = Color3.fromRGB(205, 210, 226), accent = Color3.fromRGB(70, 150, 230) },
	Bamboo = { floor = Color3.fromRGB(214, 186, 136), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(100, 180, 70), wallMat = M.SmoothPlastic, post = Color3.fromRGB(60, 140, 52), postMat = M.SmoothPlastic, postRound = true, cap = Color3.fromRGB(210, 50, 56), capMat = M.SmoothPlastic, pad = Color3.fromRGB(230, 214, 184), accent = Color3.fromRGB(220, 60, 76) },
	Crystal = { floor = Color3.fromRGB(214, 186, 220), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(150, 210, 240), wallMat = M.Glass, post = Color3.fromRGB(220, 100, 200), postMat = M.SmoothPlastic, cap = Color3.fromRGB(100, 210, 235), capMat = M.SmoothPlastic, pad = Color3.fromRGB(232, 214, 236), accent = Color3.fromRGB(226, 100, 210), wallTransparency = 0.3 },
	Sky = { floor = Color3.fromRGB(206, 222, 240), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(110, 180, 236), wallMat = M.SmoothPlastic, post = Color3.fromRGB(236, 240, 248), postMat = M.SmoothPlastic, postRound = true, cap = Color3.fromRGB(240, 210, 80), capMat = M.SmoothPlastic, pad = Color3.fromRGB(226, 236, 248), accent = Color3.fromRGB(70, 170, 236) },
	Volcano = { floor = Color3.fromRGB(80, 44, 48), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(130, 40, 44), wallMat = M.SmoothPlastic, post = Color3.fromRGB(64, 30, 34), postMat = M.SmoothPlastic, cap = Color3.fromRGB(240, 110, 24), capMat = M.SmoothPlastic, pad = Color3.fromRGB(210, 160, 130), accent = Color3.fromRGB(240, 100, 24) },
	Space = { floor = Color3.fromRGB(44, 48, 90), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(86, 96, 156), wallMat = M.SmoothPlastic, post = Color3.fromRGB(56, 60, 112), postMat = M.SmoothPlastic, cap = Color3.fromRGB(56, 210, 236), capMat = M.SmoothPlastic, pad = Color3.fromRGB(176, 190, 236), accent = Color3.fromRGB(56, 210, 236) },
	Golden = { floor = Color3.fromRGB(232, 218, 182), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(232, 180, 40), wallMat = M.Foil, post = Color3.fromRGB(240, 236, 226), postMat = M.SmoothPlastic, cap = Color3.fromRGB(236, 190, 50), capMat = M.Foil, pad = Color3.fromRGB(236, 220, 180), accent = Color3.fromRGB(236, 186, 36) },
} :: { [string]: Theme }

export type BuildInfo = {
	index: number,
	slots: number,
	theme: string,
	golden: boolean, -- 100% Index: golden trims
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

function BaseBuilder.Build(parent: Instance, info: BuildInfo): Model
	local i = info.index
	local theme = BaseBuilder.THEMES[info.theme] or BaseBuilder.THEMES.Wood
	local floors = Layout.Floors(info.slots)
	local D = Layout.BASE_DEPTH
	local HW = Layout.BASE_WIDTH / 2
	local FH = Layout.FLOOR_HEIGHT
	local top = floors * FH
	local T = Layout.WALL_THICKNESS
	local gateHalf = Layout.GATE_WIDTH / 2
	local gold = Color3.fromRGB(255, 200, 50)
	local trim = if info.golden then gold else theme.cap
	local trimMat = if info.golden then M.Foil else theme.capMat

	local base = Instance.new("Model")
	base.Name = "Base" .. i
	base:SetAttribute("Index", i)
	base:SetAttribute("Floors", floors)

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
	P(base, { Name = "Floor", Size = Vector3.new(HW * 2, 0.8, D), CFrame = L(0, 0, D / 2), Color = theme.floor, Material = theme.floorMat })
	P(base, { Name = "FloorRim", Size = Vector3.new(HW * 2 + 1.2, 0.7, D + 1.2), CFrame = L(0, -0.08, D / 2), Color = theme.accent, Material = M.SmoothPlastic })
	local tile = 12
	for tx = -HW + tile / 2, HW - tile / 2, tile do
		for td = tile / 2, D - tile / 2, tile do
			if (math.floor((tx + HW) / tile) + math.floor(td / tile)) % 2 == 0 then
				P(base, { Name = "Tile", Size = Vector3.new(tile, 0.05, tile), CFrame = L(tx, Layout.FLOOR_TOP + 0.02, td), Color = theme.floor:Lerp(Color3.new(0, 0, 0), 0.07), Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
			end
		end
	end

	-- Upper floor slabs (with an opening above the stairs that lead up to them) -----------------
	-- Shell parts don't cast shadows, so daylight still reaches the inside of the box.
	local structure = folder(base, "Structure")
	for f = 2, floors do
		local y0 = Layout.FloorY(f)
		local s = Layout.StairSide(f - 1)
		local holeD = Layout.STAIR_BACK + 0.5
		local props = function(): Props
			return { Color = theme.floor, Material = theme.floorMat, CastShadow = false }
		end
		box(structure, "Slab", -HW + T, HW - T, y0 - 0.6, y0 + 0.4, holeD, D - T, props())
		-- front piece beside the opening
		box(structure, "Slab", -s * (HW - T), s * Layout.STAIR_INNER, y0 - 0.6, y0 + 0.4, T, holeD, props())
		-- low railing around the opening so nobody walks into it by accident
		box(structure, "HoleRail", s * Layout.STAIR_INNER, s * (HW - T), y0 + 0.4, y0 + 2.6, holeD - 0.15, holeD + 0.15, { Color = trim, Material = trimMat, CastShadow = false })
	end

	-- Stairs along the inside of the front wall, alternating sides floor by floor ---------------------
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
				Color = if k % 2 == 0 then theme.wall else theme.wall:Lerp(Color3.new(1, 1, 1), 0.15),
				Material = M.SmoothPlastic,
				CastShadow = false,
			})
		end
		-- handrail on the open side of the flight
		local a = L(s * Layout.STAIR_OUTER, y0 + Layout.FLOOR_TOP + 3, Layout.STAIR_BACK + 0.2).Position
		local b = L(s * Layout.STAIR_INNER, y0 + Layout.FLOOR_TOP + FH + 3, Layout.STAIR_BACK + 0.2).Position
		P(structure, { Name = "Handrail", Size = Vector3.new(0.4, 0.4, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = trim, Material = trimMat, CanCollide = false })
	end

	-- The box: walls with window bands on every floor, the door, the roof ---------------------------------------
	local shell = folder(base, "Shell")
	local WB, WT = Layout.WINDOW_BOTTOM, Layout.WINDOW_TOP
	local function wallProps(): Props
		return { Color = theme.wall, Material = theme.wallMat, Transparency = theme.wallTransparency or 0, CastShadow = false }
	end
	local function glassProps(): Props
		return { Color = Color3.fromRGB(176, 218, 240), Material = M.Glass, Transparency = 0.55, CastShadow = false }
	end
	-- One piece of a face. `u` runs along the face: depth on the side walls
	-- (0 .. D), x on the front and back walls (inside the side walls).
	local function facePiece(which: string, name: string, u1: number, u2: number, y1: number, y2: number, props: Props, glass: boolean?)
		if u2 - u1 < 0.05 or y2 - y1 < 0.05 then
			return
		end
		local a, b = 0, T -- from the outside surface inwards
		if glass then
			a, b = T * 0.3, T * 0.7
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
	-- the window band of one floor: glass in `windows`, wall everywhere else along u1 .. u2
	local function windowBand(which: string, y0: number, u1: number, u2: number, windows: { { number } })
		local u = u1
		for _, w in windows do
			facePiece(which, "Wall", u, w[1], y0 + WB, y0 + WT, wallProps())
			facePiece(which, "Window", w[1], w[2], y0 + WB, y0 + WT, glassProps(), true)
			u = w[2]
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
	local SIDE_WINDOWS = { { 5, 30 }, { 34, 59 } }
	local FRONT_WINDOWS = { { -18, 18 } }
	local IN = HW - T -- front / back walls sit between the side walls
	for _, which in { "L", "R" } do
		for f = 1, floors + 1 do
			facePiece(which, "Wall", 0, D, bandBottom(f), bandTop(f), wallProps())
		end
		for f = 1, floors do
			windowBand(which, Layout.FloorY(f), 0, D, SIDE_WINDOWS)
		end
	end
	-- front: the door on the ground floor, windows above it
	facePiece("F", "Wall", -IN, -gateHalf, 0, WT, wallProps())
	facePiece("F", "Wall", gateHalf, IN, 0, WT, wallProps())
	facePiece("F", "Wall", -gateHalf, gateHalf, Layout.GATE_HEIGHT, WT, wallProps())
	for f = 2, floors + 1 do
		facePiece("F", "Wall", -IN, IN, bandBottom(f), bandTop(f), wallProps())
	end
	for f = 2, floors do
		windowBand("F", Layout.FloorY(f), -IN, IN, FRONT_WINDOWS)
	end
	-- back: solid
	facePiece("B", "Wall", -IN, IN, 0, top, wallProps())

	-- roof with a little parapet
	box(shell, "Roof", -HW, HW, top - 0.6, top + 0.6, 0, D, { Color = theme.wall:Lerp(Color3.new(0, 0, 0), 0.18), Material = theme.wallMat, CastShadow = false })
	box(shell, "Parapet", -HW - 0.3, HW + 0.3, top + 0.6, top + 2.2, -0.3, 0.7, { Color = trim, Material = trimMat, CastShadow = false })
	box(shell, "Parapet", -HW - 0.3, HW + 0.3, top + 0.6, top + 2.2, D - 0.7, D + 0.3, { Color = trim, Material = trimMat, CastShadow = false })
	for _, sx in { -1, 1 } do
		box(shell, "Parapet", sx * (HW + 0.3), sx * (HW - 0.7), top + 0.6, top + 2.2, 0.7, D - 0.7, { Color = trim, Material = trimMat, CastShadow = false })
	end
	-- corner pillars and a trim belt at every floor line
	for _, sx in { -1, 1 } do
		for _, d in { 0, D } do
			if theme.postRound then
				P(shell, { Name = "Pillar", Shape = CYL, Size = Vector3.new(top + 0.6, 2, 2), CFrame = L(sx * HW, (top + 0.6) / 2, d) * VERT, Color = theme.post, Material = theme.postMat, CastShadow = false })
			else
				P(shell, { Name = "Pillar", Size = Vector3.new(1.8, top + 0.6, 1.8), CFrame = L(sx * HW, (top + 0.6) / 2, d), Color = theme.post, Material = theme.postMat, CastShadow = false })
			end
		end
	end
	for f = 2, floors do
		local y = Layout.FloorY(f)
		local props = function(): Props
			return { Color = trim, Material = trimMat, CastShadow = false, CanCollide = false }
		end
		box(shell, "Belt", -HW - 0.3, HW + 0.3, y - 0.5, y + 0.3, -0.3, 0.3, props())
		box(shell, "Belt", -HW - 0.3, HW + 0.3, y - 0.5, y + 0.3, D - 0.3, D + 0.3, props())
		for _, sx in { -1, 1 } do
			box(shell, "Belt", sx * (HW + 0.3), sx * (HW - 0.3), y - 0.5, y + 0.3, 0.3, D - 0.3, props())
		end
	end

	-- Theme extras (outside the building so they never block pads) ------------------------------------------
	local deco = folder(base, "Decor")
	local rng = Random.new(i * 31)
	local function aroundOutside(k: number): (number, number)
		-- a point on a ring just outside the footprint
		local t = (k / 12 + rng:NextNumber(-0.02, 0.02)) % 1
		local per = 2 * (HW * 2 + D)
		local u = t * per
		if u < HW * 2 then
			return -HW + u, -3.5
		elseif u < HW * 2 + D then
			return HW + 3.5, u - HW * 2
		elseif u < HW * 4 + D then
			return HW - (u - HW * 2 - D), D + 3.5
		end
		return -HW - 3.5, D - (u - HW * 4 - D)
	end
	if info.theme == "Wood" then
		for _, sx in { -1, 1 } do
			P(deco, { Name = "Barrel", Shape = CYL, Size = Vector3.new(3, 2.4, 2.4), CFrame = L(sx * (gateHalf + 4.5), 1.5, -2.5) * VERT, Color = Color3.fromRGB(190, 120, 60), Material = M.SmoothPlastic })
		end
	elseif info.theme == "Stone" then
		for x = -HW + 2, HW - 2, 4 do
			P(deco, { Name = "Merlon", Size = Vector3.new(1.8, 1.6, 1.2), CFrame = L(x, top + 3, 0.2), Color = theme.wall, Material = theme.wallMat })
		end
	elseif info.theme == "Bamboo" then
		for _, sx in { -1, 1 } do
			P(deco, { Name = "ToriiPost", Shape = CYL, Size = Vector3.new(14, 1.4, 1.4), CFrame = L(sx * 12, 7, -7) * VERT, Color = Color3.fromRGB(220, 50, 50), Material = M.SmoothPlastic })
		end
		P(deco, { Name = "ToriiTop", Size = Vector3.new(30, 1.2, 1.8), CFrame = L(0, 14.4, -7), Color = Color3.fromRGB(220, 50, 50), Material = M.SmoothPlastic })
		P(deco, { Name = "ToriiBeam", Size = Vector3.new(26, 0.8, 1.1), CFrame = L(0, 12.6, -7), Color = Color3.fromRGB(50, 35, 35), Material = M.SmoothPlastic })
	elseif info.theme == "Crystal" then
		for k = 1, 12 do
			local x, d = aroundOutside(k)
			P(deco, { Name = "Crystal", Size = Vector3.new(1.6, rng:NextNumber(4, 9), 1.6), CFrame = L(x, 3, d) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = if k % 3 == 0 then Color3.fromRGB(120, 230, 255) else Color3.fromRGB(255, 130, 230), Material = M.Glass, Transparency = 0.2, CanCollide = false })
		end
	elseif info.theme == "Sky" then
		for k = 1, 12 do
			local x, d = aroundOutside(k)
			P(deco, { Name = "Cloud", Shape = BALL, Size = Vector3.new(6, 4.5, 6), CFrame = L(x, 1.5, d), Color = Color3.new(1, 1, 1), Material = M.SmoothPlastic, CanCollide = false })
		end
		for k = 1, 3 do
			local at = L(rng:NextNumber(-HW, HW), top + 14 + k * 3, rng:NextNumber(10, D - 10))
			P(deco, { Name = "IslandRock", Shape = BALL, Size = Vector3.new(6, 5, 6), CFrame = at, Color = Color3.fromRGB(150, 120, 95), Material = M.SmoothPlastic, CanCollide = false })
			P(deco, { Name = "IslandGrass", Shape = CYL, Size = Vector3.new(1, 6.5, 6.5), CFrame = at * CFrame.new(0, 2, 0) * VERT, Color = Color3.fromRGB(110, 200, 80), Material = M.SmoothPlastic, CanCollide = false })
		end
	elseif info.theme == "Volcano" then
		for _, sx in { -1, 1 } do
			for _, d in { -3, D + 3 } do
				local bowl = P(deco, { Name = "Brazier", Shape = CYL, Size = Vector3.new(1.2, 3, 3), CFrame = L(sx * (HW + 3), 3.5, d) * VERT, Color = Color3.fromRGB(50, 30, 30), Material = M.SmoothPlastic })
				P(deco, { Name = "BrazierLeg", Size = Vector3.new(0.8, 3, 0.8), CFrame = L(sx * (HW + 3), 1.9, d), Color = Color3.fromRGB(50, 30, 30), Material = M.SmoothPlastic })
				local fire = Instance.new("Fire")
				fire.Color = Color3.fromRGB(255, 120, 20)
				fire.SecondaryColor = Color3.fromRGB(255, 40, 10)
				fire.Size = 5
				fire.Parent = bowl
			end
		end
	elseif info.theme == "Space" then
		for _, sx in { -1, 1 } do
			P(deco, { Name = "Antenna", Size = Vector3.new(0.5, 12, 0.5), CFrame = L(sx * (HW - 3), top + 6.6, D - 3), Color = Color3.fromRGB(190, 196, 210), Material = M.Metal })
			P(deco, { Name = "Dish", Shape = CYL, Size = Vector3.new(0.6, 5, 5), CFrame = L(sx * (HW - 3), top + 12.6, D - 3) * CFrame.Angles(0, 0, 0.6), Color = Color3.fromRGB(225, 228, 236), Material = M.Metal })
			P(deco, { Name = "Beacon", Shape = BALL, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = L(sx * (HW - 3), top + 13.4, D - 3), Color = Color3.fromRGB(255, 60, 60), Material = M.Neon, CanCollide = false })
		end
	elseif info.theme == "Golden" then
		for _, sx in { -1, 1 } do
			P(deco, { Name = "Column", Shape = CYL, Size = Vector3.new(12, 2.4, 2.4), CFrame = L(sx * (gateHalf + 5), 6, -3) * VERT, Color = Color3.fromRGB(250, 246, 236), Material = M.Marble })
			P(deco, { Name = "ColumnCap", Size = Vector3.new(3.2, 0.8, 3.2), CFrame = L(sx * (gateHalf + 5), 12.3, -3), Color = gold, Material = M.Foil })
		end
	end

	-- Door frame + lock / shield status above it -------------------------------------------------------------------
	for _, sx in { -1, 1 } do
		P(base, { Name = "GatePost", Size = Vector3.new(1.6, Layout.GATE_HEIGHT + 1, 1.8), CFrame = L(sx * (gateHalf + 0.8), (Layout.GATE_HEIGHT + 1) / 2, 0.2), Color = theme.post, Material = theme.postMat, CastShadow = false })
	end
	P(base, { Name = "GateBeam", Size = Vector3.new(Layout.GATE_WIDTH + 3.2, 1.2, 1.8), CFrame = L(0, Layout.GATE_HEIGHT + 0.6, 0.2), Color = trim, Material = trimMat, CastShadow = false })
	local doorAnchor = P(base, { Name = "DoorStatus", Size = Vector3.new(1, 1, 1), CFrame = L(0, Layout.GATE_HEIGHT + 3, -1.5), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local door = Instance.new("BillboardGui")
	door.Name = "DoorGui"
	door.Size = UDim2.fromScale(12, 2.2)
	door.MaxDistance = 110
	door.LightInfluence = 0
	door.Enabled = false
	label(door, "Status", { Text = "", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 225, 120) })
	door.Parent = doorAnchor

	-- Owner name floating above the roof (no sign on the building) ---------------------------------------------------------
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

	-- Pads (4 per side wall, per floor) + Collect buttons -------------------------------------------------------
	local pads = folder(base, "Pads")
	local buttons = folder(base, "Buttons")
	for slot = 1, info.slots do
		local x, y0, d, side = Layout.PadLocal(slot, info.slots)
		local pad = P(pads, { Name = "Pad" .. slot, Size = Vector3.new(8, 0.6, 8), CFrame = L(x, y0 + Layout.PAD_TOP - 0.3, d), Color = theme.pad, Material = M.SmoothPlastic })
		pad:SetAttribute("Slot", slot)
		-- shown to the owner only while they're holding one of their Tungs (see PromptUI)
		local place = prompt(pad, "Place Here", "Slot " .. slot, { Action = "Place", Slot = slot, OwnerOnly = true })
		place.Name = "PlacePrompt"
		place.MaxActivationDistance = 7
		CollectionService:AddTag(place, "OwnPrompt")
		P(pad, { Name = "Glow", Size = Vector3.new(8.8, 0.3, 8.8), CFrame = L(x, y0 + Layout.PAD_TOP - 0.5, d), Color = theme.accent, Material = M.SmoothPlastic, Transparency = 0.1, CanCollide = false })
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
		P(button, { Name = "Rim", Shape = CYL, Size = Vector3.new(0.3, 4.8, 4.8), CFrame = L(bx, y0 + Layout.FLOOR_TOP + 0.15, d) * VERT, Color = theme.accent, Material = M.Neon, Transparency = 0.3, CanCollide = false, CanTouch = false })
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
	P(base, { Name = "AltarStep", Shape = CYL, Size = Vector3.new(0.6, 8, 8), CFrame = altarCf * CFrame.new(0, 0.3, 0) * VERT, Color = trim, Material = trimMat })
	P(base, { Name = "AltarPillar", Shape = CYL, Size = Vector3.new(3, 2, 2), CFrame = altarCf * CFrame.new(0, 3.1, 0) * VERT, Color = Color3.fromRGB(240, 240, 250), Material = M.SmoothPlastic })
	local orb = P(base, { Name = "AltarOrb", Shape = BALL, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = altarCf * CFrame.new(0, 6, 0), Color = Color3.fromRGB(255, 210, 80), Material = M.Neon, CanCollide = false })
	local orbLight = Instance.new("PointLight")
	orbLight.Color = Color3.fromRGB(255, 220, 120)
	orbLight.Range = 12
	orbLight.Brightness = 1
	orbLight.Parent = orb
	P(base, { Name = "AltarRing", Shape = CYL, Size = Vector3.new(0.2, 4.4, 4.4), CFrame = altarCf * CFrame.new(0, 6, 0) * CFrame.Angles(0.5, 0, 0) * VERT, Color = Color3.fromRGB(255, 240, 180), Material = M.SmoothPlastic, CanCollide = false })
	prompt(altar, "Rebirth", "Rebirth Altar", { UI = "Rebirth", OwnerOnly = true })

	-- Lock button (front right, ground floor) + laser gate ------------------------------------------------------
	local lx = gateHalf + 6
	local lockStand = P(base, { Name = "LockButton", Size = Vector3.new(2.4, 3, 2.4), CFrame = L(lx, Layout.FLOOR_TOP + 1.5, 4), Color = theme.post, Material = theme.postMat })
	P(base, { Name = "LockCap", Shape = CYL, Size = Vector3.new(0.6, 2, 2), CFrame = L(lx, Layout.FLOOR_TOP + 3.2, 4) * VERT, Color = Color3.fromRGB(255, 50, 60), Material = M.Neon })
	prompt(lockStand, "Lock Base", "Laser Gate", { Action = "Lock", OwnerOnly = true })

	local lasers = folder(base, "Lasers")
	for k, y in { 1.5, 3.5, 5.5, 7.5, 9.5 } do
		P(lasers, { Name = "Beam" .. k, Size = Vector3.new(Layout.GATE_WIDTH + 3, 0.3, 0.3), CFrame = L(0, Layout.FLOOR_TOP + y, 0), Color = Color3.fromRGB(255, 40, 50), Material = M.Neon, Transparency = 1, CanCollide = false, CastShadow = false })
	end
	P(lasers, { Name = "Wall", Size = Vector3.new(Layout.GATE_WIDTH + 3, Layout.GATE_HEIGHT, 0.6), CFrame = L(0, Layout.GATE_HEIGHT / 2, 0), Transparency = 1, CanCollide = false, CanQuery = false })

	-- Traps (just inside the gate) --------------------------------------------------------------------------------
	local traps = folder(base, "Traps")
	if info.items.Banana then
		local at = L(-4, Layout.FLOOR_TOP, 3.5)
		local m = Instance.new("Model")
		m.Name = "Banana"
		local yellow = Color3.fromRGB(255, 220, 60)
		P(m, { Name = "Peel", Size = Vector3.new(1.4, 0.3, 1.4), CFrame = at * CFrame.new(0, 0.15, 0), Color = yellow, Material = M.SmoothPlastic, CanCollide = false })
		for k = 0, 2 do
			P(m, { Name = "Flap", Size = Vector3.new(0.5, 0.15, 1.6), CFrame = at * CFrame.Angles(0, k * 2.1, 0) * CFrame.new(0, 0.1, 1) * CFrame.Angles(0.15, 0, 0), Color = yellow, Material = M.SmoothPlastic, CanCollide = false })
		end
		local hit = P(m, { Name = "Hit", Size = Vector3.new(3.5, 2, 3.5), CFrame = at * CFrame.new(0, 1, 0), Transparency = 1, CanCollide = false, CanQuery = false })
		hit:SetAttribute("Trap", "Banana")
		m.Parent = traps
	end
	if info.items.Honey then
		local at = L(4, Layout.FLOOR_TOP, 3.5)
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
		local siren = P(m, { Name = "Siren", Shape = CYL, Size = Vector3.new(1.2, 1.4, 1.4), CFrame = L(gateHalf + 1.5, Layout.GATE_HEIGHT + 2 + Layout.FLOOR_TOP, 0) * VERT, Color = Color3.fromRGB(255, 40, 40), Material = M.Neon })
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

	-- Personal belt (Rebirth 6 perk), along the back wall right of the altar -----------------------------------
	if info.personalBelt then
		local pb = folder(base, "PersonalBelt")
		local a, b = Layout.PersonalBelt(i, info.slots)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 2
		local cf = CFrame.lookAt(mid, b)
		P(pb, { Name = "Frame", Size = Vector3.new(4, 1.2, len), CFrame = cf - Vector3.new(0, 0.8, 0), Color = Color3.fromRGB(62, 62, 84), Material = M.SmoothPlastic })
		P(pb, { Name = "Surface", Size = Vector3.new(3.4, 0.2, len), CFrame = cf - Vector3.new(0, 0.1, 0), Color = Color3.fromRGB(200, 40, 52), Material = M.SmoothPlastic })
		P(pb, { Name = "Spawner", Size = Vector3.new(3.6, 5, 3.6), CFrame = CFrame.new(a + (a - b).Unit * 2.2 + Vector3.new(0, 1, 0)), Color = theme.accent, Material = M.SmoothPlastic })
		P(pb, { Name = "SpawnerTop", Shape = CYL, Size = Vector3.new(0.4, 3, 3), CFrame = CFrame.new(a + (a - b).Unit * 2.2 + Vector3.new(0, 3.7, 0)) * VERT, Color = Color3.fromRGB(255, 255, 255), Material = M.Neon })
	end

	base.PrimaryPart = base:FindFirstChild("Floor") :: BasePart
	base.Parent = parent
	return base
end

-- Max slots this base layout supports (VIP adds one on top of the rebirth slots).
BaseBuilder.MAX_SLOTS = Economy.MAX_SLOTS + 1

return BaseBuilder
