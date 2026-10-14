--!strict
-- Builds a droid's 3D model from its chassis shape + colours + style.
-- Used by the server (foundry showcase pods) and the client (crate reveals,
-- inventory viewports, droids that follow players).
--
-- Chassis: Astromech, Protocol, BB, B1, B2, Droideka, Probe, Mouse, Gonk,
--          Assassin, Security, Seeker, Spider, Pit, Medical

local Droids = require(script.Parent.Config.Droids)
local Rarities = require(script.Parent.Config.Rarities)

local DroidModel = {}

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block

local function part(model: Model, role: string, shape: Enum.PartType, size: Vector3, cf: CFrame): BasePart
	local p = Instance.new("Part")
	p.Shape = shape
	p.Name = role
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

-- shorthands (all builders: feet at y = 0, facing -Z)
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end
local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis vertical
local FWD = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis toward -Z

local Builders: { [string]: (Model) -> () } = {}

Builders.Astromech = function(m)
	part(m, "Body", CYL, Vector3.new(2.3, 2.1, 2.1), at(0, 1.75, 0) * UP)
	part(m, "Body", BALL, Vector3.new(2.1, 2.1, 2.1), at(0, 2.9, 0))
	part(m, "Accent", BLOCK, Vector3.new(0.55, 0.4, 0.2), at(-0.45, 3.4, -0.85))
	part(m, "Accent", BLOCK, Vector3.new(0.55, 0.4, 0.2), at(0.45, 3.4, -0.85))
	part(m, "Accent", BLOCK, Vector3.new(2.15, 0.22, 2.15), at(0, 2.95, 0))
	part(m, "Eye", BALL, Vector3.new(0.45, 0.45, 0.45), at(0, 3.25, -1.0))
	part(m, "Accent", BLOCK, Vector3.new(1.1, 0.5, 0.15), at(0, 2.15, -1.03))
	part(m, "Accent", BLOCK, Vector3.new(0.7, 0.35, 0.15), at(0, 1.5, -1.03))
	for _, x in { -1.3, 1.3 } do
		part(m, "Trim", BLOCK, Vector3.new(0.45, 2.4, 0.85), at(x, 1.35, 0.1) * CFrame.Angles(math.rad(-6), 0, 0))
		part(m, "Accent", CYL, Vector3.new(0.4, 0.95, 0.95), at(x, 2.45, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.7, 0.35, 1.3), at(x, 0.18, 0))
	end
	part(m, "Trim", BLOCK, Vector3.new(0.5, 0.8, 0.6), at(0, 0.4, 0.3))
end

Builders.Protocol = function(m)
	part(m, "Body", BLOCK, Vector3.new(1.5, 1.5, 0.85), at(0, 3.05, 0))
	part(m, "Accent", BLOCK, Vector3.new(1.0, 0.55, 0.15), at(0, 3.25, -0.47))
	part(m, "Trim", CYL, Vector3.new(0.6, 0.65, 0.65), at(0, 2.05, 0) * UP)
	part(m, "Body", BLOCK, Vector3.new(1.25, 0.45, 0.75), at(0, 1.6, 0))
	part(m, "Body", BALL, Vector3.new(1.1, 1.1, 1.1), at(0, 4.3, 0))
	part(m, "Trim", CYL, Vector3.new(0.35, 0.4, 0.4), at(0, 3.85, 0) * UP)
	part(m, "Eye", BALL, Vector3.new(0.26, 0.26, 0.26), at(-0.22, 4.38, -0.47))
	part(m, "Eye", BALL, Vector3.new(0.26, 0.26, 0.26), at(0.22, 4.38, -0.47))
	part(m, "Trim", BLOCK, Vector3.new(0.3, 0.1, 0.1), at(0, 4.08, -0.52))
	for _, x in { -0.98, 0.98 } do
		part(m, "Body", BLOCK, Vector3.new(0.36, 1.55, 0.36), at(x, 2.85, 0) * CFrame.Angles(0, 0, math.rad(if x > 0 then -6 else 6)))
		part(m, "Trim", BLOCK, Vector3.new(0.32, 0.35, 0.32), at(x * 1.05, 1.95, 0))
	end
	for _, x in { -0.35, 0.35 } do
		part(m, "Body", BLOCK, Vector3.new(0.42, 1.4, 0.42), at(x, 0.75, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.48, 0.24, 0.7), at(x, 0.12, -0.1))
	end
end

Builders.BB = function(m)
	part(m, "Body", BALL, Vector3.new(2.4, 2.4, 2.4), at(0, 1.2, 0))
	for _, cf in { at(-1.16, 1.2, 0), at(1.16, 1.2, 0), at(0, 1.2, -1.16) * FWD, at(0, 1.2, 1.16) * FWD } do
		part(m, "Accent", CYL, Vector3.new(0.12, 1.35, 1.35), cf)
		part(m, "Trim", CYL, Vector3.new(0.14, 0.55, 0.55), cf)
	end
	part(m, "Body", BALL, Vector3.new(1.3, 1.3, 1.3), at(0, 2.6, 0))
	part(m, "Accent", CYL, Vector3.new(0.18, 1.32, 1.32), at(0, 2.55, 0) * UP)
	part(m, "Trim", BLOCK, Vector3.new(1.0, 0.12, 1.0), at(0, 2.3, 0))
	part(m, "Eye", BALL, Vector3.new(0.42, 0.42, 0.42), at(0, 2.75, -0.55))
	part(m, "Trim", CYL, Vector3.new(0.6, 0.06, 0.06), at(0.2, 3.4, 0.1) * UP)
end

Builders.B1 = function(m)
	part(m, "Trim", BLOCK, Vector3.new(0.7, 0.3, 0.4), at(0, 1.95, 0))
	part(m, "Trim", BLOCK, Vector3.new(0.22, 0.7, 0.22), at(0, 2.35, 0.05))
	part(m, "Body", BLOCK, Vector3.new(1.1, 0.85, 0.55), at(0, 2.95, 0))
	part(m, "Trim", BLOCK, Vector3.new(0.8, 0.7, 0.35), at(0, 3.0, 0.42))
	part(m, "Trim", BLOCK, Vector3.new(0.18, 0.75, 0.18), at(0, 3.65, -0.12) * CFrame.Angles(math.rad(-20), 0, 0))
	part(m, "Body", BLOCK, Vector3.new(0.42, 0.45, 1.3), at(0, 4.05, -0.45) * CFrame.Angles(math.rad(-18), 0, 0))
	part(m, "Accent", BLOCK, Vector3.new(0.44, 0.15, 0.9), at(0, 4.22, -0.35) * CFrame.Angles(math.rad(-18), 0, 0))
	part(m, "Eye", BALL, Vector3.new(0.2, 0.2, 0.2), at(-0.22, 4.05, -0.2))
	part(m, "Eye", BALL, Vector3.new(0.2, 0.2, 0.2), at(0.22, 4.05, -0.2))
	for _, x in { -0.7, 0.7 } do
		part(m, "Body", BLOCK, Vector3.new(0.2, 1.5, 0.2), at(x, 2.55, -0.1) * CFrame.Angles(math.rad(10), 0, 0))
	end
	for _, x in { -0.25, 0.25 } do
		part(m, "Body", BLOCK, Vector3.new(0.22, 1.9, 0.22), at(x, 0.95, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.32, 0.14, 0.6), at(x, 0.07, -0.12))
	end
end

Builders.B2 = function(m)
	part(m, "Body", BLOCK, Vector3.new(2.0, 1.5, 1.3), at(0, 3.0, 0) * CFrame.Angles(math.rad(8), 0, 0))
	part(m, "Accent", BLOCK, Vector3.new(0.55, 0.4, 0.6), at(0, 3.85, -0.3))
	part(m, "Eye", BLOCK, Vector3.new(0.5, 0.1, 0.05), at(0, 3.88, -0.62))
	for _, x in { -1.3, 1.3 } do
		part(m, "Trim", BLOCK, Vector3.new(0.65, 1.7, 0.65), at(x, 2.55, -0.1))
		part(m, "Accent", BLOCK, Vector3.new(0.7, 0.45, 0.7), at(x, 1.65, -0.15))
	end
	part(m, "Trim", BLOCK, Vector3.new(1.2, 0.45, 0.8), at(0, 2.05, 0))
	for _, x in { -0.5, 0.5 } do
		part(m, "Body", BLOCK, Vector3.new(0.55, 1.85, 0.55), at(x, 0.95, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.65, 0.2, 0.85), at(x, 0.1, -0.12))
	end
end

Builders.Droideka = function(m)
	part(m, "Body", BLOCK, Vector3.new(1.0, 1.3, 1.6), at(0, 2.6, 0.2) * CFrame.Angles(math.rad(-25), 0, 0))
	part(m, "Body", BLOCK, Vector3.new(0.8, 0.6, 1.0), at(0, 3.35, -0.55))
	part(m, "Eye", BLOCK, Vector3.new(0.5, 0.15, 0.05), at(0, 3.4, -1.06))
	for i = 0, 2 do
		local a = math.rad(i * 120 + 60)
		part(m, "Trim", BLOCK, Vector3.new(0.2, 2.4, 0.2), at(math.sin(a) * 0.7, 1.15, math.cos(a) * 0.7) * CFrame.Angles(math.cos(a) * -0.4, 0, math.sin(a) * 0.4))
	end
	for _, x in { -0.6, 0.6 } do
		part(m, "Trim", BLOCK, Vector3.new(0.2, 0.2, 1.4), at(x, 2.5, -0.9))
		part(m, "Accent", BLOCK, Vector3.new(0.28, 0.28, 0.45), at(x, 2.5, -1.6))
	end
	part(m, "Shield", BALL, Vector3.new(4.4, 4.4, 4.4), at(0, 2.2, 0))
end

Builders.Probe = function(m)
	part(m, "Body", BALL, Vector3.new(2.0, 2.0, 2.0), at(0, 3.3, 0))
	part(m, "Trim", CYL, Vector3.new(0.5, 1.6, 1.6), at(0, 2.45, 0) * UP)
	for i, x in { -0.45, 0, 0.45 } do
		part(m, "Eye", BALL, Vector3.new(0.28, 0.28, 0.28), at(x, 3.25 + (if i == 2 then 0.25 else 0), -0.92))
	end
	part(m, "Trim", CYL, Vector3.new(1.2, 0.08, 0.08), at(0.3, 4.6, 0) * UP)
	part(m, "Accent", BALL, Vector3.new(0.25, 0.25, 0.25), at(0.3, 5.2, 0))
	for i = 0, 4 do
		local a = math.rad(i * 72)
		part(m, "Trim", BLOCK, Vector3.new(0.12, 2.0, 0.12), at(math.sin(a) * 0.5, 1.35, math.cos(a) * 0.5) * CFrame.Angles(math.cos(a) * 0.25, 0, -math.sin(a) * 0.25))
		part(m, "Accent", BLOCK, Vector3.new(0.25, 0.25, 0.25), at(math.sin(a) * 0.75, 0.3, math.cos(a) * 0.75))
	end
end

Builders.Mouse = function(m)
	part(m, "Body", BLOCK, Vector3.new(1.1, 0.65, 1.7), at(0, 0.55, 0))
	part(m, "Accent", BLOCK, Vector3.new(0.9, 0.12, 1.2), at(0, 0.92, 0.1))
	part(m, "Eye", BLOCK, Vector3.new(0.5, 0.15, 0.05), at(0, 0.6, -0.87))
	part(m, "Trim", BLOCK, Vector3.new(1.2, 0.25, 1.5), at(0, 0.15, 0))
end

Builders.Gonk = function(m)
	part(m, "Body", BLOCK, Vector3.new(1.8, 2.1, 1.5), at(0, 1.85, 0))
	part(m, "Accent", BLOCK, Vector3.new(1.4, 0.35, 0.1), at(0, 2.4, -0.78))
	part(m, "Accent", BLOCK, Vector3.new(1.4, 0.35, 0.1), at(0, 1.85, -0.78))
	part(m, "Eye", BALL, Vector3.new(0.22, 0.22, 0.22), at(0.55, 2.75, -0.78))
	part(m, "Trim", BLOCK, Vector3.new(1.9, 0.2, 1.6), at(0, 2.95, 0))
	for _, x in { -0.55, 0.55 } do
		part(m, "Trim", BLOCK, Vector3.new(0.4, 0.8, 0.4), at(x, 0.4, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.6, 0.15, 0.8), at(x, 0.07, -0.1))
	end
end

Builders.Assassin = function(m)
	part(m, "Body", CYL, Vector3.new(1.0, 0.75, 0.75), at(0, 5.15, 0) * UP)
	part(m, "Accent", CYL, Vector3.new(0.15, 0.8, 0.8), at(0, 5.3, 0) * UP)
	for i = 0, 3 do
		local a = math.rad(i * 90)
		part(m, "Eye", BALL, Vector3.new(0.14, 0.14, 0.14), at(math.sin(a) * 0.37, 5.3, -math.cos(a) * 0.37))
	end
	part(m, "Trim", BLOCK, Vector3.new(0.18, 0.5, 0.18), at(0, 4.5, 0))
	part(m, "Body", BLOCK, Vector3.new(0.95, 1.6, 0.5), at(0, 3.5, 0))
	part(m, "Accent", BLOCK, Vector3.new(0.6, 0.3, 0.08), at(0, 3.85, -0.28))
	for _, x in { -0.65, 0.65 } do
		part(m, "Trim", BLOCK, Vector3.new(0.2, 2.2, 0.2), at(x, 3.2, 0))
	end
	part(m, "Trim", BLOCK, Vector3.new(0.15, 0.15, 1.6), at(0.65, 2.1, -0.6))
	for _, x in { -0.25, 0.25 } do
		part(m, "Trim", BLOCK, Vector3.new(0.24, 2.6, 0.24), at(x, 1.35, 0))
		part(m, "Body", BLOCK, Vector3.new(0.35, 0.15, 0.6), at(x, 0.07, -0.1))
	end
end

Builders.Security = function(m)
	part(m, "Body", BLOCK, Vector3.new(1.3, 1.6, 0.7), at(0, 4.15, 0))
	part(m, "Trim", BLOCK, Vector3.new(0.9, 0.8, 0.6), at(0, 3.0, 0))
	part(m, "Body", BLOCK, Vector3.new(0.6, 0.6, 0.7), at(0, 5.35, -0.05))
	part(m, "Eye", BALL, Vector3.new(0.2, 0.2, 0.2), at(-0.15, 5.4, -0.4))
	part(m, "Eye", BALL, Vector3.new(0.2, 0.2, 0.2), at(0.15, 5.4, -0.4))
	for _, x in { -0.85, 0.85 } do
		part(m, "Accent", CYL, Vector3.new(0.15, 0.55, 0.55), at(x * 0.95, 4.6, 0))
		part(m, "Body", BLOCK, Vector3.new(0.28, 2.6, 0.28), at(x, 3.5, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.3, 0.4, 0.3), at(x, 2.05, 0))
	end
	for _, x in { -0.3, 0.3 } do
		part(m, "Body", BLOCK, Vector3.new(0.32, 2.6, 0.32), at(x, 1.3, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.4, 0.15, 0.7), at(x, 0.07, -0.12))
	end
end

Builders.Seeker = function(m)
	part(m, "Body", BALL, Vector3.new(1.6, 1.6, 1.6), at(0, 2.6, 0))
	part(m, "Accent", CYL, Vector3.new(0.15, 1.65, 1.65), at(0, 2.6, 0) * UP)
	part(m, "Eye", BALL, Vector3.new(0.6, 0.6, 0.6), at(0, 2.65, -0.62))
	for _, x in { -0.5, 0.5 } do
		part(m, "Trim", BLOCK, Vector3.new(0.08, 0.9, 0.08), at(x, 1.6, 0.1) * CFrame.Angles(0, 0, x * 0.4))
	end
	part(m, "Trim", BLOCK, Vector3.new(0.06, 0.8, 0.06), at(0, 3.7, 0.2))
end

Builders.Spider = function(m)
	part(m, "Body", BALL, Vector3.new(1.9, 1.9, 1.9), at(0, 2.3, 0))
	part(m, "Eye", BALL, Vector3.new(0.85, 0.85, 0.85), at(0, 2.35, -0.75))
	part(m, "Accent", CYL, Vector3.new(1.4, 0.3, 0.3), at(0, 1.55, -0.6) * FWD)
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local dx, dz = math.sin(a), math.cos(a)
		part(m, "Trim", BLOCK, Vector3.new(0.2, 0.2, 1.6), at(dx * 1.1, 2.4, dz * 1.1) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-20), 0, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.2, 2.4, 0.2), at(dx * 1.75, 1.2, dz * 1.75))
	end
end

Builders.Pit = function(m)
	part(m, "Body", BLOCK, Vector3.new(0.6, 1.0, 0.45), at(0, 1.65, 0))
	part(m, "Accent", CYL, Vector3.new(0.22, 1.6, 1.6), at(0, 2.7, -0.15) * FWD * CFrame.Angles(0, 0, math.rad(-20)))
	part(m, "Eye", BALL, Vector3.new(0.4, 0.4, 0.4), at(0, 2.7, -0.3))
	for _, x in { -0.25, 0.25 } do
		part(m, "Trim", BLOCK, Vector3.new(0.18, 1.2, 0.18), at(x, 0.6, 0))
		part(m, "Trim", BLOCK, Vector3.new(0.25, 0.12, 0.45), at(x, 0.06, -0.1))
	end
	for _, x in { -0.45, 0.45 } do
		part(m, "Trim", BLOCK, Vector3.new(0.14, 1.0, 0.14), at(x, 1.55, -0.1) * CFrame.Angles(math.rad(20), 0, 0))
	end
end

Builders.Medical = function(m)
	part(m, "Body", BLOCK, Vector3.new(1.25, 1.1, 0.8), at(0, 3.45, 0))
	local belly = part(m, "Accent", CYL, Vector3.new(0.9, 0.85, 0.85), at(0, 2.45, 0) * UP)
	belly:SetAttribute("BaseTransparency", 0.35)
	part(m, "Body", BLOCK, Vector3.new(1.0, 0.4, 0.7), at(0, 1.8, 0))
	part(m, "Body", BALL, Vector3.new(1.0, 1.0, 1.0), at(0, 4.4, 0))
	part(m, "Eye", BALL, Vector3.new(0.25, 0.25, 0.25), at(-0.18, 4.45, -0.42))
	part(m, "Eye", BALL, Vector3.new(0.25, 0.25, 0.25), at(0.18, 4.45, -0.42))
	for _, x in { -0.85, 0.85 } do
		part(m, "Trim", BLOCK, Vector3.new(0.25, 1.5, 0.25), at(x, 3.0, -0.1))
		part(m, "Accent", BLOCK, Vector3.new(0.12, 0.12, 0.6), at(x, 2.2, -0.35))
	end
	for _, x in { -0.3, 0.3 } do
		part(m, "Trim", BLOCK, Vector3.new(0.3, 1.6, 0.3), at(x, 0.85, 0))
		part(m, "Body", BLOCK, Vector3.new(0.4, 0.15, 0.6), at(x, 0.07, -0.1))
	end
end

-- Paints parts with the droid's own colours, then layers the style on top.
function DroidModel.ApplyStyle(model: Model, droidId: number, styleName: string)
	local droid = Droids.Get(droidId)
	if not droid then
		return
	end
	local rarity = Rarities.Get(droid.rarity)
	local colors = droid.colors
	for i, p in model:GetDescendants() do
		if not p:IsA("BasePart") or p.Name == "Root" then
			continue
		end
		local role: string = (p:GetAttribute("Role") :: any) or ""
		local isEye = role == "Eye"
		local isBody = role == "Body"
		local isShield = role == "Shield"
		p.Reflectance = 0
		if isShield then
			-- droideka deflector bubble keeps its see-through ForceField look
			p.Material = Enum.Material.ForceField
			p.Color = Color3.fromRGB(120, 200, 255)
			p.Transparency = 0
		elseif isEye then
			p.Material = Enum.Material.Neon
			p.Color = if styleName == "Shadow" then Color3.fromRGB(170, 60, 255) else rarity.color
			p.Transparency = 0
		else
			p.Material = if role == "Trim" then Enum.Material.Metal else Enum.Material.SmoothPlastic
			p.Color = if isBody then colors[1] elseif role == "Accent" then colors[2] else colors[3]
			p.Transparency = (p:GetAttribute("BaseTransparency") :: number?) or 0
		end

		if isShield or isEye then
			if isShield and styleName ~= "Standard" then
				p.Color = if styleName == "Gold" then Color3.fromRGB(255, 205, 60) elseif styleName == "Shadow" then Color3.fromRGB(140, 60, 255) else Color3.fromHSV((i * 0.12) % 1, 0.6, 1)
			end
		elseif styleName == "Gold" then
			p.Color = if role == "Trim" then Color3.fromRGB(200, 140, 20) else Color3.fromRGB(255, 205, 60)
			p.Material = Enum.Material.Foil
			p.Reflectance = 0.25
		elseif styleName == "Diamond" then
			p.Color = Color3.fromRGB(175, 240, 255)
			p.Material = Enum.Material.Glass
			p.Transparency = 0.2
			p.Reflectance = 0.4
		elseif styleName == "Shadow" then
			p.Color = if role == "Accent" then Color3.fromRGB(110, 30, 200) else Color3.fromRGB(22, 18, 30)
			p.Material = if role == "Accent" then Enum.Material.Neon else Enum.Material.Slate
		elseif styleName == "Neon" then
			p.Color = if isBody then Color3.fromRGB(15, 30, 40) else Color3.fromRGB(0, 255, 230)
			p.Material = if isBody then Enum.Material.SmoothPlastic else Enum.Material.Neon
		elseif styleName == "Rainbow" then
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromHSV((i * 0.12) % 1, 0.8, 1)
		end
	end

	model:SetAttribute("Style", styleName)
	model:SetAttribute("Animated", styleName == "Rainbow" or styleName == "Neon")
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

	local builder = Builders[droid.shape] or Builders.Astromech
	builder(model)
	DroidModel.ApplyStyle(model, droidId, styleName or "Standard")

	-- Normalise size so every chassis reads well at the same scale for its
	-- rarity (a Mouse Droid and K-2Sigma side by side). Rarer = bigger.
	local rarity = Rarities.Get(droid.rarity)
	local _, ext = model:GetBoundingBox()
	local biggest = math.max(ext.X, ext.Y, ext.Z)
	if droid.shape == "Droideka" then
		biggest *= 0.7 -- the shield bubble shouldn't shrink the droid itself
	end
	local target = 2.6 + 0.35 * rarity.index
	if biggest > 0 then
		model:ScaleTo(target / biggest)
	end

	model:SetAttribute("DroidId", droidId)
	model:SetAttribute("Rarity", droid.rarity)
	return model
end

return DroidModel
