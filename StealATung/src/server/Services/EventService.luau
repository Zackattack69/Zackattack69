--!strict
-- Server events (one random event every 15 minutes, lasting 3), the weekly
-- Admin Abuse window, server-wide luck (Luck Potion product), Tung Rain, and
-- the 20-minute day/night cycle.
--
-- State lives in Workspace attributes so clients can read it without remotes:
--   Event, EventEnds, NextEvent, AdminAbuse, AdminAbuseEnds, ServerLuck,
--   LuckPotionEnds, Night

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Layout = require(Shared.Config.Layout)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local TungModel = require(Shared.TungModel)
local Remotes = require(Shared.Remotes)

local BaseService = require(script.Parent.BaseService)
local EconomyService = require(script.Parent.EconomyService)
local StealService = require(script.Parent.StealService)

local EventService = {}

local DAY_LENGTH = 20 * 60 -- seconds per full day/night
local rng = Random.new()
local lastEvent = ""
local adminLuck = 1
local adminLuckEnds = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Server luck --------------------------------------------------------------------------------------
local function refreshLuck()
	local t = now()
	local luck = 1
	if ((Workspace:GetAttribute("LuckPotionEnds") :: number?) or 0) > t then
		luck *= 3
	end
	if Workspace:GetAttribute("AdminAbuse") then
		luck *= Events.ADMIN_ABUSE.luck
	end
	if adminLuckEnds > t then
		luck *= adminLuck
	end
	if Workspace:GetAttribute("ServerLuck") ~= luck then
		Workspace:SetAttribute("ServerLuck", luck)
	end
end

function EventService.LuckPotion(buyer: Player)
	local t = now()
	local ends = math.max((Workspace:GetAttribute("LuckPotionEnds") :: number?) or 0, t) + 600
	Workspace:SetAttribute("LuckPotionEnds", ends)
	refreshLuck()
	EconomyService.Alert(nil, "🧪 " .. buyer.DisplayName .. " bought a SERVER LUCK POTION! 3x luck for everyone!", Color3.fromRGB(90, 230, 120), "Jackpot", "luck")
	Remotes.Event("Global"):FireAllClients({ text = "🙏 Everyone thanks " .. buyer.DisplayName .. " for the Luck Potion! 🍀", color = "5AE678", localOnly = true })
end

function EventService.AdminLuck(mult: number, minutes: number)
	adminLuck = math.max(1, mult)
	adminLuckEnds = now() + minutes * 60
	refreshLuck()
end

-- Tung Rain -------------------------------------------------------------------------------------------
type Drop = { model: Model, tung: string, mut: string, from: Vector3, to: Vector3, t0: number, landed: boolean }
local drops: { Drop } = {}

local function spawnRainTung()
	if #drops >= 10 then
		return
	end
	local rarity = if rng:NextNumber() < 0.7 then "Common" else "Uncommon"
	local t = Tungs.PickFromRarity(rng, rarity)
	local mut = Mutations.Roll(rng, false)
	local to = Layout.RandomCorridorPoint(rng)
	local from = to + Vector3.new(0, 70, 0)
	local m = TungModel.Build(t.id, mut, { plate = "pad" })
	m:ScaleTo(m:GetScale() * 0.7)
	m.Name = "RainTung"
	m:PivotTo(CFrame.new(from) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
	-- a little parachute-ish sparkle while falling
	local root = m.PrimaryPart
	if root then
		local e = Instance.new("ParticleEmitter")
		e.Rate = 20
		e.Lifetime = NumberRange.new(0.6)
		e.Speed = NumberRange.new(1)
		e.Size = NumberSequence.new(0.6, 0)
		e.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255))
		e.LightEmission = 1
		e.Parent = root
	end
	m.Parent = Workspace
	table.insert(drops, { model = m, tung = t.id, mut = mut, from = from, to = to, t0 = os.clock(), landed = false })
end

local function rainStep()
	local t = os.clock()
	for k = #drops, 1, -1 do
		local d = drops[k]
		local a = math.clamp((t - d.t0) / 3, 0, 1)
		if not d.landed then
			local cf = d.model:GetPivot()
			d.model:PivotTo(CFrame.new(d.from:Lerp(d.to, a * a)) * cf.Rotation)
			if a >= 1 then
				d.landed = true
			end
		end
		if t - d.t0 > 30 then
			d.model:Destroy()
			table.remove(drops, k)
		end
	end
end

local function rainClaims()
	for k = #drops, 1, -1 do
		local d = drops[k]
		local pos = d.model:GetPivot().Position
		if pos.Y > 12 then
			continue
		end
		for _, player in Players:GetPlayers() do
			local c = player.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and (hrp.Position - pos).Magnitude < 5.5 and BaseService.IndexOf(player) then
				d.model:Destroy()
				table.remove(drops, k)
				BaseService.AddTung(player, d.tung, d.mut, { source = "Tung Rain" })
				local tung = Tungs.Get(d.tung)
				EconomyService.Notify(player, "🌧️ You caught a free " .. Mutations.Prefix(d.mut) .. (if tung then tung.name else "Tung") .. "!", "success")
				break
			end
		end
	end
end

-- Events --------------------------------------------------------------------------------------------------
function EventService.Start(key: string, duration: number?)
	local e = Events.ByKey[key]
	if not e then
		return false
	end
	if key == "AdminAbuse" then
		local d = duration or Events.ADMIN_ABUSE.minutes * 60
		Workspace:SetAttribute("AdminAbuse", true)
		Workspace:SetAttribute("AdminAbuseEnds", now() + d)
		refreshLuck()
		EconomyService.Alert(nil, e.icon .. " ADMIN ABUSE IS LIVE! " .. e.desc, e.color, "Jackpot", "event")
		return true
	end
	EventService.Stop()
	local d = duration or Events.DURATION
	Workspace:SetAttribute("Event", key)
	Workspace:SetAttribute("EventEnds", now() + d)
	lastEvent = key
	if key == "ThiefNight" then
		BaseService.UnlockAll()
	end
	StealService.SetHoldDurations()
	EconomyService.Alert(nil, e.icon .. " " .. string.upper(e.name) .. "! " .. e.desc, e.color, "Jackpot", "event")
	return true
end

function EventService.Stop()
	local cur = Workspace:GetAttribute("Event")
	if not cur then
		return
	end
	Workspace:SetAttribute("Event", nil)
	Workspace:SetAttribute("EventEnds", nil)
	StealService.SetHoldDurations()
	for _, d in drops do
		d.model:Destroy()
	end
	table.clear(drops)
	local e = Events.ByKey[cur :: string]
	if e then
		EconomyService.Alert(nil, e.icon .. " " .. e.name .. " is over!", e.color, nil, "event")
	end
end

function EventService.StopAdminAbuse()
	if Workspace:GetAttribute("AdminAbuse") then
		Workspace:SetAttribute("AdminAbuse", nil)
		Workspace:SetAttribute("AdminAbuseEnds", nil)
		refreshLuck()
		EconomyService.Alert(nil, "👑 Admin Abuse is over. GGs!", Color3.fromRGB(255, 60, 160), nil, "event")
	end
end

local function pickRandomEvent(): string
	local pool = {}
	for _, e in Events.List do
		if e.random and e.key ~= lastEvent then
			table.insert(pool, e.key)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- Day / night ------------------------------------------------------------------------------------------------
local function dayNightStep(dt: number)
	Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / DAY_LENGTH) % 24
	local h = Lighting.ClockTime
	local night = h < 6 or h > 18.5
	if Workspace:GetAttribute("Night") ~= night then
		Workspace:SetAttribute("Night", night)
		for _, lamp in CollectionService:GetTagged("Lantern") do
			local l = lamp:FindFirstChildOfClass("PointLight")
			if l then
				l.Enabled = night
			end
		end
	end
end

function EventService.Init()
	Lighting.ClockTime = 9
	Workspace:SetAttribute("ServerLuck", 1)
	Workspace:SetAttribute("NextEvent", now() + Events.FIRST_DELAY)

	RunService.Heartbeat:Connect(function(dt)
		if #drops > 0 then
			rainStep()
		end
	end)

	task.spawn(function()
		local rainTimer = 0
		local abuseCheck = 0
		while true do
			local dt = task.wait(0.5)
			dayNightStep(dt)
			local t = now()
			local cur = Workspace:GetAttribute("Event") :: string?
			if cur and t >= ((Workspace:GetAttribute("EventEnds") :: number?) or 0) then
				EventService.Stop()
				cur = nil
			end
			if not cur and t >= ((Workspace:GetAttribute("NextEvent") :: number?) or 0) then
				Workspace:SetAttribute("NextEvent", t + Events.INTERVAL)
				EventService.Start(pickRandomEvent())
			end
			if cur == "TungRain" then
				rainTimer += dt
				if rainTimer >= 1.8 then
					rainTimer = 0
					spawnRainTung()
				end
			end
			if #drops > 0 then
				pcall(rainClaims :: any)
			end
			-- weekly Admin Abuse window
			abuseCheck += dt
			if abuseCheck >= 15 then
				abuseCheck = 0
				local _, live = Events.AdminAbuseStatus(os.time())
				if live and not Workspace:GetAttribute("AdminAbuse") then
					EventService.Start("AdminAbuse")
				end
			end
			if Workspace:GetAttribute("AdminAbuse") and t >= ((Workspace:GetAttribute("AdminAbuseEnds") :: number?) or 0) then
				EventService.StopAdminAbuse()
			end
			refreshLuck()
		end
	end)
end

return EventService
