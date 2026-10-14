--!strict
-- Crate opening sequence (Design Doc §6.3):
--  1. crate drops in and shakes
--  2. tap 3x to crack it open
--  3. rarity flash + camera zooms onto the droid
--  4. SEPARATE style flash: the "coating" sweeps over the droid with its own chime

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DroidModel = require(Shared.DroidModel)
local Droids = require(Shared.Config.Droids)
local Rarities = require(Shared.Config.Rarities)
local Styles = require(Shared.Config.Styles)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local CrateReveal = {}
local root: ScreenGui? = nil
local playing = false

function CrateReveal.SetRoot(gui: ScreenGui)
	root = gui
end

function CrateReveal.IsPlaying(): boolean
	return playing
end

local function buildCrate(color: Color3): Model
	local m = Instance.new("Model")
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = Vector3.new(4, 4, 4)
	box.Color = Color3.fromRGB(60, 64, 78)
	box.Material = Enum.Material.Metal
	box.Anchored = true
	box.Parent = m
	m.PrimaryPart = box
	for _, axis in { Vector3.new(4.2, 0.35, 0.35), Vector3.new(0.35, 4.2, 0.35), Vector3.new(0.35, 0.35, 4.2) } do
		for _, a in { -1, 1 } do
			for _, b in { -1, 1 } do
				local e = Instance.new("Part")
				e.Size = axis
				e.Color = color
				e.Material = Enum.Material.Neon
				e.Anchored = true
				local off
				if axis.X > 1 then
					off = Vector3.new(0, a * 2, b * 2)
				elseif axis.Y > 1 then
					off = Vector3.new(a * 2, 0, b * 2)
				else
					off = Vector3.new(a * 2, b * 2, 0)
				end
				e.CFrame = CFrame.new(off)
				e.Parent = m
			end
		end
	end
	return m
end

local function flash(parent: Instance, color: Color3, duration: number)
	local f = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0, ZIndex = 50, Parent = parent })
	Lib.tween(f, duration, { BackgroundTransparency = 1 })
	task.delay(duration, function()
		f:Destroy()
	end)
end

local function confetti(parent: Instance, count: number, colors: { Color3 }?)
	for _ = 1, count do
		local c = if colors then colors[math.random(1, #colors)] else Color3.fromHSV(math.random(), 0.85, 1)
		local p = Lib.new("Frame", {
			Size = UDim2.fromOffset(math.random(8, 16), math.random(10, 20)),
			Position = UDim2.fromScale(0.5, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = c,
			Rotation = math.random(0, 360),
			ZIndex = 45,
			Parent = parent,
		})
		local ang = math.random() * math.pi * 2
		local dist = math.random(25, 70) / 100
		Lib.tween(p, math.random(9, 16) / 10, {
			Position = UDim2.fromScale(0.5 + math.cos(ang) * dist, 0.55 + math.sin(ang) * dist + 0.25),
			Rotation = math.random(-720, 720),
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad)
		task.delay(1.7, function()
			p:Destroy()
		end)
	end
end

-- Full-screen fireworks (Mythic + Rainbow, also used by server-wide announcements)
function CrateReveal.Fireworks(parent: Instance?)
	local target = parent or root
	if not target then
		return
	end
	for i = 1, 6 do
		task.delay(i * 0.25, function()
			local holder = Lib.new("Frame", { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(math.random(10, 50) / 100, math.random(5, 40) / 100), BackgroundTransparency = 1, ZIndex = 60, Parent = target })
			confetti(holder, 30)
			task.delay(2, function()
				holder:Destroy()
			end)
		end)
	end
end

local function revealSound(rarity: string)
	if rarity == "Mythic" or rarity == "Iconic" then
		Lib.sound("RevealMythic", 0.8)
	elseif rarity == "Legendary" then
		Lib.sound("RevealLegendary", 0.7)
	elseif rarity == "Epic" then
		Lib.sound("RevealEpic", 0.7)
	else
		Lib.sound("RevealBasic", 0.6)
	end
end

function CrateReveal.Play(result: any, onDone: (() -> ())?)
	if playing or not root then
		return
	end
	playing = true
	local droid = Droids.Get(result.droidId) :: Droids.Droid
	local rarity = Rarities.Get(result.rarity)
	local style = Styles.Get(result.style)
	local quick = State.settings.quickOpen

	local overlay = Lib.new("TextButton", {
		Name = "CrateReveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(5, 6, 14),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 40,
		Parent = root,
	})
	Lib.tween(overlay, 0.25, { BackgroundTransparency = 0.15 })

	-- light rays behind the viewport
	local rays = Lib.new("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = overlay,
	})
	local function setRays(color: Color3, transparency: number)
		for _, r in rays:GetChildren() do
			if r:IsA("Frame") then
				r.BackgroundColor3 = color
				r.BackgroundTransparency = transparency
			end
		end
	end
	for i = 1, 12 do
		local ray = Lib.new("Frame", {
			Size = UDim2.fromOffset(70, 900),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = i * 15,
			ZIndex = 41,
			Parent = rays,
		})
		Lib.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
			Rotation = 90,
			Parent = ray,
		})
	end
	setRays(result.crateColor or Color3.new(1, 1, 1), 0.75)

	local vf = Lib.new("ViewportFrame", {
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		ZIndex = 42,
		Parent = overlay,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.Parent = vf
	vf.CurrentCamera = cam
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4, -16), Vector3.new(0, 1.5, 0))

	local title = Lib.label({ Text = "TAP TO CRACK!", Font = Lib.FontTitle, Size = UDim2.new(0.8, 0, 0, 60), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 46, Parent = overlay })
	local subtitle = Lib.label({ Text = "", Size = UDim2.new(0.8, 0, 0, 36), Position = UDim2.fromScale(0.5, 0.87), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 46, Parent = overlay })

	-- 1. crate drops in
	local crate = buildCrate(result.crateColor or Color3.new(1, 1, 1))
	crate.Parent = vf
	local y = 14
	crate:PivotTo(CFrame.new(0, y, 0))
	local t0 = os.clock()
	while y > 2 do
		local dt = RunService.RenderStepped:Wait()
		y = math.max(2, 14 - (os.clock() - t0) ^ 2 * 60)
		crate:PivotTo(CFrame.new(0, y, 0) * CFrame.Angles(0, (os.clock() - t0) * 3, 0))
		local _ = dt
	end
	Lib.sound("CrateShake", 0.5)

	-- 2. shake + crack (tap or hold, 3 stages)
	local stage = 0
	local spin = os.clock()
	local shaking = true
	task.spawn(function()
		while shaking do
			RunService.RenderStepped:Wait()
			local amp = 0.06 + stage * 0.12
			crate:PivotTo(CFrame.new(math.random(-10, 10) / 10 * amp, 2 + math.random(-10, 10) / 10 * amp, 0) * CFrame.Angles(0, (os.clock() - spin) * (1 + stage), math.random(-10, 10) / 100 * stage))
			rays.Rotation += 0.5 + stage
		end
	end)

	local tapped = Instance.new("BindableEvent")
	local conn = overlay.Activated:Connect(function()
		tapped:Fire()
	end)
	for i = 1, 3 do
		if quick then
			task.wait(0.15)
		else
			-- auto-advance after 1.4s so holding / idle players still get a reveal
			local fired = false
			local c = tapped.Event:Connect(function()
				fired = true
			end)
			local start = os.clock()
			while not fired and os.clock() - start < 1.4 do
				task.wait()
			end
			c:Disconnect()
		end
		stage = i
		Lib.sound("CrateShake", 0.4 + i * 0.15)
		title.Text = if i < 3 then "CRACK! (" .. i .. "/3)" else ""
		-- cracks: edges flare brighter each stage
		for _, p in crate:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "Box" then
				p.Size += Vector3.new(0.12, 0.12, 0.12)
			end
		end
	end
	conn:Disconnect()
	shaking = false

	-- 3. rarity reveal
	crate:Destroy()
	flash(overlay, rarity.color, 0.6)
	revealSound(rarity.name)
	setRays(rarity.color, 0.45)

	-- the droid is shown in Standard first; the style coats it in step 4
	local model = DroidModel.Build(droid.id, "Standard")
	model.Parent = vf
	local _, ext = model:GetBoundingBox()
	local dist = math.max(ext.X, ext.Y, ext.Z) * 2.2
	local center = Vector3.new(0, ext.Y / 2, 0)
	local rotating = true
	task.spawn(function()
		local a = 0
		local zoom = 2.2
		while rotating do
			a += RunService.RenderStepped:Wait() * 0.9
			zoom = zoom + (1 - zoom) * 0.08 -- camera zoom-in
			cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(a) * dist * zoom, dist * 0.3 * zoom, -math.cos(a) * dist * zoom), center)
			rays.Rotation += 0.4
		end
	end)

	title.Text = droid.name
	title.TextColor3 = rarity.color
	subtitle.Text = string.upper(rarity.name) .. (if result.isNew then "  •  NEW!" else "")
	subtitle.TextColor3 = rarity.color
	confetti(overlay, if rarity.index >= 4 then 60 else 20, { rarity.color, rarity.color2, Color3.new(1, 1, 1) })
	if rarity.name == "Mythic" or rarity.name == "Iconic" then
		CrateReveal.Fireworks(overlay)
	end
	if rarity.name == "Iconic" then
		-- the biggest moment in the game: rainbow screen pulse + giant banner
		local wow = Lib.label({ Text = "✨ ICONIC DROID! ✨", Font = Lib.FontTitle, Size = UDim2.new(0.9, 0, 0, 90), Position = UDim2.fromScale(0.5, 0.12), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 47, Parent = overlay })
		local ws = Lib.new("UIScale", { Scale = 0.2, Parent = wow })
		Lib.tween(ws, 0.7, { Scale = 1 }, Enum.EasingStyle.Elastic)
		task.spawn(function()
			local t = 0
			while wow.Parent do
				t += task.wait()
				wow.TextColor3 = Color3.fromHSV((t * 0.6) % 1, 0.7, 1)
			end
		end)
		for k = 1, 3 do
			task.delay(k * 0.35, flash, overlay, Color3.fromHSV(k / 3, 0.6, 1), 0.5)
		end
	end

	-- 4. style reveal — a SEPARATE second flash
	if style.name ~= "Standard" then
		task.wait(if quick then 0.5 else 1.3)
		flash(overlay, style.color, 0.8)
		Lib.sound(if style.name == "Rainbow" then "StyleRainbow" else "StyleShing", 0.8)
		-- "coating" sweep: parts flip to the style one by one, top to bottom.
		-- Both models are built identically, so children line up by index.
		local styled = DroidModel.Build(droid.id, style.name)
		local styledParts = styled:GetChildren()
		local pairsList = {}
		for i, p in model:GetChildren() do
			local s = styledParts[i]
			if p:IsA("BasePart") and p.Name ~= "Root" and s and s:IsA("BasePart") then
				table.insert(pairsList, { p = p, s = s })
			end
		end
		table.sort(pairsList, function(a, b)
			return a.p.Position.Y > b.p.Position.Y
		end)
		for _, pair in pairsList do
			local p, s = pair.p, pair.s
			do
				p.Material = s.Material
				p.Transparency = s.Transparency
				p.Reflectance = s.Reflectance
				Lib.tween(p, 0.25, { Color = s.Color })
			end
			task.wait(0.05)
		end
		styled:Destroy()
		model:SetAttribute("Style", style.name)
		if style.name == "Rainbow" or style.name == "Neon" then
			model:SetAttribute("Animated", true)
			State.Fire("AnimateModel", model)
		end
		subtitle.Text = string.upper(style.name) .. " " .. string.upper(rarity.name) .. "  (+" .. math.floor(style.bonus * 100) .. "%)" .. (if result.isNew then "  •  NEW!" else "")
		subtitle.TextColor3 = style.color
		confetti(overlay, 50, { style.color, Color3.new(1, 1, 1) })
		if style.name == "Rainbow" and rarity.index >= Rarities.Get("Mythic").index then
			CrateReveal.Fireworks(overlay)
		end
	end
	if result.bonusNova and result.bonusNova > 0 then
		State.Fire("Toast", "Bonus! +" .. result.bonusNova .. " Nova Crystals found in the crate", "nova")
	end

	-- wait for dismiss
	task.wait(0.6)
	local hint = Lib.label({ Text = "tap to continue", Size = UDim2.new(0.5, 0, 0, 26), Position = UDim2.fromScale(0.5, 0.93), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Color3.fromRGB(200, 210, 240), ZIndex = 46, Parent = overlay })
	local _ = hint
	local done = false
	local c2 = overlay.Activated:Connect(function()
		done = true
	end)
	local waitStart = os.clock()
	while not done and os.clock() - waitStart < 8 do
		task.wait()
	end
	c2:Disconnect()
	rotating = false
	Lib.tween(overlay, 0.2, { BackgroundTransparency = 1 })
	overlay:Destroy()
	tapped:Destroy()
	playing = false
	if onDone then
		onDone()
	end
end

return CrateReveal
