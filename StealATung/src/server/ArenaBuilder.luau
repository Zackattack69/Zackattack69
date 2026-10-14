--!strict
-- Builds the shared arena at server start in a bright, toy-like Roblox style:
-- a striped plastic lawn, fluffy hedge walls with a white picket fence top,
-- lollipop trees, flowers and glowing lanterns, the big red conveyor belt with
-- its candy-red drum machine and hazard-striped hole, the leaderboard pillar,
-- and the shop and sell stands. (The 8 bases are built by BaseBuilder.)
--
-- Gameplay only relies on these names, so any prop can be swapped for real art:
--   Arena.Belt.Surface, Arena.Belt.Drum (Model), Arena.Pillar.Block.Board*,
--   Arena.ShopStand / SellStand (ProximityPrompt with attribute "UI").
-- Client-animated tags: "Bulb" (blinking neon), "Spin" (rotating), "Bob" (floating icon).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Style = require(Shared.Style)
local TungModel = require(Shared.TungModel)

local ArenaBuilder = {}

local M = Enum.Material
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local VERT = CFrame.Angles(0, 0, math.rad(90))
local S = Style.Colors

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

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Chunky cartoon sign text: white -> yellow gradient with a thick dark outline.
local function signLabel(parent: Instance, text: string, top: Color3?, bottom: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top or Color3.fromRGB(255, 255, 255), bottom or Color3.fromRGB(255, 220, 60))
	g.Rotation = 90
	g.Parent = l
	local s = Instance.new("UIStroke")
	s.Thickness = 6
	s.Color = S.Black
	s.Parent = l
	l.Parent = parent
	return l
end

local function prompt(parent: Instance, action: string, object: string, ui: string)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Style = Enum.ProximityPromptStyle.Custom
	pr:SetAttribute("UI", ui)
	pr.Parent = parent
	return pr
end

local function tag(inst: Instance, name: string): Instance
	CollectionService:AddTag(inst, name)
	return inst
end

-- Lighting / sky: bright, saturated and cheerful ---------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.GeographicLatitude = 20
	Lighting.Ambient = Color3.fromRGB(150, 150, 170)
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 205)
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	pcall(function()
		(Lighting :: any).ShadowSoftness = 0.35
	end)
	for _, c in Lighting:GetChildren() do
		if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.StarCount = 4000
	sky.SunAngularSize = 22
	sky.MoonAngularSize = 14
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.12
	atmo.Offset = 0
	atmo.Color = Color3.fromRGB(170, 215, 255)
	atmo.Decay = Color3.fromRGB(100, 170, 255)
	atmo.Glare = 0
	atmo.Haze = 0
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 22
	bloom.Threshold = 1.15
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Saturation = 0.32
	cc.Contrast = 0.1
	cc.Brightness = 0.03
	cc.Parent = Lighting

	-- a gentle wind for flags and particles
	Workspace.GlobalWind = Vector3.new(6, 0, 3)
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds:Destroy() -- cartoon part clouds are drawn by the client instead
	end
end

-- Ground: striped plastic lawn, paths to every gate, a plaza under the pillar ------------------------
local function buildGround(arena: Instance)
	local g = folder(arena, "Ground")
	local hx, hz = Layout.ARENA_HALF_X, Layout.ARENA_HALF_Z
	P(g, { Name = "OuterLawn", Size = Vector3.new(1100, 4, 1100), CFrame = CFrame.new(0, -2, 0), Color = S.GrassOuter, Material = M.SmoothPlastic })
	-- mowed-lawn stripes inside the walls
	local width = 16
	local n = math.ceil(hx * 2 / width)
	for k = 0, n - 1 do
		local x = -hx + width / 2 + k * width
		P(g, { Name = "Lawn", Size = Vector3.new(width, 0.2, hz * 2 + 4), CFrame = CFrame.new(x, -0.05, 0), Color = if k % 2 == 0 then S.Grass else S.Grass2, Material = M.SmoothPlastic })
	end
	-- paths from the belt to each gate
	for i = 1, Layout.BASE_COUNT do
		local gate = Layout.BaseCFrame(i).Position
		local side = if gate.X < 0 then -1 else 1
		local len = Layout.CORRIDOR_HALF - 6
		P(g, { Name = "Path", Size = Vector3.new(len, 0.2, 14), CFrame = CFrame.new(side * (6 + len / 2), 0.02, gate.Z), Color = S.Path, Material = M.SmoothPlastic })
		for k = 0, 3 do
			P(g, { Name = "PathDot", Shape = CYL, Size = Vector3.new(0.22, 2.4, 2.4), CFrame = CFrame.new(side * (9 + k * 5), 0.04, gate.Z) * VERT, Color = Color3.fromRGB(255, 196, 110), Material = M.SmoothPlastic })
		end
	end
	-- round plaza under the pillar
	P(g, { Name = "Plaza", Shape = CYL, Size = Vector3.new(0.2, 46, 46), CFrame = CFrame.new(0, 0.02, 0) * VERT, Color = S.Path, Material = M.SmoothPlastic })
	P(g, { Name = "PlazaRing", Shape = CYL, Size = Vector3.new(0.21, 50, 50), CFrame = CFrame.new(0, 0.01, 0) * VERT, Color = Color3.fromRGB(255, 150, 70), Material = M.SmoothPlastic })
	-- big cartoon hills outside the walls so the horizon isn't empty
	local rng = Random.new(42)
	local hillColors = { Color3.fromRGB(90, 200, 70), Color3.fromRGB(70, 180, 80), Color3.fromRGB(120, 220, 90) }
	for _ = 1, 24 do
		local side = rng:NextInteger(1, 4)
		local x, z
		if side <= 2 then
			x = (if side == 1 then -1 else 1) * rng:NextNumber(hx + 60, hx + 160)
			z = rng:NextNumber(-hz - 100, hz + 100)
		else
			z = (if side == 3 then -1 else 1) * rng:NextNumber(hz + 60, hz + 160)
			x = rng:NextNumber(-hx - 100, hx + 100)
		end
		local r = rng:NextNumber(60, 120)
		P(g, { Name = "Hill", Shape = BALL, Size = Vector3.new(r, r, r), CFrame = CFrame.new(x, -r * 0.28, z), Color = hillColors[rng:NextInteger(1, #hillColors)], Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
	end
end

-- Walls & decoration --------------------------------------------------------------------------------------
local LEAF_COLORS = { Color3.fromRGB(80, 200, 70), Color3.fromRGB(110, 225, 80), Color3.fromRGB(60, 180, 90), Color3.fromRGB(255, 150, 200) }

local function buildTree(parent: Instance, at: Vector3, rng: Random)
	local m = model(parent, "Tree")
	local h = rng:NextNumber(8, 13)
	P(m, { Name = "Trunk", Shape = CYL, Size = Vector3.new(h, 2.2, 2.2), CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)) * VERT, Color = S.Trunk, Material = M.SmoothPlastic })
	local leaf = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local s = rng:NextNumber(10, 14)
	P(m, { Name = "Leaves", Shape = BALL, Size = Vector3.new(s, s, s), CFrame = CFrame.new(at + Vector3.new(0, h + s * 0.35, 0)), Color = leaf, Material = M.SmoothPlastic, CanCollide = false })
	P(m, { Name = "Leaves2", Shape = BALL, Size = Vector3.new(s * 0.7, s * 0.7, s * 0.7), CFrame = CFrame.new(at + Vector3.new(s * 0.35, h + s * 0.15, s * 0.2)), Color = leaf:Lerp(Color3.new(1, 1, 1), 0.12), Material = M.SmoothPlastic, CanCollide = false })
	if rng:NextNumber() < 0.4 then
		for k = 1, 4 do
			local a = k * 1.6
			P(m, { Name = "Fruit", Shape = BALL, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * s * 0.48, h + s * 0.3, math.sin(a) * s * 0.48)), Color = Color3.fromRGB(255, 70, 80), Material = M.SmoothPlastic, CanCollide = false })
		end
	end
end

local FLOWER_COLORS = { Color3.fromRGB(255, 80, 130), Color3.fromRGB(255, 220, 50), Color3.fromRGB(160, 110, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 140, 50), Color3.fromRGB(80, 200, 255) }

local function buildFlowers(parent: Instance, at: Vector3, rng: Random)
	for _ = 1, 5 do
		local off = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		local c = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
		P(parent, { Name = "Stem", Size = Vector3.new(0.2, 1.4, 0.2), CFrame = CFrame.new(at + off + Vector3.new(0, 0.7, 0)), Color = Color3.fromRGB(60, 170, 60), Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
		for k = 0, 3 do
			local a = k * math.pi / 2
			P(parent, { Name = "Petal", Shape = BALL, Size = Vector3.new(0.6, 0.35, 0.6), CFrame = CFrame.new(at + off + Vector3.new(math.cos(a) * 0.35, 1.5, math.sin(a) * 0.35)), Color = c, Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
		end
		P(parent, { Name = "Middle", Shape = BALL, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = CFrame.new(at + off + Vector3.new(0, 1.6, 0)), Color = Color3.fromRGB(255, 220, 60), Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
	end
end

local function buildLantern(parent: Instance, at: Vector3)
	local m = model(parent, "Lantern")
	P(m, { Name = "Post", Shape = CYL, Size = Vector3.new(7, 0.8, 0.8), CFrame = CFrame.new(at + Vector3.new(0, 3.5, 0)) * VERT, Color = Color3.fromRGB(60, 60, 90), Material = M.SmoothPlastic })
	P(m, { Name = "Cap", Size = Vector3.new(1.8, 0.4, 1.8), CFrame = CFrame.new(at + Vector3.new(0, 7.9, 0)), Color = Color3.fromRGB(60, 60, 90), Material = M.SmoothPlastic })
	local lamp = P(m, { Name = "Lamp", Shape = BALL, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(at + Vector3.new(0, 7.1, 0)), Color = Color3.fromRGB(255, 220, 110), Material = M.Neon, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 200, 120)
	l.Range = 18
	l.Brightness = 1.6
	l.Enabled = false
	l.Parent = lamp
	tag(lamp, "Lantern")
end

local function buildWalls(arena: Instance)
	local walls = folder(arena, "Walls")
	local hx, hz = Layout.ARENA_HALF_X, Layout.ARENA_HALF_Z
	local sides: { { cf: CFrame, len: number } } = {
		{ cf = CFrame.new(0, 0, -hz - 2), len = hx * 2 + 8 },
		{ cf = CFrame.new(0, 0, hz + 2), len = hx * 2 + 8 },
		{ cf = CFrame.new(-hx - 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), len = hz * 2 + 8 },
		{ cf = CFrame.new(hx + 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), len = hz * 2 + 8 },
	}
	for _, s in sides do
		local cf, len = s.cf, s.len
		P(walls, { Name = "Hedge", Size = Vector3.new(len, 5.5, 4.4), CFrame = cf * CFrame.new(0, 2.75, 0), Color = S.Hedge, Material = M.SmoothPlastic })
		-- fluffy bush tops
		for x = -len / 2 + 2.5, len / 2 - 2.5, 5 do
			P(walls, { Name = "Bush", Shape = BALL, Size = Vector3.new(5.6, 5, 5.6), CFrame = cf * CFrame.new(x, 5.4, 0), Color = if math.floor(x / 5) % 2 == 0 then S.Hedge else S.HedgeLight, Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
		end
		-- white picket fence on top
		P(walls, { Name = "Rail", Size = Vector3.new(len, 0.5, 0.5), CFrame = cf * CFrame.new(0, 9.6, 0), Color = S.Fence, Material = M.SmoothPlastic })
		P(walls, { Name = "Rail", Size = Vector3.new(len, 0.5, 0.5), CFrame = cf * CFrame.new(0, 8.4, 0), Color = S.Fence, Material = M.SmoothPlastic })
		for x = -len / 2 + 2, len / 2 - 2, 6 do
			P(walls, { Name = "Picket", Size = Vector3.new(0.9, 3.8, 0.6), CFrame = cf * CFrame.new(x, 9.2, 0), Color = S.Fence, Material = M.SmoothPlastic })
			P(walls, { Name = "PicketTip", Size = Vector3.new(0.64, 0.64, 0.6), CFrame = cf * CFrame.new(x, 11.1, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = S.Fence, Material = M.SmoothPlastic })
		end
		-- invisible wall so nobody can leave the arena
		P(walls, { Name = "Barrier", Size = Vector3.new(len, 80, 2), CFrame = cf * CFrame.new(0, 40, 0), Transparency = 1, CanQuery = false })
	end

	local deco = folder(arena, "Decor")
	local rng = Random.new(7)
	for z = -hz - 8, hz + 8, 26 do
		buildTree(deco, Vector3.new(-hx - 14 - rng:NextNumber(0, 10), 0, z + rng:NextNumber(-5, 5)), rng)
		buildTree(deco, Vector3.new(hx + 14 + rng:NextNumber(0, 10), 0, z + rng:NextNumber(-5, 5)), rng)
	end
	for x = -hx, hx, 26 do
		buildTree(deco, Vector3.new(x + rng:NextNumber(-5, 5), 0, -hz - 14 - rng:NextNumber(0, 10)), rng)
		buildTree(deco, Vector3.new(x + rng:NextNumber(-5, 5), 0, hz + 14 + rng:NextNumber(0, 10)), rng)
	end
	for x = -hx + 10, hx - 10, 16 do
		if math.abs(x) > 14 then
			buildFlowers(deco, Vector3.new(x, 0, -hz + 3), rng)
			buildFlowers(deco, Vector3.new(x, 0, hz - 3), rng)
		end
	end
	for _, z in { -168, -84, 84, 168 } do
		buildLantern(deco, Vector3.new(-25, 0, z))
		buildLantern(deco, Vector3.new(25, 0, z))
	end
	for _, z in { -168, 168 } do
		for _, x in { -60, -100, 60, 100 } do
			buildLantern(deco, Vector3.new(x, 0, z))
		end
	end
	for _, z in { -150, -110, -60, -20, 20, 60, 110, 150 } do
		buildFlowers(deco, Vector3.new(-12, 0, z), rng)
		buildFlowers(deco, Vector3.new(12, 0, z), rng)
	end
end

-- The big red conveyor belt ---------------------------------------------------------------------------------
local function buildBelt(arena: Instance)
	local belt = folder(arena, "Belt")
	local a, b = Layout.BELT_START, Layout.BELT_END
	local len = (b - a).Magnitude + 8
	local mid = (a + b) / 2
	local top = Layout.BELT_Y
	local w = Layout.BELT_WIDTH
	P(belt, { Name = "Frame", Size = Vector3.new(w + 2, top - 0.4, len), CFrame = CFrame.new(mid.X, (top - 0.4) / 2, mid.Z), Color = S.Frame, Material = M.SmoothPlastic })
	local surface = P(belt, { Name = "Surface", Size = Vector3.new(w, 0.4, len), CFrame = CFrame.new(mid.X, top - 0.2, mid.Z), Color = S.Belt, Material = M.SmoothPlastic })
	-- an anchored part with velocity carries anything standing on it, like a real conveyor
	surface.AssemblyLinearVelocity = (b - a).Unit * ((b - a).Magnitude / Economy.BELT_TRAVEL)
	for _, sx in { -1, 1 } do
		P(belt, { Name = "Rail", Size = Vector3.new(0.7, 0.9, len), CFrame = CFrame.new(sx * (w / 2 + 0.55), top + 0.25, mid.Z), Color = S.Yellow, Material = M.Neon })
		P(belt, { Name = "RailBase", Size = Vector3.new(1, 0.4, len), CFrame = CFrame.new(sx * (w / 2 + 0.55), top - 0.2, mid.Z), Color = S.Frame, Material = M.SmoothPlastic })
	end
	for z = a.Z - 2, b.Z + 2, 12 do
		for _, sx in { -1, 1 } do
			P(belt, { Name = "Leg", Size = Vector3.new(0.9, top, 0.9), CFrame = CFrame.new(sx * (w / 2 + 1.2), top / 2, z), Color = Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic, CanCollide = false })
		end
	end

	-- The candy-red drum machine Tungs pop out of
	local drum = model(belt, "Drum")
	local d = Layout.DRUM_POS
	P(drum, { Name = "Shell", Shape = CYL, Size = Vector3.new(14, 20, 20), CFrame = CFrame.new(d) * VERT, Color = Color3.fromRGB(235, 45, 60), Material = M.SmoothPlastic })
	P(drum, { Name = "Head", Shape = CYL, Size = Vector3.new(0.4, 20.4, 20.4), CFrame = CFrame.new(d + Vector3.new(0, 7.1, 0)) * VERT, Color = Color3.fromRGB(255, 250, 240), Material = M.SmoothPlastic })
	for _, y in { -6.6, 6.6 } do
		P(drum, { Name = "Hoop", Shape = CYL, Size = Vector3.new(1.2, 21, 21), CFrame = CFrame.new(d + Vector3.new(0, y, 0)) * VERT, Color = S.Gold, Material = M.Foil })
	end
	for i = 0, 11 do
		local ang = i / 12 * math.pi * 2
		local r = 10.3
		P(drum, { Name = "Rope", Size = Vector3.new(0.45, 13.5, 0.45), CFrame = CFrame.new(d + Vector3.new(math.sin(ang) * r, 0, math.cos(ang) * r)) * CFrame.Angles(0, ang, if i % 2 == 0 then 0.35 else -0.35), Color = Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
	end
	-- chasing bulbs around the top hoop
	for i = 0, 15 do
		local ang = i / 16 * math.pi * 2
		local bulb = P(drum, { Name = "Bulb", Shape = BALL, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(d + Vector3.new(math.sin(ang) * 10.8, 7.4, math.cos(ang) * 10.8)), Color = S.Yellow, Material = M.Neon, CanCollide = false })
		bulb:SetAttribute("Index", i)
		tag(bulb, "Bulb")
	end
	for _, sx in { -1, 1 } do
		P(drum, { Name = "Stick", Shape = CYL, Size = Vector3.new(12, 0.9, 0.9), CFrame = CFrame.new(d + Vector3.new(sx * 2.5, 10.5, 1)) * CFrame.Angles(0, 0, sx * 0.9), Color = Color3.fromRGB(255, 220, 160), Material = M.SmoothPlastic })
		P(drum, { Name = "StickTip", Shape = BALL, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(d + Vector3.new(sx * -1.3, 13.4, 1)), Color = Color3.fromRGB(255, 120, 160), Material = M.SmoothPlastic })
	end
	P(drum, { Name = "Mouth", Size = Vector3.new(w + 1, 6, 2), CFrame = CFrame.new(0, top + 3, d.Z + 9.4), Color = Color3.fromRGB(20, 12, 30), Material = M.SmoothPlastic, CanCollide = false })
	P(drum, { Name = "MouthTrim", Size = Vector3.new(w + 3, 0.8, 2.2), CFrame = CFrame.new(0, top + 6.4, d.Z + 9.4), Color = S.Yellow, Material = M.Neon, CanCollide = false })
	local signPart = P(drum, { Name = "Sign", Size = Vector3.new(22, 5, 0.6), CFrame = CFrame.new(0, 19, d.Z + 4) * CFrame.Angles(0, math.pi, 0), Color = S.Purple, Material = M.SmoothPlastic, CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = signPart
	signLabel(sg, "🥁 TUNG MACHINE 🥁")
	drum.PrimaryPart = drum:FindFirstChild("Shell") :: BasePart

	-- The hole at the end: hazard-striped rim and a purple swirl
	local h = Layout.HOLE_POS
	for i = 0, 15 do
		local ang = i / 16 * math.pi * 2
		P(belt, { Name = "HoleRim", Size = Vector3.new(3.2, top, 2.4), CFrame = CFrame.new(h + Vector3.new(math.sin(ang) * 6.8, top / 2, math.cos(ang) * 6.8)) * CFrame.Angles(0, ang, 0), Color = if i % 2 == 0 then S.Yellow else S.Black, Material = M.SmoothPlastic })
	end
	local void = P(belt, { Name = "Void", Shape = CYL, Size = Vector3.new(0.2, 12.5, 12.5), CFrame = CFrame.new(h + Vector3.new(0, top - 0.1, 0)) * VERT, Color = Color3.fromRGB(30, 10, 50), Material = M.Neon, CanCollide = false })
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Rate = 14
	swirl.Lifetime = NumberRange.new(1, 1.6)
	swirl.Speed = NumberRange.new(1, 2)
	swirl.Size = NumberSequence.new(1.2, 0)
	swirl.LightEmission = 1
	swirl.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(90, 200, 255))
	swirl.RotSpeed = NumberRange.new(90, 180)
	swirl.Parent = void
end

-- Leaderboard pillar: the belt passes between its legs --------------------------------------------------
local function buildPillar(arena: Instance)
	local m = model(arena, "Pillar")
	local c = Layout.PILLAR_POS
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, { Name = "Leg", Shape = CYL, Size = Vector3.new(14, 3.2, 3.2), CFrame = CFrame.new(c + Vector3.new(sx * 7.5, 7, sz * 7.5)) * VERT, Color = Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
			P(m, { Name = "LegBand", Shape = CYL, Size = Vector3.new(1, 3.5, 3.5), CFrame = CFrame.new(c + Vector3.new(sx * 7.5, 3, sz * 7.5)) * VERT, Color = S.Gold, Material = M.Foil })
		end
	end
	local block = P(m, { Name = "Block", Size = Vector3.new(18, 22, 18), CFrame = CFrame.new(c + Vector3.new(0, 25, 0)), Color = Color3.fromRGB(70, 40, 150), Material = M.SmoothPlastic })
	P(m, { Name = "Cap", Size = Vector3.new(20, 1.5, 20), CFrame = CFrame.new(c + Vector3.new(0, 36.7, 0)), Color = S.Gold, Material = M.Foil })
	P(m, { Name = "Base", Size = Vector3.new(20, 1.2, 20), CFrame = CFrame.new(c + Vector3.new(0, 13.6, 0)), Color = S.Gold, Material = M.Foil })
	for _, y in { 14.6, 35.6 } do
		P(m, { Name = "NeonTrim", Size = Vector3.new(18.4, 0.5, 18.4), CFrame = CFrame.new(c + Vector3.new(0, y, 0)), Color = S.Pink, Material = M.Neon, CanCollide = false })
	end
	local faces: { { name: string, face: Enum.NormalId } } = {
		{ name = "BoardFront", face = Enum.NormalId.Front },
		{ name = "BoardBack", face = Enum.NormalId.Back },
		{ name = "BoardLeft", face = Enum.NormalId.Left },
		{ name = "BoardRight", face = Enum.NormalId.Right },
	}
	for _, f in faces do
		local sg = Instance.new("SurfaceGui")
		sg.Name = f.name
		sg.Face = f.face
		sg.CanvasSize = Vector2.new(720, 880)
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.LightInfluence = 0
		sg.Parent = block
	end
	-- golden King Tung statue on a spinning neon ring
	local statue = TungModel.Build("KingTung", "Gold", { aura = false })
	statue:ScaleTo(2.2)
	statue:PivotTo(CFrame.new(c + Vector3.new(0, 37.5, 0)) * CFrame.Angles(0, math.pi, 0))
	statue.Parent = m
	local ring = P(m, { Name = "StatueRing", Shape = CYL, Size = Vector3.new(0.4, 16, 16), CFrame = CFrame.new(c + Vector3.new(0, 38, 0)) * CFrame.Angles(0.35, 0, 0) * VERT, Color = S.Yellow, Material = M.Neon, CanCollide = false, Transparency = 0.2 })
	tag(ring, "Spin")
end

-- Shop & sell stands --------------------------------------------------------------------------------------------
local function buildStand(arena: Instance, name: string, at: Vector3, title: string, color: Color3, icon: string, ui: string, action: string)
	local m = model(arena, name)
	local facing = if at.X > 0 then -1 else 1 -- the counter faces the belt
	local cf = CFrame.lookAt(at, at + Vector3.new(facing, 0, 0))
	P(m, { Name = "Counter", Size = Vector3.new(10, 3.5, 3), CFrame = cf * CFrame.new(0, 1.75, -1), Color = color, Material = M.SmoothPlastic })
	P(m, { Name = "CounterStripe", Size = Vector3.new(10.2, 0.8, 3.2), CFrame = cf * CFrame.new(0, 2.2, -1), Color = Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
	P(m, { Name = "CounterTop", Size = Vector3.new(10.8, 0.5, 3.8), CFrame = cf * CFrame.new(0, 3.75, -1), Color = S.Yellow, Material = M.SmoothPlastic })
	for _, sx in { -1, 1 } do
		P(m, { Name = "Pole", Shape = CYL, Size = Vector3.new(9, 0.7, 0.7), CFrame = cf * CFrame.new(sx * 4.8, 4.5, 1.6) * VERT, Color = Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
		P(m, { Name = "Pole", Shape = CYL, Size = Vector3.new(9, 0.7, 0.7), CFrame = cf * CFrame.new(sx * 4.8, 4.5, -2.3) * VERT, Color = Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
	end
	for i = 0, 4 do
		P(m, { Name = "Awning", Size = Vector3.new(2.1, 0.35, 5.6), CFrame = cf * CFrame.new(-4.2 + i * 2.1, 9.2, -0.4) * CFrame.Angles(math.rad(-12), 0, 0), Color = if i % 2 == 0 then color else Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
		P(m, { Name = "Scallop", Shape = BALL, Size = Vector3.new(2.1, 1, 1), CFrame = cf * CFrame.new(-4.2 + i * 2.1, 8.55, -3.1), Color = if i % 2 == 0 then color else Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic, CanCollide = false })
	end
	local board = P(m, { Name = "Board", Size = Vector3.new(9, 2.6, 0.5), CFrame = cf * CFrame.new(0, 11, -3.2), Color = S.Purple, Material = M.SmoothPlastic })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = board
	signLabel(sg, title)
	-- big bobbing icon above the stand
	local iconPart = P(m, { Name = "Icon", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 16, -1), Transparency = 1, CanCollide = false, CanQuery = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(6, 6)
	bb.LightInfluence = 0
	bb.MaxDistance = 250
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = icon
	l.TextScaled = true
	l.Parent = bb
	bb.Parent = iconPart
	tag(iconPart, "Bob")
	local hit = P(m, { Name = "PromptPart", Size = Vector3.new(10, 4, 1), CFrame = cf * CFrame.new(0, 3, -3), Transparency = 1, CanCollide = false })
	prompt(hit, action, title, ui)
end

function ArenaBuilder.Build(): Folder
	local arena = folder(Workspace, "Arena")
	setupLighting()
	buildGround(arena)
	buildWalls(arena)
	buildBelt(arena)
	buildPillar(arena)
	buildStand(arena, "ShopStand", Layout.SHOP_POS, "SHOP", Color3.fromRGB(60, 160, 255), "🛒", "Shop", "Open Shop")
	buildStand(arena, "SellStand", Layout.SELL_POS, "SELL", Color3.fromRGB(70, 210, 90), "💰", "Sell", "Sell Tungs")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CenterSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(Layout.CENTER_SPAWN - Vector3.new(0, 2.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = arena

	folder(arena, "Bases")
	return arena
end

return ArenaBuilder
