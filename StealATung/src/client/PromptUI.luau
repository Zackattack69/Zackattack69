--!strict
-- Custom ProximityPrompt UI: every prompt (Buy, Steal, Lock, Shop, Rebirth...)
-- shows as a big tappable button above the bottom-centre of the screen, with a
-- hold-progress fill and the key hint. Also hides prompts that aren't for you
-- (your own Tungs' Steal prompts, other players' altars and lock buttons),
-- greys out Steal prompts on locked or shielded bases (or from outside the
-- walls), and switches your own Tungs' prompts: Pick Up / Sell normally, and
-- Place Here on every pad while one of your Tungs is following you.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.State)
local Lib = require(script.Parent.UI.Lib)

local PromptUI = {}

local player = Players.LocalPlayer
local C = Lib.Colors

type Card = { frame: TextButton, fill: Frame, action: TextLabel, object: TextLabel, prompt: ProximityPrompt, holding: boolean }

local cards: { [ProximityPrompt]: Card } = {}
local holder: Frame

local function baseModelOf(prompt: ProximityPrompt): Model?
	local base = prompt:GetAttribute("Base")
	if not base then
		local m = prompt:FindFirstAncestorWhichIsA("Model")
		while m and not string.match(m.Name, "^Base%d+$") do
			m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
		end
		return m
	end
	local arena = workspace:FindFirstChild("Arena")
	local bases = arena and arena:FindFirstChild("Bases")
	return bases and bases:FindFirstChild("Base" .. tostring(base)) :: Model?
end

local function ownerIdOf(prompt: ProximityPrompt): number?
	local id = prompt:GetAttribute("OwnerId") :: number?
	if id then
		return id
	end
	local base = baseModelOf(prompt)
	return base and base:GetAttribute("OwnerId") :: number?
end

-- Returns a reason the prompt can't be used right now (shown greyed), or nil.
local function blockedReason(prompt: ProximityPrompt): string?
	local custom = prompt:GetAttribute("Blocked") :: string?
	if custom and custom ~= "" then
		return custom
	end
	if prompt:GetAttribute("Action") == "Steal" then
		local base = baseModelOf(prompt)
		if base and base:GetAttribute("Locked") then
			return "🔒 Base locked"
		end
		local ownerId = ownerIdOf(prompt)
		local owner = ownerId and Players:GetPlayerByUserId(ownerId)
		if owner and owner:GetAttribute("Shielded") then
			return "🛡️ New player shield"
		end
		if player:GetAttribute("Carrying") or player:GetAttribute("Holding") then
			return "Hands full!"
		end
		local i = base and base:GetAttribute("Index")
		if i and player:GetAttribute("InBase") ~= i then
			return "🚪 Go in through the door"
		end
	end
	return nil
end

-- Your own Tungs: Pick Up / Sell while your hands are free, Place Here on the pads while one follows you.
local function holding(): boolean
	local h = player:GetAttribute("Holding") :: string?
	return h ~= nil and h ~= ""
end

local function syncOwnPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local mine = ownerIdOf(prompt) == player.UserId
	local action = prompt:GetAttribute("Action")
	if action == "Place" then
		prompt.Enabled = mine and holding()
	else
		prompt.Enabled = mine and not holding()
	end
end

local function syncOwnPrompts()
	for _, prompt in CollectionService:GetTagged("OwnPrompt") do
		syncOwnPrompt(prompt)
	end
end

-- Live sell price (base price + the cash it's holding) for the Sell prompt.
local function sellText(prompt: ProximityPrompt): string
	local d = State.data
	local e = d and d.slots and d.slots[tostring(prompt:GetAttribute("Slot"))]
	if not e then
		return "Sell"
	end
	return "Sell " .. Format.Money(Economy.SellPrice(e.id, e.m) + math.floor(e.s or 0))
end

local function keyHint(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return if prompt.HoldDuration > 0 then "HOLD" else "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "Button", ""))
	end
	return UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
end

local function colorFor(prompt: ProximityPrompt): (Color3, Color3)
	local action = prompt:GetAttribute("Action")
	if action == "Steal" then
		return C.Red, C.Red2
	elseif action == "Lock" then
		return C.Purple, C.Purple2
	elseif action == "PickUp" or action == "Place" then
		return C.Blue, C.Blue2
	elseif action == "Sell" or prompt:GetAttribute("EntryId") then
		return C.Money, C.Money2
	end
	return C.Gold, C.Gold2
end

local function refresh(card: Card)
	local reason = blockedReason(card.prompt)
	local actionText = if card.prompt:GetAttribute("Action") == "Sell" then sellText(card.prompt) else card.prompt.ActionText
	card.action.Text = if reason then reason else actionText
	card.object.Text = card.prompt.ObjectText
	if reason then
		Lib.recolor(card.frame, C.Grey, C.Grey2)
	else
		local c1, c2 = colorFor(card.prompt)
		Lib.recolor(card.frame, c1, c2)
	end
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	-- prompts that aren't for this player
	local ownerId = ownerIdOf(prompt)
	if prompt:GetAttribute("Action") == "Steal" and ownerId == player.UserId then
		prompt.Enabled = false
		return
	end
	if prompt:GetAttribute("OwnerOnly") and ownerId ~= player.UserId then
		prompt.Enabled = false
		return
	end
	if cards[prompt] then
		return
	end
	local frame = Lib.button({ Size = UDim2.fromOffset(340, 92), Color = C.Gold, Parent = holder, Radius = 24 })
	frame.Text = ""
	local fill = Lib.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, ZIndex = 2, Parent = frame })
	Lib.corner(fill, 20)
	local key = Lib.label({ Text = keyHint(prompt, inputType), Size = UDim2.fromOffset(70, 62), Position = UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.Panel, ZIndex = 3, Parent = frame })
	Lib.corner(key, 16)
	Lib.stroke(key, C.Outline, 3)
	Lib.padding(key, 8)
	local action = Lib.label({ Text = prompt.ActionText, Size = UDim2.new(1, -90, 0.58, 0), Position = UDim2.fromOffset(84, 2), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = frame })
	local object = Lib.label({ Text = prompt.ObjectText, Size = UDim2.new(1, -90, 0.36, 0), Position = UDim2.new(0, 84, 0.6, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = frame })
	local card: Card = { frame = frame, fill = fill, action = action, object = object, prompt = prompt, holding = false }
	cards[prompt] = card
	refresh(card)
	local s = Lib.new("UIScale", { Scale = 0.6, Parent = frame })
	Lib.tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if blockedReason(prompt) then
				Lib.sound("Error")
				return
			end
			card.holding = true
			prompt:InputHoldBegin()
		end
	end)
	frame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if card.holding then
				card.holding = false
				prompt:InputHoldEnd()
			end
		end
	end)
	-- keep text fresh (price changes, lock state...)
	task.spawn(function()
		while cards[prompt] == card do
			refresh(card)
			task.wait(0.25)
		end
	end)
end

local function hide(prompt: ProximityPrompt)
	local card = cards[prompt]
	if not card then
		return
	end
	cards[prompt] = nil
	if card.holding then
		card.holding = false
		pcall(function()
			prompt:InputHoldEnd()
		end)
	end
	local frame = card.frame
	local s = frame:FindFirstChildOfClass("UIScale")
	if s then
		Lib.tween(s, 0.12, { Scale = 0.5 })
	end
	task.delay(0.12, function()
		frame:Destroy()
	end)
end

function PromptUI.Init(gui: ScreenGui)
	holder = Lib.new("Frame", {
		Name = "Prompts",
		Size = UDim2.fromOffset(360, 220),
		Position = UDim2.new(0.5, 0, 1, if Lib.Touch then -150 else -130),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Lib.hudFit(holder)
	local list = Lib.list(holder, 10, false, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom

	CollectionService:GetInstanceAddedSignal("OwnPrompt"):Connect(syncOwnPrompt)
	player:GetAttributeChangedSignal("Holding"):Connect(syncOwnPrompts)
	syncOwnPrompts()

	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local card = cards[prompt]
		if card and prompt.HoldDuration > 0 then
			card.fill.Size = UDim2.fromScale(0, 1)
			Lib.tween(card.fill, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local card = cards[prompt]
		if card then
			Lib.tween(card.fill, 0.15, { Size = UDim2.fromScale(0, 1) })
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local card = cards[prompt]
		if card then
			local s = card.frame:FindFirstChild("Bounce") :: UIScale?
			if s then
				s.Scale = 1.1
				Lib.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
	end)
end

return PromptUI
