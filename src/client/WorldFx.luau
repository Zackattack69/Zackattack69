--!strict
-- World-side client visuals: droids that follow players, Rainbow/Neon model
-- animation, and per-world lighting.

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DroidModel = require(Shared.DroidModel)
local Worlds = require(Shared.Config.Worlds)

local State = require(script.Parent.State)

local WorldFx = {}

local LocalPlayer = Players.LocalPlayer
local followersFolder = Instance.new("Folder")
followersFolder.Name = "DroidFollowers"
followersFolder.Parent = workspace

type Follower = { model: Model, offset: Vector3, phase: number }
local followers: { [Player]: { key: string, list: { Follower } } } = {}
local animated: { [Model]: boolean } = {}

local function trackAnimated(model: Model)
	if model:GetAttribute("Animated") then
		animated[model] = true
		model.Destroying:Connect(function()
			animated[model] = nil
		end)
	end
end

local function clearFollowers(player: Player)
	local f = followers[player]
	if f then
		for _, entry in f.list do
			entry.model:Destroy()
		end
		followers[player] = nil
	end
end

local function rebuildFollowers(player: Player)
	local raw = player:GetAttribute("Showcase") :: string?
	local hide = State.settings.hideOthers and player ~= LocalPlayer
	local key = (raw or "") .. tostring(hide)
	if followers[player] and followers[player].key == key then
		return
	end
	clearFollowers(player)
	if not raw or hide then
		followers[player] = { key = key, list = {} }
		return
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		return
	end
	local entries = {}
	for i, d in list do
		local model = DroidModel.Build(d.id, d.style)
		model.Parent = followersFolder
		trackAnimated(model)
		-- formation: a fan behind the player
		local side = if i % 2 == 0 then 1 else -1
		local row = math.ceil(i / 2)
		table.insert(entries, { model = model, offset = Vector3.new(side * (2.5 + row * 1.5), 0, 3 + row * 2.5), phase = i * 1.3 })
	end
	followers[player] = { key = key, list = entries }
end

local function hookPlayer(player: Player)
	player:GetAttributeChangedSignal("Showcase"):Connect(function()
		rebuildFollowers(player)
	end)
	rebuildFollowers(player)
end

local function applyLighting(index: number)
	local world = Worlds.Get(index)
	if not world then
		return
	end
	Lighting.ClockTime = world.clockTime
	Lighting.Ambient = world.colors.ambient
	Lighting.OutdoorAmbient = world.colors.ambient
	Lighting.FogColor = world.colors.fog
	Lighting.FogStart = 0
	Lighting.FogEnd = world.fogEnd
	local atmos = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmos.Color = world.colors.fog
	atmos.Decay = world.colors.ground
	atmos.Density = if index == 2 or index == 8 then 0.45 else 0.3
	atmos.Haze = 1.5
	atmos.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

function WorldFx.Init()
	for _, p in Players:GetPlayers() do
		hookPlayer(p)
	end
	Players.PlayerAdded:Connect(hookPlayer)
	Players.PlayerRemoving:Connect(clearFollowers)
	State.On("Settings", function()
		for _, p in Players:GetPlayers() do
			rebuildFollowers(p)
		end
	end)
	State.On("AnimateModel", trackAnimated)

	-- Server-built showcase droids on foundry plots can be animated too.
	workspace.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("Model") and d:GetAttribute("Animated") then
			trackAnimated(d :: Model)
		end
	end)

	applyLighting(LocalPlayer:GetAttribute("World") or 1)
	LocalPlayer:GetAttributeChangedSignal("World"):Connect(function()
		-- swap lighting while the hyperspace overlay hides the screen
		task.delay(0.9, applyLighting, LocalPlayer:GetAttribute("World") or 1)
	end)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		-- followers trail their owner with a hover bob
		for player, f in followers do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			for _, entry in f.list do
				if root then
					local target = root.CFrame * CFrame.new(entry.offset) * CFrame.new(0, -2.6 + math.sin(t * 3 + entry.phase) * 0.35, 0)
					local current = entry.model:GetPivot()
					local alpha = math.clamp(dt * 8, 0, 1)
					if (current.Position - target.Position).Magnitude > 60 then
						alpha = 1 -- snap after teleports
					end
					entry.model:PivotTo(current:Lerp(target, alpha))
				end
			end
		end
		-- Rainbow hue shift / Neon pulse
		for model in animated do
			local style = model:GetAttribute("Style")
			for i, p in model:GetChildren() do
				if p:IsA("BasePart") and p.Name ~= "Root" then
					if style == "Rainbow" then
						p.Color = Color3.fromHSV((t * 0.25 + i * 0.08) % 1, 0.8, 1)
					elseif style == "Neon" and p:GetAttribute("Role") ~= "Body" then
						p.Color = Color3.fromRGB(0, 255, 230):Lerp(Color3.fromRGB(0, 120, 255), (math.sin(t * 4 + i) + 1) / 2)
					end
				end
			end
		end
	end)
end

return WorldFx
