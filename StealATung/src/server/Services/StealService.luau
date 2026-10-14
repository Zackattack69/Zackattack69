--!strict
-- Stealing and defending.
--   * Hold "Steal" (1.5 s, 0.75 s on Thief Night) on someone's Tung: it goes over
--     your head, you walk 30% slower and get a red outline everyone can see.
--   * Reach your own base with it and it's yours.
--   * Get bonked by a bat or slip on a trap and you drop it; it walks back home.
--   * Defences: base lock (BaseService), bat swings, banana peels, honey pads,
--     the Tung alarm, and the 10-minute new-player shield.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)
local Layout = require(Shared.Config.Layout)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local Remotes = require(Shared.Remotes)

local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlayerService = require(script.Parent.PlayerService)

local StealService = {}

type Carry = {
	thief: Player,
	victim: Player,
	base: number,
	slot: number,
	uid: string,
	tung: string,
	mut: string,
}

local carries: { [Player]: Carry } = {}
local holdStart: { [Player]: { prompt: ProximityPrompt, t: number } } = {}
local stealCooldown: { [Player]: number } = {}
local swingCooldown: { [Player]: number } = {}
local bananaReady: { [number]: number } = {}

local RED = Color3.fromRGB(255, 50, 60)

local function hrpOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function StealService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

local function setThiefState(player: Player, carry: Carry?)
	player:SetAttribute("Carrying", if carry then carry.tung .. "|" .. carry.mut else nil)
	local c = player.Character
	if c then
		local h = c:FindFirstChild("ThiefOutline")
		if carry and not h then
			local hl = Instance.new("Highlight")
			hl.Name = "ThiefOutline"
			hl.FillTransparency = 1
			hl.OutlineColor = RED
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = c
		elseif not carry and h then
			h:Destroy()
		end
	end
	PlayerService.RefreshSpeed(player)
	DataService.MarkDirty(player)
end

-- Ends a carry without returning the Tung (owner left / rebirthed).
local function vanish(carry: Carry)
	carries[carry.thief] = nil
	stealCooldown[carry.thief] = os.clock() + Economy.STEAL_COOLDOWN
	setThiefState(carry.thief, nil)
end

-- The thief dropped it: it walks back to its pad.
function StealService.Drop(thief: Player, reason: string)
	local carry = carries[thief]
	if not carry then
		return
	end
	carries[thief] = nil
	stealCooldown[thief] = os.clock() + Economy.STEAL_COOLDOWN
	setThiefState(thief, nil)
	local hrp = hrpOf(thief)
	local st = BaseService.Get(carry.base)
	local from = if hrp then hrp.Position - Vector3.new(0, 3, 0) else Layout.BaseCFrame(carry.base).Position
	local to = Layout.PadCFrame(carry.base, carry.slot, if st then st.slots else 8).Position
	Remotes.Event("WalkHome"):FireAllClients({ from = from, to = to, tung = carry.tung, mut = carry.mut, dur = Economy.WALK_HOME_TIME })
	task.delay(Economy.WALK_HOME_TIME, function()
		BaseService.RestoreStolen(carry.base, carry.slot, carry.uid)
	end)
	local t = Tungs.Get(carry.tung)
	local name = Mutations.Prefix(carry.mut) .. (if t then t.name else "Tung")
	if reason ~= "left" and thief.Parent then
		EconomyService.Notify(thief, "💥 You dropped the " .. name .. "! It's walking back home.", "error")
	end
	if carry.victim.Parent then
		EconomyService.Notify(carry.victim, "🏠 Your " .. name .. " is walking back home!", "success")
	end
end

local function succeed(carry: Carry)
	carries[carry.thief] = nil
	stealCooldown[carry.thief] = os.clock() + Economy.STEAL_COOLDOWN
	local thief, victim = carry.thief, carry.victim
	local entry = BaseService.Entry(victim, carry.slot)
	if not entry or entry.u ~= carry.uid then
		setThiefState(thief, nil)
		return
	end
	BaseService.RemoveTung(victim, carry.slot)
	BaseService.AddTung(thief, entry.id, entry.m, { source = "steal" })
	setThiefState(thief, nil)

	local tp = DataService.Get(thief)
	local vp = DataService.Get(victim)
	if tp then
		tp.data.stats.steals += 1
	end
	if vp then
		vp.data.stats.stolen += 1
	end
	EconomyService.Stat(thief, "steal", 1)
	local t = Tungs.Get(entry.id)
	local name = Mutations.Prefix(entry.m) .. (if t then t.name else "Tung")
	local color = if t then Tungs.Color(t) else RED
	EconomyService.Alert(nil, "🦹 " .. thief.DisplayName .. " stole " .. victim.DisplayName .. "'s " .. name .. "!", color, "Steal", "steal")
	EconomyService.Notify(victim, "😭 " .. thief.DisplayName .. " stole your " .. name .. "!", "error")
end

-- Steal prompt ---------------------------------------------------------------------------------------
local function tryBeginSteal(thief: Player, prompt: ProximityPrompt)
	local i = prompt:GetAttribute("Base") :: number?
	local slot = prompt:GetAttribute("Slot") :: number?
	if not i or not slot then
		return
	end
	local st = BaseService.Get(i)
	local victim = st and st.owner
	if not st or not victim then
		return
	end
	local function deny(msg: string)
		EconomyService.Notify(thief, msg, "error")
	end
	if victim == thief then
		return
	end
	if not DataService.Get(thief) or not BaseService.IndexOf(thief) then
		return deny("Still loading")
	end
	if carries[thief] then
		return deny("You're already carrying a Tung!")
	end
	if os.clock() < (stealCooldown[thief] or 0) then
		return deny("Catch your breath first (" .. math.ceil((stealCooldown[thief] or 0) - os.clock()) .. "s)")
	end
	if BaseService.IsLocked(i) then
		return deny("🔒 This base is locked!")
	end
	local vp = DataService.Get(victim)
	if vp and vp.data.playtime < Economy.SHIELD_SECONDS then
		return deny("🛡️ " .. victim.DisplayName .. " is new here and protected for a few minutes")
	end
	if BaseService.FreeSlotCount(thief) <= 0 then
		return deny("Your base is full! Sell a Tung first.")
	end
	-- hold-time check (only when the server saw the hold begin)
	local hs = holdStart[thief]
	if hs and hs.prompt == prompt and os.clock() - hs.t < prompt.HoldDuration * 0.7 then
		return
	end
	local hrp = hrpOf(thief)
	local tungModel = prompt.Parent and prompt.Parent.Parent
	if not hrp or not tungModel or not tungModel:IsA("Model") or (hrp.Position - tungModel:GetPivot().Position).Magnitude > 14 then
		return deny("Get closer!")
	end
	local hum = humanoidOf(thief)
	if not hum or hum.Health <= 0 then
		return
	end
	local entry = BaseService.BeginSteal(i, slot, thief)
	if not entry then
		return deny("Someone else got to it first")
	end
	local carry: Carry = { thief = thief, victim = victim, base = i, slot = slot, uid = entry.u, tung = entry.id, mut = entry.m or Mutations.NONE }
	carries[thief] = carry
	setThiefState(thief, carry)
	local t = Tungs.Get(entry.id)
	local name = Mutations.Prefix(entry.m) .. (if t then t.name else "Tung")
	EconomyService.Alert(victim, "🚨 Someone is stealing your " .. name .. "!", RED, "Siren", "steal")
	EconomyService.Notify(thief, "🦹 Run! Get the " .. name .. " back to your base!", "steal")
end

-- Bat -------------------------------------------------------------------------------------------------------
local function knockback(target: Player, dir: Vector3, speed: number)
	local hrp = hrpOf(target)
	if not hrp then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "KnockAttachment"
	att.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = Vector3.new(dir.X, 0, dir.Z).Unit * speed + Vector3.new(0, speed * 0.45, 0)
	lv.MaxForce = 1e6
	lv.Parent = hrp
	task.delay(0.18, function()
		lv:Destroy()
		att:Destroy()
	end)
end

function StealService.Swing(player: Player): (boolean, any)
	local p = DataService.Get(player)
	local hrp = hrpOf(player)
	local hum = humanoidOf(player)
	if not p or not hrp or not hum or hum.Health <= 0 then
		return false, nil
	end
	local bat = Items.Bat(p.data.items.Bat or 1)
	if os.clock() < (swingCooldown[player] or 0) then
		return false, nil
	end
	swingCooldown[player] = os.clock() + bat.cooldown
	local tool = PlayerService.EquipBat(player)
	if tool then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		task.delay(0.5, function()
			anim:Destroy()
		end)
	end
	local look = hrp.CFrame.LookVector
	local hitAny = false
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local ohrp = hrpOf(other)
		local ohum = humanoidOf(other)
		if not ohrp or not ohum or ohum.Health <= 0 then
			continue
		end
		local offset = ohrp.Position - hrp.Position
		local dist = offset.Magnitude
		if dist > bat.reach or math.abs(offset.Y) > 6 then
			continue
		end
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if dist > 3.5 and flat.Magnitude > 0 and flat.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) < 0.2 then
			continue
		end
		hitAny = true
		local wasCarrying = carries[other] ~= nil
		knockback(other, if flat.Magnitude > 0.1 then flat else look, bat.knock * (if wasCarrying then 1.2 else 0.8))
		Remotes.Event("BonkFx"):FireAllClients({ pos = ohrp.Position + Vector3.new(0, 2, 0), thief = wasCarrying })
		if wasCarrying then
			StealService.Drop(other, "bonk")
			p.data.stats.bonks += 1
			EconomyService.Stat(player, "bonk", 1)
			EconomyService.Notify(player, "🏏 BONK! You stopped a thief!", "success")
		end
	end
	return true, hitAny
end

-- Traps ----------------------------------------------------------------------------------------------------------
local function slip(player: Player)
	local hum = humanoidOf(player)
	local hrp = hrpOf(player)
	if not hum or not hrp then
		return
	end
	hum.PlatformStand = true
	knockback(player, hrp.CFrame.LookVector, 30)
	task.delay(1.6, function()
		if hum.Parent then
			hum.PlatformStand = false
		end
	end)
end

local function trapTick()
	for i, st in BaseService.All() do
		local owner = st.owner
		local model = st.model
		local traps = model and model:FindFirstChild("Traps")
		if not owner or not traps then
			continue
		end
		local banana = traps:FindFirstChild("Banana")
		local honey = traps:FindFirstChild("Honey")
		if not banana and not honey then
			continue
		end
		local armed = os.clock() >= (bananaReady[i] or 0)
		if banana then
			for _, d in banana:GetChildren() do
				if d:IsA("BasePart") and d.Name ~= "Hit" then
					d.Transparency = if armed then 0 else 1
				end
			end
		end
		for _, player in Players:GetPlayers() do
			if player == owner then
				continue
			end
			local hrp = hrpOf(player)
			if not hrp then
				continue
			end
			local bananaHit = banana and banana:FindFirstChild("Hit") :: BasePart?
			if bananaHit and armed then
				local off = hrp.Position - bananaHit.Position
				if Vector3.new(off.X, 0, off.Z).Magnitude < 2.2 and math.abs(off.Y) < 4.5 then
					bananaReady[i] = os.clock() + 15
					armed = false
					slip(player)
					Remotes.Event("BonkFx"):FireAllClients({ pos = hrp.Position, slip = true })
					if carries[player] then
						StealService.Drop(player, "trap")
					end
					EconomyService.Notify(owner, "🍌 " .. player.DisplayName .. " slipped on your banana peel!", "success")
				end
			end
			local honeyHit = honey and honey:FindFirstChild("Hit") :: BasePart?
			if honeyHit then
				local off = hrp.Position - honeyHit.Position
				if Vector3.new(off.X, 0, off.Z).Magnitude < 2.8 and math.abs(off.Y) < 4.5 then
					PlayerService.Slow(player, 3, 0.4)
				end
			end
		end
	end
end

-- Carry loop: success when the thief reaches home, drop if they die. -----------------------------------------------
local function carryTick()
	for thief, carry in carries do
		local hum = humanoidOf(thief)
		if not thief.Parent then
			StealService.Drop(thief, "left")
		elseif not hum or hum.Health <= 0 then
			StealService.Drop(thief, "died")
		elseif carry.victim.Parent == nil then
			vanish(carry)
		else
			local own = BaseService.IndexOf(thief)
			if own and thief:GetAttribute("InBase") == own then
				succeed(carry)
			end
		end
	end
end

function StealService.SetHoldDurations()
	local hold = BaseService.StealHold()
	for _, pr in CollectionService:GetTagged("StealPrompt") do
		if pr:IsA("ProximityPrompt") then
			pr.HoldDuration = hold
		end
	end
end

function StealService.Init()
	BaseService.Hooks.CancelStealsFrom = function(victim: Player)
		for _, carry in carries do
			if carry.victim == victim then
				vanish(carry)
				if carry.thief.Parent then
					EconomyService.Notify(carry.thief, "💨 The Tung vanished. Its owner is gone!", "error")
				end
			end
		end
	end
	BaseService.Hooks.DropCarried = function(player: Player, reason: string)
		if carries[player] then
			StealService.Drop(player, reason)
		end
	end

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
		holdStart[player] = { prompt = prompt, t = os.clock() }
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Action") == "Steal" then
			tryBeginSteal(player, prompt)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		holdStart[player] = nil
		stealCooldown[player] = nil
		swingCooldown[player] = nil
	end)

	PlayerService.OnSwing = function(player: Player)
		StealService.Swing(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.15)
			pcall(carryTick :: any)
			pcall(trapTick :: any)
		end
	end)
end

return StealService
