--!strict
-- Builds the shared arena at server start: grass floor, blue sky and clouds,
-- hedge walls with a wooden fence top, trees / flowers / lanterns, the conveyor
-- belt with its drum machine and hole, the leaderboard pillar, and the shop and
-- sell stands. (The 8 bases are built by BaseBuilder.)
--
-- Gameplay only relies on these names, so any prop can be swapped for real art:
--   Arena.Belt.Surface, Arena.Belt.Drum (Model), Arena.Pillar.Board*,
--   Arena.ShopStand / SellStand (ProximityPrompt with attribute "UI").

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local TungModel = require(Shared.TungModel)

local ArenaBuilder = {}

local M = Enum.Material
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local VERT = CFrame.Angles(0, 0, math.rad(90))

local GRASS = Color3.fromRGB(104, 196, 70)
local HEDGE = Color3.fromRGB(58, 142, 52)
local WOOD = Color3.fromRGB(168, 116, 70)
local WOOD_DARK = Color3.fromRGB(118, 78, 46)

type Props = { [string]: any }

local function P(parent: Instance, props: Props): BasePart
	local className = props.ClassName or "Part"
	props.ClassName = nil
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
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

local function signLabel(parent: Instance, text: string, color: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = font or Enum.Font.FredokaOne
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = Color3.fromRGB(60, 35, 20)
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

-- Lighting / sky -----------------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 13
	Lighting.Brightness = 2.4
	Lighting.GeographicLatitude = 35
	Lighting.Ambient = Color3.fromRGB(95, 95, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	for _, c in Lighting:GetChildren() do
		if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 9
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.22
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(200, 225, 255)
	atmo.Decay = Color3.fromRGB(120, 160, 220)
	atmo.Glare = 0.2
	atmo.Haze = 0.6
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting

	-- a gentle wind makes the clouds drift and the grass blades sway
	Workspace.GlobalWind = Vector3.new(6, 0, 3)
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
end

-- Ground -----------------------------------------------------------------------------------------
local function buildGround()
	local terrain = Workspace.Terrain
	terrain:SetMaterialColor(M.Grass, GRASS)
	terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(90, 170, 60))
	pcall(function()
		(terrain :: any).Decoration = true -- swaying grass blades
	end)
	-- the arena floor (top at Y = 0) plus a wide margin so the horizon isn't empty
	local hx, hz = Layout.ARENA_HALF_X + 90, Layout.ARENA_HALF_Z + 90
	for x = -hx, hx - 1, 64 do
		for z = -hz, hz - 1, 64 do
			terrain:FillBlock(CFrame.new(x + 32, -4, z + 32), Vector3.new(64, 8, 64), M.Grass)
		end
		task.wait()
	end
	-- rolling hills outside the walls
	local rng = Random.new(42)
	for _ = 1, 26 do
		local side = rng:NextInteger(1, 4)
		local x, z
		if side <= 2 then
			x = (if side == 1 then -1 else 1) * rng:NextNumber(Layout.ARENA_HALF_X + 40, Layout.ARENA_HALF_X + 80)
			z = rng:NextNumber(-hz, hz)
		else
			z = (if side == 3 then -1 else 1) * rng:NextNumber(Layout.ARENA_HALF_Z + 40, Layout.ARENA_HALF_Z + 80)
			x = rng:NextNumber(-hx, hx)
		end
		terrain:FillBall(Vector3.new(x, -rng:NextNumber(6, 14), z), rng:NextNumber(22, 38), M.Grass)
	end
end

-- Walls & decoration ------------------------------------------------------------------------------
local function buildTree(parent: Instance, at: Vector3, rng: Random)
	local m = model(parent, "Tree")
	local h = rng:NextNumber(9, 14)
	P(m, { Name = "Trunk", Shape = CYL, Size = Vector3.new(h, 2, 2), CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)) * VERT, Color = WOOD_DARK, Material = M.Wood })
	for i = 1, 3 do
		local s = rng:NextNumber(6, 9)
		P(m, {
			Name = "Leaves",
			Shape = BALL,
			Size = Vector3.new(s, s, s),
			CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-2, 2), h + i * 1.2, rng:NextNumber(-2, 2))),
			Color = Color3.fromRGB(70 + rng:NextInteger(0, 30), 160 + rng:NextInteger(0, 30), 60),
			Material = M.LeafyGrass,
			CanCollide = false,
		})
	end
end

local FLOWER_COLORS = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(150, 110, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 60) }

local function buildFlowers(parent: Instance, at: Vector3, rng: Random)
	for _ = 1, 5 do
		local off = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		P(parent, { Name = "Stem", Size = Vector3.new(0.15, 1.2, 0.15), CFrame = CFrame.new(at + off + Vector3.new(0, 0.6, 0)), Color = Color3.fromRGB(60, 150, 50), CanCollide = false, CastShadow = false })
		P(parent, { Name = "Bloom", Shape = BALL, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = CFrame.new(at + off + Vector3.new(0, 1.3, 0)), Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], CanCollide = false, CastShadow = false })
	end
end

local function buildLantern(parent: Instance, at: Vector3)
	local m = model(parent, "Lantern")
	P(m, { Name = "Post", Size = Vector3.new(0.6, 7, 0.6), CFrame = CFrame.new(at + Vector3.new(0, 3.5, 0)), Color = WOOD_DARK, Material = M.Wood })
	P(m, { Name = "Arm", Size = Vector3.new(0.4, 0.4, 2), CFrame = CFrame.new(at + Vector3.new(0, 6.8, -0.8)), Color = WOOD_DARK, Material = M.Wood })
	local lamp = P(m, { Name = "Lamp", Size = Vector3.new(1.2, 1.5, 1.2), CFrame = CFrame.new(at + Vector3.new(0, 5.9, -1.6)), Color = Color3.fromRGB(255, 210, 120), Material = M.Neon, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 200, 120)
	l.Range = 18
	l.Brightness = 1.5
	l.Enabled = false
	l.Parent = lamp
	CollectionService:AddTag(lamp, "Lantern")
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
		P(walls, { Name = "Hedge", Size = Vector3.new(len, 7, 4), CFrame = cf * CFrame.new(0, 3.5, 0), Color = HEDGE, Material = M.LeafyGrass })
		P(walls, { Name = "HedgeTop", Size = Vector3.new(len, 1.2, 4.6), CFrame = cf * CFrame.new(0, 7, 0), Color = HEDGE:Lerp(Color3.new(0.5, 0.9, 0.3), 0.2), Material = M.LeafyGrass, CanCollide = false })
		-- fence on top of the hedge
		P(walls, { Name = "Rail", Size = Vector3.new(len, 0.5, 0.4), CFrame = cf * CFrame.new(0, 9.4, 0), Color = WOOD, Material = M.WoodPlanks })
		P(walls, { Name = "Rail", Size = Vector3.new(len, 0.5, 0.4), CFrame = cf * CFrame.new(0, 8.4, 0), Color = WOOD, Material = M.WoodPlanks })
		for x = -len / 2 + 2, len / 2 - 2, 8 do
			P(walls, { Name = "Picket", Size = Vector3.new(0.7, 3.4, 0.5), CFrame = cf * CFrame.new(x, 9.1, 0), Color = WOOD, Material = M.WoodPlanks })
		end
		-- invisible wall so nobody can leave the arena
		P(walls, { Name = "Barrier", Size = Vector3.new(len, 80, 2), CFrame = cf * CFrame.new(0, 40, 0), Transparency = 1, CanQuery = false })
	end

	local deco = folder(arena, "Decor")
	local rng = Random.new(7)
	-- trees just outside the hedge, all the way round
	for z = -hz - 8, hz + 8, 22 do
		buildTree(deco, Vector3.new(-hx - 12 - rng:NextNumber(0, 8), 0, z + rng:NextNumber(-5, 5)), rng)
		buildTree(deco, Vector3.new(hx + 12 + rng:NextNumber(0, 8), 0, z + rng:NextNumber(-5, 5)), rng)
	end
	for x = -hx, hx, 22 do
		buildTree(deco, Vector3.new(x + rng:NextNumber(-5, 5), 0, -hz - 12 - rng:NextNumber(0, 8)), rng)
		buildTree(deco, Vector3.new(x + rng:NextNumber(-5, 5), 0, hz + 12 + rng:NextNumber(0, 8)), rng)
	end
	-- flowers and lanterns along the end walls and down the corridor
	for x = -hx + 10, hx - 10, 18 do
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

-- Conveyor belt ----------------------------------------------------------------------------------
local function buildBelt(arena: Instance)
	local belt = folder(arena, "Belt")
	local a, b = Layout.BELT_START, Layout.BELT_END
	local len = (b - a).Magnitude + 8
	local mid = (a + b) / 2
	local top = Layout.BELT_Y
	local w = Layout.BELT_WIDTH
	P(belt, { Name = "Frame", Size = Vector3.new(w + 2, top - 0.4, len), CFrame = CFrame.new(mid.X, (top - 0.4) / 2, mid.Z), Color = Color3.fromRGB(70, 74, 86), Material = M.Metal })
	local surface = P(belt, { Name = "Surface", Size = Vector3.new(w, 0.4, len), CFrame = CFrame.new(mid.X, top - 0.2, mid.Z), Color = Color3.fromRGB(45, 45, 52), Material = M.Rubber })
	-- an anchored part with velocity carries anything standing on it, like a real conveyor
	surface.AssemblyLinearVelocity = (b - a).Unit * ((b - a).Magnitude / Economy.BELT_TRAVEL)
	for _, sx in { -1, 1 } do
		P(belt, { Name = "Rail", Size = Vector3.new(0.6, 0.9, len), CFrame = CFrame.new(sx * (w / 2 + 0.5), top + 0.25, mid.Z), Color = Color3.fromRGB(255, 196, 40), Material = M.SmoothPlastic })
	end
	for z = a.Z - 2, b.Z + 2, 12 do
		for _, sx in { -1, 1 } do
			P(belt, { Name = "Leg", Size = Vector3.new(0.8, top, 0.8), CFrame = CFrame.new(sx * (w / 2 + 1.2), top / 2, z), Color = Color3.fromRGB(55, 58, 68), Material = M.Metal, CanCollide = false })
		end
	end

	-- The drum machine Tungs come out of
	local drum = model(belt, "Drum")
	local d = Layout.DRUM_POS
	P(drum, { Name = "Shell", Shape = CYL, Size = Vector3.new(14, 20, 20), CFrame = CFrame.new(d) * VERT, Color = Color3.fromRGB(200, 40, 45), Material = M.WoodPlanks })
	P(drum, { Name = "Head", Shape = CYL, Size = Vector3.new(0.4, 20.4, 20.4), CFrame = CFrame.new(d + Vector3.new(0, 7.1, 0)) * VERT, Color = Color3.fromRGB(250, 245, 230), Material = M.Fabric })
	for _, y in { -6.6, 6.6 } do
		P(drum, { Name = "Hoop", Shape = CYL, Size = Vector3.new(1, 20.8, 20.8), CFrame = CFrame.new(d + Vector3.new(0, y, 0)) * VERT, Color = WOOD, Material = M.Wood })
	end
	for i = 0, 11 do
		local ang = i / 12 * math.pi * 2
		local r = 10.3
		P(drum, { Name = "Rope", Size = Vector3.new(0.35, 13.5, 0.35), CFrame = CFrame.new(d + Vector3.new(math.sin(ang) * r, 0, math.cos(ang) * r)) * CFrame.Angles(0, ang, if i % 2 == 0 then 0.35 else -0.35), Color = Color3.fromRGB(245, 220, 150), Material = M.Fabric })
	end
	for _, sx in { -1, 1 } do
		P(drum, { Name = "Stick", Shape = CYL, Size = Vector3.new(12, 0.8, 0.8), CFrame = CFrame.new(d + Vector3.new(sx * 2.5, 10.5, 1)) * CFrame.Angles(0, 0, sx * 0.9), Color = Color3.fromRGB(230, 190, 130), Material = M.Wood })
		P(drum, { Name = "StickTip", Shape = BALL, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(d + Vector3.new(sx * -1.3, 13.4, 1)), Color = Color3.fromRGB(240, 210, 160), Material = M.Wood })
	end
	P(drum, { Name = "Mouth", Size = Vector3.new(w + 1, 6, 2), CFrame = CFrame.new(0, top + 3, d.Z + 9.4), Color = Color3.fromRGB(15, 10, 10), Material = M.SmoothPlastic, CanCollide = false })
	local signPart = P(drum, { Name = "Sign", Size = Vector3.new(16, 4, 0.5), CFrame = CFrame.new(0, 17.5, d.Z + 4) * CFrame.Angles(0, math.pi, 0), Transparency = 1, CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = signPart
	signLabel(sg, "🥁 TUNG MACHINE 🥁", Color3.fromRGB(255, 220, 90))
	drum.PrimaryPart = drum:FindFirstChild("Shell") :: BasePart

	-- The hole at the end
	local h = Layout.HOLE_POS
	P(belt, { Name = "HoleRim", Shape = CYL, Size = Vector3.new(top, 15, 15), CFrame = CFrame.new(h + Vector3.new(0, top / 2, 0)) * VERT, Color = Color3.fromRGB(110, 100, 90), Material = M.Cobblestone })
	local void = P(belt, { Name = "Void", Shape = CYL, Size = Vector3.new(0.2, 12, 12), CFrame = CFrame.new(h + Vector3.new(0, top + 0.06, 0)) * VERT, Color = Color3.fromRGB(5, 5, 8), Material = M.SmoothPlastic, CanCollide = false })
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/smoke_main.dds"
	swirl.Rate = 6
	swirl.Lifetime = NumberRange.new(1.5, 2)
	swirl.Speed = NumberRange.new(0.5, 1)
	swirl.Size = NumberSequence.new(4, 1)
	swirl.Transparency = NumberSequence.new(0.6, 1)
	swirl.Color = ColorSequence.new(Color3.fromRGB(40, 20, 60))
	swirl.RotSpeed = NumberRange.new(90, 180)
	swirl.Parent = void
end

-- Leaderboard pillar: the belt passes between its legs --------------------------------------------
local function buildPillar(arena: Instance)
	local m = model(arena, "Pillar")
	local c = Layout.PILLAR_POS
	local stone = Color3.fromRGB(235, 222, 196)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, { Name = "Leg", Size = Vector3.new(3, 14, 3), CFrame = CFrame.new(c + Vector3.new(sx * 7.5, 7, sz * 7.5)), Color = stone, Material = M.Sandstone })
		end
	end
	local block = P(m, { Name = "Block", Size = Vector3.new(18, 22, 18), CFrame = CFrame.new(c + Vector3.new(0, 25, 0)), Color = WOOD, Material = M.WoodPlanks })
	P(m, { Name = "Cap", Size = Vector3.new(20, 1.5, 20), CFrame = CFrame.new(c + Vector3.new(0, 36.7, 0)), Color = stone, Material = M.Sandstone })
	P(m, { Name = "Base", Size = Vector3.new(20, 1.2, 20), CFrame = CFrame.new(c + Vector3.new(0, 13.6, 0)), Color = stone, Material = M.Sandstone })
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
	-- golden King Tung statue on top
	local statue = TungModel.Build("KingTung", "Gold", { aura = false })
	statue:ScaleTo(2.2)
	statue:PivotTo(CFrame.new(c + Vector3.new(0, 37.5, 0)) * CFrame.Angles(0, math.pi, 0))
	statue.Parent = m
end

-- Shop & sell stands --------------------------------------------------------------------------------
local function buildStand(arena: Instance, name: string, at: Vector3, title: string, color: Color3, ui: string, action: string)
	local m = model(arena, name)
	local facing = if at.X > 0 then -1 else 1 -- the counter faces the belt
	local cf = CFrame.lookAt(at, at + Vector3.new(facing, 0, 0))
	P(m, { Name = "Counter", Size = Vector3.new(10, 3.5, 3), CFrame = cf * CFrame.new(0, 1.75, -1), Color = WOOD, Material = M.WoodPlanks })
	P(m, { Name = "CounterTop", Size = Vector3.new(10.6, 0.4, 3.6), CFrame = cf * CFrame.new(0, 3.7, -1), Color = WOOD_DARK, Material = M.Wood })
	for _, sx in { -1, 1 } do
		P(m, { Name = "Pole", Size = Vector3.new(0.6, 9, 0.6), CFrame = cf * CFrame.new(sx * 4.8, 4.5, 1.6), Color = WOOD_DARK, Material = M.Wood })
		P(m, { Name = "Pole", Size = Vector3.new(0.6, 9, 0.6), CFrame = cf * CFrame.new(sx * 4.8, 4.5, -2.3), Color = WOOD_DARK, Material = M.Wood })
	end
	for i = 0, 4 do
		P(m, { Name = "Awning", Size = Vector3.new(2.1, 0.3, 5.4), CFrame = cf * CFrame.new(-4.2 + i * 2.1, 9.2, -0.4) * CFrame.Angles(math.rad(-12), 0, 0), Color = if i % 2 == 0 then color else Color3.fromRGB(250, 245, 235), Material = M.Fabric })
	end
	local board = P(m, { Name = "Board", Size = Vector3.new(9, 2.4, 0.4), CFrame = cf * CFrame.new(0, 10.8, -3.2), Color = WOOD, Material = M.WoodPlanks })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = board
	signLabel(sg, title, Color3.fromRGB(255, 240, 200), Enum.Font.LuckiestGuy)
	local hit = P(m, { Name = "PromptPart", Size = Vector3.new(10, 4, 1), CFrame = cf * CFrame.new(0, 3, -3), Transparency = 1, CanCollide = false })
	prompt(hit, action, title, ui)
end

function ArenaBuilder.Build(): Folder
	local arena = folder(Workspace, "Arena")
	setupLighting()
	buildGround()
	buildWalls(arena)
	buildBelt(arena)
	buildPillar(arena)
	buildStand(arena, "ShopStand", Layout.SHOP_POS, "SHOP", Color3.fromRGB(60, 160, 255), "Shop", "Open Shop")
	buildStand(arena, "SellStand", Layout.SELL_POS, "SELL", Color3.fromRGB(255, 90, 80), "Sell", "Sell Tungs")

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

	local bases = folder(arena, "Bases")
	local _ = bases
	return arena
end

return ArenaBuilder
