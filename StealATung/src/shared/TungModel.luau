--!strict
-- Builds a Tung's 3D model from parts: a wooden log with a face, little legs,
-- arms and a bat, then an outfit (hat / props), the rarity aura and the
-- mutation skin. Used by the server (pads) and the client (belt, carried and
-- following Tungs, Index viewports).
--
-- The model's pivot is the centre of its feet; its front (face) is -Z.
-- Named pieces the client animates: "Bat" (Model, pivot = grip), "Hat" (Model),
-- "Body", "AuraShell", "Orb1"/"Orb2", "DiscoBall", "Bubble", "Visor", "Rune1-4",
-- "Zzz" (BillboardGui). Every aura instance is tagged "AuraFx" so low-graphics
-- mode and "hide other players' auras" can switch them off.

local CollectionService = game:GetService("CollectionService")

local Rarities = require(script.Parent.Config.Rarities)
local Tungs = require(script.Parent.Config.Tungs)
local Mutations = require(script.Parent.Config.Mutations)
local Format = require(script.Parent.Util.Format)

local TungModel = {}

local M = Enum.Material
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block
local VERT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis X -> Z

local WOOD = Color3.fromRGB(176, 122, 74)
local WOOD_DARK = Color3.fromRGB(120, 80, 48)
local WOOD_LIGHT = Color3.fromRGB(226, 186, 128)
local BLACK = Color3.fromRGB(20, 20, 24)
local WHITE = Color3.fromRGB(250, 250, 250)

TungModel.HEIGHT = 6.4 -- unscaled height to the top of the log

local PARTICLE_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PARTICLE_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local PARTICLE_FIRE = "rbxasset://textures/particles/fire_main.dds"
local PARTICLE_SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"

type Props = { [string]: any }

local function part(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: Props?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- Cylinder between two points.
local function limb(parent: Instance, name: string, a: Vector3, b: Vector3, dia: number, color: Color3, material: Enum.Material?): Part
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	return part(parent, name, CYL, Vector3.new(len, dia, dia), CFrame.lookAt(mid, b) * ALONG_Z, color, material)
end

local function aura(inst: Instance): Instance
	CollectionService:AddTag(inst, "AuraFx")
	return inst
end

local function emitter(parent: Instance, props: Props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = PARTICLE_SPARKLE
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

local function light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function subModel(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function textBillboard(parent: Instance, name: string, text: string, size: Vector2, offset: Vector3, color: Color3): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = UDim2.fromScale(size.X, size.Y)
	bb.StudsOffset = offset
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = color
	l.Parent = bb
	bb.Parent = parent
	return bb
end

-- Outfit pieces ----------------------------------------------------------------------------
local function buildHat(model: Model, kind: string, accent: Color3?)
	local hat = subModel(model, "Hat")
	local top = 6.4
	if kind == "Nightcap" then
		local blue = Color3.fromRGB(80, 110, 210)
		part(hat, "Cap1", CYL, Vector3.new(0.7, 2.5, 2.5), CFrame.new(0, top + 0.3, 0) * VERT, blue, M.Fabric)
		part(hat, "Cap2", CYL, Vector3.new(0.6, 1.9, 1.9), CFrame.new(0.15, top + 0.9, 0.1) * CFrame.Angles(0, 0, -0.25) * VERT, WHITE, M.Fabric)
		part(hat, "Cap3", CYL, Vector3.new(0.6, 1.2, 1.2), CFrame.new(0.45, top + 1.4, 0.2) * CFrame.Angles(0, 0, -0.5) * VERT, blue, M.Fabric)
		part(hat, "Pompom", BALL, Vector3.new(0.7, 0.7, 0.7), CFrame.new(0.8, top + 1.75, 0.25), WHITE, M.Fabric)
	elseif kind == "Bucket" then
		local khaki = Color3.fromRGB(196, 176, 122)
		part(hat, "Brim", CYL, Vector3.new(0.2, 3.7, 3.7), CFrame.new(0, top + 0.05, 0) * VERT, khaki, M.Fabric)
		part(hat, "Crown", CYL, Vector3.new(1.1, 2.6, 2.6), CFrame.new(0, top + 0.6, 0) * VERT, khaki, M.Fabric)
		part(hat, "Band", CYL, Vector3.new(0.3, 2.66, 2.66), CFrame.new(0, top + 0.25, 0) * VERT, Color3.fromRGB(120, 95, 60), M.Fabric)
	elseif kind == "Leaves" then
		local green = Color3.fromRGB(88, 176, 64)
		for i, off in { Vector3.new(0, 0.6, 0), Vector3.new(0.8, 0.4, 0.3), Vector3.new(-0.8, 0.45, 0.2), Vector3.new(0.2, 0.5, 0.8), Vector3.new(-0.3, 1.1, -0.2) } do
			local s = 1.0 + (i % 3) * 0.25
			part(hat, "Leaf" .. i, BALL, Vector3.new(s, s * 0.8, s), CFrame.new(Vector3.new(0, top, 0) + off), if i % 2 == 0 then green else green:Lerp(Color3.new(0.6, 0.9, 0.3), 0.3), M.LeafyGrass)
		end
		part(hat, "Twig", CYL, Vector3.new(0.9, 0.18, 0.18), CFrame.new(0.1, top + 1.6, 0) * CFrame.Angles(0, 0, 1.3), WOOD_DARK, M.Wood)
	elseif kind == "NinjaBand" then
		local red = accent or Color3.fromRGB(220, 40, 50)
		part(hat, "Band", CYL, Vector3.new(0.5, 2.72, 2.72), CFrame.new(0, 5.65, 0) * VERT, red, M.Fabric)
		part(hat, "Tail1", BLOCK, Vector3.new(0.18, 0.35, 1.3), CFrame.new(0.3, 5.5, 1.75) * CFrame.Angles(-0.5, 0.3, 0), red, M.Fabric)
		part(hat, "Tail2", BLOCK, Vector3.new(0.18, 0.35, 1.1), CFrame.new(-0.25, 5.4, 1.7) * CFrame.Angles(-0.8, -0.3, 0), red, M.Fabric)
	elseif kind == "Afro" then
		part(hat, "Afro", BALL, Vector3.new(3.6, 3.0, 3.4), CFrame.new(0, top + 0.6, 0.2), Color3.fromRGB(58, 34, 24), M.Fabric)
	elseif kind == "Antenna" then
		part(hat, "Stalk", CYL, Vector3.new(1.4, 0.16, 0.16), CFrame.new(0, top + 0.7, 0) * VERT, Color3.fromRGB(150, 155, 165), M.Metal)
		part(hat, "AntennaTip", BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, top + 1.5, 0), accent or Color3.fromRGB(255, 40, 40), M.Neon)
	elseif kind == "Nemes" then
		local gold = accent or Color3.fromRGB(255, 196, 45)
		local blue = Color3.fromRGB(40, 70, 170)
		part(hat, "Crown", BLOCK, Vector3.new(2.9, 1.0, 2.9), CFrame.new(0, top + 0.3, 0.05), gold, M.Foil)
		for i, y in { 5.9, 5.1, 4.3 } do
			for _, sx in { -1, 1 } do
				part(hat, "Flap", BLOCK, Vector3.new(0.35, 0.8, 1.5), CFrame.new(sx * 1.42, y, -0.2), if i % 2 == 0 then blue else gold, if i % 2 == 0 then M.SmoothPlastic else M.Foil)
			end
		end
		part(hat, "Cobra", BALL, Vector3.new(0.45, 0.6, 0.45), CFrame.new(0, top + 0.6, -1.45), gold, M.Foil)
	elseif kind == "Crown" then
		local gold = Color3.fromRGB(255, 200, 45)
		part(hat, "Ring", CYL, Vector3.new(0.8, 2.2, 2.2), CFrame.new(0, top + 0.4, 0) * VERT, gold, M.Foil)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			part(hat, "Spike", BLOCK, Vector3.new(0.38, 0.75, 0.38), CFrame.new(math.sin(a) * 0.95, top + 1.05, -math.cos(a) * 0.95) * CFrame.Angles(0, a, math.rad(45)), gold, M.Foil)
		end
		part(hat, "Gem", BALL, Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, top + 0.45, -1.1), Color3.fromRGB(230, 30, 60), M.Neon)
	elseif kind == "Cap" then
		local c = accent or Color3.fromRGB(60, 150, 255)
		part(hat, "Cap", CYL, Vector3.new(0.75, 2.5, 2.5), CFrame.new(0, top + 0.3, 0) * VERT, c, M.Fabric)
		part(hat, "Bill", BLOCK, Vector3.new(1.7, 0.15, 1.3), CFrame.new(0, top + 0.05, -1.55), c, M.Fabric)
	elseif kind == "TopHat" then
		local black = Color3.fromRGB(26, 26, 30)
		part(hat, "Brim", CYL, Vector3.new(0.2, 3.2, 3.2), CFrame.new(0, top + 0.05, 0) * VERT, black)
		part(hat, "Crown", CYL, Vector3.new(2.0, 2.1, 2.1), CFrame.new(0, top + 1.1, 0) * VERT, black)
		part(hat, "Band", CYL, Vector3.new(0.35, 2.16, 2.16), CFrame.new(0, top + 0.35, 0) * VERT, accent or Color3.fromRGB(255, 200, 45), M.Foil)
	elseif kind == "Horns" then
		local c = Color3.fromRGB(40, 22, 22)
		for _, sx in { -1, 1 } do
			limb(hat, "Horn", Vector3.new(sx * 0.85, top - 0.2, 0), Vector3.new(sx * 1.55, top + 1.3, -0.15), 0.45, c, M.SmoothPlastic)
			part(hat, "HornTip", BALL, Vector3.new(0.35, 0.35, 0.35), CFrame.new(sx * 1.6, top + 1.4, -0.17), accent or Color3.new(1, 0.4, 0.1), M.Neon)
		end
	end
	if #hat:GetChildren() == 0 then
		hat:Destroy()
	end
end

local function buildProp(model: Model, kind: string, accent: Color3?, skin: { BasePart })
	if kind == "Drum" then
		local drum = subModel(model, "Drum")
		part(drum, "Shell", CYL, Vector3.new(0.9, 1.7, 1.7), CFrame.new(0, 2.6, -1.75) * VERT, Color3.fromRGB(210, 40, 50))
		part(drum, "Skin", CYL, Vector3.new(0.12, 1.72, 1.72), CFrame.new(0, 3.08, -1.75) * VERT, WHITE)
		part(drum, "Rim", CYL, Vector3.new(0.12, 1.78, 1.78), CFrame.new(0, 2.15, -1.75) * VERT, Color3.fromRGB(230, 200, 80), M.Metal)
	elseif kind == "Scarf" then
		local c = accent or Color3.fromRGB(220, 50, 60)
		part(model, "Scarf", CYL, Vector3.new(0.6, 2.78, 2.78), CFrame.new(0, 3.55, 0) * VERT, c, M.Fabric)
		part(model, "ScarfTail", BLOCK, Vector3.new(0.55, 1.5, 0.2), CFrame.new(0.65, 2.75, -1.38) * CFrame.Angles(0, 0, 0.15), c, M.Fabric)
	elseif kind == "DiscoBall" then
		local ball = part(model, "DiscoBall", BALL, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 10.2, 0), Color3.fromRGB(225, 225, 235), M.Foil, { Reflectance = 0.4 })
		part(model, "String", CYL, Vector3.new(1.2, 0.08, 0.08), CFrame.new(0, 9.0, 0) * VERT, Color3.fromRGB(80, 80, 90))
		for i, c in { Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 200, 255) } do
			local s = Instance.new("SpotLight")
			s.Name = "Disco" .. i
			s.Color = c
			s.Range = 18
			s.Angle = 50
			s.Brightness = 3
			s.Face = if i == 1 then Enum.NormalId.Bottom else Enum.NormalId.Front
			s.Parent = ball
			aura(s)
		end
	elseif kind == "Cape" then
		local c = accent or Color3.fromRGB(200, 25, 40)
		part(model, "Cape", BLOCK, Vector3.new(2.7, 3.9, 0.22), CFrame.new(0, 3.6, 1.42) * CFrame.Angles(-0.12, 0, 0), c, M.Fabric)
		part(model, "Collar", CYL, Vector3.new(0.4, 2.8, 2.8), CFrame.new(0, 5.4, 0.05) * VERT, Color3.fromRGB(250, 245, 235), M.Fabric)
	elseif kind == "Wraps" then
		local c = accent or Color3.fromRGB(255, 196, 45)
		for _, y in { 2.2, 3.0, 3.8 } do
			part(model, "Wrap", CYL, Vector3.new(0.35, 2.68, 2.68), CFrame.new(0, y, 0) * VERT, c, M.Foil)
		end
		for _, y in { 2.6, 3.4 } do
			part(model, "Linen", CYL, Vector3.new(0.35, 2.66, 2.66), CFrame.new(0, y, 0) * VERT, Color3.fromRGB(240, 232, 210), M.Fabric)
		end
	elseif kind == "Visor" then
		part(model, "Visor", BLOCK, Vector3.new(2.1, 0.5, 0.35), CFrame.new(0, 5.0, -1.25), accent or Color3.fromRGB(255, 40, 40), M.Neon)
	elseif kind == "Shades" then
		local glass = Color3.fromRGB(15, 15, 20)
		for _, sx in { -1, 1 } do
			part(model, "Lens", BLOCK, Vector3.new(0.85, 0.5, 0.12), CFrame.new(sx * 0.5, 5.0, -1.52), glass, M.Glass, { Reflectance = 0.35 })
		end
		part(model, "Bridge", BLOCK, Vector3.new(0.4, 0.12, 0.12), CFrame.new(0, 5.12, -1.52), glass)
	elseif kind == "Cracks" then
		local c = accent or Color3.fromRGB(255, 120, 20)
		local specs = { { 0.2, 2.6, 0.4, 1.6 }, { 1.4, 3.7, -0.5, 1.3 }, { 2.6, 2.4, 0.6, 1.2 }, { 3.6, 4.4, -0.3, 1.5 }, { 4.6, 3.0, 0.5, 1.1 }, { 5.5, 5.4, -0.6, 0.9 } }
		for _, s in specs do
			local a, y, tilt, len = s[1], s[2], s[3], s[4]
			local pos = Vector3.new(math.sin(a) * 1.31, y, -math.cos(a) * 1.31)
			aura(part(model, "Crack", BLOCK, Vector3.new(0.14, len, 0.06), CFrame.lookAt(pos, Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, tilt), c, M.Neon))
		end
	elseif kind == "MoonHalo" then
		local anchor = part(model, "Halo", BLOCK, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 8.4, 0), WHITE, M.SmoothPlastic, { Transparency = 1 })
		local bb = textBillboard(anchor, "MoonGui", "🌙", Vector2.new(3.4, 3.4), Vector3.zero, Color3.fromRGB(255, 236, 140))
		bb.MaxDistance = 160
		aura(light(anchor, Color3.fromRGB(255, 236, 160), 14, 1.5))
	elseif kind == "Cheeks" then
		for _, sx in { -1, 1 } do
			part(model, "Cheek", BALL, Vector3.new(0.5, 0.35, 0.3), CFrame.new(sx * 0.88, 4.4, -1.12), Color3.fromRGB(255, 110, 160))
		end
	elseif kind == "Stars" then
		for _, p in skin do
			if p.Name == "Body" then
				aura(emitter(p, {
					Name = "Stars",
					Rate = 14,
					Lifetime = NumberRange.new(1.5, 2.5),
					Speed = NumberRange.new(0.2, 0.6),
					Size = seq(0.25, 0),
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 200, 255)),
					LockedToPart = true,
				}))
			end
		end
	end
end

-- Signature effects that are plain particles (the animated ones live in WorldFx).
local function buildEffect(model: Model, t: Tungs.Tung, body: BasePart, root: BasePart)
	local e = t.effect
	if e == "Zzz" then
		textBillboard(body, "Zzz", "z Z z", Vector2.new(2.4, 1.4), Vector3.new(1.4, 3.6, 0), Color3.fromRGB(200, 220, 255))
	elseif e == "Leaves" then
		aura(emitter(body, { Name = "Leaves", Texture = PARTICLE_SMOKE, Rate = 2, Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(0.5, 1), Acceleration = Vector3.new(0, -1.5, 0), Size = seq(0.5, 0.3), Color = ColorSequence.new(Color3.fromRGB(110, 200, 70), Color3.fromRGB(200, 170, 60)), RotSpeed = NumberRange.new(-90, 90), SpreadAngle = Vector2.new(60, 60) }))
	elseif e == "Frost" then
		aura(part(model, "Frost", CYL, Vector3.new(0.08, 5.5, 5.5), CFrame.new(0, 0.04, 0) * VERT, Color3.fromRGB(225, 245, 255), M.Ice, { Transparency = 0.15 }))
		local mouth = model:FindFirstChild("Mouth") :: BasePart?
		if mouth then
			aura(emitter(mouth, { Name = "Breath", Texture = PARTICLE_SMOKE, Rate = 6, Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(2, 3), EmissionDirection = Enum.NormalId.Front, Size = seq(0.4, 1.2), Transparency = seq(0.3, 1), Color = ColorSequence.new(Color3.fromRGB(230, 250, 255)), SpreadAngle = Vector2.new(15, 15) }))
		end
	elseif e == "Lava" then
		aura(emitter(body, { Name = "LavaDrips", Texture = PARTICLE_SPARKS, Rate = 12, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 2), Acceleration = Vector3.new(0, -18, 0), Size = seq(0.35, 0.1), Color = ColorSequence.new(Color3.fromRGB(255, 180, 40), Color3.fromRGB(255, 60, 10)), LightEmission = 1, SpreadAngle = Vector2.new(180, 180) }))
	elseif e == "Sand" then
		aura(emitter(root, { Name = "Sand", Texture = PARTICLE_SMOKE, Rate = 10, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(2, 3), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80), Size = seq(0.6, 1.6), Transparency = seq(0.4, 1), RotSpeed = NumberRange.new(120, 200), Color = ColorSequence.new(Color3.fromRGB(230, 200, 130)) }))
	elseif e == "Coins" then
		aura(emitter(body, { Name = "Coins", Rate = 0, Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(6, 10), Acceleration = Vector3.new(0, -25, 0), Size = seq(0.5, 0.4), Color = ColorSequence.new(Color3.fromRGB(255, 210, 60)), SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top, LightEmission = 0.6 }))
	elseif e == "Shadow" then
		aura(emitter(root, { Name = "ShadowSmoke", Texture = PARTICLE_SMOKE, Rate = 10, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.3, 0.8), Size = seq(1.5, 3), Transparency = seq(0.35, 1), Color = ColorSequence.new(Color3.fromRGB(15, 15, 20)), SpreadAngle = Vector2.new(180, 180) }))
	elseif e == "Sparkle" then
		aura(emitter(body, { Name = "VipSparkle", Rate = 6, Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(0.5, 1), Size = seq(0.4, 0), Color = ColorSequence.new(Color3.fromRGB(255, 210, 60)), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8 }))
	elseif e == "Bubble" then
		part(model, "Bubble", BALL, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 4.0, -1.5), Color3.fromRGB(255, 140, 200), M.SmoothPlastic, { Transparency = 0.1 })
	elseif e == "Runes" then
		for i = 1, 4 do
			local p = part(model, "Rune" .. i, BLOCK, Vector3.new(0.2, 0.2, 0.2), CFrame.new(math.sin(i * 1.57) * 3, 4, -math.cos(i * 1.57) * 3), WHITE, M.SmoothPlastic, { Transparency = 1 })
			local bb = textBillboard(p, "RuneGui", ({ "ᚱ", "ᛟ", "ᚦ", "ᛉ" })[i], Vector2.new(1.4, 1.4), Vector3.zero, Color3.fromRGB(230, 170, 255))
			aura(bb)
		end
	end
end

-- Rarity aura (Design Doc: Rarity tiers).
local function buildAura(model: Model, t: Tungs.Tung, body: BasePart, root: BasePart)
	local r = t.rarity
	local color = Tungs.Color(t)
	if r == "Common" then
		aura(emitter(root, { Name = "Puff", Texture = PARTICLE_SMOKE, Rate = 0, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(4, 6), Size = seq(1.2, 2.2), Transparency = seq(0.4, 1), Color = ColorSequence.new(Color3.fromRGB(205, 185, 150)), SpreadAngle = Vector2.new(80, 10), EmissionDirection = Enum.NormalId.Top }))
	elseif r == "Uncommon" then
		aura(part(model, "AuraRing", CYL, Vector3.new(0.06, 4.6, 4.6), CFrame.new(0, 0.05, 0) * VERT, color, M.Neon, { Transparency = 0.55, CastShadow = false }))
	elseif r == "Rare" then
		aura(light(body, color, 10, 1.2))
		aura(emitter(body, { Name = "Sparkles", Rate = 5, Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(0.5, 1.2), Size = seq(0.45, 0), Color = ColorSequence.new(color, Color3.new(1, 1, 1)), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.7 }))
	elseif r == "Epic" then
		aura(part(model, "AuraShell", CYL, Vector3.new(5.1, 3.2, 3.2), body.CFrame, color, M.ForceField, { CastShadow = false }))
		for i = 1, 2 do
			aura(part(model, "Orb" .. i, BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(if i == 1 then 2.4 else -2.4, 4, 0), color, M.Neon, { CastShadow = false }))
		end
		aura(light(body, color, 10, 1))
	elseif r == "Legendary" then
		aura(part(model, "AuraBeam", CYL, Vector3.new(30, 3.4, 3.4), CFrame.new(0, 15, 0) * VERT, color, M.Neon, { Transparency = 0.82, CastShadow = false }))
		aura(emitter(body, { Name = "Glitter", Rate = 14, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.3, 1), Acceleration = Vector3.new(0, -1, 0), Size = seq(0.4, 0), Color = ColorSequence.new(color, Color3.new(1, 1, 0.8)), SpreadAngle = Vector2.new(180, 180), LightEmission = 1 }))
		aura(light(body, color, 14, 1.6))
	elseif r == "Secret" then
		aura(part(model, "AuraShell", CYL, Vector3.new(5.2, 3.3, 3.3), body.CFrame, Color3.fromRGB(255, 80, 200), M.ForceField, { CastShadow = false }))
		aura(emitter(root, { Name = "SecretSmoke", Texture = PARTICLE_SMOKE, Rate = 8, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.5, 1.5), Size = seq(2, 3.5), Transparency = seq(0.45, 1), Color = ColorSequence.new(Color3.fromRGB(20, 15, 30)), SpreadAngle = Vector2.new(180, 30) }))
		aura(light(body, Color3.fromRGB(200, 120, 255), 12, 1.2))
	elseif r == "Mythic" then
		local fire = Instance.new("Fire")
		fire.Color = color
		fire.SecondaryColor = color:Lerp(Color3.new(1, 1, 1), 0.5)
		fire.Size = 9
		fire.Heat = 12
		fire.Parent = body
		aura(fire)
		aura(emitter(body, { Name = "Flames", Texture = PARTICLE_FIRE, Rate = 30, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(3, 5), EmissionDirection = Enum.NormalId.Top, Size = seq(2.2, 0.4), Transparency = seq(0.2, 1), Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color), LightEmission = 1, SpreadAngle = Vector2.new(25, 25), Shape = Enum.ParticleEmitterShape.Cylinder }))
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + 0.3
			local len = 3 + (i % 3)
			aura(part(model, "GroundCrack", BLOCK, Vector3.new(0.35, 0.06, len), CFrame.new(math.sin(a) * (1.6 + len / 2), 0.03, math.cos(a) * (1.6 + len / 2)) * CFrame.Angles(0, a, 0), color, M.Neon, { CastShadow = false }))
		end
		aura(part(model, "SkyBeam", CYL, Vector3.new(320, 2.6, 2.6), CFrame.new(0, 160, 0) * VERT, color, M.Neon, { Transparency = 0.6, CastShadow = false }))
		aura(light(body, color, 20, 3))
	end
end

local function applyMutation(model: Model, mut: string, skin: { BasePart }, eyes: { BasePart })
	if mut == "Gold" then
		for _, p in skin do
			p.Color = Color3.fromRGB(255, 196, 45)
			p.Material = M.SmoothPlastic
			p.Reflectance = 0.35
		end
	elseif mut == "Diamond" then
		for _, p in skin do
			p.Color = Color3.fromRGB(170, 232, 255)
			p.Material = M.Glass
			p.Transparency = 0.35
			p.Reflectance = 0.25
		end
	elseif mut == "Rainbow" then
		for i, p in skin do
			p.Color = Color3.fromHSV((i * 0.13) % 1, 0.75, 1)
			p.Material = M.SmoothPlastic
		end
	elseif mut == "Cursed" then
		for _, p in skin do
			p.Color = Color3.fromRGB(36, 16, 26)
			p.Material = M.SmoothPlastic
		end
		for _, p in eyes do
			p.Color = Color3.fromRGB(255, 20, 30)
			p.Material = M.Neon
		end
	end
	model:SetAttribute("Mutation", mut)
end

export type BuildOpts = {
	aura: boolean?, -- default true
	plate: string?, -- "belt" | "pad" | nil
}

function TungModel.Build(id: string, mut: string?, opts: BuildOpts?): Model
	local t = Tungs.Get(id) or Tungs.List[1]
	local o: BuildOpts = opts or {}
	local look = t.look
	local model = Instance.new("Model")
	model.Name = t.id
	model:SetAttribute("TungId", t.id)
	model:SetAttribute("Effect", t.effect)
	model:SetAttribute("Rarity", t.rarity)
	CollectionService:AddTag(model, "Tung")

	local root = part(model, "Root", BLOCK, Vector3.new(2.6, 0.2, 2.6), CFrame.identity, WHITE, M.SmoothPlastic, { Transparency = 1 })
	model.PrimaryPart = root

	local skinColor = look.body or WOOD
	local skinMat = look.material or M.Wood
	local skin: { BasePart } = {}
	local eyes: { BasePart } = {}
	local function sk(p: BasePart): BasePart
		table.insert(skin, p)
		p:SetAttribute("Skin", true)
		return p
	end
	local dark = skinColor:Lerp(Color3.new(0, 0, 0), 0.3)

	-- legs & feet
	for _, sx in { -1, 1 } do
		sk(part(model, "Leg", CYL, Vector3.new(1.4, 0.62, 0.62), CFrame.new(sx * 0.55, 1.1, 0) * VERT, skinColor, skinMat))
		part(model, "Foot", BLOCK, Vector3.new(0.85, 0.45, 1.2), CFrame.new(sx * 0.55, 0.23, -0.18), dark, skinMat)
	end
	-- the log
	local body = sk(part(model, "Body", CYL, Vector3.new(4.6, 2.6, 2.6), CFrame.new(0, 4.1, 0) * VERT, skinColor, skinMat, { CastShadow = true, CanQuery = true }))
	sk(part(model, "TopRing", CYL, Vector3.new(0.1, 2.42, 2.42), CFrame.new(0, 6.42, 0) * VERT, skinColor:Lerp(WOOD_LIGHT, 0.6), skinMat))
	part(model, "TopCore", CYL, Vector3.new(0.1, 1.3, 1.3), CFrame.new(0, 6.44, 0) * VERT, skinColor:Lerp(WOOD_DARK, 0.4), skinMat)

	-- face (front is -Z)
	local glow = look.eyes == "Glow"
	for _, sx in { -1, 1 } do
		if glow then
			table.insert(eyes, part(model, "Eye", BALL, Vector3.new(0.7, 0.7, 0.7), CFrame.new(sx * 0.5, 5.0, -1.12), look.eyeColor or WHITE, M.Neon))
		else
			part(model, "EyeWhite", BALL, Vector3.new(0.82, 0.82, 0.82), CFrame.new(sx * 0.5, 5.0, -1.08), WHITE)
			table.insert(eyes, part(model, "Pupil", BALL, Vector3.new(0.38, 0.38, 0.38), CFrame.new(sx * 0.48, 4.98, -1.47), BLACK))
		end
		if look.eyes == "Sleepy" then
			part(model, "Eyelid", BLOCK, Vector3.new(0.9, 0.45, 0.4), CFrame.new(sx * 0.5, 5.2, -1.3), skinColor, skinMat)
		end
		part(model, "Brow", BLOCK, Vector3.new(0.78, 0.17, 0.17), CFrame.new(sx * 0.5, 5.62, -1.27) * CFrame.Angles(0, 0, sx * -0.22), BLACK)
	end
	part(model, "Nose", BALL, Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 4.55, -1.35), skinColor:Lerp(WOOD_DARK, 0.35), skinMat)
	part(model, "Mouth", BLOCK, Vector3.new(1.05, 0.24, 0.2), CFrame.new(0, 3.95, -1.24), Color3.fromRGB(70, 25, 25))

	-- arms: left hangs, right holds the bat
	local lShoulder, lHand = Vector3.new(-1.32, 5.0, 0), Vector3.new(-1.8, 3.35, -0.25)
	local rShoulder, rHand = Vector3.new(1.32, 5.0, 0), Vector3.new(1.85, 3.6, -0.75)
	sk(limb(model, "ArmL", lShoulder, lHand, 0.5, skinColor, skinMat))
	sk(limb(model, "ArmR", rShoulder, rHand, 0.5, skinColor, skinMat))
	sk(part(model, "HandL", BALL, Vector3.new(0.62, 0.62, 0.62), CFrame.new(lHand), skinColor, skinMat))
	sk(part(model, "HandR", BALL, Vector3.new(0.62, 0.62, 0.62), CFrame.new(rHand), skinColor, skinMat))

	-- the bat (pivot = grip, bat axis = -Z of the pivot)
	local bat = subModel(model, "Bat")
	local batColor = look.bat or WOOD_LIGHT
	local batMat = look.batMaterial or M.Wood
	local grip = CFrame.lookAt(rHand, rHand + Vector3.new(0.2, 1, 0.45))
	part(bat, "Handle", CYL, Vector3.new(1.5, 0.3, 0.3), grip * CFrame.new(0, 0, -0.45) * ALONG_Z, batColor:Lerp(WOOD_DARK, 0.25), batMat)
	part(bat, "Barrel", CYL, Vector3.new(2.6, 0.62, 0.62), grip * CFrame.new(0, 0, -2.3) * ALONG_Z, batColor, batMat)
	part(bat, "Tip", BALL, Vector3.new(0.62, 0.62, 0.62), grip * CFrame.new(0, 0, -3.6), batColor, batMat)
	part(bat, "Knob", BALL, Vector3.new(0.45, 0.45, 0.45), grip * CFrame.new(0, 0, 0.3), batColor:Lerp(WOOD_DARK, 0.4), batMat)
	bat.WorldPivot = grip

	if look.hat then
		buildHat(model, look.hat, look.accent)
	end
	local props: { string } = look.props or {}
	for _, prop in props do
		buildProp(model, prop, look.accent, skin)
	end

	local doAura = o.aura ~= false
	if doAura then
		buildEffect(model, t, body, root)
		buildAura(model, t, body, root)
	end

	local m = mut or Mutations.NONE
	if m ~= Mutations.NONE then
		applyMutation(model, m, skin, eyes)
	else
		model:SetAttribute("Mutation", Mutations.NONE)
	end

	local scale = (t.scale or 1) * Rarities.Get(t.rarity).scale
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:SetAttribute("Height", TungModel.HEIGHT * scale)

	if o.plate then
		TungModel.Nameplate(model, t.id, m, o.plate)
	end
	return model
end

-- Floating nameplate. "belt": name, rarity, price, $/s. "pad": name + $/s.
function TungModel.Nameplate(model: Model, id: string, mut: string?, mode: string): BillboardGui?
	local t = Tungs.Get(id)
	local root = model.PrimaryPart
	if not t or not root then
		return nil
	end
	local h = (model:GetAttribute("Height") :: number?) or TungModel.HEIGHT
	local color = Tungs.Color(t)
	local mutation = Mutations.Get(mut)
	local belt = mode == "belt"

	local bb = Instance.new("BillboardGui")
	bb.Name = "Nameplate"
	bb.Size = if belt then UDim2.fromOffset(230, 104) else UDim2.fromOffset(200, 54)
	bb.StudsOffset = Vector3.new(0, h + (if belt then 2.6 else 1.6), 0)
	bb.LightInfluence = 0
	bb.MaxDistance = if belt then 140 else 70
	bb.ResetOnSpawn = false

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = bb

	local function line(order: number, text: string, textColor: Color3, height: number, strokeColor: Color3?): TextLabel
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, height)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = textColor
		l.LayoutOrder = order
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = strokeColor or Color3.fromRGB(25, 20, 15)
		s.Parent = l
		l.Parent = bb
		return l
	end

	if mutation then
		line(1, mutation.icon .. " " .. string.upper(mutation.name), mutation.color, 18)
	end
	line(2, t.name, Color3.new(1, 1, 1), 24)
	local rarityLabel = line(3, Tungs.RarityLabel(t), if t.rarity == "Secret" then Color3.new(1, 1, 1) else color, 20)
	if t.rarity == "Secret" then
		local g = Instance.new("UIGradient")
		g.Color = Rarities.RAINBOW
		g.Parent = rarityLabel
	end
	if belt then
		local price = t.price * Mutations.Mult(mut)
		line(4, Format.Money(price), Color3.fromRGB(120, 255, 120), 22)
	end
	line(5, Format.Money(t.income * Mutations.Mult(mut)) .. "/s", Color3.fromRGB(255, 225, 90), if belt then 18 else 16)

	bb.Parent = root
	return bb
end

return TungModel
