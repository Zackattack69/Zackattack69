--!strict
-- ADMIN panel (only shown to admins / the owner). Unlock it with the admin code;
-- the server checks the code and that you're an admin, so nobody else can use it.
--   Money:  give yourself any amount (1000, 2.5M, 1e15...) or tap a quick amount
--   Tungs:  spawn any Tung, with any mutation, into your base or onto the belt
--   Events: start any server event or Admin Abuse

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local AdminPanel = {}

local function textBox(parent: Instance, placeholder: string, size: UDim2, position: UDim2): TextBox
	local box = Lib.new("TextBox", {
		Size = size,
		Position = position,
		BackgroundColor3 = Color3.new(1, 1, 1),
		PlaceholderText = placeholder,
		PlaceholderColor3 = C.SubText,
		Text = "",
		TextColor3 = C.TextDark,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = parent,
	})
	Lib.corner(box, 16)
	Lib.stroke(box, C.Outline, 3)
	Lib.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = box })
	return box
end

function AdminPanel.Build(): any
	local win = Lib.window("Admin", Vector2.new(940, 640), C.Red, "👑")
	local body = win.body

	-- Locked view -----------------------------------------------------------------------------------------
	local locked = Lib.new("Frame", { Name = "Locked", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	Lib.title({ Text = "🔐 ENTER ADMIN CODE", Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 70), Parent = locked })
	local codeBox = textBox(locked, "admin code", UDim2.fromOffset(420, 70), UDim2.new(0.5, -210, 0, 160))
	local unlockedView: Frame

	local function tryUnlock()
		local ok = State.Request("AdminUnlock", codeBox.Text)
		if ok then
			Lib.sound("Jackpot")
			locked.Visible = false
			unlockedView.Visible = true
			State.Fire("Toast", "👑 Admin panel unlocked", "success")
		end
	end
	Lib.button({ Text = "UNLOCK", Size = UDim2.fromOffset(300, 76), Position = UDim2.new(0.5, -150, 0, 260), Color = C.Gold, Color2 = C.Gold2, Parent = locked, OnClick = tryUnlock })
	codeBox.FocusLost:Connect(function(enter)
		if enter then
			tryUnlock()
		end
	end)

	-- Unlocked view ------------------------------------------------------------------------------------------
	unlockedView = Lib.new("Frame", { Name = "Unlocked", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = body })
	local tabHolder = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = unlockedView })
	local pages: { [string]: Frame } = {}
	for _, name in { "Money", "Tungs", "Events" } do
		pages[name] = Lib.new("Frame", { Name = name, Size = UDim2.new(1, 0, 1, -64), Position = UDim2.fromOffset(0, 64), BackgroundTransparency = 1, Visible = false, Parent = unlockedView })
	end

	-- Money
	local money = pages.Money
	Lib.label({ Text = "Give yourself money: type an amount like 5000, 2.5M, 10B or 1e15", Size = UDim2.new(1, 0, 0, 30), Dark = true, Parent = money })
	local amountBox = textBox(money, "amount", UDim2.new(0.62, 0, 0, 72), UDim2.fromOffset(0, 44))
	local function give(amount: any)
		local ok = State.Request("AdminMoney", amount)
		if ok then
			Lib.sound("ChaChing")
		end
	end
	Lib.button({ Text = "💵 GIVE MONEY", Size = UDim2.new(0.36, 0, 0, 72), Position = UDim2.new(0.64, 0, 0, 44), Color = C.Money, Color2 = C.Money2, Parent = money, OnClick = function()
		local n = Format.Parse(amountBox.Text)
		if not n then
			State.Fire("Toast", "Type an amount like 5000, 2.5M or 1e15", "error")
			return
		end
		give(n)
	end })
	Lib.label({ Text = "Quick amounts", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 136), Dark = true, Parent = money })
	local quick = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 200), Position = UDim2.fromOffset(0, 170), BackgroundTransparency = 1, Parent = money })
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(200, 70), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = quick })
	for k, n in { 1e3, 1e5, 1e6, 1e9, 1e12, 1e15, 1e18, 1e21 } do
		Lib.button({ Text = "+" .. Format.Money(n), Size = UDim2.fromOffset(200, 70), Color = if k % 2 == 0 then C.Green else C.Blue, LayoutOrder = k, Parent = quick, OnClick = function()
			give(n)
		end })
	end

	-- Tungs
	local tungsPage = pages.Tungs
	local mutation = Mutations.NONE
	local destination = "base"
	local optionRow = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = tungsPage })
	Lib.list(optionRow, 8, true)
	local mutButtons: { [string]: TextButton } = {}
	local mutKeys = { Mutations.NONE }
	for _, m in Mutations.List do
		table.insert(mutKeys, m.key)
	end
	local destButtons: { [string]: TextButton } = {}
	local function refreshOptions()
		for key, b in mutButtons do
			local m = Mutations.Get(key)
			Lib.recolor(b, if key == mutation then (if m then m.color else C.Gold) else C.Grey, if key == mutation then nil else C.Grey2)
		end
		for key, b in destButtons do
			Lib.recolor(b, if key == destination then C.Purple else C.Grey, if key == destination then C.Purple2 else C.Grey2)
		end
	end
	for k, key in mutKeys do
		mutButtons[key] = Lib.button({ Text = if key == Mutations.NONE then "Normal" else key, Size = UDim2.fromOffset(112, 48), LayoutOrder = k, NoShine = true, Parent = optionRow, OnClick = function()
			mutation = key
			refreshOptions()
		end })
	end
	for k, key in { "base", "belt" } do
		destButtons[key] = Lib.button({ Text = if key == "base" then "🏠 My base" else "🛤️ Belt", Size = UDim2.fromOffset(140, 48), LayoutOrder = 10 + k, NoShine = true, Parent = optionRow, OnClick = function()
			destination = key
			refreshOptions()
		end })
	end
	refreshOptions()
	local grid = Lib.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -62), Position = UDim2.fromOffset(0, 62), BackgroundTransparency = 1, ScrollBarThickness = 8, ScrollBarImageColor3 = C.Wood2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = tungsPage })
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 190), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	Lib.padding(grid, 4)
	local built = false
	local function buildTungGrid()
		if built then
			return
		end
		built = true
		for k, t in Tungs.List do
			local card = Lib.new("TextButton", { Size = UDim2.fromOffset(160, 190), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, LayoutOrder = k, Parent = grid })
			Lib.corner(card, 16)
			local color = Tungs.Color(t)
			Lib.gradient(card, color:Lerp(Color3.new(1, 1, 1), 0.5), color:Lerp(Color3.new(0, 0, 0), 0.1), 90)
			Lib.stroke(card, C.Outline, 3)
			Lib.tungViewport(card, t.id, nil, UDim2.new(1, -10, 0, 108), UDim2.fromOffset(5, 4), false)
			Lib.label({ Text = t.name, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 114), Parent = card })
			local r = Lib.label({ Text = Tungs.RarityLabel(t), Font = Lib.FontTitle, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 140), Parent = card })
			Lib.rarityText(r, t)
			Lib.label({ Text = "TAP TO SPAWN", Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 164), TextColor3 = Color3.fromRGB(255, 240, 150), Parent = card })
			Lib.bouncy(card)
			card.Activated:Connect(function()
				local ok = State.Request("AdminTung", t.id, mutation, destination)
				if ok then
					Lib.sound("Purchase")
					if destination == "belt" then
						State.Fire("Toast", "👑 " .. Mutations.Prefix(mutation) .. t.name .. " is on the belt!", "success")
					end
				end
			end)
		end
	end

	-- Events
	local eventsPage = pages.Events
	local eventGrid = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = eventsPage })
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(280, 86), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = eventGrid })
	for k, e in Events.List do
		Lib.button({ Text = e.icon .. " " .. e.name, Size = UDim2.fromOffset(280, 86), Color = e.color, LayoutOrder = k, Parent = eventGrid, OnClick = function()
			State.Request("AdminEvent", e.key)
		end })
	end
	Lib.button({ Text = "⛔ Stop events", Size = UDim2.fromOffset(280, 86), Color = C.Grey, Color2 = C.Grey2, LayoutOrder = 99, Parent = eventGrid, OnClick = function()
		State.Request("AdminEvent", "stop")
	end })

	local select = Lib.tabs(tabHolder, { "Money", "Tungs", "Events" }, 48, function(name)
		for n, p in pages do
			p.Visible = n == name
		end
		if name == "Tungs" then
			buildTungGrid()
		end
	end, { Money = C.Money, Tungs = C.Purple, Events = C.Orange })
	select("Money")

	return win
end

return AdminPanel
