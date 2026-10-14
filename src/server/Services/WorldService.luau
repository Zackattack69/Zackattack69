--!strict
-- Worlds, foundry plots, spawning, hyperspace travel, name tags + rebirth trails.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DroidModel = require(Shared.DroidModel)
local Economy = require(Shared.Config.Economy)
local Worlds = require(Shared.Config.Worlds)
local Remotes = require(Shared.Remotes)

local Bus = require(script.Parent.Parent.Bus)
local WorldBuilder = require(script.Parent.Parent.WorldBuilder)
local DataService = require(script.Parent.DataService)
local DroidService = require(script.Parent.DroidService)
local EconomyService = require(script.Parent.EconomyService)

local WorldService = {}

local worldsFolder: Folder
local plotOwners: { [number]: Player } = {}
local playerPlot: { [Player]: Model } = {}
local lastTravel: { [Player]: number } = {}

local function getWorldFolder(index: number): Folder
	return worldsFolder:FindFirstChild("World" .. index) :: Folder
end

local function spawnCFrame(player: Player, worldIndex: number): CFrame
	if worldIndex == 1 then
		local plot = playerPlot[player]
		if plot then
			local s = plot:FindFirstChild("PlotSpawn") :: BasePart
			return s.CFrame * CFrame.new(0, 4, 0)
		end
	end
	local spawn = getWorldFolder(worldIndex):FindFirstChild("Spawn") :: BasePart
	local jitter = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
	return CFrame.new(spawn.Position + jitter + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(180), 0)
end

local function moveCharacter(player: Player, cf: CFrame)
	local char = player.Character
	if char and char.PrimaryPart then
		char:PivotTo(cf)
	end
end

-- Plots ------------------------------------------------------------------------------
local function refreshPlot(player: Player)
	local plot = playerPlot[player]
	local p = DataService.Get(player)
	if not plot or not p then
		return
	end
	local accent = Worlds.Get(1).colors.accent
	WorldBuilder.DecoratePlot(plot, p.data.upgrades, accent)
	local sign = plot:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChildWhichIsA("SurfaceGui") and (sign :: any).SurfaceGui.Owner
	if label then
		label.Text = player.DisplayName .. "'s Foundry"
	end
	-- Showcase droids on the pods
	local dyn = plot:FindFirstChild("Dynamic") :: Folder
	for i, entry in DroidService.TopStationed(p.data, 4) do
		local pod = dyn:FindFirstChild("ShowcasePod" .. i) :: BasePart?
		if pod then
			local model = DroidModel.Build(entry.id, entry.style)
			local facing = WorldBuilder.PlotFacing(plot)
			model:PivotTo(CFrame.new(pod.Position + Vector3.new(0, 0.6, 0)) * facing.Rotation)
			model.Parent = dyn
		end
	end
end

local function assignPlot(player: Player)
	for i = 1, WorldBuilder.PLOT_COUNT do
		if not plotOwners[i] then
			plotOwners[i] = player
			local plot = (getWorldFolder(1):FindFirstChild("Plots") :: Folder):FindFirstChild("Plot" .. i) :: Model
			playerPlot[player] = plot
			plot:SetAttribute("Owner", player.UserId)
			player:SetAttribute("Plot", i)
			return
		end
	end
end

local function releasePlot(player: Player)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	local i = plot:GetAttribute("PlotIndex") :: number
	plotOwners[i] = nil
	playerPlot[player] = nil
	plot:SetAttribute("Owner", nil)
	WorldBuilder.DecoratePlot(plot, {}, Worlds.Get(1).colors.accent)
	local sign = plot:FindFirstChild("Sign") :: any
	if sign then
		sign.SurfaceGui.Owner.Text = "EMPTY FOUNDRY"
	end
end

-- Name tag + rebirth trail ------------------------------------------------------------
local function decorateCharacter(player: Player)
	local char = player.Character
	local p = DataService.Get(player)
	if not char or not p then
		return
	end
	local head = char:FindFirstChild("Head") :: BasePart?
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then
		return
	end
	local data = p.data
	local color = Economy.RebirthColor(data.rebirths)

	local old = head:FindFirstChild("FoundryTag")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "FoundryTag"
	bb.Size = UDim2.fromOffset(220, 56)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.45)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = color
	title.Text = data.equippedTitle or ""
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = title
	title.Parent = bb
	local vip = if Economy.HasPass(data, "VIP") then "👑 " else ""
	local nameLabel = title:Clone()
	nameLabel.Position = UDim2.fromScale(0, 0.45)
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.TextColor3 = if data.rebirths >= 8 then color else Color3.new(1, 1, 1)
	nameLabel.Text = vip .. player.DisplayName
	nameLabel.Parent = bb
	bb.Parent = head

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	-- Rebirth trail ("Chrome Aura" etc.)
	local oldTrail = root:FindFirstChild("RebirthTrail")
	if oldTrail then
		oldTrail:Destroy()
	end
	if data.rebirths > 0 then
		local a0 = root:FindFirstChild("TrailA0") :: Attachment? or Instance.new("Attachment")
		a0.Name = "TrailA0"
		a0.Position = Vector3.new(0, 1, 0)
		a0.Parent = root
		local a1 = root:FindFirstChild("TrailA1") :: Attachment? or Instance.new("Attachment")
		a1.Name = "TrailA1"
		a1.Position = Vector3.new(0, -1.5, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "RebirthTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.5
		trail.LightEmission = 0.8
		trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = root
	end
end

-- Travel -----------------------------------------------------------------------------------
function WorldService.Travel(player: Player, worldIndex: number): (boolean, string?)
	local p = DataService.Get(player)
	if not p or type(worldIndex) ~= "number" then
		return false
	end
	local world = Worlds.Get(worldIndex)
	if not world then
		return false, "Unknown world"
	end
	if not Worlds.IsUnlocked(worldIndex, p.data.rebirths, p.data.allMaps) then
		return false, "Reach Rebirth " .. world.unlockRebirth .. " to unlock " .. world.name
	end
	if lastTravel[player] and os.clock() - lastTravel[player] < 2 then
		return false, "Hyperdrive cooling down..."
	end
	lastTravel[player] = os.clock()

	if p.data.world ~= worldIndex then
		p.data.stats.travels += 1
	end
	p.data.world = worldIndex
	player:SetAttribute("World", worldIndex)
	DataService.MarkDirty(player, true)
	-- Client plays the hyperspace streaks first, then we move the character.
	task.delay(0.9, function()
		moveCharacter(player, spawnCFrame(player, worldIndex))
		Remotes.Event("Travelled"):FireClient(player, worldIndex)
	end)
	return true
end

-- Setup ------------------------------------------------------------------------------------
local function hookInteractables()
	for _, wf in worldsFolder:GetChildren() do
		local piles = wf:FindFirstChild("ScrapPiles")
		if piles then
			for _, pile in piles:GetChildren() do
				local hit = (pile :: Model).PrimaryPart :: BasePart
				local cd = hit:FindFirstChildOfClass("ClickDetector") :: ClickDetector
				cd.MouseClick:Connect(function(player)
					local v = EconomyService.Click(player)
					if v > 0 then
						Remotes.Event("ClickFx"):FireClient(player, hit.Position + Vector3.new(0, 4, 0), v)
					end
				end)
			end
		end
		for _, d in wf:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				local terminal = (d.Parent :: Instance):GetAttribute("Terminal")
				d.Triggered:Connect(function(player)
					Remotes.Event("OpenUI"):FireClient(player, terminal)
				end)
			end
		end
	end
end

local function onCharacterAdded(player: Player, char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait() -- let the default spawn finish before moving
	local p = DataService.Get(player)
	local worldIndex = if p then p.data.world else 1
	moveCharacter(player, spawnCFrame(player, worldIndex))
	decorateCharacter(player)
end

function WorldService.Init()
	worldsFolder = WorldBuilder.Build()
	hookInteractables()

	DataService.OnLoaded(function(profile)
		local player = profile.player
		local data = profile.data
		-- If they lost access to a world (shouldn't happen) fall back to the Scrapyard.
		if not Worlds.IsUnlocked(data.world, data.rebirths, data.allMaps) then
			data.world = 1
		end
		player:SetAttribute("World", data.world)
		assignPlot(player)
		refreshPlot(player)
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player)
		lastTravel[player] = nil
	end)

	Bus.On("UpgradesChanged", refreshPlot)
	Bus.On("DroidsChanged", refreshPlot)
	Bus.On("Rebirthed", decorateCharacter)
	Bus.On("PassesChanged", decorateCharacter)
end

return WorldService
