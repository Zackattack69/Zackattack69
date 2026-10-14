--!strict
-- Procedurally builds the greybox for all 8 worlds (Design Doc §9.1) so the
-- place file needs no hand-built map to be playable. Swap any world's props for
-- hand-built art later — gameplay only relies on the tagged parts:
--   "Spawn" (Part), "CrateTerminal" (Part w/ ProximityPrompt),
--   "HyperGate" (Part w/ ProximityPrompt), "ScrapPile" (Model w/ ClickDetector)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)

local WorldBuilder = {}

local GROUND_SIZE = 640
local HALF = GROUND_SIZE / 2

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

local function billboard(adornee: BasePart, text: string, color: Color3, size: UDim2, offset: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = Vector3.new(0, offset, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 400
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
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

-- Shared world furniture -----------------------------------------------------------
local function buildScrapPile(parent: Instance, at: Vector3, world: Worlds.World, rng: Random)
	local m = Instance.new("Model")
	m.Name = "ScrapPile"
	local hit = P(m, {
		Name = "Hitbox",
		Size = Vector3.new(9, 6, 9),
		CFrame = CFrame.new(at + Vector3.new(0, 3, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	for i = 1, 7 do
		local s = rng:NextNumber(1.2, 3.2)
		P(m, {
			Name = "Chunk",
			Size = Vector3.new(s * rng:NextNumber(0.8, 2), s * 0.6, s),
			CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-3, 3), s * 0.3 + (i // 3) * 1.1, rng:NextNumber(-3, 3)))
				* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6.28), rng:NextNumber(0, 1)),
			Color = if i % 3 == 0 then world.colors.accent else Color3.fromRGB(110, 100, 95):Lerp(world.colors.accent2, 0.3),
			Material = if i % 3 == 0 then Enum.Material.Neon else Enum.Material.CorrodedMetal,
			CanCollide = false,
		})
	end
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 60
	cd.Parent = hit
	m.PrimaryPart = hit
	m:SetAttribute("ScrapPile", true)
	m.Parent = parent
	return m
end

local function buildCrateTerminal(parent: Instance, at: Vector3, world: Worlds.World)
	local base = P(parent, {
		Name = "CrateTerminalBase",
		Size = Vector3.new(16, 2, 16),
		CFrame = CFrame.new(at + Vector3.new(0, 1, 0)),
		Color = Color3.fromRGB(50, 52, 60),
		Material = Enum.Material.DiamondPlate,
	})
	local ring = P(parent, {
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 17, 17),
		CFrame = CFrame.new(at + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = world.colors.accent,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	ring.Transparency = 0.2
	local crate = P(parent, {
		Name = "CrateTerminal",
		Size = Vector3.new(7, 7, 7),
		CFrame = CFrame.new(at + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = Color3.fromRGB(70, 75, 90),
		Material = Enum.Material.Metal,
	})
	for _, axis in { Vector3.new(7.3, 0.6, 0.6), Vector3.new(0.6, 7.3, 0.6), Vector3.new(0.6, 0.6, 7.3) } do
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				local off
				if axis.X > 1 then
					off = Vector3.new(0, sx * 3.5, sy * 3.5)
				elseif axis.Y > 1 then
					off = Vector3.new(sx * 3.5, 0, sy * 3.5)
				else
					off = Vector3.new(sx * 3.5, sy * 3.5, 0)
				end
				P(parent, {
					Name = "CrateEdge",
					Size = axis,
					CFrame = crate.CFrame * CFrame.new(off),
					Color = world.colors.accent,
					Material = Enum.Material.Neon,
					CanCollide = false,
				})
			end
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Crates"
	prompt.ObjectText = world.name .. " Crate Terminal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = crate
	crate:SetAttribute("Terminal", "Crates")
	billboard(base, "📦 CRATES", world.colors.accent, UDim2.fromOffset(220, 60), 13)
	return crate
end

local function buildHyperGate(parent: Instance, at: Vector3, world: Worlds.World)
	local segments = 20
	local radius = 14
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		P(parent, {
			Name = "GateRing",
			Size = Vector3.new(3, 4.6, 3),
			CFrame = CFrame.new(at + Vector3.new(math.cos(a) * radius, radius + 2 + math.sin(a) * radius, 0)) * CFrame.Angles(0, 0, a),
			Color = if i % 2 == 0 then Color3.fromRGB(60, 64, 76) else world.colors.accent2,
			Material = if i % 2 == 0 then Enum.Material.Metal else Enum.Material.Neon,
		})
	end
	local portal = P(parent, {
		Name = "HyperGate",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, radius * 2 - 3, radius * 2 - 3),
		CFrame = CFrame.new(at + Vector3.new(0, radius + 2, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.ForceField,
		CanCollide = false,
	})
	particles(portal, {
		Rate = 25,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(10, 20),
		LightEmission = 1,
		Size = NumberSequence.new(0.4, 0),
		Color = ColorSequence.new(Color3.fromRGB(180, 230, 255)),
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Jump to Hyperspace"
	prompt.ObjectText = "Hyperspace Gate"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	portal:SetAttribute("Terminal", "Map")
	billboard(portal, "🌌 HYPERSPACE", Color3.fromRGB(170, 220, 255), UDim2.fromOffset(260, 60), radius + 4)
	return portal
end

-- Theme props per world ----------------------------------------------------------------
local Themes: { [number]: (Folder, Worlds.World, Random) -> () } = {}

local function ring(rng: Random, minR: number, maxR: number): (number, number)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(minR, maxR)
	return math.cos(a) * r, math.sin(a) * r
end

-- 1. The Scrapyard: crashed freighters, cranes
Themes[1] = function(f, world, rng)
	local o = world.origin
	for i = 1, 9 do
		local x, z = ring(rng, 235, 290)
		local base = CFrame.new(o + Vector3.new(x, 6, z)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35))
		local len = rng:NextNumber(40, 80)
		P(f, { Name = "Hull", Size = Vector3.new(18, 14, len), CFrame = base, Color = Color3.fromRGB(130, 110, 95), Material = Enum.Material.CorrodedMetal })
		P(f, { ClassName = "WedgePart", Name = "Nose", Size = Vector3.new(18, 14, 16), CFrame = base * CFrame.new(0, 0, -len / 2 - 8) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(120, 100, 85), Material = Enum.Material.CorrodedMetal })
		for _, sx in { -5, 5 } do
			P(f, { Name = "Engine", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 8, 8), CFrame = base * CFrame.new(sx, 0, len / 2 + 4) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(80, 75, 70), Material = Enum.Material.Metal })
			P(f, { Name = "EngineGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6, 6), CFrame = base * CFrame.new(sx, 0, len / 2 + 9.1) * CFrame.Angles(0, math.rad(90), 0), Color = world.colors.accent, Material = Enum.Material.Neon })
		end
	end
	for i = 1, 4 do
		local x, z = ring(rng, 215, 230)
		local at = o + Vector3.new(x, 0, z)
		P(f, { Name = "CraneMast", Size = Vector3.new(3, 70, 3), CFrame = CFrame.new(at + Vector3.new(0, 35, 0)), Color = Color3.fromRGB(230, 160, 40), Material = Enum.Material.Metal })
		P(f, { Name = "CraneArm", Size = Vector3.new(3, 3, 50), CFrame = CFrame.new(at + Vector3.new(0, 69, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.new(0, 0, -20), Color = Color3.fromRGB(230, 160, 40), Material = Enum.Material.Metal })
	end
	local dust = P(f, { Name = "Dust", Size = Vector3.new(GROUND_SIZE, 1, GROUND_SIZE), CFrame = CFrame.new(o + Vector3.new(0, 60, 0)), Transparency = 1, CanCollide = false })
	particles(dust, { Rate = 40, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(2, 5), Size = NumberSequence.new(1.5), Transparency = NumberSequence.new(0.7), Color = ColorSequence.new(world.colors.fog), EmissionDirection = Enum.NormalId.Bottom })
end

-- 2. Undercroft: cavern ceiling, neon pillars and signs
Themes[2] = function(f, world, rng)
	local o = world.origin
	P(f, { Name = "Ceiling", Size = Vector3.new(GROUND_SIZE, 10, GROUND_SIZE), CFrame = CFrame.new(o + Vector3.new(0, 140, 0)), Color = Color3.fromRGB(25, 22, 35), Material = Enum.Material.Rock })
	for i = 1, 26 do
		local x, z = ring(rng, 90, 300)
		local h = rng:NextNumber(30, 135)
		local c = if i % 2 == 0 then world.colors.accent else world.colors.accent2
		P(f, { Name = "Tower", Size = Vector3.new(rng:NextNumber(12, 26), h, rng:NextNumber(12, 26)), CFrame = CFrame.new(o + Vector3.new(x, h / 2, z)), Color = Color3.fromRGB(35, 32, 50), Material = Enum.Material.Concrete })
		P(f, { Name = "NeonStrip", Size = Vector3.new(1, h * 0.8, 1), CFrame = CFrame.new(o + Vector3.new(x, h * 0.45, z)) * CFrame.new(0, 0, -7), Color = c, Material = Enum.Material.Neon })
		if i % 3 == 0 then
			P(f, { Name = "Sign", Size = Vector3.new(14, 5, 0.6), CFrame = CFrame.new(o + Vector3.new(x, h * 0.6, z)) * CFrame.new(0, 0, -8), Color = c, Material = Enum.Material.Neon })
		end
	end
	for i = 1, 14 do
		local x, z = ring(rng, 30, 280)
		P(f, { Name = "Stalactite", ClassName = "WedgePart", Size = Vector3.new(6, 24, 6), CFrame = CFrame.new(o + Vector3.new(x, 123, z)) * CFrame.Angles(math.rad(180), rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(40, 35, 55), Material = Enum.Material.Rock })
	end
end

-- 3. Duneport: dunes, domed huts, twin suns
Themes[3] = function(f, world, rng)
	local o = world.origin
	for i = 1, 18 do
		local x, z = ring(rng, 210, 330)
		local s = rng:NextNumber(60, 120)
		P(f, { Name = "Dune", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), CFrame = CFrame.new(o + Vector3.new(x, -s * 0.38, z)), Color = world.colors.ground, Material = Enum.Material.Sand })
	end
	for i = 1, 10 do
		local x, z = ring(rng, 120, 200)
		local s = rng:NextNumber(18, 30)
		P(f, { Name = "Hut", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), CFrame = CFrame.new(o + Vector3.new(x, 0, z)), Color = Color3.fromRGB(225, 205, 170), Material = Enum.Material.Plaster })
		P(f, { Name = "Door", Size = Vector3.new(5, 7, 3), CFrame = CFrame.lookAt(o + Vector3.new(x, 3.5, z), o) * CFrame.new(0, 0, -s / 2 + 1), Color = Color3.fromRGB(80, 60, 40), Material = Enum.Material.Wood })
	end
	for i = 1, 8 do
		local x, z = ring(rng, 70, 110)
		local at = o + Vector3.new(x, 0, z)
		P(f, { Name = "StallPole", Size = Vector3.new(1, 10, 1), CFrame = CFrame.new(at + Vector3.new(0, 5, 0)), Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.Wood })
		P(f, { Name = "Awning", Size = Vector3.new(12, 0.5, 10), CFrame = CFrame.new(at + Vector3.new(0, 10, 0)) * CFrame.Angles(0.15, 0, 0), Color = if i % 2 == 0 then world.colors.accent else Color3.fromRGB(200, 60, 60), Material = Enum.Material.Fabric })
	end
	P(f, { Name = "SunA", Shape = Enum.PartType.Ball, Size = Vector3.new(80, 80, 80), CFrame = CFrame.new(o + Vector3.new(-160, 380, -900)), Color = Color3.fromRGB(255, 230, 150), Material = Enum.Material.Neon, CanCollide = false })
	P(f, { Name = "SunB", Shape = Enum.PartType.Ball, Size = Vector3.new(50, 50, 50), CFrame = CFrame.new(o + Vector3.new(30, 330, -900)), Color = Color3.fromRGB(255, 170, 110), Material = Enum.Material.Neon, CanCollide = false })
	local wind = P(f, { Name = "Sandstorm", Size = Vector3.new(GROUND_SIZE, 1, GROUND_SIZE), CFrame = CFrame.new(o + Vector3.new(0, 25, 0)), Transparency = 1, CanCollide = false })
	particles(wind, { Rate = 60, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(30, 50), Size = NumberSequence.new(0.6), Transparency = NumberSequence.new(0.5), Color = ColorSequence.new(world.colors.ground), EmissionDirection = Enum.NormalId.Right })
end

-- 4. Cloud Reach: floating platform over a cloud sea, gas-mining towers
Themes[4] = function(f, world, rng)
	local o = world.origin
	for i = 1, 40 do
		local x, z = ring(rng, 0, 700)
		local s = rng:NextNumber(60, 140)
		P(f, { Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), CFrame = CFrame.new(o + Vector3.new(x, rng:NextNumber(-200, -90), z)), Color = Color3.fromRGB(255, 220, 220), Material = Enum.Material.SmoothPlastic, Transparency = 0.25, CanCollide = false })
	end
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local at = o + Vector3.new(math.cos(a) * 270, 0, math.sin(a) * 270)
		P(f, { Name = "GasTower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(90, 14, 14), CFrame = CFrame.new(at + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.Metal })
		P(f, { Name = "GasGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(16, 16, 16), CFrame = CFrame.new(at + Vector3.new(0, 92, 0)), Color = world.colors.accent, Material = Enum.Material.Neon })
	end
	-- Under-hull of the floating city
	P(f, { Name = "Hull", Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, GROUND_SIZE * 0.9, GROUND_SIZE * 0.9), CFrame = CFrame.new(o + Vector3.new(0, -45, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 190, 205), Material = Enum.Material.Metal })
end

-- 5. The Hatchery: rows of glowing pods, conveyor belts, rock spires
Themes[5] = function(f, world, rng)
	local o = world.origin
	for row = -3, 3 do
		for col = 1, 2 do
			local side = if col == 1 then -1 else 1
			local at = o + Vector3.new(side * rng:NextNumber(150, 250), 0, row * 70)
			P(f, { Name = "Pod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(18, 12, 12), CFrame = CFrame.new(at + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 50, 40), Material = Enum.Material.Metal })
			P(f, { Name = "PodGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(10, 10, 10), CFrame = CFrame.new(at + Vector3.new(0, 19, 0)), Color = world.colors.accent, Material = Enum.Material.Neon, Transparency = 0.15 })
		end
	end
	for i = -2, 2 do
		P(f, { Name = "Conveyor", Size = Vector3.new(10, 2, 420), CFrame = CFrame.new(o + Vector3.new(100 + i * 14, 1, 0)), Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.DiamondPlate })
	end
	for i = 1, 12 do
		local x, z = ring(rng, 250, 320)
		local h = rng:NextNumber(40, 110)
		P(f, { Name = "Spire", ClassName = "WedgePart", Size = Vector3.new(20, h, 20), CFrame = CFrame.new(o + Vector3.new(x, h / 2, z)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(130, 60, 40), Material = Enum.Material.Rock })
	end
	local embers = P(f, { Name = "Embers", Size = Vector3.new(GROUND_SIZE, 1, GROUND_SIZE), CFrame = CFrame.new(o), Transparency = 1, CanCollide = false })
	particles(embers, { Rate = 50, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(4, 9), LightEmission = 1, Size = NumberSequence.new(0.3), Color = ColorSequence.new(world.colors.accent, world.colors.accent2), EmissionDirection = Enum.NormalId.Top })
end

-- 6. Frostspire: ice spikes, snow, frozen wreck
Themes[6] = function(f, world, rng)
	local o = world.origin
	for i = 1, 36 do
		local x, z = ring(rng, 100, 320)
		local h = rng:NextNumber(15, 70)
		P(f, { Name = "IceSpike", ClassName = "WedgePart", Size = Vector3.new(rng:NextNumber(6, 14), h, rng:NextNumber(6, 14)), CFrame = CFrame.new(o + Vector3.new(x, h / 2 - 2, z)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), 0), Color = Color3.fromRGB(160, 215, 255), Material = Enum.Material.Glacier, Transparency = 0.1 })
	end
	for i = 1, 12 do
		local x, z = ring(rng, 60, 300)
		local s = rng:NextNumber(20, 50)
		P(f, { Name = "SnowMound", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), CFrame = CFrame.new(o + Vector3.new(x, -s * 0.35, z)), Color = Color3.fromRGB(245, 250, 255), Material = Enum.Material.Snow })
	end
	-- Frozen four-legged walker wreck
	local at = o + Vector3.new(-200, 0, -170)
	P(f, { Name = "WalkerBody", Size = Vector3.new(30, 16, 50), CFrame = CFrame.new(at + Vector3.new(0, 38, 0)) * CFrame.Angles(0, 0.6, 0.25), Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.Metal })
	for _, off in { Vector3.new(-12, 0, -18), Vector3.new(12, 0, -18), Vector3.new(-12, 0, 18), Vector3.new(12, 0, 18) } do
		P(f, { Name = "WalkerLeg", Size = Vector3.new(5, 34, 5), CFrame = CFrame.new(at + off + Vector3.new(0, 15, 0)), Color = Color3.fromRGB(140, 145, 155), Material = Enum.Material.Metal })
	end
	local snow = P(f, { Name = "Snowfall", Size = Vector3.new(GROUND_SIZE, 1, GROUND_SIZE), CFrame = CFrame.new(o + Vector3.new(0, 90, 0)), Transparency = 1, CanCollide = false })
	particles(snow, { Rate = 200, Lifetime = NumberRange.new(8, 10), Speed = NumberRange.new(8, 14), Size = NumberSequence.new(0.35), Color = ColorSequence.new(Color3.new(1, 1, 1)), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15) })
end

-- 7. Undercity Spire: skyscrapers, air-traffic, landing pads
Themes[7] = function(f, world, rng)
	local o = world.origin
	for i = 1, 34 do
		local x, z = ring(rng, 170, 320)
		local h = rng:NextNumber(90, 320)
		local w = rng:NextNumber(24, 44)
		local tower = P(f, { Name = "Skyscraper", Size = Vector3.new(w, h, w), CFrame = CFrame.new(o + Vector3.new(x, h / 2, z)), Color = Color3.fromRGB(60, 66, 82), Material = Enum.Material.Glass, Reflectance = 0.2 })
		for s = 1, math.floor(h / 30) do
			P(f, { Name = "Windows", Size = Vector3.new(w + 0.4, 1.4, w + 0.4), CFrame = tower.CFrame * CFrame.new(0, -h / 2 + s * 30, 0), Color = if s % 2 == 0 then world.colors.accent else world.colors.accent2, Material = Enum.Material.Neon })
		end
	end
	for i = 1, 6 do
		local x, z = ring(rng, 90, 150)
		P(f, { Name = "LandingPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 30, 30), CFrame = CFrame.new(o + Vector3.new(x, 0.6, z)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 95, 110), Material = Enum.Material.DiamondPlate })
		P(f, { Name = "PadLight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 31, 31), CFrame = CFrame.new(o + Vector3.new(x, 0.5, z)) * CFrame.Angles(0, 0, math.rad(90)), Color = world.colors.accent2, Material = Enum.Material.Neon })
	end
	-- Traffic lanes: rows of tiny glowing "speeders" high in the sky
	for lane = 1, 4 do
		for i = 1, 14 do
			P(f, { Name = "Speeder", Size = Vector3.new(3, 1, 6), CFrame = CFrame.new(o + Vector3.new(-300 + i * 42, 120 + lane * 35, -250 + lane * 120)), Color = if lane % 2 == 0 then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, CanCollide = false })
		end
	end
end

-- 8. The Core Vault: giant reactor sphere, pylons, sealed walls
Themes[8] = function(f, world, rng)
	local o = world.origin
	local coreAt = o + Vector3.new(0, 110, -200)
	P(f, { Name = "ReactorCore", Shape = Enum.PartType.Ball, Size = Vector3.new(110, 110, 110), CFrame = CFrame.new(coreAt), Color = Color3.fromRGB(255, 80, 60), Material = Enum.Material.Neon })
	P(f, { Name = "ReactorShell", Shape = Enum.PartType.Ball, Size = Vector3.new(130, 130, 130), CFrame = CFrame.new(coreAt), Color = Color3.fromRGB(255, 140, 120), Material = Enum.Material.ForceField, CanCollide = false })
	for i = 1, 3 do
		P(f, { Name = "ContainmentRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 170, 170), CFrame = CFrame.new(coreAt) * CFrame.Angles(0, math.rad(i * 60), math.rad(90)) * CFrame.Angles(math.rad(70), 0, 0), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal, Transparency = 0.1 })
	end
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2
		local at = o + Vector3.new(math.cos(a) * 260, 0, math.sin(a) * 260)
		P(f, { Name = "Pylon", Size = Vector3.new(10, 80, 10), CFrame = CFrame.new(at + Vector3.new(0, 40, 0)), Color = Color3.fromRGB(55, 55, 62), Material = Enum.Material.DiamondPlate })
		P(f, { Name = "PylonLight", Size = Vector3.new(10.4, 4, 10.4), CFrame = CFrame.new(at + Vector3.new(0, 70, 0)), Color = world.colors.accent, Material = Enum.Material.Neon })
	end
	local sparks = P(f, { Name = "Sparks", Size = Vector3.new(120, 1, 120), CFrame = CFrame.new(coreAt), Transparency = 1, CanCollide = false })
	particles(sparks, { Rate = 80, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(40, 80), LightEmission = 1, Size = NumberSequence.new(1, 0), Color = ColorSequence.new(Color3.fromRGB(255, 200, 150)), SpreadAngle = Vector2.new(180, 180) })
end

-- Foundry plots (The Scrapyard only) -------------------------------------------------------
WorldBuilder.PLOT_COUNT = 10
WorldBuilder.PLOT_RADIUS = 165

local function buildPlot(parent: Instance, index: number, world: Worlds.World): Model
	local a = (index / WorldBuilder.PLOT_COUNT) * math.pi * 2
	local center = world.origin + Vector3.new(math.cos(a) * WorldBuilder.PLOT_RADIUS, 0, math.sin(a) * WorldBuilder.PLOT_RADIUS)
	local facing = CFrame.lookAt(center, world.origin * Vector3.new(1, 0, 1)) -- faces the hub
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	local pad = P(m, { Name = "Pad", Size = Vector3.new(54, 1, 54), CFrame = facing * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(90, 92, 100), Material = Enum.Material.Concrete })
	P(m, { Name = "Border", Size = Vector3.new(56, 0.8, 56), CFrame = facing * CFrame.new(0, 0.3, 0), Color = world.colors.accent, Material = Enum.Material.Neon })
	local spawn = P(m, { Name = "PlotSpawn", Size = Vector3.new(6, 1, 6), CFrame = facing * CFrame.new(0, 1.1, -18), Transparency = 1, CanCollide = false })
	local sign = P(m, { Name = "Sign", Size = Vector3.new(16, 6, 1), CFrame = facing * CFrame.new(0, 10, -27), Color = Color3.fromRGB(40, 42, 50), Material = Enum.Material.Metal })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = world.colors.accent
	label.Text = "EMPTY FOUNDRY"
	label.Parent = gui
	gui.Parent = sign
	P(m, { Name = "SignPost", Size = Vector3.new(1, 8, 1), CFrame = facing * CFrame.new(0, 4, -27.2), Color = Color3.fromRGB(40, 42, 50), Material = Enum.Material.Metal })

	local dyn = Instance.new("Folder")
	dyn.Name = "Dynamic"
	dyn.Parent = m
	m.PrimaryPart = pad
	m:SetAttribute("PlotIndex", index)
	spawn:SetAttribute("Spawn", true)
	m.Parent = parent
	return m
end

-- Rebuilds the visible foundry for a plot from upgrade levels + top droids.
function WorldBuilder.DecoratePlot(plot: Model, upgrades: { [string]: number }, accent: Color3)
	local dyn = plot:FindFirstChild("Dynamic") :: Folder
	dyn:ClearAllChildren()
	local pad = plot.PrimaryPart :: BasePart
	local base = pad.CFrame

	-- Main foundry building grows with Assembly Line level
	local assembly = upgrades.Assembly or 0
	local h = 12 + math.min(assembly, 30) * 1.4
	P(dyn, { Name = "Foundry", Size = Vector3.new(22, h, 16), CFrame = base * CFrame.new(0, 0.5 + h / 2, 14), Color = Color3.fromRGB(105, 95, 90), Material = Enum.Material.CorrodedMetal })
	P(dyn, { Name = "FoundryDoor", Size = Vector3.new(10, 9, 0.6), CFrame = base * CFrame.new(0, 5, 5.8), Color = accent, Material = Enum.Material.Neon })
	local stacks = 1 + math.min(assembly // 5, 4)
	for i = 1, stacks do
		local x = -8 + (i - 1) * (16 / math.max(stacks - 1, 1))
		if stacks == 1 then
			x = 6
		end
		P(dyn, { Name = "Smokestack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 3, 3), CFrame = base * CFrame.new(x, h + 5.5, 18) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 65, 62), Material = Enum.Material.Metal })
	end

	-- Crane arms for Salvage Claws (one per 5 levels, max 4)
	local claws = upgrades.Claws or 0
	for i = 1, math.min(1 + claws // 5, 4) do
		local x = if i % 2 == 0 then 20 else -20
		local z = if i <= 2 then 18 else 0
		P(dyn, { Name = "ClawMast", Size = Vector3.new(1.6, 18, 1.6), CFrame = base * CFrame.new(x, 9.5, z), Color = Color3.fromRGB(230, 160, 40), Material = Enum.Material.Metal })
		P(dyn, { Name = "ClawArm", Size = Vector3.new(1.4, 1.4, 12), CFrame = base * CFrame.new(x, 18, z - 5), Color = Color3.fromRGB(230, 160, 40), Material = Enum.Material.Metal })
	end

	-- Station Bay: one docking light per level
	local bay = upgrades.Bay or 0
	for i = 1, bay do
		P(dyn, { Name = "BayLight", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = base * CFrame.new(-21 + i * 4.6, 1.5, 25), Color = Color3.fromRGB(80, 255, 140), Material = Enum.Material.Neon })
	end

	-- Showcase pods (droids are placed on these by WorldService)
	for i = 1, 4 do
		P(dyn, { Name = "ShowcasePod" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 7, 7), CFrame = base * CFrame.new(-15 + (i - 1) * 10, 1, -4) * CFrame.Angles(0, 0, math.rad(90)), Color = accent, Material = Enum.Material.Neon })
	end
end

-- Build everything ----------------------------------------------------------------------------
function WorldBuilder.Build(): Folder
	local root = workspace:FindFirstChild("Worlds") :: Folder?
	if root then
		return root
	end
	local worldsFolder = folder(workspace, "Worlds")

	for _, world in Worlds.List do
		local wf = folder(worldsFolder, "World" .. world.index)
		wf:SetAttribute("WorldIndex", world.index)
		local rng = Random.new(world.index * 1337)
		local o = world.origin

		P(wf, { Name = "Ground", Size = Vector3.new(GROUND_SIZE, 20, GROUND_SIZE), CFrame = CFrame.new(o + Vector3.new(0, -10, 0)), Color = world.colors.ground, Material = world.groundMaterial })
		-- Invisible boundary walls
		for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			P(wf, {
				Name = "Boundary",
				Size = if d.X ~= 0 then Vector3.new(4, 400, GROUND_SIZE) else Vector3.new(GROUND_SIZE, 400, 4),
				CFrame = CFrame.new(o + d * HALF + Vector3.new(0, 200, 0)),
				Transparency = 1,
			})
		end

		local spawn = P(wf, { Name = "Spawn", Size = Vector3.new(14, 1, 14), CFrame = CFrame.new(o + Vector3.new(0, 0.5, 70)), Color = world.colors.accent, Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false })
		spawn:SetAttribute("Spawn", true)
		local signPart = P(wf, { Name = "WorldSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(o + Vector3.new(0, 30, -10)), Transparency = 1, CanCollide = false })
		billboard(signPart, string.upper(world.name), world.colors.accent, UDim2.fromOffset(600, 110), 0)

		buildCrateTerminal(wf, o + Vector3.new(-30, 0, 20), world)
		buildHyperGate(wf, o + Vector3.new(30, 0, 20), world)

		local piles = folder(wf, "ScrapPiles")
		for i = 1, 14 do
			local x, z = ring(rng, 45, if world.index == 1 then 130 else 200)
			buildScrapPile(piles, o + Vector3.new(x, 0, z), world, rng)
		end

		local props = folder(wf, "Props")
		Themes[world.index](props, world, rng)

		if world.index == 1 then
			local plots = folder(wf, "Plots")
			for i = 1, WorldBuilder.PLOT_COUNT do
				local plot = buildPlot(plots, i, world)
				WorldBuilder.DecoratePlot(plot, {}, world.colors.accent)
			end
		end
	end
	return worldsFolder
end

return WorldBuilder
