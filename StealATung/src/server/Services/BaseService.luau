--!strict
-- Bases: assignment, placed Tung models, per-pad income (capped at 1 hour),
-- Collect / Collect All, base lock + laser gate, selling, rebirth, Tungs that
-- follow you home after buying, picking up / moving / selling your own Tungs
-- right in the base, alarms, and the owner name above the roof.
--
-- Every slot change goes through this module. StealService plugs in through
-- BaseService.Hooks so the two don't require each other.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BaseSkins = require(Shared.Config.BaseSkins)
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local TungModel = require(Shared.TungModel)

local Bus = require(script.Parent.Parent.Bus)
local BaseBuilder = require(script.Parent.Parent.BaseBuilder)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local BaseService = {}

export type BaseState = {
	index: number,
	owner: Player?,
	model: Model?,
	slots: number,
	skin: string,
	tungs: { [number]: Model }, -- slot -> placed model
	stolen: { [number]: Player }, -- slot -> thief carrying it
	arriving: { [number]: number }, -- slot -> os.clock() it was bought (following the owner)
	held: number?, -- slot of the Tung the owner picked up (it follows them until placed)
	heldOutside: number?, -- os.clock() the owner left the base while holding one
	locked: boolean,
	lockEnds: number,
	lockReady: number,
	alarmCooldown: { [Player]: number },
}

local bases: { BaseState } = {}
local hookButtons: (BaseState) -> ()
local baseOf: { [Player]: number } = {}
local basesFolder: Folder

-- Filled in by StealService.
BaseService.Hooks = {
	CancelStealsFrom = function(_victim: Player) end,
	DropCarried = function(_player: Player, _reason: string) end,
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

function BaseService.Get(i: number): BaseState?
	return bases[i]
end

function BaseService.All(): { BaseState }
	return bases
end

function BaseService.IndexOf(player: Player): number?
	return baseOf[player]
end

function BaseService.StealHold(): number
	return if Workspace:GetAttribute("Event") == "ThiefNight" then Economy.STEAL_HOLD_THIEF_NIGHT else Economy.STEAL_HOLD
end

-- Slots -----------------------------------------------------------------------------------
local function key(slot: number): string
	return tostring(slot)
end

-- First slot that's neither filled nor reserved.
local function freeSlot(data: any, max: number): number?
	for slot = 1, max do
		if data.slots[key(slot)] == nil then
			return slot
		end
	end
	return nil
end

function BaseService.FreeSlotCount(player: Player): number
	local p = DataService.Get(player)
	if not p then
		return 0
	end
	local max = Economy.Slots(p.data)
	local used = 0
	for _ in p.data.slots do
		used += 1
	end
	return math.max(0, max - used)
end

local function setFollowing(player: Player)
	local i = baseOf[player]
	local st = i and bases[i]
	local p = DataService.Get(player)
	if not st or not p then
		player:SetAttribute("Following", "")
		return
	end
	local list = {}
	for slot in st.arriving do
		local e = p.data.slots[key(slot)]
		if e then
			table.insert(list, e.id .. "|" .. (e.m or Mutations.NONE))
		end
	end
	player:SetAttribute("Following", table.concat(list, ","))
end

-- "id|mutation" of the Tung the player picked up in their own base (it follows them).
local function setHolding(player: Player)
	local i = baseOf[player]
	local st = i and bases[i]
	local slot = st and st.held
	local p = DataService.Get(player)
	local e = slot and p and p.data.slots[key(slot)]
	player:SetAttribute("Holding", if e then e.id .. "|" .. (e.m or Mutations.NONE) else nil)
end

-- Collision groups: base i's locked laser wall ("Laser<i>") blocks everyone
-- except that base's owner, whose character is in "BaseOwner<i>".
local function registerGroups()
	for i = 1, Layout.BASE_COUNT do
		local laser, owner = "Laser" .. i, "BaseOwner" .. i
		for _, g in { laser, owner } do
			if not PhysicsService:IsCollisionGroupRegistered(g) then
				PhysicsService:RegisterCollisionGroup(g)
			end
		end
		PhysicsService:CollisionGroupSetCollidable(laser, owner, false)
	end
end

local function ownerGroup(player: Player): string
	local i = baseOf[player]
	return if i then "BaseOwner" .. i else "Default"
end

local function setCharacterGroup(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local group = ownerGroup(player)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

-- Pad visuals ---------------------------------------------------------------------------------
local function padParts(st: BaseState, slot: number): (BasePart?, BasePart?)
	local model = st.model
	if not model then
		return nil, nil
	end
	local pads = model:FindFirstChild("Pads")
	local buttons = model:FindFirstChild("Buttons")
	local pad = pads and pads:FindFirstChild("Pad" .. slot) :: BasePart?
	local button = buttons and buttons:FindFirstChild("Button" .. slot) :: BasePart?
	return pad, button
end

local function setPadLook(st: BaseState, slot: number, entry: any?)
	local pad, button = padParts(st, slot)
	if not pad or not button then
		return
	end
	local t = entry and Tungs.Get(entry.id)
	local ghost = pad:FindFirstChild("Ghost")
	if ghost then
		for _, d in ghost:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = if t then 1 else 0
			elseif d:IsA("BillboardGui") then
				d.Enabled = t == nil
			end
		end
	end
	local glow = pad:FindFirstChild("Glow") :: BasePart?
	if glow then
		glow.Color = if t then Tungs.Color(t) else BaseSkins.Get(st.skin).accent
		glow.Transparency = if t then 0.15 else 0.45
	end
	button.Color = if t then Tungs.Color(t) else Color3.fromRGB(190, 190, 196)
	button.Material = if t and t.rarity == "Secret" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local counter = button:FindFirstChild("Counter") :: BillboardGui?
	if counter then
		counter.Enabled = t ~= nil
	end
end

-- Pad of a Tung the owner is carrying around: empty pad, "WITH YOU" on the counter.
local function setPadHeld(st: BaseState, slot: number)
	setPadLook(st, slot, nil)
	local _, button = padParts(st, slot)
	local counter = button and button:FindFirstChild("Counter") :: BillboardGui?
	local label = counter and counter:FindFirstChild("Amount") :: TextLabel?
	if counter and label then
		counter.Enabled = true
		label.Text = "🐾 WITH YOU"
	end
end

local function updateCounter(st: BaseState, slot: number, stored: number)
	local _, button = padParts(st, slot)
	local counter = button and button:FindFirstChild("Counter")
	local label = counter and counter:FindFirstChild("Amount") :: TextLabel?
	if label then
		local text = Format.Money(math.floor(stored))
		if label.Text ~= text then
			label.Text = text
		end
	end
end

local function removeModel(st: BaseState, slot: number)
	local m = st.tungs[slot]
	if m then
		m:Destroy()
		st.tungs[slot] = nil
	end
	setPadLook(st, slot, nil)
end

local function placeModel(st: BaseState, slot: number, entry: any, fx: boolean?)
	removeModel(st, slot)
	local owner = st.owner
	if not owner or not st.model then
		return
	end
	local t = Tungs.Get(entry.id)
	if not t then
		return
	end
	local model = TungModel.Build(entry.id, entry.m, { plate = "pad" })
	model.Name = "Tung" .. slot
	model:PivotTo(Layout.PadCFrame(st.index, slot, st.slots))
	model:SetAttribute("OwnerId", owner.UserId)
	model:SetAttribute("Base", st.index)
	model:SetAttribute("Slot", slot)
	if not t.bound then
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "StealPrompt"
		pr.ActionText = "Steal"
		pr.ObjectText = Mutations.Prefix(entry.m) .. t.name
		pr.HoldDuration = BaseService.StealHold()
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr.Style = Enum.ProximityPromptStyle.Custom
		pr:SetAttribute("Action", "Steal")
		pr:SetAttribute("Base", st.index)
		pr:SetAttribute("Slot", slot)
		pr:SetAttribute("OwnerId", owner.UserId)
		pr.Parent = model.PrimaryPart
		CollectionService:AddTag(pr, "StealPrompt")
	end
	-- owner-only prompts: pick it up (it follows you to another pad) or sell it right here
	local function ownPrompt(name: string, action: string, text: string, keyCode: Enum.KeyCode, padCode: Enum.KeyCode, hold: number)
		local pr = Instance.new("ProximityPrompt")
		pr.Name = name
		pr.ActionText = text
		pr.ObjectText = Mutations.Prefix(entry.m) .. t.name
		pr.KeyboardKeyCode = keyCode
		pr.GamepadKeyCode = padCode
		pr.HoldDuration = hold
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr.Style = Enum.ProximityPromptStyle.Custom
		pr:SetAttribute("Action", action)
		pr:SetAttribute("Base", st.index)
		pr:SetAttribute("Slot", slot)
		pr:SetAttribute("OwnerId", owner.UserId)
		pr:SetAttribute("OwnerOnly", true)
		pr.Parent = model.PrimaryPart
		CollectionService:AddTag(pr, "OwnPrompt")
	end
	ownPrompt("PickUpPrompt", "PickUp", "Pick Up", Enum.KeyCode.E, Enum.KeyCode.ButtonX, 0)
	if not t.bound then
		ownPrompt("SellPrompt", "Sell", "Sell", Enum.KeyCode.F, Enum.KeyCode.ButtonY, 0.8)
	end
	model.Parent = st.model
	st.tungs[slot] = model
	setPadLook(st, slot, entry)
	updateCounter(st, slot, entry.s or 0)
	if fx then
		Remotes.Event("PlaceFx"):FireAllClients({ pos = Layout.PadCFrame(st.index, slot, st.slots).Position, tung = entry.id, mut = entry.m, base = st.index, slot = slot })
	end
end

-- Base (re)building --------------------------------------------------------------------------------
-- Owner name above the roof, and lock / new-player shield status above the door.
local function refreshHeadline(st: BaseState)
	local model = st.model
	if not model then
		return
	end
	local owner = st.owner
	local anchor = model:FindFirstChild("Headline")
	local head = anchor and anchor:FindFirstChild("OwnerGui") :: BillboardGui?
	if head then
		head.Enabled = owner ~= nil
		local l = head:FindFirstChild("OwnerName") :: TextLabel?
		local text = if owner then owner.DisplayName .. "'s Base" else ""
		if l and l.Text ~= text then
			l.Text = text
		end
	end
	local doorAnchor = model:FindFirstChild("DoorStatus")
	local door = doorAnchor and doorAnchor:FindFirstChild("DoorGui") :: BillboardGui?
	if door then
		local status = ""
		if owner then
			local p = DataService.Get(owner)
			local shield = if p then Economy.SHIELD_SECONDS - p.data.playtime else 0
			if st.locked then
				status = "🔒 LOCKED " .. Format.Time(st.lockEnds - now())
			elseif shield > 0 then
				status = "🛡️ PROTECTED " .. Format.Time(shield)
			end
		end
		door.Enabled = status ~= ""
		local l = door:FindFirstChild("Status") :: TextLabel?
		if l and l.Text ~= status then
			l.Text = status
		end
	end
end

local function setLasers(st: BaseState)
	local model = st.model
	local lasers = model and model:FindFirstChild("Lasers")
	if not lasers then
		return
	end
	for _, p in lasers:GetChildren() do
		if p:IsA("BasePart") then
			if p.Name == "Wall" then
				p.CanCollide = st.locked
			else
				p.Transparency = if st.locked then 0.15 else 1
				p.CanCollide = false
			end
		end
	end
	if model then
		model:SetAttribute("Locked", st.locked)
		model:SetAttribute("LockEnds", st.lockEnds)
		model:SetAttribute("LockReady", st.lockReady)
	end
	local owner = st.owner
	if owner then
		owner:SetAttribute("LockEnds", st.lockEnds)
		owner:SetAttribute("LockReady", st.lockReady)
		owner:SetAttribute("Locked", st.locked)
	end
end

function BaseService.Rebuild(i: number)
	local st = bases[i]
	if not st then
		return
	end
	if st.model then
		st.model:Destroy()
	end
	st.tungs = {}
	local owner = st.owner
	local p = owner and DataService.Get(owner)
	local data = p and p.data
	-- the look is the owner's chosen skin; rebirths only add floors
	local info = if data
		then {
			index = i,
			slots = Economy.Slots(data),
			skin = BaseSkins.Get(data.baseSkin).key,
			items = data.items,
			personalBelt = data.rebirths >= 6,
		}
		else { index = i, slots = 8, skin = BaseSkins.DEFAULT, items = {}, personalBelt = false }
	st.slots = info.slots
	st.skin = info.skin
	local model = BaseBuilder.Build(basesFolder, info)
	model:SetAttribute("OwnerId", if owner then owner.UserId else 0)
	model:SetAttribute("Slots", info.slots)
	model:SetAttribute("PersonalBelt", info.personalBelt)
	st.model = model
	setLasers(st)
	refreshHeadline(st)
	if data then
		for k, entry in data.slots do
			local slot = tonumber(k) :: number
			if st.held == slot then
				setPadHeld(st, slot)
			elseif not st.stolen[slot] and not st.arriving[slot] then
				placeModel(st, slot, entry)
			end
		end
	end
	hookButtons(st)
end

-- Adding / removing Tungs ------------------------------------------------------------------------------
export type AddOpts = { arriving: boolean?, source: string?, uid: string?, discover: boolean? }

-- Puts a Tung in the player's base (or the pending queue if full). Returns the slot (or nil if queued).
function BaseService.AddTung(player: Player, id: string, mut: string?, opts: AddOpts?): number?
	local p = DataService.Get(player)
	local i = baseOf[player]
	if not p or not i then
		return nil
	end
	local o: AddOpts = opts or {}
	local data = p.data
	local entry = { id = id, m = mut or Mutations.NONE, u = o.uid or DataService.NewUid(data), s = 0 }
	if o.discover ~= false then
		EconomyService.Discover(player, id, entry.m)
	end
	-- lifetime count per rarity (unlocks rarity base styles); trades don't count
	local tung = Tungs.Get(id)
	if tung and o.source ~= "trade" then
		data.collected[tung.rarity] = (data.collected[tung.rarity] or 0) + 1
		local skin = BaseSkins.ByKey[tung.rarity .. "Style"]
		if skin and skin.need and data.collected[tung.rarity] == skin.need then
			EconomyService.Notify(player, "🎨 New base style unlocked: " .. skin.name .. "! Pick it at the Skins stand.", "success")
		end
	end
	local slot = freeSlot(data, Economy.Slots(data))
	if not slot then
		table.insert(data.pending, { id = entry.id, m = entry.m, u = entry.u })
		EconomyService.Notify(player, "🎁 Your base is full, so " .. (Tungs.Get(id) :: any).name .. " is waiting for a free slot", "info")
		DataService.MarkDirty(player, true)
		return nil
	end
	data.slots[key(slot)] = entry
	local st = bases[i]
	if o.arriving then
		st.arriving[slot] = os.clock()
		setFollowing(player)
	else
		placeModel(st, slot, entry, true)
	end
	DataService.MarkDirty(player, true)
	return slot
end

-- Places queued Tungs into any free slots.
function BaseService.FillPending(player: Player)
	local p = DataService.Get(player)
	local i = baseOf[player]
	if not p or not i then
		return
	end
	local data = p.data
	while #data.pending > 0 do
		local slot = freeSlot(data, Economy.Slots(data))
		if not slot then
			break
		end
		local e = table.remove(data.pending, 1)
		local entry = { id = e.id, m = e.m, u = e.u or DataService.NewUid(data), s = 0 }
		data.slots[key(slot)] = entry
		placeModel(bases[i], slot, entry, true)
	end
	DataService.MarkDirty(player, true)
end

function BaseService.Entry(player: Player, slot: number): any?
	local p = DataService.Get(player)
	return p and p.data.slots[key(slot)]
end

-- Removes a Tung from data + world. Returns the entry.
function BaseService.RemoveTung(player: Player, slot: number): any?
	local p = DataService.Get(player)
	local i = baseOf[player]
	if not p or not i then
		return nil
	end
	local entry = p.data.slots[key(slot)]
	if not entry then
		return nil
	end
	p.data.slots[key(slot)] = nil
	local st = bases[i]
	st.stolen[slot] = nil
	st.arriving[slot] = nil
	if st.held == slot then
		st.held = nil
		st.heldOutside = nil
		setHolding(player)
	end
	removeModel(st, slot)
	setFollowing(player)
	DataService.MarkDirty(player, true)
	task.defer(BaseService.FillPending, player)
	return entry
end

-- Arrival: Tungs bought from the belt follow you home and hop onto their pads.
function BaseService.Arrive(player: Player)
	local i = baseOf[player]
	local p = DataService.Get(player)
	if not i or not p then
		return
	end
	local st = bases[i]
	local any = false
	for slot in st.arriving do
		st.arriving[slot] = nil
		local entry = p.data.slots[key(slot)]
		if entry then
			placeModel(st, slot, entry, true)
			any = true
		end
	end
	if any then
		setFollowing(player)
	end
end

-- Stealing support ----------------------------------------------------------------------------------------
function BaseService.IsStolen(i: number, slot: number): boolean
	local st = bases[i]
	return st ~= nil and (st.stolen[slot] :: any) ~= nil
end

-- Marks a placed Tung as being carried by a thief and removes its model.
function BaseService.BeginSteal(i: number, slot: number, thief: Player): any?
	local st = bases[i]
	local owner = st and st.owner
	if not st or not owner or st.stolen[slot] or st.arriving[slot] or not st.tungs[slot] then
		return nil
	end
	local entry = BaseService.Entry(owner, slot)
	if not entry then
		return nil
	end
	st.stolen[slot] = thief
	removeModel(st, slot)
	local _, button = padParts(st, slot)
	if button then
		local counter = button:FindFirstChild("Counter") :: BillboardGui?
		local label = counter and counter:FindFirstChild("Amount") :: TextLabel?
		if counter and label then
			counter.Enabled = true
			label.Text = "STOLEN!"
		end
	end
	return entry
end

-- The steal failed: the Tung is back on its pad (call after it walked home).
function BaseService.RestoreStolen(i: number, slot: number, uid: string)
	local st = bases[i]
	if not st then
		return
	end
	st.stolen[slot] = nil
	local owner = st.owner
	local entry = owner and BaseService.Entry(owner, slot)
	if entry and entry.u == uid then
		placeModel(st, slot, entry, true)
	else
		setPadLook(st, slot, nil)
	end
end

-- Collecting ---------------------------------------------------------------------------------------------------
local lastTouch: { [Player]: { [number]: number } } = {}

function BaseService.Collect(player: Player, slot: number, silent: boolean?): number
	local i = baseOf[player]
	local p = DataService.Get(player)
	if not i or not p then
		return 0
	end
	local st = bases[i]
	local entry = p.data.slots[key(slot)]
	if not entry or not st.tungs[slot] then
		return 0
	end
	local amount = math.floor(entry.s or 0)
	if amount <= 0 then
		return 0
	end
	entry.s -= amount
	EconomyService.AddMoney(player, amount)
	p.data.stats.collected += amount
	EconomyService.Stat(player, "collectMoney", amount)
	EconomyService.Stat(player, "collects", 1)
	updateCounter(st, slot, entry.s)
	if not silent then
		local _, button = padParts(st, slot)
		Remotes.Event("CollectFx"):FireClient(player, { { pos = if button then button.Position else Vector3.zero, amount = amount, from = st.tungs[slot]:GetPivot().Position } })
	end
	return amount
end

function BaseService.CollectAll(player: Player): (boolean, any)
	local p = DataService.Get(player)
	local i = baseOf[player]
	if not p or not i then
		return false, "Still loading"
	end
	if not Economy.CanCollectAll(p.data) then
		return false, "Collect All unlocks at Rebirth 1 (or with the Collect All pass)"
	end
	local st = bases[i]
	local fx = {}
	local total = 0
	for k in p.data.slots do
		local slot = tonumber(k) :: number
		local amount = BaseService.Collect(player, slot, true)
		if amount > 0 then
			total += amount
			local _, button = padParts(st, slot)
			table.insert(fx, { pos = if button then button.Position else Vector3.zero, amount = amount, from = st.tungs[slot]:GetPivot().Position })
		end
	end
	if total <= 0 then
		return false, "Nothing to collect yet"
	end
	Remotes.Event("CollectFx"):FireClient(player, fx)
	return true, total
end

function hookButtons(st: BaseState)
	local model = st.model
	local buttons = model and model:FindFirstChild("Buttons")
	if not buttons then
		return
	end
	for _, b in buttons:GetChildren() do
		if not b:IsA("BasePart") then
			continue
		end
		local slot = b:GetAttribute("Slot") :: number
		-- standing on the button collects every 1.5 s; a tap/click collects right away
		local function tryCollect(player: Player, debounce: number)
			local owner = st.owner
			if owner == nil or owner ~= player then
				return
			end
			local t = lastTouch[player] or {}
			lastTouch[player] = t
			if os.clock() - (t[slot] or 0) < debounce then
				return
			end
			t[slot] = os.clock()
			BaseService.Collect(player, slot)
		end
		b.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				tryCollect(player, 1.5)
			end
		end)
		local cd = b:FindFirstChildOfClass("ClickDetector")
		if cd then
			cd.MouseClick:Connect(function(player)
				tryCollect(player, 0.3)
			end)
		end
	end
end

-- Base lock ------------------------------------------------------------------------------------------------------
function BaseService.Lock(player: Player): (boolean, any)
	local i = baseOf[player]
	local p = DataService.Get(player)
	if not i or not p then
		return false, "Still loading"
	end
	if Workspace:GetAttribute("Event") == "ThiefNight" then
		return false, "Base locks are OFF during Thief Night!"
	end
	local st = bases[i]
	local t = now()
	if st.locked then
		return false, "Your base is already locked"
	end
	if t < st.lockReady then
		return false, "Lock is cooling down (" .. math.ceil(st.lockReady - t) .. "s)"
	end
	st.locked = true
	st.lockEnds = t + Economy.LockDuration(p.data)
	st.lockReady = t + Economy.LOCK_COOLDOWN
	setLasers(st)
	refreshHeadline(st)
	EconomyService.Notify(player, "🔒 Base locked for " .. Economy.LockDuration(p.data) .. " seconds!", "success")
	return true, st.lockEnds
end

local function unlock(st: BaseState)
	if st.locked then
		st.locked = false
		setLasers(st)
		refreshHeadline(st)
	end
end

function BaseService.UnlockAll()
	for _, st in bases do
		unlock(st)
	end
end

function BaseService.IsLocked(i: number): boolean
	local st = bases[i]
	return st ~= nil and st.locked
end

-- Selling ------------------------------------------------------------------------------------------------------------
function BaseService.Sell(player: Player, slot: number): (boolean, any)
	local i = baseOf[player]
	local p = DataService.Get(player)
	if not i or not p then
		return false, "Still loading"
	end
	local st = bases[i]
	local entry = p.data.slots[key(slot)]
	if not entry then
		return false, "Nothing in that slot"
	end
	local t = Tungs.Get(entry.id)
	if not t or t.bound then
		return false, "This Tung can't be sold"
	end
	if st.stolen[slot] then
		return false, "Someone is stealing that one!"
	end
	if st.arriving[slot] then
		return false, "Bring it home first"
	end
	local price = Economy.SellPrice(entry.id, entry.m) + math.floor(entry.s or 0)
	BaseService.RemoveTung(player, slot)
	EconomyService.AddMoney(player, price)
	p.data.stats.sold += 1
	EconomyService.Stat(player, "sell", 1)
	EconomyService.Notify(player, "💰 Sold " .. Mutations.Prefix(entry.m) .. t.name .. " for " .. Format.Money(price), "money")
	return true, price
end

-- Moving your own Tungs ----------------------------------------------------------------------------------------------
-- Pick one up and it follows you around (it earns nothing while it's off its
-- pad, and nobody can steal it). Press "Place Here" on any pad in your base to
-- put it down there; on a pad that already has a Tung, the two swap places.
local HELD_OUTSIDE_LIMIT = 60 -- seconds outside your base before a held Tung hops back home

local function nearPos(player: Player, pos: Vector3, range: number): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and (hrp.Position - pos).Magnitude <= range
end

-- Puts a held Tung back on its own pad.
local function returnHeld(st: BaseState)
	local slot = st.held
	if not slot then
		return
	end
	st.held = nil
	st.heldOutside = nil
	local owner = st.owner
	local entry = owner and BaseService.Entry(owner, slot)
	if entry then
		placeModel(st, slot, entry, true)
	else
		setPadLook(st, slot, nil)
	end
	if owner then
		setHolding(owner)
	end
end

function BaseService.ReturnHeld(player: Player)
	local i = baseOf[player]
	if i then
		returnHeld(bases[i])
	end
end

function BaseService.PickUp(player: Player, slot: number): (boolean, any)
	local i = baseOf[player]
	local p = DataService.Get(player)
	if not i or not p then
		return false, "Still loading"
	end
	local st = bases[i]
	if st.held then
		return false, "You're already holding a Tung. Place it first!"
	end
	if player:GetAttribute("Carrying") then
		return false, "Your hands are full!"
	end
	local entry = p.data.slots[key(slot)]
	local model = st.tungs[slot]
	if not entry or not model then
		return false, "Nothing to pick up there"
	end
	if st.stolen[slot] or st.arriving[slot] then
		return false, "Not right now"
	end
	if not nearPos(player, model:GetPivot().Position, 16) then
		return false, "Get closer"
	end
	BaseService.Collect(player, slot) -- bank its cash so nothing is lost while it's off the pad
	st.held = slot
	st.heldOutside = nil
	removeModel(st, slot)
	setPadHeld(st, slot)
	setHolding(player)
	local t = Tungs.Get(entry.id)
	EconomyService.Notify(player, "🐾 " .. Mutations.Prefix(entry.m) .. (if t then t.name else "Tung") .. " is following you. Press Place Here on any pad!", "info")
	return true, slot
end

function BaseService.Place(player: Player, target: number): (boolean, any)
	local i = baseOf[player]
	local p = DataService.Get(player)
	if not i or not p then
		return false, "Still loading"
	end
	local st = bases[i]
	local from = st.held
	if not from then
		return false, "Pick up one of your Tungs first"
	end
	local data = p.data
	if target < 1 or target > Economy.Slots(data) or target ~= math.floor(target) then
		return false, "That pad doesn't exist"
	end
	if st.stolen[target] or st.arriving[target] then
		return false, "That pad is busy right now"
	end
	if not nearPos(player, Layout.PadCFrame(i, target, st.slots).Position, 16) then
		return false, "Get closer to the pad"
	end
	local a = data.slots[key(from)]
	if not a then
		st.held = nil
		setHolding(player)
		return false, "That Tung is gone"
	end
	local b = data.slots[key(target)]
	st.held = nil
	st.heldOutside = nil
	if target ~= from then
		data.slots[key(target)] = a
		data.slots[key(from)] = b -- nil when the target pad was empty
		if b then
			removeModel(st, target)
			placeModel(st, from, b, true)
		else
			setPadLook(st, from, nil)
		end
	end
	placeModel(st, target, a, true)
	setHolding(player)
	DataService.MarkDirty(player, true)
	return true, target
end

-- Base skins -------------------------------------------------------------------------------------------------------
function BaseService.SetSkin(player: Player, key: string): (boolean, any)
	local i = baseOf[player]
	local p = DataService.Get(player)
	if not i or not p then
		return false, "Still loading"
	end
	local skin = BaseSkins.ByKey[key]
	if not skin then
		return false, "Unknown skin"
	end
	local unlocked, how = BaseSkins.Unlocked(p.data, skin)
	if not unlocked then
		return false, "🔒 " .. how
	end
	if p.data.baseSkin == skin.key then
		return true, skin.key
	end
	p.data.baseSkin = skin.key
	DataService.MarkDirty(player, true)
	BaseService.Rebuild(i)
	EconomyService.Notify(player, "🎨 Your base is now " .. skin.name .. "!", "success")
	return true, skin.key
end

-- Rebirth -------------------------------------------------------------------------------------------------------------
function BaseService.Rebirth(player: Player, useSkip: boolean): (boolean, any)
	local i = baseOf[player]
	local p = DataService.Get(player)
	if not i or not p then
		return false, "Still loading"
	end
	local data = p.data
	if useSkip and (data.tokens.SkipRebirth or 0) < 1 then
		return false, "You don't have a Skip Rebirth token"
	end
	local ok, why = Economy.CanRebirth(data, useSkip)
	if not ok then
		return false, why
	end
	local st = bases[i]
	BaseService.Hooks.CancelStealsFrom(player)
	BaseService.Hooks.DropCarried(player, "rebirth")
	returnHeld(st)

	-- cinematic: every Tung flies into the sky
	local flying = {}
	for slot, m in st.tungs do
		table.insert(flying, { tung = m:GetAttribute("TungId"), mut = m:GetAttribute("Mutation"), cf = m:GetPivot() })
	end
	Remotes.Event("RebirthFx"):FireAllClients({ base = i, tungs = flying, center = Layout.Local(i, 0, 0, Layout.Depth(st.slots) / 2).Position, player = player.UserId })
	for slot in st.tungs do
		removeModel(st, slot)
	end

	-- keep bound specials (VIP / Group Tung); everything else is wiped
	local keep = {}
	for _, entry in data.slots do
		local t = Tungs.Get(entry.id)
		if t and t.bound then
			table.insert(keep, { id = entry.id, m = entry.m, u = entry.u })
		end
	end
	for _, e in data.pending do
		table.insert(keep, e)
	end
	if useSkip then
		data.tokens.SkipRebirth -= 1
	end
	data.money = 0
	data.slots = {}
	data.pending = keep
	data.rebirths += 1
	st.arriving = {}
	st.stolen = {}
	setFollowing(player)
	DataService.MarkDirty(player, true)
	DataService.Save(player)

	local info = Economy.Rebirth(data.rebirths)
	EconomyService.Alert(nil, "♻️ " .. player.DisplayName .. " reached REBIRTH " .. data.rebirths .. "! (x" .. info.mult .. ")", Color3.fromRGB(255, 200, 50), "Rebirth", "rebirth")
	Bus.Fire("Rebirthed", player)
	task.delay(1.8, function()
		if baseOf[player] == i then
			BaseService.Rebuild(i)
			BaseService.FillPending(player)
		end
	end)
	return true, data.rebirths
end

-- Assignment ----------------------------------------------------------------------------------------------------------------
local function assign(player: Player)
	if baseOf[player] then
		return
	end
	for i, st in bases do
		if not st.owner then
			st.owner = player
			st.locked = false
			st.lockEnds = 0
			st.lockReady = 0
			st.stolen = {}
			st.arriving = {}
			st.held = nil
			st.heldOutside = nil
			st.alarmCooldown = {}
			baseOf[player] = i
			player:SetAttribute("Base", i)
			setCharacterGroup(player)
			BaseService.Rebuild(i)
			BaseService.FillPending(player)
			DataService.MarkDirty(player, true)
			Bus.Fire("BaseAssigned", player, i)
			return
		end
	end
	warn("[BaseService] No free base for", player.Name)
end

local function release(player: Player)
	local i = baseOf[player]
	if not i then
		return
	end
	BaseService.Hooks.CancelStealsFrom(player)
	BaseService.Hooks.DropCarried(player, "left")
	local st = bases[i]
	-- Tungs still following the owner are already in their data; nothing to do.
	st.owner = nil
	st.locked = false
	st.stolen = {}
	st.arriving = {}
	st.held = nil -- still in its slot in the save
	st.heldOutside = nil
	player:SetAttribute("Holding", nil)
	baseOf[player] = nil
	setCharacterGroup(player)
	lastTouch[player] = nil
	BaseService.Rebuild(i)
end

-- Ticks ------------------------------------------------------------------------------------------------------------------
local function incomeTick()
	for _, st in bases do
		local owner = st.owner
		local p = owner and DataService.Get(owner)
		if not owner or not p then
			continue
		end
		local data = p.data
		data.playtime += 1
		local mult = EconomyService.Multiplier(owner, data)
		for slot, _ in st.tungs do
			local entry = data.slots[key(slot)]
			if entry then
				local rate = Economy.TungIncome(entry.id, entry.m) * mult
				local cap = rate * Economy.COLLECT_CAP_SECONDS
				entry.s = math.min(cap, (entry.s or 0) + rate)
				updateCounter(st, slot, entry.s)
			end
		end
		-- lock expiry + Auto Lock pass
		local t = now()
		if st.locked and t >= st.lockEnds then
			unlock(st)
		end
		if not st.locked and t >= st.lockReady and Economy.HasPass(data, "AutoLock") and Workspace:GetAttribute("Event") ~= "ThiefNight" then
			BaseService.Lock(owner)
		end
		refreshHeadline(st)
		local shieldLeft = Economy.SHIELD_SECONDS - data.playtime
		owner:SetAttribute("Shielded", shieldLeft > 0)
		DataService.MarkDirty(owner)
	end
end

local function alarm(st: BaseState, intruder: Player)
	local owner = st.owner
	if not owner or not st.model then
		return
	end
	local last = st.alarmCooldown[intruder] or 0
	if os.clock() - last < 12 then
		return
	end
	st.alarmCooldown[intruder] = os.clock()
	EconomyService.Alert(owner, "🚨 " .. intruder.DisplayName .. " walked into your base!", Color3.fromRGB(255, 60, 60), "Alarm", "alarm")
	local traps = st.model:FindFirstChild("Traps")
	local siren = traps and traps:FindFirstChild("Alarm") and (traps :: any).Alarm:FindFirstChild("Siren") :: BasePart?
	local light = siren and siren:FindFirstChild("AlarmLight") :: SpotLight?
	if siren and light then
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		snd.PlaybackSpeed = 1.4
		snd.Volume = 0.35
		snd.RollOffMaxDistance = 90
		snd.Parent = siren
		task.spawn(function()
			for _ = 1, 4 do
				light.Brightness = 6
				snd:Play()
				task.wait(0.25)
				light.Brightness = 0
				task.wait(0.25)
			end
			snd:Destroy()
		end)
	end
end

local function zoneTick()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inBase = 0
		if hrp then
			for i, st in bases do
				if Layout.InBase(i, st.slots, hrp.Position) then
					inBase = i
					break
				end
			end
		end
		if player:GetAttribute("InBase") ~= inBase then
			player:SetAttribute("InBase", inBase)
		end
		local own = baseOf[player]
		if own then
			local st = bases[own]
			if st.held then
				if inBase == own then
					st.heldOutside = nil
				elseif not st.heldOutside then
					st.heldOutside = os.clock()
				elseif os.clock() - (st.heldOutside :: number) > HELD_OUTSIDE_LIMIT then
					returnHeld(st)
					EconomyService.Notify(player, "🏠 Your Tung got homesick and hopped back onto its pad", "info")
				end
			end
			if inBase == own and next(st.arriving) then
				BaseService.Arrive(player)
			else
				for slot, t in st.arriving do
					if os.clock() - t > 120 then
						st.arriving[slot] = nil
						local entry = BaseService.Entry(player, slot)
						if entry then
							placeModel(st, slot, entry, true)
						end
						setFollowing(player)
					end
				end
			end
		end
		if inBase ~= 0 and inBase ~= own then
			local st = bases[inBase]
			local owner = st.owner
			local p = owner and DataService.Get(owner)
			if p and p.data.items.Alarm then
				alarm(st, player)
			end
		end
	end
end

function BaseService.Init()
	registerGroups()
	basesFolder = (Workspace:WaitForChild("Arena") :: Instance):WaitForChild("Bases") :: Folder
	for i = 1, Layout.BASE_COUNT do
		bases[i] = {
			index = i,
			owner = nil,
			model = nil,
			slots = 8,
			skin = BaseSkins.DEFAULT,
			tungs = {},
			stolen = {},
			arriving = {},
			held = nil,
			heldOutside = nil,
			locked = false,
			lockEnds = 0,
			lockReady = 0,
			alarmCooldown = {},
		}
		BaseService.Rebuild(i)
	end

	DataService.OnLoaded(function(profile)
		assign(profile.player)
	end)
	DataService.OnReleasing(function(profile)
		-- Tungs still following get placed into the save as normal slots (they already are).
		release(profile.player)
	end)

	Bus.On("GrantTung", function(player: Player, id: string, mut: string?, source: string?)
		local slot = BaseService.AddTung(player, id, mut, { source = source })
		local t = Tungs.Get(id)
		if t and slot then
			EconomyService.Notify(player, "🎁 " .. Mutations.Prefix(mut) .. t.name .. " was added to your base! (" .. (source or "gift") .. ")", "success")
		end
	end)
	-- Slot count / look / traps changed (VIP pass, Index Master, shop traps)
	Bus.On("BaseChanged", function(player: Player)
		local i = baseOf[player]
		if i then
			BaseService.Rebuild(i)
			BaseService.FillPending(player)
		end
	end)
	Bus.On("PassesChanged", function(player: Player)
		local i = baseOf[player]
		local p = DataService.Get(player)
		if i and p and Economy.Slots(p.data) ~= bases[i].slots then
			BaseService.Rebuild(i)
			BaseService.FillPending(player)
		end
	end)

	-- Server-side handling of prompts that belong to bases.
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
		local action = prompt:GetAttribute("Action")
		local ui = prompt:GetAttribute("UI")
		local base = prompt:FindFirstAncestorWhichIsA("Model")
		local ownerId = base and base:GetAttribute("OwnerId")
		if prompt:GetAttribute("OwnerOnly") and ownerId ~= player.UserId then
			return
		end
		local slot = tonumber(prompt:GetAttribute("Slot")) or 0
		local ok, msg = true, nil
		if action == "Lock" then
			ok, msg = BaseService.Lock(player)
		elseif action == "PickUp" then
			ok, msg = BaseService.PickUp(player, slot)
		elseif action == "Place" then
			ok, msg = BaseService.Place(player, slot)
		elseif action == "Sell" then
			ok, msg = BaseService.Sell(player, slot)
		elseif type(ui) == "string" then
			Remotes.Event("OpenUI"):FireClient(player, ui)
		end
		if not ok and type(msg) == "string" then
			EconomyService.Notify(player, msg, "error")
		end
	end)

	-- a held Tung goes back to its pad when you respawn; your character can pass your own lasers
	local function hookCharacter(player: Player)
		player.CharacterRemoving:Connect(function()
			BaseService.ReturnHeld(player)
		end)
		local function onCharacter(character: Model)
			setCharacterGroup(player)
			character.DescendantAdded:Connect(function(d)
				if d:IsA("BasePart") then
					d.CollisionGroup = ownerGroup(player)
				end
			end)
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(incomeTick :: any)
			if not ok then
				warn("[BaseService] income tick:", err)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(zoneTick :: any)
			if not ok then
				warn("[BaseService] zone tick:", err)
			end
		end
	end)
end

return BaseService
