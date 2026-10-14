--!strict
-- Everything 3D the client draws or animates:
--   * signature effects of every Tung (bat taps, Zzz, disco, glitch, runes...)
--   * rarity aura animation, Rainbow skins, Cursed laughs
--   * Tungs following you home, stolen Tungs over a thief's head, Tungs walking home
--   * place puffs, coins flying into you on collect, bonks, rebirth cinematic
--   * rare-spawn hype (drum shake, dark sky + spotlight, Mythic colour flood)
--   * day/night glow, butterflies & fireflies, event tints, Tung Rain clouds
--   * low graphics mode / hide other players' auras, your own laser gate, screen shake

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Tungs = require(Shared.Config.Tungs)
local Remotes = require(Shared.Remotes)
local TungModel = require(Shared.TungModel)

local State = require(script.Parent.State)
local Lib = require(script.Parent.UI.Lib)
local Belt = require(script.Parent.Belt)
local Music = require(script.Parent.Music)

local WorldFx = {}

local player = Players.LocalPlayer
local fxFolder: Folder

-- Camera shake --------------------------------------------------------------------------------------
local shakeUntil, shakeMag = 0, 0
function WorldFx.Shake(magnitude: number, duration: number)
	shakeMag = math.max(if os.clock() < shakeUntil then shakeMag else 0, magnitude)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local function near(pos: Vector3, dist: number): boolean
	return (camPos() - pos).Magnitude < dist
end

local function chat(text: string, color: Color3?)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local sys = channels and channels:FindFirstChild("RBXSystem") :: TextChannel?
		if sys then
			local hex = (color or Color3.fromRGB(255, 210, 80)):ToHex()
			sys:DisplaySystemMessage('<font color="#' .. hex .. '">' .. text .. "</font>")
		end
	end)
end
WorldFx.Chat = chat

-- Aura visibility (low graphics / hide other players' auras) --------------------------------------------
local function ownerOf(inst: Instance): number?
	local m = inst:FindFirstAncestorWhichIsA("Model")
	while m do
		local id = m:GetAttribute("OwnerId")
		if id ~= nil then
			return id :: number
		end
		m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

local function applyAura(inst: Instance)
	if not inst:IsDescendantOf(Workspace) then
		return
	end
	local s = State.settings
	local owner = ownerOf(inst)
	local hidden = s.low or (s.hideAuras and owner ~= nil and owner ~= 0 and owner ~= player.UserId)
	if inst:IsA("ParticleEmitter") or inst:IsA("Fire") or inst:IsA("Light") or inst:IsA("Beam") or inst:IsA("Trail") then
		(inst :: any).Enabled = not hidden
	elseif inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = if hidden then 1 else 0
	elseif inst:IsA("BillboardGui") then
		inst.Enabled = not hidden
	end
end

local function applyAllAuras()
	for _, inst in CollectionService:GetTagged("AuraFx") do
		applyAura(inst)
	end
	-- low graphics: cheaper lighting
	local low = State.settings.low
	for _, c in Lighting:GetChildren() do
		if c:IsA("BloomEffect") or c:IsA("SunRaysEffect") then
			c.Enabled = not low
		end
	end
	Lighting.GlobalShadows = not low
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = not low
	end
end

-- Night glow: lights in auras get brighter after dark.
local function nightGlow()
	local night = Workspace:GetAttribute("Night") == true
	for _, inst in CollectionService:GetTagged("AuraFx") do
		if inst:IsA("PointLight") or inst:IsA("SpotLight") then
			local base = inst:GetAttribute("BaseBrightness") :: number?
			if not base then
				base = inst.Brightness
				inst:SetAttribute("BaseBrightness", base)
			end
			inst.Brightness = (base :: number) * (if night then 2.2 else 1)
		end
	end
end

-- Signature animations ---------------------------------------------------------------------------------
type Anim = {
	model: Model,
	effect: string,
	rarity: string,
	mut: string,
	phase: number,
	bat: Model?,
	batRel: CFrame?,
	hat: Model?,
	hatRel: CFrame?,
	skin: { BasePart },
	allParts: { BasePart },
	timer: number,
	state: number,
	extra: { [string]: any },
}

local anims: { [Model]: Anim } = {}

local function track(model: Instance)
	if not model:IsA("Model") or not model:IsDescendantOf(Workspace) or anims[model] then
		return
	end
	local m = model :: Model
	local bat = m:FindFirstChild("Bat") :: Model?
	local hat = m:FindFirstChild("Hat") :: Model?
	local pivot = m:GetPivot()
	local skin, all = {}, {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(all, d)
			if d:GetAttribute("Skin") then
				table.insert(skin, d)
			end
		end
	end
	anims[m] = {
		model = m,
		effect = (m:GetAttribute("Effect") :: string?) or "",
		rarity = (m:GetAttribute("Rarity") :: string?) or "Common",
		mut = (m:GetAttribute("Mutation") :: string?) or Mutations.NONE,
		phase = math.random() * 10,
		bat = bat,
		batRel = if bat then pivot:ToObjectSpace(bat:GetPivot()) else nil,
		hat = hat,
		hatRel = if hat then pivot:ToObjectSpace(hat:GetPivot()) else nil,
		skin = skin,
		allParts = all,
		timer = 0,
		state = 0,
		extra = {},
	}
end

local function untrack(model: Instance)
	local a = anims[model :: Model]
	if a then
		for _, v in a.extra do
			if typeof(v) == "Instance" then
				(v :: Instance):Destroy()
			end
		end
		anims[model :: Model] = nil
	end
end

local function ring(pos: Vector3, color: Color3, fromSize: number, toSize: number, time: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.3
	p.Size = Vector3.new(0.08, fromSize, fromSize)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.08, toSize, toSize), Transparency = 1 }):Play()
	task.delay(time, function()
		p:Destroy()
	end)
end

local function batAngle(a: Anim, t: number): number
	-- quick swing down and back every few seconds
	local period = if a.effect == "Quake" then 4 else 3.2
	local x = (t + a.phase) % period
	if x < 0.5 then
		return math.sin(x / 0.5 * math.pi) * 1.5
	end
	return 0
end

local function onBatHit(a: Anim, pivot: CFrame)
	local feet = pivot.Position
	if a.effect == "Coins" then
		local body = a.model:FindFirstChild("Body")
		local e = body and body:FindFirstChild("Coins") :: ParticleEmitter?
		if e and not State.settings.low then
			e:Emit(10)
		end
	elseif a.effect == "Quake" then
		local d = (camPos() - feet).Magnitude
		if d < 70 then
			WorldFx.Shake(math.clamp(1.2 - d / 70, 0.15, 1.2), 0.35)
			Lib.sound3D("Bonk", feet, 0.9, 0.45)
		end
		ring(feet + Vector3.new(0, 0.1, 0), Color3.fromRGB(255, 80, 20), 3, 16, 0.6)
	elseif a.effect == "BatTap" and near(feet, 35) then
		Lib.sound3D("Tung", feet, 0.35, 1.1)
	end
end

local function animate(a: Anim, t: number, dt: number)
	local m = a.model
	local pivot = m:GetPivot()
	local e = a.effect

	-- bat
	if a.bat and a.batRel and (e == "BatTap" or e == "Coins" or e == "Quake") then
		local ang = batAngle(a, t)
		a.bat:PivotTo(pivot * a.batRel * CFrame.Angles(-ang, 0, 0))
		local hitNow = ang > 1.35
		if hitNow and a.state == 0 then
			a.state = 1
			onBatHit(a, pivot)
		elseif ang < 0.5 then
			a.state = 0
		end
	end

	if e == "HatBounce" and a.hat and a.hatRel then
		a.hat:PivotTo(pivot * a.hatRel + Vector3.new(0, math.abs(math.sin((t + a.phase) * 5)) * 0.45, 0))
	elseif e == "Zzz" then
		local body = m:FindFirstChild("Body")
		local bb = body and body:FindFirstChild("Zzz") :: BillboardGui?
		if bb then
			local x = ((t + a.phase) % 2.5) / 2.5
			bb.StudsOffset = Vector3.new(1.4 + x * 0.6, 3.2 + x * 2.2, 0)
			local l = bb:FindFirstChildOfClass("TextLabel")
			if l then
				l.TextTransparency = x * x
			end
		end
	elseif e == "Squeak" then
		a.timer += dt
		if a.timer > 2.4 then
			a.timer = 0
			if near(pivot.Position, 30) then
				Lib.sound3D("Squeak", pivot.Position)
			end
		end
	elseif e == "Drum" then
		local drum = m:FindFirstChild("Drum") :: Model?
		if drum then
			if not a.extra.drumRel then
				a.extra.drumRel = pivot:ToObjectSpace(drum:GetPivot())
			end
			local beat = ((t + a.phase) * 4) % 4
			local hit = beat % 1 < 0.15
			drum:PivotTo(pivot * (a.extra.drumRel :: CFrame) + Vector3.new(0, if hit then -0.12 else 0, 0))
			a.timer += dt
			if a.timer > 1 then
				a.timer = 0
				if near(pivot.Position, 28) then
					Lib.sound3D("Tung", pivot.Position, 0.3, 1.6)
				end
			end
		end
	elseif e == "Bubble" then
		local b = m:FindFirstChild("Bubble") :: BasePart?
		if b then
			local x = ((t + a.phase) % 3) / 3
			local scale = (m:GetAttribute("Height") :: number? or 6.4) / 6.4
			local size = (0.3 + x * 2.2) * scale
			b.Size = Vector3.new(size, size, size)
			if not a.extra.bubbleRel then
				a.extra.bubbleRel = pivot:ToObjectSpace(b.CFrame)
			end
			b.CFrame = pivot * (a.extra.bubbleRel :: CFrame) * CFrame.new(0, 0, -size * 0.4)
			if x > 0.97 and a.state == 0 then
				a.state = 1
				if near(pivot.Position, 30) then
					Lib.sound3D("Pop2", pivot.Position)
				end
			elseif x < 0.5 then
				a.state = 0
			end
		end
	elseif e == "Ninja" then
		local x = (t + a.phase) % 10
		local target = if x < 2.5 then 0.6 else 0
		if a.extra.ninja ~= target then
			a.extra.ninja = target
			for _, p in a.allParts do
				if not CollectionService:HasTag(p, "AuraFx") then
					p.LocalTransparencyModifier = target
				end
			end
		end
	elseif e == "Disco" then
		local ball = m:FindFirstChild("DiscoBall") :: BasePart?
		if ball then
			ball.CFrame = CFrame.new(ball.Position) * CFrame.Angles(0, t * 3, 0)
			for i, l in { ball:FindFirstChild("Disco1"), ball:FindFirstChild("Disco2") } do
				if l and l:IsA("SpotLight") then
					l.Color = Color3.fromHSV((t * 0.5 + i * 0.5) % 1, 0.8, 1)
				end
			end
		end
	elseif e == "Robo" then
		local visor = m:FindFirstChild("Visor") :: BasePart?
		if visor then
			visor.Transparency = 0.2 + math.abs(math.sin(t * 3 + a.phase)) * 0.5
			local beam = a.extra.beam :: BasePart?
			if not beam and not State.settings.low then
				local p = Instance.new("Part")
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Material = Enum.Material.Neon
				p.Color = Color3.fromRGB(255, 40, 40)
				p.Transparency = 0.35
				p.Size = Vector3.new(0.12, 0.12, 9)
				p.Parent = fxFolder
				a.extra.beam = p
				beam = p
			end
			if beam then
				local sweep = math.sin(t * 1.6 + a.phase) * 0.6
				beam.CFrame = visor.CFrame * CFrame.Angles(-0.35, sweep, 0) * CFrame.new(0, 0, -4.6)
			end
			a.timer += dt
			if a.timer > 4 then
				a.timer = 0
				if near(visor.Position, 25) then
					Lib.sound3D("Beep", visor.Position)
				end
			end
		end
	elseif e == "Glitch" then
		a.timer += dt
		if a.timer > 0.12 then
			a.timer = 0
			local flick = math.random() < 0.3
			for _, p in a.skin do
				p.Color = if flick then Color3.fromRGB(40, 255, 240) else Color3.fromRGB(255, 40, 200)
			end
			if math.random() < 0.05 and not a.extra.jumped then
				a.extra.jumped = true
				local off = Vector3.new(math.random(-20, 20) / 10, 0, math.random(-20, 20) / 10)
				for _, p in a.allParts do
					p.CFrame += off
				end
				task.delay(0.25, function()
					if m.Parent then
						for _, p in a.allParts do
							p.CFrame -= off
						end
					end
					a.extra.jumped = nil
				end)
			end
		end
	elseif e == "Ripples" then
		a.timer += dt
		if a.timer > 1.4 and not State.settings.low then
			a.timer = 0
			ring(pivot.Position + Vector3.new(0, 0.1, 0), Color3.fromRGB(90, 200, 255), 3, 18, 1.4)
		end
	elseif e == "Runes" then
		for i = 1, 4 do
			local r = m:FindFirstChild("Rune" .. i) :: BasePart?
			if r then
				local ang = t * 1.2 + i * math.pi / 2
				local scale = (m:GetAttribute("Height") :: number? or 6.4) / 6.4
				r.CFrame = pivot * CFrame.new(math.cos(ang) * 3.4 * scale, (4 + math.sin(t * 2 + i) * 0.8) * scale, math.sin(ang) * 3.4 * scale)
			end
		end
		a.timer += dt
		if a.timer > 2.5 and not State.settings.low then
			a.timer = 0
			-- lightning crackle
			local from = pivot.Position + Vector3.new(math.random(-3, 3), 9, math.random(-3, 3))
			local prev = from
			for k = 1, 4 do
				local nextP = from:Lerp(pivot.Position + Vector3.new(0, 4, 0), k / 4) + Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
				local seg = Instance.new("Part")
				seg.Anchored = true
				seg.CanCollide = false
				seg.CanQuery = false
				seg.CanTouch = false
				seg.Material = Enum.Material.Neon
				seg.Color = Color3.fromRGB(220, 160, 255)
				seg.Size = Vector3.new(0.15, 0.15, (nextP - prev).Magnitude)
				seg.CFrame = CFrame.lookAt((prev + nextP) / 2, nextP)
				seg.Parent = fxFolder
				task.delay(0.15, function()
					seg:Destroy()
				end)
				prev = nextP
			end
		end
	end

	-- rarity aura motion
	if a.rarity == "Epic" then
		local scale = (m:GetAttribute("Height") :: number? or 6.4) / 6.4
		for i = 1, 2 do
			local orb = m:FindFirstChild("Orb" .. i) :: BasePart?
			if orb then
				local ang = t * 2 + i * math.pi
				orb.CFrame = pivot * CFrame.new(math.cos(ang) * 2.5 * scale, (4 + math.sin(t * 3 + i) * 0.7) * scale, math.sin(ang) * 2.5 * scale)
			end
		end
		local shell = m:FindFirstChild("AuraShell") :: BasePart?
		if shell then
			shell.Transparency = 0.15 + (math.sin(t * 3 + a.phase) + 1) * 0.3
		end
	elseif a.rarity == "Secret" then
		local shell = m:FindFirstChild("AuraShell") :: BasePart?
		if shell then
			shell.Color = Color3.fromHSV((t * 0.25 + a.phase) % 1, 0.8, 1)
		end
	elseif a.rarity == "Legendary" then
		local beam = m:FindFirstChild("AuraBeam") :: BasePart?
		if beam then
			beam.Transparency = 0.75 + math.sin(t * 2 + a.phase) * 0.07
		end
	end

	-- mutations
	if a.mut == "Rainbow" then
		for i, p in a.skin do
			p.Color = Color3.fromHSV((t * 0.35 + i * 0.08) % 1, 0.75, 1)
		end
	elseif a.mut == "Cursed" then
		a.extra.laugh = ((a.extra.laugh :: number?) or (8 + a.phase)) - dt
		if (a.extra.laugh :: number) <= 0 then
			a.extra.laugh = 10 + math.random() * 8
			if near(pivot.Position, 40) then
				Lib.sound3D("Laugh", pivot.Position)
			end
		end
	end
end

-- Followers, carried & walking-home Tungs --------------------------------------------------------------------
type Carrier = { following: string, carrying: string, followers: { Model }, carried: Model? }
local carriers: { [Player]: Carrier } = {}

local function buildSmall(id: string, mut: string, scale: number): Model
	local m = TungModel.Build(id, mut, { aura = true })
	m:ScaleTo((m:GetScale()) * scale)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	m.Parent = fxFolder
	return m
end

local function parsePair(s: string): (string, string)
	local id, mut = string.match(s, "^([^|]+)|?(.*)$")
	return id or s, if mut and mut ~= "" then mut else Mutations.NONE
end

local function refreshCarrier(p: Player)
	local c = carriers[p]
	if not c then
		c = { following = "", carrying = "", followers = {}, carried = nil }
		carriers[p] = c
	end
	local carrier = c :: Carrier
	local following = (p:GetAttribute("Following") :: string?) or ""
	local carrying = (p:GetAttribute("Carrying") :: string?) or ""
	if following ~= carrier.following then
		carrier.following = following
		for _, m in carrier.followers do
			m:Destroy()
		end
		carrier.followers = {}
		if following ~= "" then
			for _, pair in string.split(following, ",") do
				local id, mut = parsePair(pair)
				if Tungs.Get(id) then
					table.insert(carrier.followers, buildSmall(id, mut, 0.75))
				end
			end
		end
	end
	if carrying ~= carrier.carrying then
		carrier.carrying = carrying
		if carrier.carried then
			carrier.carried:Destroy()
			carrier.carried = nil
		end
		if carrying ~= "" then
			local id, mut = parsePair(carrying)
			if Tungs.Get(id) then
				carrier.carried = buildSmall(id, mut, 0.6)
			end
		end
	end
end

local function updateCarriers(t: number)
	for p, c in carriers do
		local ch = p.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = ch and ch:FindFirstChild("Head") :: BasePart?
		if not hrp then
			continue
		end
		if c.carried and head then
			c.carried:PivotTo(head.CFrame * CFrame.new(0, 1.2 + math.sin(t * 8) * 0.15, 0) * CFrame.Angles(0, 0, math.sin(t * 5) * 0.12))
		end
		local groundY = hrp.Position.Y - 2.9
		for k, m in c.followers do
			local back = hrp.CFrame * CFrame.new((k % 2 == 0 and 2 or -2), 0, 3.5 + k * 3)
			local target = Vector3.new(back.Position.X, groundY + math.abs(math.sin(t * 9 + k)) * 0.5, back.Position.Z)
			local cur = m:GetPivot().Position
			local pos = cur:Lerp(target, 0.18)
			local look = hrp.Position - pos
			local flat = Vector3.new(look.X, 0, look.Z)
			local rot = if flat.Magnitude > 0.1 then CFrame.lookAt(Vector3.zero, flat) else m:GetPivot().Rotation
			m:PivotTo(CFrame.new(pos) * rot)
		end
	end
end

local function walkHome(d: any)
	local t = Tungs.Get(d.tung)
	if not t then
		return
	end
	local m = buildSmall(d.tung, d.mut, 1)
	local start = os.clock()
	local dir = Vector3.new(d.to.X - d.from.X, 0, d.to.Z - d.from.Z)
	local rot = if dir.Magnitude > 0.1 then CFrame.lookAt(Vector3.zero, dir) else CFrame.identity
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / d.dur, 0, 1)
		local pos = d.from:Lerp(d.to, a) + Vector3.new(0, math.abs(math.sin(a * math.pi * 6)) * 0.8, 0)
		m:PivotTo(CFrame.new(pos) * rot)
		if a >= 1 then
			conn:Disconnect()
			m:Destroy()
		end
	end)
end

-- One-shot effects -------------------------------------------------------------------------------------------
local function puff(pos: Vector3, color: Color3?)
	if State.settings.low then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = fxFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(5, 8)
	e.SpreadAngle = Vector2.new(90, 90)
	e.Size = NumberSequence.new(1.4, 2.6)
	e.Transparency = NumberSequence.new(0.35, 1)
	e.Color = ColorSequence.new(color or Color3.fromRGB(210, 190, 160))
	e.Parent = p
	e:Emit(18)
	task.delay(1.5, function()
		p:Destroy()
	end)
end

local function stars(pos: Vector3, color: Color3)
	if State.settings.low then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = fxFolder
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(8, 14)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.9, 0)
	e.LightEmission = 1
	e.Color = ColorSequence.new(color)
	e.Parent = p
	e:Emit(24)
	task.delay(1.5, function()
		p:Destroy()
	end)
end

local function fireworks(center: Vector3)
	for k = 1, 6 do
		task.delay(k * 0.25, function()
			local pos = center + Vector3.new(math.random(-20, 20), math.random(28, 45), math.random(-20, 20))
			stars(pos, Color3.fromHSV(math.random(), 0.8, 1))
			Lib.sound3D("Firework", pos, 0.6)
		end)
	end
end

local coinTemplate: Part? = nil
local function flyCoins(from: Vector3, count: number)
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	if not coinTemplate then
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.25, 1, 1)
		c.Color = Color3.fromRGB(255, 205, 50)
		c.Material = Enum.Material.Foil
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		coinTemplate = c
	end
	for k = 1, count do
		local coin = (coinTemplate :: Part):Clone()
		local start = from + Vector3.new(math.random(-15, 15) / 10, 6, math.random(-15, 15) / 10)
		coin.CFrame = CFrame.new(start)
		coin.Parent = fxFolder
		local delay = (k - 1) * 0.04
		task.delay(delay, function()
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local a = math.clamp((os.clock() - t0) / 0.45, 0, 1)
				local target = hrp.Position
				local pos = start:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 4, 0)
				coin.CFrame = CFrame.new(pos) * CFrame.Angles(0, a * 12, math.rad(90))
				if a >= 1 then
					conn:Disconnect()
					coin:Destroy()
				end
			end)
		end)
	end
end

-- Rare spawn hype ---------------------------------------------------------------------------------------------
local hypeCC: ColorCorrectionEffect
local eventCC: ColorCorrectionEffect

local function shakeDrum()
	local arena = Workspace:FindFirstChild("Arena")
	local belt = arena and arena:FindFirstChild("Belt")
	local drum = belt and belt:FindFirstChild("Drum") :: Model?
	if not drum then
		return
	end
	local base = drum:GetPivot()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1.6 do
			local k = 1 - (os.clock() - t0) / 1.6
			drum:PivotTo(base * CFrame.Angles(math.rad(math.random(-3, 3)) * k, 0, math.rad(math.random(-3, 3)) * k))
			task.wait(0.03)
		end
		drum:PivotTo(base)
	end)
	task.spawn(function()
		for _ = 1, 10 do
			Lib.sound3D("Drumroll", Layout.DRUM_POS, 0.6, 0.9 + math.random() * 0.3)
			task.wait(0.09)
		end
	end)
end

local function spotlight(entryId: number, color: Color3, seconds: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Parent = fxFolder
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Bottom
	s.Angle = 28
	s.Range = 40
	s.Brightness = 8
	s.Color = color
	s.Parent = p
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local m = Belt.GetModel(entryId)
		if not m or os.clock() - t0 > seconds then
			conn:Disconnect()
			p:Destroy()
			return
		end
		p.CFrame = CFrame.new(m:GetPivot().Position + Vector3.new(0, 26, 0))
	end)
end

local function darkenSky(seconds: number, tint: Color3, brightness: number)
	hypeCC.TintColor = tint
	TweenService:Create(hypeCC, TweenInfo.new(0.6), { Brightness = brightness, Contrast = 0.15 }):Play()
	task.delay(seconds, function()
		TweenService:Create(hypeCC, TweenInfo.new(1.2), { Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	end)
end

local function onHype(h: any)
	local t = Tungs.Get(h.tung)
	if not t then
		return
	end
	local color = Tungs.Color(t)
	local name = Mutations.Prefix(h.mut) .. t.name
	shakeDrum()
	if h.level == "Secret" or h.level == "Mythic" then
		darkenSky(5, Color3.fromRGB(150, 140, 190), -0.25)
		spotlight(h.entry, if h.level == "Secret" then Color3.fromRGB(255, 255, 255) else color, 30)
	end
	if h.level == "Mythic" then
		Music.Cut(9)
		Music.Chant(3)
		task.delay(1, function()
			darkenSky(6, color, -0.1)
			WorldFx.Shake(0.4, 1.5)
		end)
	end
	chat("[TUNG MACHINE] " .. (if h.level == "Mythic" then "🔥 A MYTHIC " elseif h.level == "Secret" then "🌑 A SECRET " else "✨ A LEGENDARY ") .. string.upper(name) .. " IS ON THE BELT!", color)
	State.Fire("Hype", h.level, name, color, t)
end

-- Ambient life: butterflies by day, fireflies by night ------------------------------------------------------------
type Critter = { part: BasePart, wings: { BasePart }?, home: Vector3, phase: number }
local critters: { Critter } = {}

local function makeCritters()
	local rng = Random.new()
	for k = 1, 14 do
		local body = Instance.new("Part")
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		body.CastShadow = false
		body.Size = Vector3.new(0.2, 0.2, 0.5)
		body.Color = Color3.fromRGB(60, 40, 30)
		body.Parent = fxFolder
		local wings: { BasePart } = {}
		local wingColor = Color3.fromHSV(rng:NextNumber(), 0.6, 1)
		for _ = 1, 2 do
			local w = Instance.new("Part")
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.CastShadow = false
			w.Size = Vector3.new(0.6, 0.05, 0.5)
			w.Color = wingColor
			w.Material = Enum.Material.SmoothPlastic
			w.Parent = fxFolder
			table.insert(wings, w)
		end
		table.insert(critters, { part = body :: BasePart, wings = wings :: { BasePart }?, home = Layout.RandomCorridorPoint(rng) + Vector3.new(0, rng:NextNumber(2, 6), 0), phase = k })
	end
	for k = 1, 22 do
		local f = Instance.new("Part")
		f.Shape = Enum.PartType.Ball
		f.Anchored = true
		f.CanCollide = false
		f.CanQuery = false
		f.CanTouch = false
		f.CastShadow = false
		f.Size = Vector3.new(0.3, 0.3, 0.3)
		f.Material = Enum.Material.Neon
		f.Color = Color3.fromRGB(255, 240, 120)
		f.Transparency = 1
		f.Parent = fxFolder
		table.insert(critters, { part = f :: BasePart, wings = nil :: { BasePart }?, home = Layout.RandomCorridorPoint(rng) + Vector3.new(0, rng:NextNumber(1.5, 5), 0), phase = k * 1.7 })
	end
end

local function updateCritters(t: number)
	local night = Workspace:GetAttribute("Night") == true
	local hidden = State.settings.low
	for _, c in critters do
		local p = c.home + Vector3.new(math.sin(t * 0.4 + c.phase) * 6, math.sin(t * 1.3 + c.phase) * 1.2, math.cos(t * 0.33 + c.phase) * 6)
		if c.wings then
			local show = not night and not hidden
			c.part.Transparency = if show then 0 else 1
			local heading = CFrame.lookAt(p, p + Vector3.new(math.cos(t * 0.4 + c.phase), 0, -math.sin(t * 0.33 + c.phase)))
			c.part.CFrame = heading
			local flap = math.sin(t * 18 + c.phase) * 0.9
			for k, w in c.wings do
				local side = if k == 1 then 1 else -1
				w.Transparency = if show then 0 else 1
				w.CFrame = heading * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 0.32, 0, 0)
			end
		else
			c.part.Transparency = if night and not hidden then (0.2 + (math.sin(t * 3 + c.phase) + 1) * 0.35) else 1
			c.part.CFrame = CFrame.new(p)
		end
	end
end

-- Event tints ---------------------------------------------------------------------------------------------------------
local rainEmitter: ParticleEmitter? = nil
local function eventVisuals()
	local ev = Workspace:GetAttribute("Event")
	local tint, bright, sat = Color3.new(1, 1, 1), 0, 0
	if ev == "SahurHour" then
		tint, bright, sat = Color3.fromRGB(205, 170, 255), -0.08, 0.1
	elseif ev == "ThiefNight" then
		tint, bright, sat = Color3.fromRGB(255, 190, 200), -0.12, -0.05
	elseif ev == "GoldenBelt" then
		tint, bright, sat = Color3.fromRGB(255, 240, 200), 0.02, 0.1
	end
	if Workspace:GetAttribute("AdminAbuse") then
		tint = tint:Lerp(Color3.fromRGB(255, 200, 235), 0.5)
	end
	TweenService:Create(eventCC, TweenInfo.new(2), { TintColor = tint, Brightness = bright, Saturation = sat }):Play()
	if rainEmitter then
		rainEmitter.Enabled = ev == "TungRain" and not State.settings.low
	end
end

-- Own laser gate: the owner walks straight through ---------------------------------------------------------------------
local function hookOwnLasers(base: Instance)
	if not base:IsA("Model") then
		return
	end
	local function check()
		if base:GetAttribute("OwnerId") ~= player.UserId then
			return
		end
		local lasers = base:FindFirstChild("Lasers")
		local wall = lasers and lasers:FindFirstChild("Wall") :: BasePart?
		if wall then
			wall.CanCollide = false
			wall:GetPropertyChangedSignal("CanCollide"):Connect(function()
				if wall.CanCollide and base:GetAttribute("OwnerId") == player.UserId then
					wall.CanCollide = false
				end
			end)
		end
	end
	check()
	base:GetAttributeChangedSignal("OwnerId"):Connect(check)
end

-- Tapping a Tung: a hollow wooden "TUNG" (higher for small Tungs, deeper for big ones)
local function tapTung(screenPos: Vector2)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	local hit = result and result.Instance
	if not hit or hit.Name ~= "Body" then
		return
	end
	local model = hit:FindFirstAncestorWhichIsA("Model")
	if not model or not CollectionService:HasTag(model, "Tung") then
		return
	end
	local height = (model:GetAttribute("Height") :: number?) or 6.4
	Lib.sound3D("Tung", hit.Position, 0.8, math.clamp(1.25 * 6.4 / height, 0.5, 2))
	local body = hit :: BasePart
	local size = body.Size
	body.Size = Vector3.new(size.X * 0.88, size.Y * 1.08, size.Z * 1.08)
	task.delay(0.12, function()
		if body.Parent then
			body.Size = size
		end
	end)
end

-- Init -------------------------------------------------------------------------------------------------------------------
function WorldFx.Init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			tapTung(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFx"
	fxFolder.Parent = Workspace

	hypeCC = Instance.new("ColorCorrectionEffect")
	hypeCC.Name = "HypeTint"
	hypeCC.Parent = Lighting
	eventCC = Instance.new("ColorCorrectionEffect")
	eventCC.Name = "EventTint"
	eventCC.Parent = Lighting

	-- Tung tracking
	for _, m in CollectionService:GetTagged("Tung") do
		track(m)
	end
	CollectionService:GetInstanceAddedSignal("Tung"):Connect(function(m)
		task.defer(track, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Tung"):Connect(untrack)

	-- Aura visibility
	CollectionService:GetInstanceAddedSignal("AuraFx"):Connect(function(inst)
		task.defer(applyAura, inst)
	end)
	State.On("Settings", applyAllAuras)
	applyAllAuras()
	Workspace:GetAttributeChangedSignal("Night"):Connect(nightGlow)
	task.spawn(function()
		while true do
			task.wait(5)
			nightGlow()
		end
	end)

	-- Carriers
	local function hookPlayer(p: Player)
		refreshCarrier(p)
		p:GetAttributeChangedSignal("Following"):Connect(function()
			refreshCarrier(p)
		end)
		p:GetAttributeChangedSignal("Carrying"):Connect(function()
			refreshCarrier(p)
		end)
	end
	for _, p in Players:GetPlayers() do
		hookPlayer(p)
	end
	Players.PlayerAdded:Connect(hookPlayer)
	Players.PlayerRemoving:Connect(function(p)
		local c = carriers[p]
		if c then
			for _, m in c.followers do
				m:Destroy()
			end
			if c.carried then
				c.carried:Destroy()
			end
			carriers[p] = nil
		end
	end)

	-- Remote effects
	Remotes.Event("WalkHome").OnClientEvent:Connect(walkHome)
	Remotes.Event("PlaceFx").OnClientEvent:Connect(function(d)
		local t = Tungs.Get(d.tung)
		if not t then
			return
		end
		local scale = (t.scale or 1) * Rarities.Get(t.rarity).scale
		puff(d.pos + Vector3.new(0, 0.5, 0), nil)
		Lib.sound3D("Place", d.pos, nil, 1.3 / scale)
		Lib.sound3D("Tung", d.pos, 0.5, 1.2 / scale)
		if t.effect == "Fanfare" then
			Lib.sound3D("Fanfare", d.pos, 0.8)
		end
		if d.mut == "Cursed" then
			Lib.sound3D("Laugh", d.pos)
		end
		ring(d.pos + Vector3.new(0, 0.1, 0), Tungs.Color(t), 2, 10, 0.5)
	end)
	Remotes.Event("CollectFx").OnClientEvent:Connect(function(list)
		local total = 0
		for _, item in list do
			total += item.amount
			flyCoins(item.from, math.clamp(math.floor(math.log10(item.amount + 1) * 2), 3, 10))
		end
		State.Fire("CollectPop", total)
	end)
	Remotes.Event("BonkFx").OnClientEvent:Connect(function(d)
		if d.slip then
			Lib.sound3D("Slip", d.pos)
			stars(d.pos, Color3.fromRGB(255, 230, 80))
		else
			Lib.sound3D("Bonk", d.pos)
			stars(d.pos, if d.thief then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 240, 160))
			if near(d.pos, 12) then
				WorldFx.Shake(0.25, 0.2)
			end
		end
	end)
	Remotes.Event("RebirthFx").OnClientEvent:Connect(function(d)
		for _, item in d.tungs do
			if Tungs.Get(item.tung) then
				local m = TungModel.Build(item.tung, item.mut, { aura = false })
				m:PivotTo(item.cf)
				m.Parent = fxFolder
				local t0 = os.clock()
				local spin = math.random() * 4 + 2
				local conn
				conn = RunService.RenderStepped:Connect(function()
					local a = (os.clock() - t0) / 2.2
					m:PivotTo(item.cf * CFrame.new(0, a * a * 140, 0) * CFrame.Angles(0, a * spin * 6, 0))
					if a >= 1 then
						conn:Disconnect()
						m:Destroy()
					end
				end)
			end
		end
		fireworks(d.center)
		task.delay(1.8, function()
			fireworks(d.center)
		end)
		if d.player == player.UserId then
			State.Fire("RebirthFlash")
		end
	end)
	Remotes.Event("Hype").OnClientEvent:Connect(onHype)
	Remotes.Event("Global").OnClientEvent:Connect(function(d)
		local color = if type(d.color) == "string" then Color3.fromHex(d.color) else nil
		chat((if d.localOnly then "" else "[GLOBAL] ") .. d.text, color)
		if not d.localOnly then
			State.Fire("Toast", "🌍 " .. d.text, "hype")
		end
	end)

	-- Lasers on own base
	local arena = Workspace:WaitForChild("Arena")
	local bases = arena:WaitForChild("Bases")
	for _, b in bases:GetChildren() do
		hookOwnLasers(b)
	end
	bases.ChildAdded:Connect(function(b)
		task.defer(hookOwnLasers, b)
	end)

	-- Events
	Workspace:GetAttributeChangedSignal("Event"):Connect(function()
		eventVisuals()
		if Workspace:GetAttribute("Event") == "SahurHour" then
			Music.Chant(4)
		end
	end)
	Workspace:GetAttributeChangedSignal("AdminAbuse"):Connect(eventVisuals)
	local rainPart = Instance.new("Part")
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(80, 1, 80)
	rainPart.Parent = fxFolder
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Rate = 120
	rain.Lifetime = NumberRange.new(1.2)
	rain.Speed = NumberRange.new(40, 50)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Size = NumberSequence.new(0.25)
	rain.Color = ColorSequence.new(Color3.fromRGB(170, 210, 255))
	rain.Enabled = false
	rain.Parent = rainPart
	rainEmitter = rain
	eventVisuals()
	makeCritters()

	-- Per-frame update
	local accum = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		updateCarriers(t)
		rainPart.CFrame = CFrame.new(camPos() + Vector3.new(0, 40, 0))
		accum += dt
		if accum >= 1 / 30 then
			local step = accum
			accum = 0
			local cp = camPos()
			for m, a in anims do
				if not m.Parent then
					untrack(m)
				elseif (m:GetPivot().Position - cp).Magnitude < 160 then
					animate(a, t, step)
				end
			end
			updateCritters(t)
		end
	end)

	-- camera shake runs after the camera updates
	RunService:BindToRenderStep("StealATungShake", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() < shakeUntil then
			local cam = Workspace.CurrentCamera
			if cam then
				local k = shakeMag * (shakeUntil - os.clock())
				cam.CFrame *= CFrame.Angles(math.rad(math.random(-10, 10) / 10 * k), math.rad(math.random(-10, 10) / 10 * k), 0) + Vector3.new(math.random(-10, 10) / 40 * k, math.random(-10, 10) / 40 * k, 0)
			end
		end
	end)
end

return WorldFx
