--!strict
-- Renders the conveyor belt locally. The server only sends "Tung X starts at
-- time T and rides from A to B in D seconds"; every client builds the models,
-- moves them each frame, drops them into the hole, and shows a Buy prompt.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local TungModel = require(Shared.TungModel)

local State = require(script.Parent.State)
local Lib = require(script.Parent.UI.Lib)

local Belt = {}

local player = Players.LocalPlayer

type Item = {
	data: any,
	model: Model,
	prompt: ProximityPrompt?,
	facing: CFrame,
	falling: number?, -- os.clock() it started falling
}

local items: { [number]: Item } = {}
local folder: Folder

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Belt.GetModel(entryId: number): Model?
	local it = items[entryId]
	return it and it.model
end

local function priceOf(e: any): number
	return if e.free then 0 else Economy.TungPrice(e.tung, e.mut)
end

local function updatePrompt(it: Item)
	local pr = it.prompt
	if not pr then
		return
	end
	local e = it.data
	local price = priceOf(e)
	pr.ActionText = if e.free then "Grab – FREE" else "Buy – " .. Format.Money(price)
	local blocked = ""
	if State.BaseFull() then
		blocked = "Base full"
	elseif State.data and State.data.money < price then
		blocked = "Need " .. Format.Money(price)
	elseif player:GetAttribute("Carrying") then
		blocked = "Hands full!"
	end
	pr:SetAttribute("Blocked", blocked)
end

local function add(e: any)
	if items[e.id] then
		return
	end
	local t = Tungs.Get(e.tung)
	if not t then
		return
	end
	local model = TungModel.Build(e.tung, e.mut, { plate = "belt" })
	model.Name = "BeltTung" .. e.id
	model:SetAttribute("EntryId", e.id)
	-- main-belt Tungs face alternate sides so both rows of bases see faces
	local dir = (e.b - e.a).Unit
	local side = if e.id % 2 == 0 then 1 else -1
	local facing = CFrame.lookAt(Vector3.zero, Vector3.new(dir.Z * side, 0, -dir.X * side))
	if e.belt ~= "main" then
		facing = CFrame.lookAt(Vector3.zero, -dir:Cross(Vector3.yAxis))
	end
	local it: Item = { data = e, model = model, facing = facing }

	local mine = e.owner == nil or e.owner == player.UserId
	if e.owner ~= nil then
		local plate = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Nameplate")
		if plate then
			local owner = Players:GetPlayerByUserId(e.owner)
			local tag = Instance.new("TextLabel")
			tag.Size = UDim2.new(1, 0, 0, 20)
			tag.BackgroundTransparency = 1
			tag.TextScaled = true
			tag.Font = Enum.Font.FredokaOne
			tag.TextColor3 = if mine then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 160, 160)
			tag.Text = if mine then "⭐ JUST FOR YOU ⭐" else "Reserved for " .. (if owner then owner.DisplayName else "someone")
			tag.LayoutOrder = 0
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Parent = tag
			tag.Parent = plate
		end
	end
	if mine and model.PrimaryPart then
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "BuyPrompt"
		pr.ObjectText = Mutations.Prefix(e.mut) .. t.name
		pr.HoldDuration = Economy.BUY_HOLD
		pr.MaxActivationDistance = 11
		pr.RequiresLineOfSight = false
		pr.Style = Enum.ProximityPromptStyle.Custom
		pr:SetAttribute("EntryId", e.id)
		pr.Parent = model.PrimaryPart
		pr.Triggered:Connect(function()
			local ok = State.Request("Buy", e.id)
			if ok then
				Lib.sound("Purchase")
				State.Fire("Toast", "🛒 Bought " .. Mutations.Prefix(e.mut) .. t.name .. "! Walk it back to your base.", "money")
			end
		end)
		it.prompt = pr
		updatePrompt(it)
	end
	items[e.id] = it
	model.Parent = folder
	-- spawn sound: a single knock for Common up to a full drumroll for Mythic
	if e.belt == "main" then
		Lib.sound3D("Spawn" .. t.rarity, Layout.DRUM_POS, nil, nil)
	end
end

local function remove(id: number, buyer: number?)
	local it = items[id]
	if not it then
		return
	end
	items[id] = nil
	if buyer then
		local pos = it.model:GetPivot().Position
		Lib.sound3D("Puff", pos)
	end
	it.model:Destroy()
end

-- Moving slats on the belt surface so it looks like it's running (local parts).
local function slats()
	local a, b = Layout.BELT_START, Layout.BELT_END
	local dir = (b - a).Unit
	local len = (b - a).Magnitude + 4
	local spacing = 6
	local count = math.floor(len / spacing)
	local parts: { BasePart } = {}
	for k = 1, count do
		local p = Instance.new("Part")
		p.Name = "Slat"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(Layout.BELT_WIDTH - 0.4, 0.06, 1.4)
		p.Color = Color3.fromRGB(78, 78, 90)
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = folder
		parts[k] = p
	end
	local speed = (b - a).Magnitude / Economy.BELT_TRAVEL
	local cframes: { CFrame } = table.create(count)
	local offset = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local fast = Workspace:GetAttribute("Event") == "SpeedBelt"
		offset = (offset + dt * speed * (if fast then 2 else 1)) % spacing
		local start = a - dir * 2
		for k = 1, count do
			local pos = start + dir * ((k - 1) * spacing + offset) + Vector3.new(0, 0.03, 0)
			cframes[k] = CFrame.lookAt(pos, pos + dir)
		end
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

function Belt.Init()
	folder = Instance.new("Folder")
	folder.Name = "BeltTungs"
	folder.Parent = Workspace

	Remotes.Event("BeltAdd").OnClientEvent:Connect(add)
	Remotes.Event("BeltRemove").OnClientEvent:Connect(remove)
	Remotes.Event("BeltSync").OnClientEvent:Connect(function(list)
		for _, e in list do
			add(e)
		end
	end)

	slats()

	RunService.RenderStepped:Connect(function()
		local t = now()
		local clock = os.clock()
		for id, it in items do
			local e = it.data
			local a = (t - e.t0) / e.dur
			if a < 1 then
				local pos = e.a:Lerp(e.b, math.max(a, 0))
				local bob = math.abs(math.sin(clock * 6 + id)) * 0.25
				it.model:PivotTo(CFrame.new(pos + Vector3.new(0, bob, 0)) * it.facing)
			else
				-- drop into the hole
				if not it.falling then
					it.falling = clock
					if it.prompt then
						it.prompt.Enabled = false
					end
				end
				local f = clock - (it.falling :: number)
				local pos = e.b + (e.b - e.a).Unit * math.min(f * 8, 5) - Vector3.new(0, f * f * 30, 0)
				it.model:PivotTo(CFrame.new(pos) * it.facing * CFrame.Angles(f * 4, 0, f * 2))
				if f > 1.1 then
					items[id] = nil
					it.model:Destroy()
				end
			end
		end
	end)

	-- refresh Buy prompts (money / base full) a few times a second
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, it in items do
				updatePrompt(it)
			end
		end
	end)

	-- ask for the current belt once we're listening
	task.delay(1.5, function()
		State.Request("Sync")
	end)
end

return Belt
