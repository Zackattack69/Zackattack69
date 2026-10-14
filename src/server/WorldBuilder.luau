--!strict
-- Builds all 8 planets at server start: real Terrain landscapes (dunes, snow,
-- forests, lava valleys) or built platforms (cloud city, capital city, battle
-- station), plus iconic set pieces (crashed star destroyer, walkers, X-wings,
-- TIEs, freighters, treehouse villages...).
--
-- Gameplay only relies on these tagged parts, so you can swap any prop for
-- hand-built art later:
--   "Spawn" (Part), CrateTerminal (Part w/ ProximityPrompt),
--   HyperGate (Part w/ ProximityPrompt), "ScrapPile" (Model w/ ClickDetector)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)

local WorldBuilder = {}

local PLAY_SIZE = 640 -- walkable square (walls at ±320)
local HALF = PLAY_SIZE / 2
local TERRAIN_HALF = 440 -- terrain continues past the walls so the horizon isn't empty
local STEP = 8 -- terrain column size

local Terrain = workspace.Terrain

type Props = { [string]: any }

-- Helpers -------------------------------------------------------------------------------
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

local function light(part: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 2
	l.Parent = part
end

local function billboard(adornee: BasePart, text: string, color: Color3, size: UDim2, offset: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = Vector3.new(0, offset, 0)
	bb.MaxDistance = 500
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 20, 35)
	stroke.Parent = label
	label.Parent = bb
	bb.Parent = adornee
	return bb
end

local function particles(parent: BasePart, props: Props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function ring(rng: Random, minR: number, maxR: number): (number, number)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(minR, maxR)
	return math.cos(a) * r, math.sin(a) * r
end

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local UP = CFrame.Angles(0, 0, math.rad(90))
local FWD = CFrame.Angles(0, math.rad(90), 0)
local M = Enum.Material

local GREY = Color3.fromRGB(165, 168, 175)
local DARK = Color3.fromRGB(60, 62, 70)
local WHITE = Color3.fromRGB(235, 236, 240)

-- Terrain ---------------------------------------------------------------------------------
-- Height of the landscape at a local (x, z). The middle stays flat for gameplay.
local function heightAt(world: Worlds.World, x: number, z: number): number
	local spec = world.terrain
	if spec.kind ~= "terrain" then
		return 0
	end
	local amp = spec.amplitude or 30
	local freq = spec.frequency or 1 / 120
	local flat = spec.flatRadius or 160
	local seed = world.index * 13.37
	local dist = math.sqrt(x * x + z * z)
	local t = math.clamp((dist - flat) / 170, 0, 1)
	t = t * t * (3 - 2 * t)
	local n = math.noise(x * freq, z * freq, seed)
	local detail = math.noise(x * freq * 3.1, z * freq * 3.1, seed + 7.7) * 0.35
	local hills = if spec.waterLevel then (n + detail) * amp * 1.3 else (n + detail + 0.45) * amp
	-- gentle ripples inside the play area (not right at the hub)
	local ripple = detail * 6 * math.clamp((dist - 70) / 80, 0, 1) * (1 - t)
	return hills * t + ripple
end
WorldBuilder.HeightAt = heightAt

local function generateTerrain(world: Worlds.World)
	local spec = world.terrain
	local o = world.origin
	local amp = spec.amplitude or 30
	local count = 0
	for x = -TERRAIN_HALF, TERRAIN_HALF, STEP do
		for z = -TERRAIN_HALF, TERRAIN_HALF, STEP do
			local h = heightAt(world, x, z)
			local bottom = math.min(-30, h - 6)
			local mat = if h > amp * 0.75 then spec.peak elseif h > amp * 0.3 then spec.base elseif h < -1.5 and spec.lava then spec.base else spec.top
			Terrain:FillBlock(CFrame.new(o.X + x, (bottom + h) / 2, o.Z + z), Vector3.new(STEP, h - bottom, STEP), mat :: Enum.Material)
			if spec.waterLevel and not spec.lava and h < spec.waterLevel then
				Terrain:FillBlock(CFrame.new(o.X + x, (h + spec.waterLevel) / 2, o.Z + z), Vector3.new(STEP, spec.waterLevel - h, STEP), M.Water)
			end
			count += 1
			if count % 500 == 0 then
				task.wait() -- keep the server responsive while generating
			end
		end
	end
end

-- Shared world furniture --------------------------------------------------------------------
local function buildScrapPile(parent: Instance, at: Vector3, world: Worlds.World, rng: Random)
	local m = Instance.new("Model")
	m.Name = "ScrapPile"
	local hit = P(m, { Name = "Hitbox", Size = Vector3.new(10, 7, 10), CFrame = CFrame.new(at + Vector3.new(0, 3.5, 0)), Transparency = 1, CanCollide = false })
	for i = 1, 8 do
		local s = rng:NextNumber(1.2, 3.4)
		local glow = i % 4 == 0
		P(m, {
			Name = "Chunk",
			Shape = if i % 3 == 0 then CYL else Enum.PartType.Block,
			Size = Vector3.new(s * rng:NextNumber(0.8, 2), s * 0.6, s),
			CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-3, 3), s * 0.3 + (i // 3) * 1.1, rng:NextNumber(-3, 3)))
				* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6.28), rng:NextNumber(0, 1)),
			Color = if glow then world.colors.accent elseif i % 2 == 0 then GREY else DARK,
			Material = if glow then M.Neon else M.Metal,
			CanCollide = false,
		})
	end
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 60
	cd.Parent = hit
	m.PrimaryPart = hit
	m.Parent = parent
	return m
end

-- Holo-projector with a spinning holographic crate
local function buildCrateTerminal(parent: Instance, at: Vector3, world: Worlds.World)
	P(parent, { Name = "TerminalBase", Shape = CYL, Size = Vector3.new(2, 18, 18), CFrame = CFrame.new(at + Vector3.new(0, 1, 0)) * UP, Color = DARK, Material = M.DiamondPlate })
	P(parent, { Name = "TerminalRing", Shape = CYL, Size = Vector3.new(0.4, 18.6, 18.6), CFrame = CFrame.new(at + Vector3.new(0, 2.1, 0)) * UP, Color = Color3.fromRGB(80, 200, 255), Material = M.Neon })
	P(parent, { Name = "Projector", Shape = CYL, Size = Vector3.new(3, 5, 5), CFrame = CFrame.new(at + Vector3.new(0, 3.5, 0)) * UP, Color = GREY, Material = M.Metal })
	-- imperial-style supply crates stacked around the projector
	for i, off in { Vector3.new(-7, 2.5, 4), Vector3.new(6, 2.5, 5), Vector3.new(5, 2.5, -6) } do
		P(parent, { Name = "SupplyCrate", Size = Vector3.new(4, 3, 3), CFrame = CFrame.new(at + off) * CFrame.Angles(0, i, 0), Color = Color3.fromRGB(70, 75, 85), Material = M.Metal })
		P(parent, { Name = "SupplyStripe", Size = Vector3.new(4.1, 0.4, 3.1), CFrame = CFrame.new(at + off + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, i, 0), Color = world.colors.accent, Material = M.Neon })
	end
	local crate = P(parent, {
		Name = "CrateTerminal",
		Size = Vector3.new(6, 6, 6),
		CFrame = CFrame.new(at + Vector3.new(0, 10, 0)) * CFrame.Angles(0, math.rad(45), math.rad(15)),
		Color = Color3.fromRGB(110, 210, 255),
		Material = M.ForceField,
		CanCollide = false,
	})
	crate:SetAttribute("Spin", true)
	local beam = P(parent, { Name = "HoloBeam", Shape = CYL, Size = Vector3.new(6, 2.5, 2.5), CFrame = CFrame.new(at + Vector3.new(0, 6.5, 0)) * UP, Color = Color3.fromRGB(110, 210, 255), Material = M.Neon, Transparency = 0.6, CanCollide = false })
	light(beam, Color3.fromRGB(110, 210, 255), 24, 2)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Crates"
	prompt.ObjectText = "Supply Terminal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = crate
	crate:SetAttribute("Terminal", "Crates")
	billboard(crate, "📦 CRATES", Color3.fromRGB(255, 220, 90), UDim2.fromOffset(220, 60), 7)
	return crate
end

local function buildHyperGate(parent: Instance, at: Vector3, world: Worlds.World)
	local segments = 24
	local radius = 14
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		P(parent, {
			Name = "GateRing",
			Size = Vector3.new(3.2, 4, 3.2),
			CFrame = CFrame.new(at + Vector3.new(math.cos(a) * radius, radius + 2 + math.sin(a) * radius, 0)) * CFrame.Angles(0, 0, a),
			Color = if i % 2 == 0 then DARK else world.colors.accent,
			Material = if i % 2 == 0 then M.Metal else M.Neon,
		})
	end
	local portal = P(parent, {
		Name = "HyperGate",
		Shape = CYL,
		Size = Vector3.new(0.5, radius * 2 - 3, radius * 2 - 3),
		CFrame = CFrame.new(at + Vector3.new(0, radius + 2, 0)) * FWD,
		Color = Color3.fromRGB(140, 210, 255),
		Material = M.ForceField,
		CanCollide = false,
	})
	light(portal, Color3.fromRGB(140, 210, 255), 30, 3)
	particles(portal, {
		Rate = 40,
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(20, 35),
		LightEmission = 1,
		Size = NumberSequence.new(0.35, 0),
		Color = ColorSequence.new(Color3.fromRGB(200, 235, 255)),
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Jump to Hyperspace"
	prompt.ObjectText = "Hyperspace Gate"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 22
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	portal:SetAttribute("Terminal", "Map")
	billboard(portal, "🌌 HYPERSPACE", Color3.fromRGB(170, 225, 255), UDim2.fromOffset(280, 60), radius + 4)
	return portal
end

-- Ships & walkers ------------------------------------------------------------------------------
local function xWing(f: Instance, cf: CFrame, s: number)
	local function q(props: Props)
		props.CFrame = cf * props.CFrame
		props.Size = props.Size * s
		return P(f, props)
	end
	local function at(x: number, y: number, z: number, rot: CFrame?): CFrame
		return CFrame.new(x * s, y * s, z * s) * (rot or CFrame.new())
	end
	q({ Name = "XFuselage", Size = Vector3.new(5, 4, 28), CFrame = at(0, 0, 0), Color = WHITE, Material = M.SmoothPlastic })
	q({ ClassName = "WedgePart", Name = "XNose", Size = Vector3.new(4.6, 3.6, 14), CFrame = at(0, -0.2, -21), Color = WHITE, Material = M.SmoothPlastic })
	q({ Name = "XStripe", Size = Vector3.new(5.1, 0.6, 6), CFrame = at(0, 1.6, -6), Color = Color3.fromRGB(200, 50, 50), Material = M.SmoothPlastic })
	q({ Name = "XCanopy", Size = Vector3.new(3, 1.8, 6), CFrame = at(0, 2.6, -4), Color = Color3.fromRGB(30, 40, 60), Material = M.Glass })
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local tilt = CFrame.Angles(0, 0, math.rad(12 * sx * sy))
			q({ Name = "XWing", Size = Vector3.new(20, 0.8, 7), CFrame = at(sx * 12, sy * 2, 7, tilt), Color = WHITE, Material = M.SmoothPlastic })
			q({ Name = "XWingStripe", Size = Vector3.new(6, 0.9, 7.1), CFrame = at(sx * 15, sy * 2 + sy * sx * 0.6, 7, tilt), Color = Color3.fromRGB(200, 50, 50), Material = M.SmoothPlastic })
			q({ Name = "XEngine", Shape = CYL, Size = Vector3.new(10, 2.6, 2.6), CFrame = at(sx * 4.5, sy * 2.4, 8, FWD), Color = GREY, Material = M.Metal })
			q({ Name = "XGlow", Shape = CYL, Size = Vector3.new(0.3, 2, 2), CFrame = at(sx * 4.5, sy * 2.4, 13.1, FWD), Color = Color3.fromRGB(255, 120, 80), Material = M.Neon })
			q({ Name = "XCannon", Size = Vector3.new(0.6, 0.6, 18), CFrame = at(sx * 22, sy * (2 + 10 * math.tan(math.rad(12))), 0), Color = DARK, Material = M.Metal })
		end
	end
end

local function tie(f: Instance, cf: CFrame, s: number)
	local function q(name: string, shape: Enum.PartType?, size: Vector3, local_: CFrame, color: Color3, mat: Enum.Material)
		P(f, { Name = name, Shape = shape or Enum.PartType.Block, Size = size * s, CFrame = cf * CFrame.new(local_.Position * s) * local_.Rotation, Color = color, Material = mat })
	end
	q("TieCockpit", BALL, Vector3.new(8, 8, 8), CFrame.new(), GREY, M.Metal)
	q("TieWindow", CYL, Vector3.new(0.6, 4.5, 4.5), CFrame.new(0, 0, -3.9) * FWD, Color3.fromRGB(25, 30, 40), M.Glass)
	for _, sx in { -1, 1 } do
		q("TieStrut", CYL, Vector3.new(7, 2.2, 2.2), CFrame.new(sx * 6, 0, 0), GREY, M.Metal)
		q("TieWing", nil, Vector3.new(1, 22, 18), CFrame.new(sx * 10, 0, 0), Color3.fromRGB(45, 48, 58), M.Metal)
		q("TieFrame", nil, Vector3.new(1.3, 23, 1.6), CFrame.new(sx * 10, 0, 0), GREY, M.Metal)
	end
end

local function freighter(f: Instance, cf: CFrame, s: number)
	local function q(name: string, shape: Enum.PartType?, size: Vector3, local_: CFrame, color: Color3, mat: Enum.Material)
		return P(f, { Name = name, Shape = shape or Enum.PartType.Block, Size = size * s, CFrame = cf * CFrame.new(local_.Position * s) * local_.Rotation, Color = color, Material = mat })
	end
	q("FreighterHull", CYL, Vector3.new(4, 48, 48), CFrame.new(0, 0, 0) * UP, Color3.fromRGB(200, 200, 195), M.SmoothPlastic)
	q("FreighterTop", CYL, Vector3.new(3, 30, 30), CFrame.new(0, 2.5, 2) * UP, Color3.fromRGB(185, 185, 180), M.Metal)
	for _, sx in { -1, 1 } do
		q("FreighterMandible", nil, Vector3.new(7, 3.6, 20), CFrame.new(sx * 6.5, 0, -28), Color3.fromRGB(200, 200, 195), M.SmoothPlastic)
	end
	q("FreighterNeck", nil, Vector3.new(10, 4, 8), CFrame.new(22, 0, -12), Color3.fromRGB(195, 195, 190), M.SmoothPlastic)
	q("FreighterCockpit", CYL, Vector3.new(10, 5, 5), CFrame.new(26, 0, -18) * FWD, Color3.fromRGB(205, 205, 200), M.SmoothPlastic)
	q("FreighterWindow", CYL, Vector3.new(0.5, 4, 4), CFrame.new(26, 0, -23.1) * FWD, Color3.fromRGB(30, 35, 45), M.Glass)
	q("FreighterDish", CYL, Vector3.new(0.6, 8, 8), CFrame.new(-6, 6, 6) * CFrame.Angles(0, 0, math.rad(60)), GREY, M.Metal)
	local glow = q("FreighterEngine", nil, Vector3.new(34, 2, 1), CFrame.new(0, 0, 23.6), Color3.fromRGB(120, 200, 255), M.Neon)
	light(glow, Color3.fromRGB(120, 200, 255), 30, 2)
	for _, off in { Vector3.new(-12, -4, 8), Vector3.new(12, -4, 8), Vector3.new(0, -4, -14) } do
		q("FreighterGear", CYL, Vector3.new(5, 1.5, 1.5), CFrame.new(off) * UP, DARK, M.Metal)
	end
end

local function atat(f: Instance, cf: CFrame, s: number)
	local function q(name: string, size: Vector3, local_: CFrame, color: Color3?)
		P(f, { Name = name, Size = size * s, CFrame = cf * CFrame.new(local_.Position * s) * local_.Rotation, Color = color or GREY, Material = M.Metal })
	end
	q("AtatBody", Vector3.new(22, 16, 44), CFrame.new(0, 50, 0))
	q("AtatBodyTop", Vector3.new(18, 3, 40), CFrame.new(0, 59, 0), Color3.fromRGB(150, 152, 160))
	q("AtatNeck", Vector3.new(7, 7, 10), CFrame.new(0, 48, -26), DARK)
	q("AtatHead", Vector3.new(11, 10, 16), CFrame.new(0, 46, -38))
	q("AtatChin", Vector3.new(9, 3, 6), CFrame.new(0, 41, -44), DARK)
	for _, x in { -7, 7 } do
		for _, z in { -14, 14 } do
			q("AtatThigh", Vector3.new(5, 22, 6), CFrame.new(x * 1.1, 33, z))
			q("AtatShin", Vector3.new(4, 22, 5), CFrame.new(x * 1.1, 12, z), Color3.fromRGB(150, 152, 160))
			q("AtatFoot", Vector3.new(9, 3, 9), CFrame.new(x * 1.1, 1.5, z), DARK)
		end
	end
end

local function atst(f: Instance, cf: CFrame, s: number)
	local function q(name: string, size: Vector3, local_: CFrame, color: Color3?)
		P(f, { Name = name, Size = size * s, CFrame = cf * CFrame.new(local_.Position * s) * local_.Rotation, Color = color or GREY, Material = M.Metal })
	end
	q("AtstHead", Vector3.new(10, 7, 11), CFrame.new(0, 22, 0))
	q("AtstWindow", Vector3.new(8, 1.4, 0.4), CFrame.new(0, 23, -5.6), Color3.fromRGB(25, 25, 30))
	q("AtstGun", Vector3.new(1.2, 1.2, 6), CFrame.new(-5.5, 20, -6), DARK)
	for _, x in { -3, 3 } do
		q("AtstThigh", Vector3.new(1.6, 9, 1.6), CFrame.new(x, 15, 1) * CFrame.Angles(math.rad(-20), 0, 0))
		q("AtstShin", Vector3.new(1.4, 10, 1.4), CFrame.new(x, 6, 0) * CFrame.Angles(math.rad(15), 0, 0))
		q("AtstFoot", Vector3.new(4, 1, 5), CFrame.new(x, 0.5, -1), DARK)
	end
end

-- Huge half-buried triangular battleship (Junkku's centrepiece)
local function starDestroyer(f: Instance, cf: CFrame, L: number)
	local W = L * 0.55
	local thick = L * 0.08
	local function half(sign: number, y: number, scale: number, color: Color3)
		P(f, {
			ClassName = "WedgePart",
			Name = "DestroyerHull",
			Size = Vector3.new(thick * scale, W / 2 * scale, L * scale),
			CFrame = cf * CFrame.new(-sign * W / 4 * scale, y, (1 - scale) * L * 0.5) * CFrame.Angles(0, 0, math.rad(90 * sign)),
			Color = color,
			Material = M.Metal,
		})
	end
	half(1, 0, 1, Color3.fromRGB(150, 150, 155))
	half(-1, 0, 1, Color3.fromRGB(150, 150, 155))
	half(1, thick * 0.9, 0.7, Color3.fromRGB(135, 135, 140))
	half(-1, thick * 0.9, 0.7, Color3.fromRGB(135, 135, 140))
	-- command tower + bridge
	P(f, { Name = "DestroyerTower", Size = Vector3.new(W * 0.18, thick * 2.2, L * 0.12), CFrame = cf * CFrame.new(0, thick * 2.2, L * 0.38), Color = Color3.fromRGB(140, 140, 145), Material = M.Metal })
	P(f, { Name = "DestroyerBridge", Size = Vector3.new(W * 0.4, thick * 0.5, L * 0.05), CFrame = cf * CFrame.new(0, thick * 3.4, L * 0.38), Color = Color3.fromRGB(130, 130, 135), Material = M.Metal })
	for _, sx in { -1, 1 } do
		P(f, { Name = "DestroyerDome", Shape = BALL, Size = Vector3.new(1, 1, 1) * thick * 0.7, CFrame = cf * CFrame.new(sx * W * 0.13, thick * 3.9, L * 0.38), Color = Color3.fromRGB(150, 150, 155), Material = M.Metal })
	end
	-- dead engines at the back
	for _, sx in { -0.25, 0, 0.25 } do
		P(f, { Name = "DestroyerEngine", Shape = CYL, Size = Vector3.new(thick * 0.8, thick * 1.1, thick * 1.1), CFrame = cf * CFrame.new(sx * W, thick * 0.6, L * 0.5) * FWD, Color = DARK, Material = M.Metal })
	end
end

local function redwood(f: Instance, at: Vector3, h: number, d: number, rng: Random)
	P(f, { Name = "Trunk", Shape = CYL, Size = Vector3.new(h, d, d), CFrame = CFrame.new(at + Vector3.new(0, h / 2 - 4, 0)) * UP, Color = Color3.fromRGB(105, 65, 45), Material = M.Wood })
	for i = 1, 5 do
		local s = rng:NextNumber(d * 2.5, d * 4)
		P(f, { Name = "Canopy", Shape = BALL, Size = Vector3.new(s, s, s), CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-d, d), h - 8 + rng:NextNumber(-10, 6), rng:NextNumber(-d, d))), Color = Color3.fromRGB(45, 95 + i * 6, 45), Material = M.Grass })
	end
end

local function treehouse(f: Instance, at: Vector3, trunkD: number, height: number)
	P(f, { Name = "TreePlatform", Shape = CYL, Size = Vector3.new(1.5, trunkD + 20, trunkD + 20), CFrame = CFrame.new(at + Vector3.new(0, height, 0)) * UP, Color = Color3.fromRGB(130, 90, 55), Material = M.WoodPlanks })
	for i = 1, 3 do
		local a = i * 2.1
		local hp = at + Vector3.new(math.cos(a) * (trunkD / 2 + 6), height + 3.5, math.sin(a) * (trunkD / 2 + 6))
		P(f, { Name = "Hut", Shape = CYL, Size = Vector3.new(6, 7, 7), CFrame = CFrame.new(hp) * UP, Color = Color3.fromRGB(150, 110, 70), Material = M.Wood })
		P(f, { Name = "HutRoof", Shape = BALL, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(hp + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(170, 140, 80), Material = M.Fabric })
	end
	local fire = P(f, { Name = "Torch", Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(at + Vector3.new(trunkD / 2 + 3, height + 2, 0)), Color = Color3.fromRGB(255, 170, 60), Material = M.Neon })
	light(fire, Color3.fromRGB(255, 170, 80), 24, 2)
end

-- Planet themes ----------------------------------------------------------------------------------
local Themes: { [number]: (Folder, Worlds.World, Random) -> () } = {}

-- 1. Junkku: crashed star destroyer, fallen walker, wrecked fighters
Themes[1] = function(f, world, rng)
	local o = world.origin
	starDestroyer(f, CFrame.new(o + Vector3.new(60, 10, -660)) * CFrame.Angles(math.rad(8), math.rad(160), math.rad(-14)), 700)
	-- a fallen walker you can climb on (someone made it their home)
	atat(f, CFrame.new(o + Vector3.new(-250, -6, -40)) * CFrame.Angles(0, math.rad(70), math.rad(-80)), 1)
	xWing(f, CFrame.new(o + Vector3.new(230, 3, 60)) * CFrame.Angles(math.rad(-10), math.rad(40), math.rad(25)), 1)
	tie(f, CFrame.new(o + Vector3.new(-120, 4, 250)) * CFrame.Angles(math.rad(30), math.rad(20), math.rad(40)), 1.4)
	for i = 1, 10 do
		local x, z = ring(rng, 240, 300)
		local y = heightAt(world, x, z)
		P(f, { Name = "Debris", Size = Vector3.new(rng:NextNumber(10, 30), rng:NextNumber(3, 8), rng:NextNumber(8, 20)), CFrame = CFrame.new(o + Vector3.new(x, y + 1, z)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)), Color = Color3.fromRGB(130, 125, 120), Material = M.CorrodedMetal })
	end
	-- scavenger market stalls near the hub
	for i = 1, 6 do
		local a = math.rad(200 + i * 22)
		local at = o + Vector3.new(math.cos(a) * 95, 0, math.sin(a) * 95)
		P(f, { Name = "StallPole", Size = Vector3.new(1, 10, 1), CFrame = CFrame.new(at + Vector3.new(0, 5, 0)), Color = Color3.fromRGB(110, 80, 50), Material = M.Wood })
		P(f, { Name = "Awning", Size = Vector3.new(14, 0.5, 10), CFrame = CFrame.new(at + Vector3.new(0, 10, 0)) * CFrame.Angles(0.15, a, 0), Color = if i % 2 == 0 then Color3.fromRGB(220, 200, 160) else Color3.fromRGB(160, 120, 80), Material = M.Fabric })
	end
	local dust = P(f, { Name = "Dust", Size = Vector3.new(PLAY_SIZE, 1, PLAY_SIZE), CFrame = CFrame.new(o + Vector3.new(0, 50, 0)), Transparency = 1, CanCollide = false })
	particles(dust, { Rate = 30, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(2, 5), Size = NumberSequence.new(1.5), Transparency = NumberSequence.new(0.75), Color = ColorSequence.new(world.colors.fog), EmissionDirection = Enum.NormalId.Bottom })
end

-- 2. Sigmatooine: twin suns, domed spaceport, moisture farms, sandcrawler, freighter
Themes[2] = function(f, world, rng)
	local o = world.origin
	P(f, { Name = "SunA", Shape = BALL, Size = Vector3.new(120, 120, 120), CFrame = CFrame.new(o + Vector3.new(-300, 520, -1500)), Color = Color3.fromRGB(255, 240, 190), Material = M.Neon, CanCollide = false, CastShadow = false })
	P(f, { Name = "SunB", Shape = BALL, Size = Vector3.new(80, 80, 80), CFrame = CFrame.new(o + Vector3.new(-80, 440, -1500)), Color = Color3.fromRGB(255, 190, 120), Material = M.Neon, CanCollide = false, CastShadow = false })
	for i = 1, 14 do
		local x, z = ring(rng, 110, 230)
		local s = rng:NextNumber(18, 34)
		local y = heightAt(world, x, z)
		P(f, { Name = "Dome", Shape = BALL, Size = Vector3.new(s, s, s), CFrame = CFrame.new(o + Vector3.new(x, y, z)), Color = Color3.fromRGB(232, 215, 185), Material = M.Plaster })
		P(f, { Name = "DomeDoor", Size = Vector3.new(5, 7, 3), CFrame = CFrame.lookAt(o + Vector3.new(x, y + 3.5, z), o) * CFrame.new(0, 0, -s / 2 + 1), Color = Color3.fromRGB(90, 70, 50), Material = M.Wood })
		if i % 3 == 0 then
			P(f, { Name = "AdobeBlock", Size = Vector3.new(s * 0.8, s * 0.35, s * 0.6), CFrame = CFrame.new(o + Vector3.new(x + s * 0.6, y + s * 0.17, z)), Color = Color3.fromRGB(220, 200, 165), Material = M.Plaster })
		end
	end
	for i = 1, 12 do
		local x, z = ring(rng, 240, 300)
		local y = heightAt(world, x, z)
		local base = o + Vector3.new(x, y, z)
		P(f, { Name = "Vaporator", Shape = CYL, Size = Vector3.new(18, 2.2, 2.2), CFrame = CFrame.new(base + Vector3.new(0, 9, 0)) * UP, Color = Color3.fromRGB(190, 190, 185), Material = M.Metal })
		for k = 1, 3 do
			P(f, { Name = "VaporatorRing", Shape = CYL, Size = Vector3.new(0.6, 4 - k * 0.6, 4 - k * 0.6), CFrame = CFrame.new(base + Vector3.new(0, 6 + k * 3.5, 0)) * UP, Color = DARK, Material = M.Metal })
		end
	end
	-- sandcrawler
	local sc = CFrame.new(o + Vector3.new(-230, heightAt(world, -230, 160) + 10, 160)) * CFrame.Angles(0, math.rad(30), 0)
	P(f, { Name = "CrawlerBody", Size = Vector3.new(50, 24, 80), CFrame = sc * CFrame.new(0, 14, 0), Color = Color3.fromRGB(160, 110, 70), Material = M.CorrodedMetal })
	P(f, { ClassName = "WedgePart", Name = "CrawlerFront", Size = Vector3.new(50, 24, 22), CFrame = sc * CFrame.new(0, 14, -51), Color = Color3.fromRGB(150, 100, 60), Material = M.CorrodedMetal })
	P(f, { Name = "CrawlerTop", Size = Vector3.new(36, 14, 46), CFrame = sc * CFrame.new(0, 33, 10), Color = Color3.fromRGB(165, 115, 75), Material = M.CorrodedMetal })
	for _, sx in { -22, 22 } do
		P(f, { Name = "CrawlerTread", Size = Vector3.new(10, 8, 84), CFrame = sc * CFrame.new(sx, -1, 0), Color = DARK, Material = M.DiamondPlate })
	end
	freighter(f, CFrame.new(o + Vector3.new(190, 8, -170)) * CFrame.Angles(0, math.rad(-35), 0), 1.2)
	local wind = P(f, { Name = "Sandstorm", Size = Vector3.new(PLAY_SIZE, 1, PLAY_SIZE), CFrame = CFrame.new(o + Vector3.new(0, 25, 0)), Transparency = 1, CanCollide = false })
	particles(wind, { Rate = 50, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(30, 50), Size = NumberSequence.new(0.5), Transparency = NumberSequence.new(0.6), Color = ColorSequence.new(world.colors.ground), EmissionDirection = Enum.NormalId.Right })
end

-- 3. Hothdog: rebel base in the ice, walkers on the ridge, X-wings in the hangar
Themes[3] = function(f, world, rng)
	local o = world.origin
	-- Echo-style hangar carved into an ice cliff
	local back = o + Vector3.new(0, 0, -250)
	P(f, { Name = "IceCliff", Size = Vector3.new(300, 90, 60), CFrame = CFrame.new(back + Vector3.new(0, 40, -20)), Color = Color3.fromRGB(200, 225, 245), Material = M.Glacier })
	P(f, { Name = "HangarMouth", Size = Vector3.new(110, 46, 4), CFrame = CFrame.new(back + Vector3.new(0, 23, 11)), Color = Color3.fromRGB(35, 40, 50), Material = M.Metal })
	P(f, { Name = "BlastDoor", Size = Vector3.new(112, 12, 5), CFrame = CFrame.new(back + Vector3.new(0, 42, 12)), Color = GREY, Material = M.DiamondPlate })
	for i = -2, 2 do
		local lamp = P(f, { Name = "HangarLight", Size = Vector3.new(10, 1, 1), CFrame = CFrame.new(back + Vector3.new(i * 22, 38, 14)), Color = Color3.fromRGB(255, 240, 200), Material = M.Neon })
		light(lamp, Color3.fromRGB(255, 240, 200), 30, 1.5)
	end
	for i = -1, 1 do
		xWing(f, CFrame.new(back + Vector3.new(i * 34, 6, 40)) * CFrame.Angles(0, math.rad(180), 0), 0.9)
	end
	-- walkers advancing over the snow
	for i, x in { -180, 190 } do
		local z = -60 - i * 90
		atat(f, CFrame.new(o + Vector3.new(x, heightAt(world, x, z) - 2, z)) * CFrame.Angles(0, math.rad(150 + i * 20), 0), 1.4)
	end
	-- shield generator dish
	local g = o + Vector3.new(230, heightAt(world, 230, 180), 180)
	P(f, { Name = "GeneratorBase", Shape = CYL, Size = Vector3.new(12, 20, 20), CFrame = CFrame.new(g + Vector3.new(0, 6, 0)) * UP, Color = GREY, Material = M.Metal })
	P(f, { Name = "GeneratorDish", Shape = BALL, Size = Vector3.new(34, 34, 34), CFrame = CFrame.new(g + Vector3.new(0, 26, 0)), Color = WHITE, Material = M.SmoothPlastic })
	P(f, { Name = "GeneratorCore", Shape = BALL, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(g + Vector3.new(0, 44, 0)), Color = Color3.fromRGB(120, 210, 255), Material = M.Neon })
	-- trenches
	for i = -3, 3 do
		P(f, { Name = "Trench", Size = Vector3.new(30, 4, 3), CFrame = CFrame.new(o + Vector3.new(i * 34, 2, 150)) * CFrame.Angles(0, i * 0.05, 0), Color = Color3.fromRGB(220, 235, 250), Material = M.Snow })
	end
	for i = 1, 26 do
		local x, z = ring(rng, 150, 320)
		local h = rng:NextNumber(12, 40)
		P(f, { ClassName = "WedgePart", Name = "IceSpike", Size = Vector3.new(rng:NextNumber(6, 14), h, rng:NextNumber(6, 14)), CFrame = CFrame.new(o + Vector3.new(x, heightAt(world, x, z) + h / 2 - 3, z)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Color = Color3.fromRGB(170, 220, 255), Material = M.Ice, Transparency = 0.1 })
	end
	local snow = P(f, { Name = "Snowfall", Size = Vector3.new(PLAY_SIZE, 1, PLAY_SIZE), CFrame = CFrame.new(o + Vector3.new(0, 90, 0)), Transparency = 1, CanCollide = false })
	particles(snow, { Rate = 260, Lifetime = NumberRange.new(8, 10), Speed = NumberRange.new(10, 16), Size = NumberSequence.new(0.35), Color = ColorSequence.new(Color3.new(1, 1, 1)), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 25) })
end

-- 4. Endor, Ohio: giant redwoods, treehouse villages, bunker, two-legged walker
Themes[4] = function(f, world, rng)
	local o = world.origin
	local placed = 0
	local tries = 0
	while placed < 46 and tries < 400 do
		tries += 1
		local x, z = ring(rng, 95, 420)
		local d = rng:NextNumber(9, 16)
		local h = rng:NextNumber(130, 210)
		redwood(f, o + Vector3.new(x, heightAt(world, x, z), z), h, d, rng)
		if placed % 6 == 0 then
			treehouse(f, o + Vector3.new(x, heightAt(world, x, z), z), d, rng:NextNumber(35, 60))
		end
		placed += 1
	end
	-- shield bunker
	local b = o + Vector3.new(-200, heightAt(world, -200, -150), -150)
	P(f, { Name = "Bunker", Size = Vector3.new(50, 20, 34), CFrame = CFrame.new(b + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0.5, 0), Color = Color3.fromRGB(120, 125, 120), Material = M.Concrete })
	P(f, { Name = "BunkerDoor", Size = Vector3.new(14, 12, 1), CFrame = CFrame.new(b + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0.5, 0) * CFrame.new(0, -2, -17.1), Color = DARK, Material = M.DiamondPlate })
	P(f, { Name = "BunkerDish", Shape = CYL, Size = Vector3.new(1, 18, 18), CFrame = CFrame.new(b + Vector3.new(0, 24, 0)) * CFrame.Angles(0, 0, math.rad(60)), Color = GREY, Material = M.Metal })
	atst(f, CFrame.new(o + Vector3.new(150, heightAt(world, 150, -120), -120)) * CFrame.Angles(0, math.rad(200), 0), 1.3)
	-- ferns on the forest floor
	for i = 1, 60 do
		local x, z = ring(rng, 60, 300)
		local s = rng:NextNumber(4, 9)
		P(f, { Name = "Fern", Shape = BALL, Size = Vector3.new(s, s, s), CFrame = CFrame.new(o + Vector3.new(x, heightAt(world, x, z) + s * 0.2, z)), Color = Color3.fromRGB(60, 120 + i % 30, 50), Material = M.Grass, CanCollide = false })
	end
	local fireflies = P(f, { Name = "Fireflies", Size = Vector3.new(PLAY_SIZE, 30, PLAY_SIZE), CFrame = CFrame.new(o + Vector3.new(0, 20, 0)), Transparency = 1, CanCollide = false })
	particles(fireflies, { Rate = 25, Lifetime = NumberRange.new(4, 8), Speed = NumberRange.new(0.5, 2), LightEmission = 1, Size = NumberSequence.new(0.25), Color = ColorSequence.new(Color3.fromRGB(255, 240, 150)), SpreadAngle = Vector2.new(180, 180) })
end

-- 5. Bespin Bussin: tiered floating city above a sunset cloud sea
Themes[5] = function(f, world, rng)
	local o = world.origin
	P(f, { Name = "CityDeck", Shape = CYL, Size = Vector3.new(4, 660, 660), CFrame = CFrame.new(o + Vector3.new(0, -2, 0)) * UP, Color = Color3.fromRGB(235, 232, 236), Material = M.Marble })
	P(f, { Name = "DeckRing", Shape = CYL, Size = Vector3.new(3, 670, 670), CFrame = CFrame.new(o + Vector3.new(0, -3, 0)) * UP, Color = world.colors.accent, Material = M.Neon })
	for tier = 1, 5 do
		P(f, { Name = "Underside", Shape = CYL, Size = Vector3.new(30, 620 - tier * 110, 620 - tier * 110), CFrame = CFrame.new(o + Vector3.new(0, -20 - tier * 28, 0)) * UP, Color = Color3.fromRGB(215, 210, 215), Material = M.Metal })
	end
	P(f, { Name = "Stalk", Shape = CYL, Size = Vector3.new(220, 40, 40), CFrame = CFrame.new(o + Vector3.new(0, -260, 0)) * UP, Color = Color3.fromRGB(200, 195, 200), Material = M.Metal })
	-- elegant towers with domes
	for i = 1, 16 do
		local a = (i / 16) * math.pi * 2 + 0.2
		local r = if i % 2 == 0 then 270 else 230
		local h = rng:NextNumber(40, 120)
		local d = rng:NextNumber(18, 30)
		local at = o + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		P(f, { Name = "Tower", Shape = CYL, Size = Vector3.new(h, d, d), CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)) * UP, Color = Color3.fromRGB(245, 240, 240), Material = M.SmoothPlastic })
		P(f, { Name = "TowerDome", Shape = BALL, Size = Vector3.new(d, d, d), CFrame = CFrame.new(at + Vector3.new(0, h, 0)), Color = Color3.fromRGB(250, 235, 225), Material = M.SmoothPlastic })
		P(f, { Name = "TowerWindows", Shape = CYL, Size = Vector3.new(2, d + 0.4, d + 0.4), CFrame = CFrame.new(at + Vector3.new(0, h * 0.7, 0)) * UP, Color = world.colors.accent, Material = M.Neon })
	end
	-- landing pad with a freighter
	P(f, { Name = "LandingPad", Shape = CYL, Size = Vector3.new(2, 80, 80), CFrame = CFrame.new(o + Vector3.new(170, 1, -140)) * UP, Color = Color3.fromRGB(210, 205, 210), Material = M.DiamondPlate })
	freighter(f, CFrame.new(o + Vector3.new(170, 7, -140)) * CFrame.Angles(0, math.rad(30), 0), 1)
	-- cloud sea below + drifting cloud cars
	for i = 1, 50 do
		local x, z = ring(rng, 0, 1100)
		local s = rng:NextNumber(80, 180)
		P(f, { Name = "Cloud", Shape = BALL, Size = Vector3.new(s, s, s), CFrame = CFrame.new(o + Vector3.new(x, rng:NextNumber(-330, -200), z)), Color = Color3.fromRGB(255, 205, 190), Material = M.SmoothPlastic, Transparency = 0.2, CanCollide = false, CastShadow = false })
	end
	for i = 1, 8 do
		local x, z = ring(rng, 360, 600)
		local car = CFrame.new(o + Vector3.new(x, rng:NextNumber(20, 90), z)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		P(f, { Name = "CloudCar", Size = Vector3.new(4, 3, 12), CFrame = car, Color = Color3.fromRGB(200, 60, 40), Material = M.SmoothPlastic, CanCollide = false })
		P(f, { Name = "CloudCarPod", Shape = BALL, Size = Vector3.new(5, 5, 5), CFrame = car * CFrame.new(4, 0, 0), Color = Color3.fromRGB(210, 70, 50), Material = M.SmoothPlastic, CanCollide = false })
	end
end

-- 6. Mustafanum: lava valleys, collector arms, fortress on the edge of the fire
Themes[6] = function(f, world, rng)
	local o = world.origin
	P(f, { Name = "LavaSea", Size = Vector3.new(TERRAIN_HALF * 2, 2, TERRAIN_HALF * 2), CFrame = CFrame.new(o + Vector3.new(0, (world.terrain.waterLevel or -4) - 1, 0)), Color = Color3.fromRGB(255, 90, 20), Material = M.Neon, CanCollide = false })
	-- collector arms reaching over the lava
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local at = o + Vector3.new(math.cos(a) * 280, 0, math.sin(a) * 280)
		local y = heightAt(world, at.X - o.X, at.Z - o.Z)
		P(f, { Name = "CollectorTower", Size = Vector3.new(14, 90, 14), CFrame = CFrame.new(at + Vector3.new(0, y + 45, 0)), Color = Color3.fromRGB(45, 45, 50), Material = M.Metal })
		local arm = CFrame.lookAt(at + Vector3.new(0, y + 80, 0), o + Vector3.new(0, y + 80, 0)) * CFrame.new(0, 0, -25)
		P(f, { Name = "CollectorArm", Size = Vector3.new(6, 6, 50), CFrame = arm, Color = Color3.fromRGB(55, 55, 60), Material = M.Metal })
		local tip = P(f, { Name = "CollectorTip", Size = Vector3.new(8, 3, 8), CFrame = arm * CFrame.new(0, -3, -24), Color = Color3.fromRGB(255, 120, 40), Material = M.Neon })
		particles(tip, { Rate = 25, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(10, 20), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Color = ColorSequence.new(Color3.fromRGB(255, 180, 80)), EmissionDirection = Enum.NormalId.Bottom })
	end
	-- dark fortress on a spire
	local fz = o + Vector3.new(-60, 0, -330)
	P(f, { Name = "FortressRock", Size = Vector3.new(60, 120, 60), CFrame = CFrame.new(fz + Vector3.new(0, 40, 0)), Color = Color3.fromRGB(35, 30, 30), Material = M.Basalt })
	P(f, { Name = "Fortress", Size = Vector3.new(30, 60, 40), CFrame = CFrame.new(fz + Vector3.new(0, 130, 0)), Color = Color3.fromRGB(25, 25, 30), Material = M.Slate })
	P(f, { Name = "FortressWindow", Size = Vector3.new(31, 3, 20), CFrame = CFrame.new(fz + Vector3.new(0, 145, 0)), Color = Color3.fromRGB(255, 80, 30), Material = M.Neon })
	-- lavafalls
	for i = 1, 5 do
		local x, z = ring(rng, 330, 400)
		P(f, { Name = "Lavafall", Size = Vector3.new(10, 120, 4), CFrame = CFrame.lookAt(o + Vector3.new(x, 50, z), o + Vector3.new(0, 50, 0)), Color = Color3.fromRGB(255, 120, 30), Material = M.Neon, CanCollide = false })
	end
	local embers = P(f, { Name = "Embers", Size = Vector3.new(PLAY_SIZE, 1, PLAY_SIZE), CFrame = CFrame.new(o), Transparency = 1, CanCollide = false })
	particles(embers, { Rate = 80, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(4, 10), LightEmission = 1, Size = NumberSequence.new(0.3), Color = ColorSequence.new(world.colors.accent, Color3.fromRGB(255, 220, 120)), EmissionDirection = Enum.NormalId.Top })
end

-- 7. Coruscan't: skyline, temple with five spires, air-traffic lanes
Themes[7] = function(f, world, rng)
	local o = world.origin
	P(f, { Name = "CityPlaza", Size = Vector3.new(PLAY_SIZE + 40, 6, PLAY_SIZE + 40), CFrame = CFrame.new(o + Vector3.new(0, -3, 0)), Color = Color3.fromRGB(150, 155, 165), Material = M.Concrete })
	for gx = -4, 4 do
		P(f, { Name = "PlazaLine", Size = Vector3.new(1, 0.2, PLAY_SIZE), CFrame = CFrame.new(o + Vector3.new(gx * 70, 0.05, 0)), Color = Color3.fromRGB(120, 125, 135), Material = M.Concrete })
	end
	-- temple: stepped base + five spires
	local t = o + Vector3.new(0, 0, -220)
	for step = 0, 3 do
		local s = 140 - step * 28
		P(f, { Name = "TempleStep", Size = Vector3.new(s, 18, s), CFrame = CFrame.new(t + Vector3.new(0, 9 + step * 18, 0)), Color = Color3.fromRGB(205, 195, 175), Material = M.Limestone })
	end
	for _, off in { Vector3.new(0, 0, 0), Vector3.new(-26, 0, -26), Vector3.new(26, 0, -26), Vector3.new(-26, 0, 26), Vector3.new(26, 0, 26) } do
		local tall = off.Magnitude == 0
		local h = if tall then 120 else 80
		P(f, { Name = "Spire", Shape = CYL, Size = Vector3.new(h, if tall then 12 else 9, if tall then 12 else 9), CFrame = CFrame.new(t + off + Vector3.new(0, 72 + h / 2, 0)) * UP, Color = Color3.fromRGB(215, 205, 185), Material = M.Limestone })
		local tip = P(f, { Name = "SpireTip", Shape = BALL, Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(t + off + Vector3.new(0, 72 + h, 0)), Color = Color3.fromRGB(255, 215, 120), Material = M.Neon })
		light(tip, Color3.fromRGB(255, 215, 120), 40, 2)
	end
	-- skyline inside and far beyond the walls
	for i = 1, 90 do
		local x, z = ring(rng, if i <= 30 then 200 else 360, if i <= 30 then 320 else 900)
		if math.abs(x) < 90 and z < -150 then
			continue -- keep the temple view clear
		end
		local h = rng:NextNumber(120, 420)
		local w = rng:NextNumber(26, 60)
		local tower = P(f, { Name = "Skyscraper", Size = Vector3.new(w, h, w), CFrame = CFrame.new(o + Vector3.new(x, h / 2 - 60, z)), Color = Color3.fromRGB(70, 78, 98), Material = M.Glass, Reflectance = 0.15, CastShadow = false })
		for s = 1, math.floor(h / 40) do
			P(f, { Name = "Windows", Size = Vector3.new(w + 0.4, 1.6, w + 0.4), CFrame = tower.CFrame * CFrame.new(0, -h / 2 + s * 40, 0), Color = if s % 2 == 0 then world.colors.accent else world.colors.accent2, Material = M.Neon, CastShadow = false })
		end
	end
	-- air-traffic lanes of glowing speeders
	for lane = 1, 5 do
		for i = 1, 18 do
			P(f, { Name = "Speeder", Size = Vector3.new(3, 1.2, 7), CFrame = CFrame.new(o + Vector3.new(-420 + i * 47, 110 + lane * 30, -300 + lane * 110)), Color = if lane % 2 == 0 then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 240, 200), Material = M.Neon, CanCollide = false })
		end
	end
	freighter(f, CFrame.new(o + Vector3.new(-200, 160, 120)) * CFrame.Angles(0, math.rad(60), math.rad(10)), 1)
end

-- 8. The Sigma Star: panelled battle-station surface, trench, reactor beam, parked TIEs
Themes[8] = function(f, world, rng)
	local o = world.origin
	for gx = -5, 4 do
		for gz = -5, 4 do
			local shade = 62 + ((gx + gz) % 2) * 10 + rng:NextInteger(0, 6)
			P(f, { Name = "HullPanel", Size = Vector3.new(64, 4, 64), CFrame = CFrame.new(o + Vector3.new(gx * 64 + 32, -2, gz * 64 + 32)), Color = Color3.fromRGB(shade, shade + 2, shade + 8), Material = M.DiamondPlate })
		end
	end
	-- greebles & turrets
	for i = 1, 70 do
		local x, z = ring(rng, 120, 310)
		local h = rng:NextNumber(4, 30)
		P(f, { Name = "Greeble", Size = Vector3.new(rng:NextNumber(6, 24), h, rng:NextNumber(6, 24)), CFrame = CFrame.new(o + Vector3.new(x, h / 2, z)), Color = Color3.fromRGB(80, 82, 90), Material = M.Metal })
		if i % 7 == 0 then
			P(f, { Name = "Turret", Shape = BALL, Size = Vector3.new(10, 10, 10), CFrame = CFrame.new(o + Vector3.new(x, h + 3, z)), Color = GREY, Material = M.Metal })
			P(f, { Name = "TurretGun", Size = Vector3.new(1, 1, 14), CFrame = CFrame.new(o + Vector3.new(x, h + 5, z)) * CFrame.Angles(math.rad(30), rng:NextNumber(0, 6), 0), Color = DARK, Material = M.Metal })
		end
	end
	-- the trench
	for _, sx in { -1, 1 } do
		P(f, { Name = "TrenchWall", Size = Vector3.new(10, 60, 900), CFrame = CFrame.new(o + Vector3.new(sx * 360, 26, 0)), Color = Color3.fromRGB(75, 78, 86), Material = M.DiamondPlate })
		for k = -6, 6 do
			P(f, { Name = "TrenchLight", Size = Vector3.new(1, 2, 8), CFrame = CFrame.new(o + Vector3.new(sx * 354.5, 40, k * 70)), Color = Color3.fromRGB(255, 70, 70), Material = M.Neon })
		end
	end
	-- reactor shaft with an energy beam
	local r = o + Vector3.new(0, 0, -250)
	P(f, { Name = "ReactorRing", Shape = CYL, Size = Vector3.new(6, 70, 70), CFrame = CFrame.new(r + Vector3.new(0, 3, 0)) * UP, Color = DARK, Material = M.Metal })
	local beam = P(f, { Name = "ReactorBeam", Shape = CYL, Size = Vector3.new(600, 24, 24), CFrame = CFrame.new(r + Vector3.new(0, 300, 0)) * UP, Color = Color3.fromRGB(120, 255, 140), Material = M.Neon, Transparency = 0.25, CanCollide = false })
	light(beam, Color3.fromRGB(120, 255, 140), 60, 3)
	-- parked TIEs + a huge planet in the sky
	for i = -2, 2 do
		tie(f, CFrame.new(o + Vector3.new(i * 40, 12, 200)) * CFrame.Angles(0, math.rad(180), 0), 1)
	end
	P(f, { Name = "Planet", Shape = BALL, Size = Vector3.new(900, 900, 900), CFrame = CFrame.new(o + Vector3.new(-900, 500, -2400)), Color = Color3.fromRGB(90, 140, 220), Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
	P(f, { Name = "PlanetGlow", Shape = BALL, Size = Vector3.new(940, 940, 940), CFrame = CFrame.new(o + Vector3.new(-900, 500, -2400)), Color = Color3.fromRGB(160, 210, 255), Material = M.ForceField, CanCollide = false, CastShadow = false })
end

-- Foundry plots (Junkku only) -------------------------------------------------------------------
WorldBuilder.PLOT_COUNT = 10
WorldBuilder.PLOT_RADIUS = 175

local function buildPlot(parent: Instance, index: number, world: Worlds.World): Model
	local a = (index / WorldBuilder.PLOT_COUNT) * math.pi * 2
	local center = world.origin + Vector3.new(math.cos(a) * WorldBuilder.PLOT_RADIUS, 0, math.sin(a) * WorldBuilder.PLOT_RADIUS)
	local facing = CFrame.lookAt(center, world.origin * Vector3.new(1, 0, 1))
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	local pad = P(m, { Name = "Pad", Shape = CYL, Size = Vector3.new(1.2, 58, 58), CFrame = facing * CFrame.new(0, 0.6, 0) * UP, Color = Color3.fromRGB(120, 122, 130), Material = M.DiamondPlate })
	P(m, { Name = "Border", Shape = CYL, Size = Vector3.new(1, 60, 60), CFrame = facing * CFrame.new(0, 0.4, 0) * UP, Color = Color3.fromRGB(80, 200, 255), Material = M.Neon })
	P(m, { Name = "PlotSpawn", Size = Vector3.new(6, 1, 6), CFrame = facing * CFrame.new(0, 1.3, -18), Transparency = 1, CanCollide = false })
	local sign = P(m, { Name = "Sign", Size = Vector3.new(18, 6, 1), CFrame = facing * CFrame.new(0, 11, -29), Color = Color3.fromRGB(35, 38, 48), Material = M.Metal })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 90)
	label.Text = "EMPTY FOUNDRY"
	label.Parent = gui
	gui.Parent = sign
	P(m, { Name = "SignPost", Size = Vector3.new(1, 8, 1), CFrame = facing * CFrame.new(0, 4, -29.2), Color = DARK, Material = M.Metal })

	local dyn = Instance.new("Folder")
	dyn.Name = "Dynamic"
	dyn.Parent = m
	m.PrimaryPart = pad
	m:SetAttribute("PlotIndex", index)
	m.Parent = parent
	return m
end

-- A plot's "facing" frame: centred on the pad, -Z pointing at the hub (where the sign is).
function WorldBuilder.PlotFacing(plot: Model): CFrame
	local pad = plot.PrimaryPart :: BasePart
	local sign = plot:FindFirstChild("Sign") :: BasePart
	return CFrame.lookAt(pad.Position, pad.Position + (sign.Position - pad.Position) * Vector3.new(1, 0, 1))
end

-- Rebuilds the visible foundry for a plot from upgrade levels.
function WorldBuilder.DecoratePlot(plot: Model, upgrades: { [string]: number }, accent: Color3)
	local dyn = plot:FindFirstChild("Dynamic") :: Folder
	dyn:ClearAllChildren()
	local base = WorldBuilder.PlotFacing(plot)

	-- Hangar grows with Assembly Line level
	local assembly = upgrades.Assembly or 0
	local h = 12 + math.min(assembly, 30) * 1.3
	P(dyn, { Name = "Hangar", Size = Vector3.new(24, h, 16), CFrame = base * CFrame.new(0, 1.2 + h / 2, 15), Color = Color3.fromRGB(150, 145, 140), Material = M.Metal })
	P(dyn, { Name = "HangarRoof", Shape = CYL, Size = Vector3.new(24, 16, 16), CFrame = base * CFrame.new(0, 1.2 + h, 15), Color = Color3.fromRGB(165, 160, 155), Material = M.Metal })
	P(dyn, { Name = "HangarDoor", Size = Vector3.new(12, 9, 0.6), CFrame = base * CFrame.new(0, 5.7, 6.8), Color = accent, Material = M.Neon })
	local antennas = 1 + math.min(assembly // 5, 4)
	for i = 1, antennas do
		P(dyn, { Name = "Antenna", Shape = CYL, Size = Vector3.new(10, 0.8, 0.8), CFrame = base * CFrame.new(-9 + (i - 1) * 4.5, 1.2 + h + 12, 18) * UP, Color = Color3.fromRGB(90, 90, 95), Material = M.Metal })
		P(dyn, { Name = "AntennaLight", Shape = BALL, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = base * CFrame.new(-9 + (i - 1) * 4.5, 1.2 + h + 17.5, 18), Color = Color3.fromRGB(255, 70, 70), Material = M.Neon })
	end
	-- Salvage Claws: crane arms (one per 5 levels, max 4)
	local claws = upgrades.Claws or 0
	for i = 1, math.min(1 + claws // 5, 4) do
		local x = if i % 2 == 0 then 21 else -21
		local z = if i <= 2 then 16 else -2
		P(dyn, { Name = "ClawMast", Size = Vector3.new(1.6, 18, 1.6), CFrame = base * CFrame.new(x, 10, z), Color = Color3.fromRGB(230, 160, 40), Material = M.Metal })
		P(dyn, { Name = "ClawArm", Size = Vector3.new(1.4, 1.4, 12), CFrame = base * CFrame.new(x, 18.5, z - 5), Color = Color3.fromRGB(230, 160, 40), Material = M.Metal })
	end
	-- Station Bay: one docking light per level
	for i = 1, upgrades.Bay or 0 do
		P(dyn, { Name = "BayLight", Shape = BALL, Size = Vector3.new(2, 2, 2), CFrame = base * CFrame.new(-21 + i * 4.6, 2, 25), Color = Color3.fromRGB(80, 255, 140), Material = M.Neon })
	end
	-- Showcase pods (droids are placed on these by WorldService)
	for i = 1, 4 do
		P(dyn, { Name = "ShowcasePod" .. i, Shape = CYL, Size = Vector3.new(1, 7, 7), CFrame = base * CFrame.new(-15 + (i - 1) * 10, 1.5, -4) * UP, Color = accent, Material = M.Neon })
	end
end

-- Build everything ------------------------------------------------------------------------------
local function buildWorld(worldsFolder: Folder, world: Worlds.World)
	local wf = folder(worldsFolder, "World" .. world.index)
	wf:SetAttribute("WorldIndex", world.index)
	local rng = Random.new(world.index * 1337)
	local o = world.origin

	if world.terrain.kind == "terrain" then
		generateTerrain(world)
	end
	-- invisible boundary walls
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		P(wf, {
			Name = "Boundary",
			Size = if d.X ~= 0 then Vector3.new(4, 500, PLAY_SIZE) else Vector3.new(PLAY_SIZE, 500, 4),
			CFrame = CFrame.new(o + d * HALF + Vector3.new(0, 200, 0)),
			Transparency = 1,
		})
	end
	-- safety floor under the hub so nobody falls through while terrain is generating
	P(wf, { Name = "HubFloor", Shape = CYL, Size = Vector3.new(1, 150, 150), CFrame = CFrame.new(o + Vector3.new(0, -0.6, 0)) * UP, Transparency = 1 })

	local spawn = P(wf, { Name = "Spawn", Shape = CYL, Size = Vector3.new(0.4, 16, 16), CFrame = CFrame.new(o + Vector3.new(0, 0.2, 70)) * UP, Color = world.colors.accent, Material = M.Neon, Transparency = 0.3, CanCollide = false })
	spawn:SetAttribute("Spawn", true)
	local signPart = P(wf, { Name = "WorldSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(o + Vector3.new(0, 36, -10)), Transparency = 1, CanCollide = false })
	billboard(signPart, world.icon .. " " .. string.upper(world.name), Color3.fromRGB(255, 225, 90), UDim2.fromOffset(700, 120), 0)

	buildCrateTerminal(wf, o + Vector3.new(-32, 0, 20), world)
	buildHyperGate(wf, o + Vector3.new(32, 0, 20), world)

	local piles = folder(wf, "ScrapPiles")
	for _ = 1, 16 do
		local x, z = ring(rng, 50, if world.index == 1 then 135 else 210)
		buildScrapPile(piles, o + Vector3.new(x, heightAt(world, x, z), z), world, rng)
	end

	local props = folder(wf, "Props")
	Themes[world.index](props, world, rng)

	if world.index == 1 then
		local plots = folder(wf, "Plots")
		for i = 1, WorldBuilder.PLOT_COUNT do
			local plot = buildPlot(plots, i, world)
			WorldBuilder.DecoratePlot(plot, {}, Color3.fromRGB(80, 200, 255))
		end
	end
end

function WorldBuilder.Build(): Folder
	local existing = workspace:FindFirstChild("Worlds") :: Folder?
	if existing then
		return existing
	end
	local worldsFolder = folder(workspace, "Worlds")
	-- Terrain generation yields every few hundred columns, so this takes a
	-- couple of seconds at server start but never freezes the server.
	for _, world in Worlds.List do
		buildWorld(worldsFolder, world)
	end
	return worldsFolder
end

return WorldBuilder
