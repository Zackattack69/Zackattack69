--!strict
-- Characters: spawn inside your own base, walk speed (rebirth perk, speed coil,
-- carrying, honey), the bat tool, the overhead name tag (VIP gold name,
-- "Tung Master" title), avatar aura cosmetics, the Rebirth 5 trail, and the
-- player-list leaderstats.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)
local Layout = require(Shared.Config.Layout)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Util.Format)
local Style = require(Shared.Style)

local Bus = require(script.Parent.Parent.Bus)
local DataService = require(script.Parent.DataService)

local PlayerService = {}

-- Set by StealService: called when a player swings their bat.
PlayerService.OnSwing = nil :: ((Player) -> ())?

local slowUntil: { [Player]: { t: number, factor: number } } = {}

local function dataOf(player: Player): any?
	local p = DataService.Get(player)
	return p and p.data
end

-- Walk speed -------------------------------------------------------------------------------------
function PlayerService.RefreshSpeed(player: Player)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local data = dataOf(player)
	if not hum or not data then
		return
	end
	local speed = Economy.WalkSpeed(data)
	if player:GetAttribute("Carrying") then
		speed *= Economy.CARRY_SPEED
	end
	local slow = slowUntil[player]
	if slow and os.clock() < slow.t then
		speed *= slow.factor
	end
	hum.WalkSpeed = speed
end

function PlayerService.Slow(player: Player, seconds: number, factor: number)
	local cur = slowUntil[player]
	if cur and os.clock() < cur.t then
		cur.t = math.max(cur.t, os.clock() + seconds)
		return
	end
	slowUntil[player] = { t = os.clock() + seconds, factor = factor }
	PlayerService.RefreshSpeed(player)
	task.delay(seconds + 0.05, function()
		PlayerService.RefreshSpeed(player)
	end)
end

-- Bat tool -------------------------------------------------------------------------------------------
local function makeBat(tier: number): Tool
	local bat = Items.Bat(tier)
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.ToolTip = bat.name .. " — bonk thieves!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, 0, -0.7)
	tool:SetAttribute("Tier", tier)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 0.45, 2)
	handle.Color = bat.color:Lerp(Color3.new(0, 0, 0), 0.25)
	Style.Apply(handle, bat.material)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(2.6, 0.85, 0.85)
	barrel.CFrame = handle.CFrame * CFrame.new(0, 0, 2.1) * CFrame.Angles(0, math.rad(90), 0)
	barrel.Color = bat.color
	Style.Apply(barrel, bat.material)
	barrel.CanCollide = false
	barrel.Massless = true
	barrel.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = barrel
	w.Parent = barrel

	local knob = Instance.new("Part")
	knob.Name = "Knob"
	knob.Shape = Enum.PartType.Ball
	knob.Size = Vector3.new(0.6, 0.6, 0.6)
	knob.CFrame = handle.CFrame * CFrame.new(0, 0, -1)
	knob.Color = handle.Color
	Style.Apply(knob, bat.material)
	knob.CanCollide = false
	knob.Massless = true
	knob.Parent = tool
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = handle
	w2.Part1 = knob
	w2.Parent = knob

	local swing = Instance.new("Sound")
	swing.Name = "SwingSound"
	swing.SoundId = "rbxasset://sounds/swordslash.wav"
	swing.PlaybackSpeed = 0.8
	swing.Volume = 0.3
	swing.Parent = handle
	return tool
end

local function giveBat(player: Player)
	local data = dataOf(player)
	local tier = if data then data.items.Bat or 1 else 1
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	-- remove an outdated bat
	local containers: { Instance } = {}
	if backpack then
		table.insert(containers, backpack)
	end
	if character then
		table.insert(containers, character)
	end
	for _, container in containers do
		local old = container:FindFirstChild("Bat")
		if old and old:IsA("Tool") then
			if old:GetAttribute("Tier") == tier then
				return
			end
			old:Destroy()
		end
	end
	if not backpack then
		return
	end
	local tool = makeBat(tier)
	tool.Activated:Connect(function()
		local handle = tool:FindFirstChild("Handle")
		local snd = handle and handle:FindFirstChild("SwingSound") :: Sound?
		if snd then
			snd:Play()
		end
		if PlayerService.OnSwing then
			PlayerService.OnSwing(player)
		end
	end)
	tool.Parent = backpack
end

-- Equips the bat (used by the mobile swing button). Returns the tool.
function PlayerService.EquipBat(player: Player): Tool?
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not hum then
		return nil
	end
	local equipped = c:FindFirstChild("Bat")
	if equipped and equipped:IsA("Tool") then
		return equipped
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = backpack and backpack:FindFirstChild("Bat")
	if tool and tool:IsA("Tool") then
		hum:EquipTool(tool)
		return tool
	end
	return nil
end

-- Overhead tag, aura cosmetic, rebirth trail ------------------------------------------------------------
local function refreshAppearance(player: Player)
	local c = player.Character
	local data = dataOf(player)
	if not c or not data then
		return
	end
	local head = c:FindFirstChild("Head") :: BasePart?
	local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vip = Economy.HasPass(data, "VIP")
	player:SetAttribute("VIP", vip)
	player:SetAttribute("Title", if data.indexRewards.Master then "Tung Master" else nil)

	if head then
		local tag = head:FindFirstChild("OverheadTag") :: BillboardGui?
		if not tag then
			local bb = Instance.new("BillboardGui")
			bb.Name = "OverheadTag"
			bb.Size = UDim2.fromOffset(220, 56)
			bb.StudsOffset = Vector3.new(0, 2.6, 0)
			bb.MaxDistance = 80
			bb.LightInfluence = 0
			bb.ResetOnSpawn = false
			local list = Instance.new("UIListLayout")
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.VerticalAlignment = Enum.VerticalAlignment.Bottom
			list.HorizontalAlignment = Enum.HorizontalAlignment.Center
			list.Parent = bb
			for k, name in { "Title", "PlayerName" } do
				local l = Instance.new("TextLabel")
				l.Name = name
				l.Size = UDim2.new(1, 0, 0, if k == 1 then 22 else 28)
				l.BackgroundTransparency = 1
				l.TextScaled = true
				l.Font = Enum.Font.FredokaOne
				l.LayoutOrder = k
				local s = Instance.new("UIStroke")
				s.Thickness = 2.5
				s.Color = Color3.fromRGB(30, 20, 10)
				s.Parent = l
				l.Parent = bb
			end
			bb.Parent = head
			tag = bb
		end
		local t = tag :: BillboardGui
		local title = t:FindFirstChild("Title") :: TextLabel
		local name = t:FindFirstChild("PlayerName") :: TextLabel
		title.Visible = data.indexRewards.Master == true
		title.Text = "🏆 TUNG MASTER 🏆"
		title.TextColor3 = Color3.fromRGB(255, 205, 60)
		name.Text = (if vip then "👑 " else "") .. player.DisplayName
		name.TextColor3 = if vip then Color3.fromRGB(255, 205, 60) else Color3.new(1, 1, 1)
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end

	if hrp then
		local old = hrp:FindFirstChild("AvatarAura")
		if old then
			old:Destroy()
		end
		local m = Mutations.Get(data.aura)
		if m then
			local e = Instance.new("ParticleEmitter")
			e.Name = "AvatarAura"
			e.Rate = 14
			e.Lifetime = NumberRange.new(0.8, 1.4)
			e.Speed = NumberRange.new(1, 2.5)
			e.Size = NumberSequence.new(0.5, 0)
			e.LightEmission = 0.8
			e.SpreadAngle = Vector2.new(180, 180)
			e.Color = if m.key == "Rainbow" then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 120, 255)),
			}) else ColorSequence.new(m.color)
			e.Parent = hrp
		end
		-- Rebirth 5 perk: cosmetic trail
		local oldTrail = hrp:FindFirstChild("RebirthTrail")
		if data.rebirths >= 5 and not oldTrail then
			local a0 = Instance.new("Attachment")
			a0.Name = "TrailTop"
			a0.Position = Vector3.new(0, 0.8, 0)
			a0.Parent = hrp
			local a1 = Instance.new("Attachment")
			a1.Name = "TrailBottom"
			a1.Position = Vector3.new(0, -0.8, 0)
			a1.Parent = hrp
			local trail = Instance.new("Trail")
			trail.Name = "RebirthTrail"
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.5
			trail.LightEmission = 0.7
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 90, 200))
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = hrp
		end
	end
	PlayerService.RefreshSpeed(player)
end

-- Spawning ------------------------------------------------------------------------------------------------
local function sendHome(player: Player)
	local i = player:GetAttribute("Base") :: number?
	local c = player.Character
	if not i or not c then
		return
	end
	local hrp = c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		task.wait()
		c:PivotTo(Layout.Spawn(i))
	end
end

local function onCharacter(player: Player, character: Model)
	task.spawn(sendHome, player)
	local hum = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.BreakJointsOnDeath = false
	end
	task.wait(0.2)
	giveBat(player)
	refreshAppearance(player)
end

-- Leaderstats -------------------------------------------------------------------------------------------------
local function makeLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local money = Instance.new("StringValue")
	money.Name = "Money"
	money.Value = "$0"
	money.Parent = ls
	local steals = Instance.new("IntValue")
	steals.Name = "Steals"
	steals.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = ls
	ls.Parent = player
end

local function updateLeaderstats()
	for player, p in DataService.All() do
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			local money = ls:FindFirstChild("Money") :: StringValue?
			local steals = ls:FindFirstChild("Steals") :: IntValue?
			local rebirths = ls:FindFirstChild("Rebirths") :: IntValue?
			if money then
				money.Value = Format.Money(p.data.money)
			end
			if steals then
				steals.Value = p.data.stats.steals
			end
			if rebirths then
				rebirths.Value = p.data.rebirths
			end
		end
	end
end

function PlayerService.Init()
	Players.RespawnTime = 3
	local function onPlayer(player: Player)
		makeLeaderstats(player)
		player.CharacterAdded:Connect(function(c)
			onCharacter(player, c)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, pl in Players:GetPlayers() do
		task.spawn(onPlayer, pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		slowUntil[player] = nil
	end)

	Bus.On("BaseAssigned", function(player: Player)
		task.spawn(sendHome, player)
		giveBat(player)
		refreshAppearance(player)
	end)
	Bus.On("AppearanceChanged", function(player: Player)
		giveBat(player)
		refreshAppearance(player)
	end)
	Bus.On("Rebirthed", function(player: Player)
		refreshAppearance(player)
	end)
	Bus.On("PassesChanged", function(player: Player)
		refreshAppearance(player)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			pcall(updateLeaderstats :: any)
		end
	end)
end

return PlayerService
