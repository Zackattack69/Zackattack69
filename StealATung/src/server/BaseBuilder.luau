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
	-- bright toy-plastic palettes; materials are run through Style.Material
	Wood = { floor = Color3.fromRGB(255, 214, 150), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(240, 150, 70), wallMat = M.SmoothPlastic, wallHeight = 4, post = Color3.fromRGB(200, 110, 50), postMat = M.SmoothPlastic, cap = Color3.fromRGB(255, 200, 70), capMat = M.SmoothPlastic, pad = Color3.fromRGB(255, 245, 220), accent = Color3.fromRGB(255, 200, 40) },
	Stone = { floor = Color3.fromRGB(214, 220, 236), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(170, 180, 205), wallMat = M.SmoothPlastic, wallHeight = 5.5, post = Color3.fromRGB(120, 130, 165), postMat = M.SmoothPlastic, cap = Color3.fromRGB(70, 170, 255), capMat = M.Neon, pad = Color3.fromRGB(245, 248, 255), accent = Color3.fromRGB(70, 170, 255) },
	Bamboo = { floor = Color3.fromRGB(255, 232, 180), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(120, 215, 80), wallMat = M.SmoothPlastic, wallHeight = 5, post = Color3.fromRGB(70, 170, 60), postMat = M.SmoothPlastic, postRound = true, cap = Color3.fromRGB(240, 50, 60), capMat = M.SmoothPlastic, pad = Color3.fromRGB(255, 250, 235), accent = Color3.fromRGB(255, 60, 80) },
	Crystal = { floor = Color3.fromRGB(255, 225, 250), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(160, 230, 255), wallMat = M.Glass, wallHeight = 5, post = Color3.fromRGB(255, 110, 220), postMat = M.Neon, cap = Color3.fromRGB(110, 235, 255), capMat = M.Neon, pad = Color3.fromRGB(255, 245, 255), accent = Color3.fromRGB(255, 110, 230), wallTransparency = 0.3 },
	Sky = { floor = Color3.fromRGB(255, 255, 255), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(130, 205, 255), wallMat = M.SmoothPlastic, wallHeight = 3, post = Color3.fromRGB(255, 255, 255), postMat = M.SmoothPlastic, postRound = true, cap = Color3.fromRGB(255, 230, 90), capMat = M.SmoothPlastic, pad = Color3.fromRGB(225, 242, 255), accent = Color3.fromRGB(80, 190, 255) },
	Volcano = { floor = Color3.fromRGB(90, 45, 50), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(150, 40, 45), wallMat = M.SmoothPlastic, wallHeight = 6, post = Color3.fromRGB(70, 30, 35), postMat = M.SmoothPlastic, cap = Color3.fromRGB(255, 120, 20), capMat = M.Neon, pad = Color3.fromRGB(255, 200, 150), accent = Color3.fromRGB(255, 110, 20) },
	Space = { floor = Color3.fromRGB(45, 50, 95), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(95, 105, 170), wallMat = M.SmoothPlastic, wallHeight = 5, post = Color3.fromRGB(60, 65, 120), postMat = M.SmoothPlastic, cap = Color3.fromRGB(60, 235, 255), capMat = M.Neon, pad = Color3.fromRGB(200, 215, 255), accent = Color3.fromRGB(60, 235, 255) },
	Golden = { floor = Color3.fromRGB(255, 248, 225), floorMat = M.SmoothPlastic, wall = Color3.fromRGB(255, 200, 40), wallMat = M.Foil, wallHeight = 6, post = Color3.fromRGB(255, 255, 255), postMat = M.SmoothPlastic, cap = Color3.fromRGB(255, 215, 60), capMat = M.Foil, pad = Color3.fromRGB(255, 240, 200), accent = Color3.fromRGB(255, 205, 40) },
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
	local D = Layout.Depth(info.slots)
	local W2 = Layout.PLOT_WIDTH / 2 - 1
	local gold = Color3.fromRGB(255, 200, 50)
	local trim = if info.golden then gold else theme.cap
	local trimMat = if info.golden then M.Foil else theme.capMat

	local base = Instance.new("Model")
	base.Name = "Base" .. i
	base:SetAttribute("Index", i)

	local function L(x: number, y: number, d: number): CFrame
		return Layout.Local(i, x, y, d)
	end

	-- Floor ----------------------------------------------------------------------------------
	P(base, { Name = "Floor", Size = Vector3.new(W2 * 2 + 2, 0.8, D), CFrame = L(0, 0, D / 2), Color = theme.floor, Material = theme.floorMat })
	P(base, { Name = "FloorRim", Size = Vector3.new(W2 * 2 + 3.2, 0.7, D + 1.2), CFrame = L(0, -0.08, D / 2), Color = theme.accent, Material = M.SmoothPlastic })
	-- checkerboard tiles make the floor read as a toy play-mat
	local tile = 12
	for tx = -W2 + tile / 2, W2 - tile / 2, tile do
		for td = tile / 2, D - tile / 2, tile do
			if (math.floor((tx + W2) / tile) + math.floor(td / tile)) % 2 == 0 then
				P(base, { Name = "Tile", Size = Vector3.new(tile, 0.05, tile), CFrame = L(tx, Layout.FLOOR_TOP + 0.02, td), Color = theme.floor:Lerp(Color3.new(0, 0, 0), 0.06), Material = M.SmoothPlastic, CanCollide = false, CastShadow = false })
			end
		end
	end

	-- Fence ------------------------------------------------------------------------------------
	local fence = folder(base, "Fence")
	local gateHalf = Layout.GATE_WIDTH / 2
	local h = theme.wallHeight
	local function segment(x1: number, d1: number, x2: number, d2: number)
		local a = L(x1, 0, d1).Position
		local b = L(x2, 0, d2).Position
		local len = (b - a).Magnitude
		if len < 0.5 then
			return
		end
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		P(fence, { Name = "Wall", Size = Vector3.new(0.8, h, len), CFrame = cf + Vector3.new(0, Layout.FLOOR_TOP + h / 2, 0), Color = theme.wall, Material = theme.wallMat, Transparency = theme.wallTransparency or 0 })
		P(fence, { Name = "Cap", Size = Vector3.new(1.2, 0.5, len + 1), CFrame = cf + Vector3.new(0, Layout.FLOOR_TOP + h + 0.25, 0), Color = trim, Material = trimMat })
		-- tall invisible collider: the gate is the only way in
		P(fence, { Name = "Collider", Size = Vector3.new(1, 22, len), CFrame = cf + Vector3.new(0, 11, 0), Transparency = 1, CanQuery = false })
		local n = math.max(1, math.floor(len / 8))
		for k = 0, n do
			local pos = a:Lerp(b, k / n)
			if theme.postRound then
				P(fence, { Name = "Post", Shape = CYL, Size = Vector3.new(h + 1.2, 1.3, 1.3), CFrame = CFrame.new(pos + Vector3.new(0, Layout.FLOOR_TOP + (h + 1.2) / 2, 0)) * VERT, Color = theme.post, Material = theme.postMat })
			else
				P(fence, { Name = "Post", Size = Vector3.new(1.4, h + 1.2, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, Layout.FLOOR_TOP + (h + 1.2) / 2, 0)), Color = theme.post, Material = theme.postMat })
			end
		end
	end
	segment(-W2, 0, -gateHalf - 1.5, 0)
	segment(gateHalf + 1.5, 0, W2, 0)
	segment(-W2, 0, -W2, D)
	segment(W2, 0, W2, D)
	segment(-W2, D, W2, D)

	-- Theme extras -------------------------------------------------------------------------------
	local deco = folder(base, "Decor")
	local rng = Random.new(i * 31)
	if info.theme == "Stone" then
		for x = -W2 + 2, W2 - 2, 4 do
			P(deco, { Name = "Merlon", Size = Vector3.new(1.6, 1.4, 1.2), CFrame = L(x, Layout.FLOOR_TOP + h + 1.2, D), Color = theme.wall, Material = theme.wallMat })
		end
	elseif info.theme == "Bamboo" then
		-- red torii-style gate
		P(deco, { Name = "ToriiTop", Size = Vector3.new(24, 1.2, 1.6), CFrame = L(0, 14.6, -0.6), Color = Color3.fromRGB(210, 40, 40), Material = M.SmoothPlastic })
		P(deco, { Name = "ToriiBeam", Size = Vector3.new(21, 0.8, 1), CFrame = L(0, 12.4, -0.6), Color = Color3.fromRGB(40, 30, 30), Material = M.SmoothPlastic })
		for _, x in { -W2 + 3, W2 - 3 } do
			for _, d in { 6, D - 6 } do
				P(deco, { Name = "Lantern", Size = Vector3.new(1.4, 2, 1.4), CFrame = L(x, 2, d), Color = Color3.fromRGB(255, 120, 60), Material = M.Neon, CanCollide = false })
			end
		end
	elseif info.theme == "Crystal" then
		for k = 1, 10 do
			local x = rng:NextNumber(-W2 + 2, W2 - 2)
			local side = if k % 2 == 0 then D - 2 else 2.5
			if math.abs(x) > gateHalf + 2 or side > 3 then
				P(deco, { Name = "Crystal", Size = Vector3.new(1.4, rng:NextNumber(4, 8), 1.4), CFrame = L(x, 3.5, side) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = if k % 3 == 0 then Color3.fromRGB(120, 230, 255) else Color3.fromRGB(255, 130, 230), Material = M.Neon, Transparency = 0.15, CanCollide = false })
			end
		end
	elseif info.theme == "Sky" then
		for x = -W2, W2, 6 do
			for _, d in { 0.5, D - 0.5 } do
				if d > 1 or math.abs(x) > gateHalf + 2 then
					P(deco, { Name = "Cloud", Shape = BALL, Size = Vector3.new(5, 4, 5), CFrame = L(x, 1.2, d), Color = Color3.new(1, 1, 1), Material = M.SmoothPlastic, CanCollide = false })
				end
			end
		end
		for k = 1, 3 do
			local at = L(rng:NextNumber(-W2, W2), 18 + k * 3, rng:NextNumber(10, D - 10))
			P(deco, { Name = "IslandRock", Shape = BALL, Size = Vector3.new(6, 5, 6), CFrame = at, Color = Color3.fromRGB(130, 110, 90), Material = M.Rock, CanCollide = false })
			P(deco, { Name = "IslandGrass", Shape = CYL, Size = Vector3.new(1, 6.5, 6.5), CFrame = at * CFrame.new(0, 2, 0) * VERT, Color = Color3.fromRGB(110, 200, 80), Material = M.Grass, CanCollide = false })
		end
	elseif info.theme == "Volcano" then
		for _, x in { -W2 + 2.5, W2 - 2.5 } do
			for _, d in { 3, D - 3 } do
				local bowl = P(deco, { Name = "Brazier", Shape = CYL, Size = Vector3.new(1.2, 3, 3), CFrame = L(x, 3.5, d) * VERT, Color = Color3.fromRGB(40, 32, 30), Material = M.Basalt })
				P(deco, { Name = "BrazierLeg", Size = Vector3.new(0.8, 3, 0.8), CFrame = L(x, 1.9, d), Color = Color3.fromRGB(40, 32, 30), Material = M.Basalt })
				local f = Instance.new("Fire")
				f.Color = Color3.fromRGB(255, 120, 20)
				f.SecondaryColor = Color3.fromRGB(255, 40, 10)
				f.Size = 5
				f.Parent = bowl
			end
		end
		for x = -W2, W2, 3 do
			P(deco, { Name = "LavaStrip", Size = Vector3.new(3, 0.1, 0.6), CFrame = L(x, Layout.FLOOR_TOP + 0.05, D - 1.2), Color = Color3.fromRGB(255, 100, 20), Material = M.Neon, CanCollide = false })
		end
	elseif info.theme == "Space" then
		for _, x in { -W2 + 3, W2 - 3 } do
			P(deco, { Name = "Antenna", Size = Vector3.new(0.5, 12, 0.5), CFrame = L(x, 6, D - 3), Color = Color3.fromRGB(180, 186, 200), Material = M.Metal })
			P(deco, { Name = "Dish", Shape = CYL, Size = Vector3.new(0.6, 5, 5), CFrame = L(x, 12, D - 3) * CFrame.Angles(0, 0, 0.6), Color = Color3.fromRGB(220, 224, 232), Material = M.Metal })
			P(deco, { Name = "Beacon", Shape = BALL, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = L(x, 12.8, D - 3), Color = Color3.fromRGB(255, 60, 60), Material = M.Neon, CanCollide = false })
		end
	elseif info.theme == "Golden" then
		P(deco, { Name = "Pediment", Size = Vector3.new(24, 2, 2.4), CFrame = L(0, 14.6, -0.4), Color = gold, Material = M.Foil })
		for _, x in { -W2 + 4, W2 - 4 } do
			for _, d in { 4, D - 4 } do
				P(deco, { Name = "Column", Shape = CYL, Size = Vector3.new(10, 2.2, 2.2), CFrame = L(x, 5.4, d) * VERT, Color = Color3.fromRGB(250, 246, 236), Material = M.Marble })
				P(deco, { Name = "ColumnCap", Size = Vector3.new(3, 0.8, 3), CFrame = L(x, 10.8, d), Color = gold, Material = M.Foil })
			end
		end
	end

	-- Gate arch + sign ----------------------------------------------------------------------------
	for _, sx in { -1, 1 } do
		P(base, { Name = "GatePost", Size = Vector3.new(1.8, 13, 1.8), CFrame = L(sx * (gateHalf + 1.5), 6.5 + Layout.FLOOR_TOP, 0), Color = theme.post, Material = theme.postMat })
	end
	P(base, { Name = "GateBeam", Size = Vector3.new(Layout.GATE_WIDTH + 5, 1.2, 1.8), CFrame = L(0, 13.2, 0), Color = trim, Material = trimMat })
	local sign = P(base, { Name = "Sign", Size = Vector3.new(18, 6, 0.6), CFrame = L(0, 16.8, 0) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(40, 36, 70), Material = M.SmoothPlastic })
	P(base, { Name = "SignFrame", Size = Vector3.new(18.8, 6.8, 0.4), CFrame = L(0, 16.8, 0.15) * CFrame.Angles(0, math.pi, 0), Color = theme.accent, Material = M.Neon })
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

	-- Pads + Collect buttons --------------------------------------------------------------------------
	local pads = folder(base, "Pads")
	local buttons = folder(base, "Buttons")
	for slot = 1, info.slots do
		local x, d = Layout.PadLocal(slot, info.slots)
		local pad = P(pads, { Name = "Pad" .. slot, Size = Vector3.new(8, 0.6, 8), CFrame = L(x, Layout.PAD_TOP - 0.3, d), Color = theme.pad, Material = M.SmoothPlastic })
		pad:SetAttribute("Slot", slot)
		P(pad, { Name = "Glow", Size = Vector3.new(8.8, 0.3, 8.8), CFrame = L(x, Layout.PAD_TOP - 0.5, d), Color = theme.accent, Material = M.Neon, Transparency = 0.35, CanCollide = false })
		-- faint Tung outline + "+" shown while the pad is empty
		local ghost = Instance.new("Model")
		ghost.Name = "Ghost"
		P(ghost, { Name = "GhostBody", Shape = CYL, Size = Vector3.new(4.4, 2.6, 2.6), CFrame = L(x, Layout.PAD_TOP + 4.1, d) * VERT, Color = Color3.new(1, 1, 1), Material = M.ForceField, CanCollide = false, CanQuery = false })
		for _, sx in { -0.55, 0.55 } do
			P(ghost, { Name = "GhostLeg", Shape = CYL, Size = Vector3.new(1.6, 0.6, 0.6), CFrame = L(x + sx, Layout.PAD_TOP + 0.9, d) * VERT, Color = Color3.new(1, 1, 1), Material = M.ForceField, CanCollide = false, CanQuery = false })
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

		local button = P(buttons, { Name = "Button" .. slot, Shape = CYL, Size = Vector3.new(0.5, 4.2, 4.2), CFrame = L(x, Layout.FLOOR_TOP + 0.25, d - 6) * VERT, Color = Color3.fromRGB(190, 190, 196), Material = M.SmoothPlastic })
		button:SetAttribute("Slot", slot)
		P(button, { Name = "Rim", Shape = CYL, Size = Vector3.new(0.3, 4.8, 4.8), CFrame = L(x, Layout.FLOOR_TOP + 0.15, d - 6) * VERT, Color = theme.accent, Material = M.Neon, CanCollide = false, CanTouch = false })
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

	-- Rebirth Altar --------------------------------------------------------------------------------------
	local altarCf = Layout.Altar(i, info.slots)
	P(base, { Name = "AltarGlow", Shape = CYL, Size = Vector3.new(0.1, 10, 10), CFrame = altarCf * CFrame.new(0, 0.05, 0) * VERT, Color = Color3.fromRGB(255, 220, 80), Material = M.Neon, Transparency = 0.4, CanCollide = false })
	local altar = P(base, { Name = "Altar", Shape = CYL, Size = Vector3.new(1.6, 6, 6), CFrame = altarCf * CFrame.new(0, 0.8, 0) * VERT, Color = Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
	P(base, { Name = "AltarStep", Shape = CYL, Size = Vector3.new(0.6, 8, 8), CFrame = altarCf * CFrame.new(0, 0.3, 0) * VERT, Color = trim, Material = trimMat })
	P(base, { Name = "AltarPillar", Shape = CYL, Size = Vector3.new(3, 2, 2), CFrame = altarCf * CFrame.new(0, 3.1, 0) * VERT, Color = Color3.fromRGB(255, 255, 255), Material = M.SmoothPlastic })
	local orb = P(base, { Name = "AltarOrb", Shape = BALL, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = altarCf * CFrame.new(0, 6, 0), Color = Color3.fromRGB(255, 220, 90), Material = M.Neon, CanCollide = false })
	local orbLight = Instance.new("PointLight")
	orbLight.Color = Color3.fromRGB(255, 220, 120)
	orbLight.Range = 14
	orbLight.Brightness = 1.5
	orbLight.Parent = orb
	P(base, { Name = "AltarRing", Shape = CYL, Size = Vector3.new(0.2, 4.4, 4.4), CFrame = altarCf * CFrame.new(0, 6, 0) * CFrame.Angles(0.5, 0, 0) * VERT, Color = Color3.fromRGB(255, 240, 180), Material = M.Neon, CanCollide = false })
	prompt(altar, "Rebirth", "Rebirth Altar", { UI = "Rebirth", OwnerOnly = true })

	-- Lock button + laser gate ----------------------------------------------------------------------------
	local lockStand = P(base, { Name = "LockButton", Size = Vector3.new(2.4, 3, 2.4), CFrame = L(-gateHalf - 6, Layout.FLOOR_TOP + 1.5, 4), Color = theme.post, Material = theme.postMat })
	P(base, { Name = "LockCap", Shape = CYL, Size = Vector3.new(0.6, 2, 2), CFrame = L(-gateHalf - 6, Layout.FLOOR_TOP + 3.2, 4) * VERT, Color = Color3.fromRGB(255, 50, 60), Material = M.Neon })
	prompt(lockStand, "Lock Base", "Laser Gate", { Action = "Lock", OwnerOnly = true })

	local lasers = folder(base, "Lasers")
	for k, y in { 1.5, 3.5, 5.5, 7.5, 9.5 } do
		P(lasers, { Name = "Beam" .. k, Size = Vector3.new(Layout.GATE_WIDTH + 3, 0.3, 0.3), CFrame = L(0, Layout.FLOOR_TOP + y, 0), Color = Color3.fromRGB(255, 40, 50), Material = M.Neon, Transparency = 1, CanCollide = false, CastShadow = false })
	end
	P(lasers, { Name = "Wall", Size = Vector3.new(Layout.GATE_WIDTH + 3, 22, 0.6), CFrame = L(0, 11, 0), Transparency = 1, CanCollide = false, CanQuery = false })

	-- Traps ------------------------------------------------------------------------------------------------
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
		local siren = P(m, { Name = "Siren", Shape = CYL, Size = Vector3.new(1.2, 1.4, 1.4), CFrame = L(gateHalf + 1.5, 13.6 + Layout.FLOOR_TOP, 0) * VERT, Color = Color3.fromRGB(255, 40, 40), Material = M.Neon })
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

	-- Personal belt (Rebirth 6 perk) ----------------------------------------------------------------------------
	if info.personalBelt then
		local pb = folder(base, "PersonalBelt")
		local a, b = Layout.PersonalBelt(i, info.slots)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 2
		local cf = CFrame.lookAt(mid, b)
		P(pb, { Name = "Frame", Size = Vector3.new(4, 1.2, len), CFrame = cf - Vector3.new(0, 0.8, 0), Color = Color3.fromRGB(62, 62, 84), Material = M.SmoothPlastic })
		P(pb, { Name = "Surface", Size = Vector3.new(3.4, 0.2, len), CFrame = cf - Vector3.new(0, 0.1, 0), Color = Color3.fromRGB(226, 40, 52), Material = M.SmoothPlastic })
		P(pb, { Name = "Spawner", Size = Vector3.new(4.4, 5, 4.4), CFrame = CFrame.new(a + (a - b).Unit * 2.5 + Vector3.new(0, 1, 0)), Color = theme.accent, Material = M.SmoothPlastic })
		P(pb, { Name = "SpawnerTop", Shape = CYL, Size = Vector3.new(0.4, 3.6, 3.6), CFrame = CFrame.new(a + (a - b).Unit * 2.5 + Vector3.new(0, 3.7, 0)) * VERT, Color = Color3.fromRGB(255, 255, 255), Material = M.Neon })
	end

	base.PrimaryPart = base:FindFirstChild("Floor") :: BasePart
	base.Parent = parent
	return base
end

-- Max slots this base layout supports (VIP adds one on top of the rebirth slots).
BaseBuilder.MAX_SLOTS = Economy.MAX_SLOTS + 1

return BaseBuilder
