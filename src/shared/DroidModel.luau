--!strict
-- Builds a droid's 3D model procedurally from its chassis shape + rarity + style.
-- Used by the server (foundry showcase pods) and the client (crate reveals,
-- inventory viewports, droids that follow players).

local Droids = require(script.Parent.Config.Droids)
local Rarities = require(script.Parent.Config.Rarities)
local Styles = require(script.Parent.Config.Styles)
local Worlds = require(script.Parent.Config.Worlds)

local DroidModel = {}

local function part(model: Model, name: string, role: string, shape: Enum.PartType?, size: Vector3, cf: CFrame): BasePart
	local p: BasePart
	if shape == Enum.PartType.Cylinder or shape == Enum.PartType.Ball then
		local pp = Instance.new("Part")
		pp.Shape = shape :: Enum.PartType
		p = pp
	elseif shape == Enum.PartType.Wedge then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
	end
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Role", role)
	p.Parent = model
	return p
end

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block

-- Each builder lays parts out around the origin (feet at y = 0), facing -Z.
local Builders: { [string]: (Model) -> () } = {}

Builders.Dome = function(m)
	part(m, "Body", "Body", CYL, Vector3.new(2.2, 1.8, 1.8), CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)))
	part(m, "Head", "Accent", BALL, Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 2.6, 0))
	part(m, "Eye", "Eye", BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.85, -0.75))
	part(m, "Stripe", "Accent", BLOCK, Vector3.new(1.85, 0.25, 1.85), CFrame.new(0, 1.9, 0))
	part(m, "LegL", "Trim", BLOCK, Vector3.new(0.4, 2, 0.7), CFrame.new(-1.1, 1, 0))
	part(m, "LegR", "Trim", BLOCK, Vector3.new(0.4, 2, 0.7), CFrame.new(1.1, 1, 0))
end

Builders.Humanoid = function(m)
	part(m, "Body", "Body", BLOCK, Vector3.new(1.6, 1.8, 0.9), CFrame.new(0, 2.6, 0))
	part(m, "Head", "Accent", BALL, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4, 0))
	part(m, "EyeL", "Eye", BALL, Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.25, 4.1, -0.5))
	part(m, "EyeR", "Eye", BALL, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.25, 4.1, -0.5))
	part(m, "ArmL", "Trim", BLOCK, Vector3.new(0.4, 1.7, 0.4), CFrame.new(-1.05, 2.5, 0))
	part(m, "ArmR", "Trim", BLOCK, Vector3.new(0.4, 1.7, 0.4), CFrame.new(1.05, 2.5, 0))
	part(m, "LegL", "Trim", BLOCK, Vector3.new(0.5, 1.7, 0.5), CFrame.new(-0.4, 0.85, 0))
	part(m, "LegR", "Trim", BLOCK, Vector3.new(0.5, 1.7, 0.5), CFrame.new(0.4, 0.85, 0))
	part(m, "Chest", "Accent", BLOCK, Vector3.new(0.9, 0.5, 0.2), CFrame.new(0, 2.9, -0.5))
end

Builders.Orb = function(m)
	part(m, "Body", "Body", BALL, Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 2.2, 0))
	part(m, "Ring", "Accent", CYL, Vector3.new(0.3, 3.2, 3.2), CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
	part(m, "Eye", "Eye", BALL, Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 2.3, -0.85))
	part(m, "Antenna", "Trim", CYL, Vector3.new(1.2, 0.15, 0.15), CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(90)))
	part(m, "Tip", "Eye", BALL, Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 4.25, 0))
end

Builders.Walker = function(m)
	part(m, "Body", "Body", BLOCK, Vector3.new(2.4, 1, 2), CFrame.new(0, 2.2, 0))
	part(m, "Head", "Accent", BLOCK, Vector3.new(1.2, 0.8, 1), CFrame.new(0, 2.6, -1.2))
	part(m, "Eye", "Eye", BLOCK, Vector3.new(0.9, 0.2, 0.1), CFrame.new(0, 2.7, -1.72))
	for i, off in { Vector3.new(-1.2, 0, -0.8), Vector3.new(1.2, 0, -0.8), Vector3.new(-1.2, 0, 0.8), Vector3.new(1.2, 0, 0.8) } do
		part(m, "Leg" .. i, "Trim", BLOCK, Vector3.new(0.3, 2.2, 0.3), CFrame.new(off + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(if off.X > 0 then -15 else 15)))
	end
end

Builders.Tank = function(m)
	part(m, "TreadL", "Trim", BLOCK, Vector3.new(0.7, 0.9, 2.6), CFrame.new(-1, 0.45, 0))
	part(m, "TreadR", "Trim", BLOCK, Vector3.new(0.7, 0.9, 2.6), CFrame.new(1, 0.45, 0))
	part(m, "Body", "Body", BLOCK, Vector3.new(2, 1.2, 2.2), CFrame.new(0, 1.4, 0))
	part(m, "Head", "Accent", CYL, Vector3.new(0.8, 1.4, 1.4), CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)))
	part(m, "Barrel", "Trim", CYL, Vector3.new(1.4, 0.3, 0.3), CFrame.new(0, 2.4, -1.2) * CFrame.Angles(0, math.rad(90), 0))
	part(m, "Eye", "Eye", BALL, Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.4, 2.6, -0.6))
end

function DroidModel.ApplyStyle(model: Model, rarityName: string, styleName: string, worldIndex: number)
	local rarity = Rarities.Get(rarityName)
	local world = Worlds.Get(worldIndex)
	local style = Styles.Get(styleName)
	local bodyColor = if world then world.colors.accent2 else rarity.color2
	local accentColor = rarity.color
	local trimColor = Color3.fromRGB(70, 72, 80)

	for i, p in model:GetDescendants() do
		if not p:IsA("BasePart") or p.Name == "Root" then
			continue
		end
		local role: string = (p:GetAttribute("Role") :: any) or ""
		p.Transparency = 0
		p.Reflectance = 0
		p.Material = Enum.Material.SmoothPlastic
		if role == "Eye" then
			p.Material = Enum.Material.Neon
			p.Color = if styleName == "Shadow" then Color3.fromRGB(170, 60, 255) else accentColor
		elseif role == "Body" then
			p.Color = bodyColor
			p.Material = Enum.Material.Metal
		elseif role == "Accent" then
			p.Color = accentColor
		else
			p.Color = trimColor
			p.Material = Enum.Material.DiamondPlate
		end

		local isEye = role == "Eye"
		local isBody = role == "Body"
		if styleName == "Gold" and not isEye then
			p.Color = if role == "Trim" then Color3.fromRGB(200, 140, 20) else Color3.fromRGB(255, 205, 60)
			p.Material = Enum.Material.Foil
			p.Reflectance = 0.25
		elseif styleName == "Diamond" and not isEye then
			p.Color = Color3.fromRGB(175, 240, 255)
			p.Material = Enum.Material.Glass
			p.Transparency = 0.25
			p.Reflectance = 0.4
		elseif styleName == "Shadow" and not isEye then
			p.Color = if role == "Accent" then Color3.fromRGB(110, 30, 200) else Color3.fromRGB(22, 18, 30)
			p.Material = if role == "Accent" then Enum.Material.Neon else Enum.Material.Slate
		elseif styleName == "Neon" then
			p.Material = Enum.Material.Neon
			p.Color = if isBody then Color3.fromRGB(15, 30, 40) else Color3.fromRGB(0, 255, 230)
			if isBody then
				p.Material = Enum.Material.SmoothPlastic
			end
		elseif styleName == "Rainbow" then
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromHSV((i * 0.12) % 1, 0.8, 1)
		end
	end

	model:SetAttribute("Style", styleName)
	-- Rainbow / Neon models are animated by the client (hue shift / pulse).
	if style.name == "Rainbow" or style.name == "Neon" then
		model:SetAttribute("Animated", true)
	end
end

function DroidModel.Build(droidId: number, styleName: string?): Model
	local droid = Droids.Get(droidId)
	assert(droid, "Unknown droid " .. tostring(droidId))
	local model = Instance.new("Model")
	model.Name = droid.name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, 0, 0)
	root.Parent = model
	model.PrimaryPart = root

	local builder = Builders[droid.shape] or Builders.Dome
	builder(model)

	local rarity = Rarities.Get(droid.rarity)
	DroidModel.ApplyStyle(model, droid.rarity, styleName or "Standard", droid.world)

	-- Higher rarities are physically bigger.
	model:ScaleTo(0.55 + 0.1 * rarity.index)

	model:SetAttribute("DroidId", droidId)
	model:SetAttribute("Rarity", droid.rarity)
	return model
end

return DroidModel
