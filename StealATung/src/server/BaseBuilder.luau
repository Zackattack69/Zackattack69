--!strict
-- Builds one player base: a fenced plot whose look depends on the rebirth
-- level (wooden fence -> stone -> bamboo dojo -> crystal garden -> sky island
-- -> volcano fortress -> space station -> golden temple), with glowing pads,
-- round Collect buttons, the gate sign, the Rebirth Altar, the lock button and
-- laser gate, owned traps and (Rebirth 6+) the personal belt.
--
-- Rebuilt from scratch whenever the base grows or changes look. BaseService
-- relies only on these names: Pads/Pad<n>, Buttons/Button<n>, Sign, Altar,
-- LockButton, Lasers, Traps/<Banana|Honey|Alarm>, PersonalBelt.

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
	wallHeight: number,
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
	Wood = { floor = Color3.fromRGB(214, 170, 118), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(196, 120, 62), wallMat = M.SmoothPlastic, wallHeight = 4, post = Color3.fromRGB(150, 88, 44), postMat = M.SmoothPlastic, cap = Color3.fromRGB(232, 176, 70), capMat = M.SmoothPlastic, pad = Color3.fromRGB(226, 210, 176), accent = Color3.fromRGB(232, 176, 40) },
	Stone = { floor = Color3.fromRGB(168, 174, 192), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(140, 148, 172), wallMat = M.SmoothPlastic, wallHeight = 5.5, post = Color3.fromRGB(100, 108, 138), postMat = M.SmoothPlastic, cap = Color3.fromRGB(70, 150, 230), capMat = M.SmoothPlastic, pad = Color3.fromRGB(205, 210, 226), accent = Color3.fromRGB(70, 150, 230) },
	Bamboo = { floor = Color3.fromRGB(214, 186, 136), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(100, 180, 70), wallMat = M.SmoothPlastic, wallHeight = 5, post = Color3.fromRGB(60, 140, 52), postMat = M.SmoothPlastic, postRound = true, cap = Color3.fromRGB(210, 50, 56), capMat = M.SmoothPlastic, pad = Color3.fromRGB(230, 214, 184), accent = Color3.fromRGB(220, 60, 76) },
	Crystal = { floor = Color3.fromRGB(214, 186, 220), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(150, 210, 240), wallMat = M.Glass, wallHeight = 5, post = Color3.fromRGB(220, 100, 200), postMat = M.SmoothPlastic, cap = Color3.fromRGB(100, 210, 235), capMat = M.SmoothPlastic, pad = Color3.fromRGB(232, 214, 236), accent = Color3.fromRGB(226, 100, 210), wallTransparency = 0.3 },
	Sky = { floor = Color3.fromRGB(206, 222, 240), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(110, 180, 236), wallMat = M.SmoothPlastic, wallHeight = 3, post = Color3.fromRGB(236, 240, 248), postMat = M.SmoothPlastic, postRound = true, cap = Color3.fromRGB(240, 210, 80), capMat = M.SmoothPlastic, pad = Color3.fromRGB(226, 236, 248), accent = Color3.fromRGB(70, 170, 236) },
	Volcano = { floor = Color3.fromRGB(80, 44, 48), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(130, 40, 44), wallMat = M.SmoothPlastic, wallHeight = 6, post = Color3.fromRGB(64, 30, 34), postMat = M.SmoothPlastic, cap = Color3.fromRGB(240, 110, 24), capMat = M.SmoothPlastic, pad = Color3.fromRGB(210, 160, 130), accent = Color3.fromRGB(240, 100, 24) },
	Space = { floor = Color3.fromRGB(44, 48, 90), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(86, 96, 156), wallMat = M.SmoothPlastic, wallHeight = 5, post = Color3.fromRGB(56, 60, 112), postMat = M.SmoothPlastic, cap = Color3.fromRGB(56, 210, 236), capMat = M.SmoothPlastic, pad = Color3.fromRGB(176, 190, 236), accent = Color3.fromRGB(56, 210, 236) },
	Golden = { floor = Color3.fromRGB(232, 218, 182), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(232, 180, 40), wallMat = M.Foil, wallHeight = 6, post = Color3.fromRGB(240, 236, 226), postMat = M.SmoothPlastic, cap = Color3.fromRGB(236, 190, 50), capMat = M.Foil, pad = Color3.fromRGB(236, 220, 180), accent = Color3.fromRGB(236, 186, 36) },
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
	local structure = folder(base, "Structure")
	for f = 2, floors do
		local y0 = Layout.FloorY(f)
		local s = Layout.StairSide(f - 1)
		local holeD = Layout.STAIR_BACK + 0.5
		local props = function(): Props
			return { Color = theme.floor, Material = theme.floorMat }
		end
		box(structure, "Slab", -HW, HW, y0 - 0.6, y0 + 0.4, holeD, D, props())
		-- front piece beside the opening
		box(structure, "Slab", -s * HW, s * Layout.STAIR_INNER, y0 - 0.6, y0 + 0.4, 0, holeD, props())
		-- coloured edge trim under the slab
		box(structure, "SlabTrim", -HW - 0.3, HW + 0.3, y0 - 1.2, y0 - 0.6, -0.3, 0.3, { Color = theme.accent, Material = M.SmoothPlastic })
		box(structure, "SlabTrim", -HW - 0.3, HW + 0.3, y0 - 1.2, y0 - 0.6, D - 0.3, D + 0.3, { Color = theme.accent, Material = M.SmoothPlastic })
		for _, sx in { -1, 1 } do
			box(structure, "SlabTrim", sx * HW - 0.3, sx * HW + 0.3, y0 - 1.2, y0 - 0.6, 0, D, { Color = theme.accent, Material = M.SmoothPlastic })
		end
	end

	-- Stairs along the front wall, alternating sides floor by floor -----------------------------------
	for f = 1, floors - 1 do
		local y0 = Layout.FloorY(f)
		local s = Layout.StairSide(f)
		for k = 1, 14 do
			local x = s * (Layout.STAIR_OUTER - (k - 0.5))
			P(structure, {
				Name = "Step",
				Size = Vector3.new(1, k, Layout.STAIR_BACK - Layout.STAIR_FRONT),
				CFrame = L(x, y0 + Layout.FLOOR_TOP + k / 2, (Layout.STAIR_FRONT + Layout.STAIR_BACK) / 2),
				Color = if k % 2 == 0 then theme.wall else theme.wall:Lerp(Color3.new(1, 1, 1), 0.15),
				Material = M.SmoothPlastic,
			})
		end
		-- handrail on the open side of the flight
		local a = L(s * Layout.STAIR_OUTER, y0 + Layout.FLOOR_TOP + 3, Layout.STAIR_BACK + 0.2).Position
		local b = L(s * Layout.STAIR_INNER, y0 + Layout.FLOOR_TOP + 17, Layout.STAIR_BACK + 0.2).Position
		P(structure, { Name = "Handrail", Size = Vector3.new(0.4, 0.4, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = trim, Material = trimMat, CanCollide = false })
	end

	-- Walls, railings, pillars ---------------------------------------------------------------------------------
	local fence = folder(base, "Fence")
	local h = theme.wallHeight
	local function wall(y0: number, height: number, x1: number, d1: number, x2: number, d2: number)
		local a = L(x1, 0, d1).Position
		local b = L(x2, 0, d2).Position
		local len = (b - a).Magnitude
		if len < 0.5 then
			return
		end
		local cf = CFrame.lookAt((a + b) / 2, b)
		P(fence, { Name = "Wall", Size = Vector3.new(0.8, height, len), CFrame = cf + Vector3.new(0, y0 + Layout.FLOOR_TOP + height / 2, 0), Color = theme.wall, Material = theme.wallMat, Transparency = theme.wallTransparency or 0 })
		P(fence, { Name = "Cap", Size = Vector3.new(1.2, 0.5, len + 1), CFrame = cf + Vector3.new(0, y0 + Layout.FLOOR_TOP + height + 0.25, 0), Color = trim, Material = trimMat })
	end
	local W2 = HW - 0.4
	-- ground floor walls (gap for the gate)
	wall(0, h, -W2, 0.4, -gateHalf - 1.5, 0.4)
	wall(0, h, gateHalf + 1.5, 0.4, W2, 0.4)
	wall(0, h, -W2, 0.4, -W2, D - 0.4)
	wall(0, h, W2, 0.4, W2, D - 0.4)
	wall(0, h, -W2, D - 0.4, W2, D - 0.4)
	-- railings around every upper floor
	for f = 2, floors do
		local y0 = Layout.FloorY(f)
		wall(y0, 3.2, -W2, 0.4, W2, 0.4)
		wall(y0, 3.2, -W2, 0.4, -W2, D - 0.4)
		wall(y0, 3.2, W2, 0.4, W2, D - 0.4)
		wall(y0, 3.2, -W2, D - 0.4, W2, D - 0.4)
	end
	-- pillars at the corners and halfway along the sides
	local pillarTop = if floors > 1 then top + 3.6 else h + 1.2
	for _, sx in { -1, 1 } do
		for _, d in { 0.7, D / 2, D - 0.7 } do
			if theme.postRound then
				P(fence, { Name = "Pillar", Shape = CYL, Size = Vector3.new(pillarTop, 1.6, 1.6), CFrame = L(sx * (HW - 0.7), Layout.FLOOR_TOP + pillarTop / 2, d) * VERT, Color = theme.post, Material = theme.postMat })
			else
				P(fence, { Name = "Pillar", Size = Vector3.new(1.6, pillarTop, 1.6), CFrame = L(sx * (HW - 0.7), Layout.FLOOR_TOP + pillarTop / 2, d), Color = theme.post, Material = theme.postMat })
			end
		end
	end
	-- invisible colliders: the gate is the only way in, and nobody jumps off the upper floors
	local colliderTop = top + 8
	local function collider(x1: number, x2: number, y1: number, y2: number, d1: number, d2: number)
		box(fence, "Collider", x1, x2, y1, y2, d1, d2, { Transparency = 1, CanQuery = false })
	end
	collider(-HW - 0.5, -HW + 0.5, 0, colliderTop, 0, D)
	collider(HW - 0.5, HW + 0.5, 0, colliderTop, 0, D)
	collider(-HW, HW, 0, colliderTop, D - 0.5, D + 0.5)
	collider(-HW, -gateHalf - 1.5, 0, colliderTop, -0.5, 0.5)
	collider(gateHalf + 1.5, HW, 0, colliderTop, -0.5, 0.5)
	collider(-gateHalf - 1.5, gateHalf + 1.5, Layout.GATE_HEIGHT, colliderTop, -0.5, 0.5)

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
			P(deco, { Name = "Merlon", Size = Vector3.new(1.8, 1.6, 1.2), CFrame = L(x, (if floors > 1 then top + 3.6 else h) + 1.3, D - 0.4), Color = theme.wall, Material = theme.wallMat })
		end
	elseif info.theme == "Bamboo" then
		for _, sx in { -1, 1 } do
			P(deco, { Name = "ToriiPost", Shape = CYL, Size = Vector3.new(11, 1.4, 1.4), CFrame = L(sx * 12, 5.5, -7) * VERT, Color = Color3.fromRGB(220, 50, 50), Material = M.SmoothPlastic })
		end
		P(deco, { Name = "ToriiTop", Size = Vector3.new(30, 1.2, 1.8), CFrame = L(0, 11.4, -7), Color = Color3.fromRGB(220, 50, 50), Material = M.SmoothPlastic })
		P(deco, { Name = "ToriiBeam", Size = Vector3.new(26, 0.8, 1.1), CFrame = L(0, 9.6, -7), Color = Color3.fromRGB(50, 35, 35), Material = M.SmoothPlastic })
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
			local at = L(rng:NextNumber(-HW, HW), top + 10 + k * 3, rng:NextNumber(10, D - 10))
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
			P(deco, { Name = "Antenna", Size = Vector3.new(0.5, 12, 0.5), CFrame = L(sx * (HW - 2), top + 6, D - 2), Color = Color3.fromRGB(190, 196, 210), Material = M.Metal })
			P(deco, { Name = "Dish", Shape = CYL, Size = Vector3.new(0.6, 5, 5), CFrame = L(sx * (HW - 2), top + 12, D - 2) * CFrame.Angles(0, 0, 0.6), Color = Color3.fromRGB(225, 228, 236), Material = M.Metal })
			P(deco, { Name = "Beacon", Shape = BALL, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = L(sx * (HW - 2), top + 12.8, D - 2), Color = Color3.fromRGB(255, 60, 60), Material = M.Neon, CanCollide = false })
		end
	elseif info.theme == "Golden" then
		for _, sx in { -1, 1 } do
			P(deco, { Name = "Column", Shape = CYL, Size = Vector3.new(12, 2.4, 2.4), CFrame = L(sx * (gateHalf + 5), 6, -3) * VERT, Color = Color3.fromRGB(250, 246, 236), Material = M.Marble })
			P(deco, { Name = "ColumnCap", Size = Vector3.new(3.2, 0.8, 3.2), CFrame = L(sx * (gateHalf + 5), 12.3, -3), Color = gold, Material = M.Foil })
		end
	end

	-- Gate + owner sign -----------------------------------------------------------------------------------------
	for _, sx in { -1, 1 } do
		P(base, { Name = "GatePost", Size = Vector3.new(1.8, Layout.GATE_HEIGHT + 1, 1.8), CFrame = L(sx * (gateHalf + 1.5), (Layout.GATE_HEIGHT + 1) / 2 + Layout.FLOOR_TOP, 0), Color = theme.post, Material = theme.postMat })
	end
	P(base, { Name = "GateBeam", Size = Vector3.new(Layout.GATE_WIDTH + 5, 1.2, 1.8), CFrame = L(0, Layout.GATE_HEIGHT + 0.6, 0), Color = trim, Material = trimMat })
	local signY = Layout.GATE_HEIGHT + 4.4
	local sign = P(base, { Name = "Sign", Size = Vector3.new(18, 6, 0.6), CFrame = L(0, signY, -1.4) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(40, 36, 70), Material = M.SmoothPlastic })
	P(base, { Name = "SignFrame", Size = Vector3.new(18.8, 6.8, 0.4), CFrame = L(0, signY, -1.05) * CFrame.Angles(0, math.pi, 0), Color = theme.accent, Material = M.SmoothPlastic })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "SignGui"
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 28
	sg.LightInfluence = 0
	sg.Parent = sign
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.fromScale(0.3, 0.9)
	avatar.Position = UDim2.fromScale(0.02, 0.05)
	avatar.BackgroundColor3 = Color3.fromRGB(255, 240, 210)
	avatar.Image = ""
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0.2, 0)
	ac.Parent = avatar
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = avatar
	avatar.Parent = sg
	label(sg, "OwnerName", { Text = "Empty Base", Size = UDim2.fromScale(0.64, 0.5), Position = UDim2.fromScale(0.34, 0.05), TextXAlignment = Enum.TextXAlignment.Left })
	label(sg, "Status", { Text = "", Size = UDim2.fromScale(0.64, 0.34), Position = UDim2.fromScale(0.34, 0.6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 225, 120) })

	-- Pads (4 per side wall, per floor) + Collect buttons -------------------------------------------------------
	local pads = folder(base, "Pads")
	local buttons = folder(base, "Buttons")
	for slot = 1, info.slots do
		local x, y0, d, side = Layout.PadLocal(slot, info.slots)
		local pad = P(pads, { Name = "Pad" .. slot, Size = Vector3.new(8, 0.6, 8), CFrame = L(x, y0 + Layout.PAD_TOP - 0.3, d), Color = theme.pad, Material = M.SmoothPlastic })
		pad:SetAttribute("Slot", slot)
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
