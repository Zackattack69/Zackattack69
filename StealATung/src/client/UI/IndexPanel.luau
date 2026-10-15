--!strict
-- The Index: a wooden collection book of every Tung. Found Tungs are full
-- colour and animated with name, rarity, income and the date first found;
-- missing ones are black silhouettes with "???" (Mythics get a flame-outlined
-- question mark). Tabs per rarity + a Mutations tab with its rewards.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Tungs = require(Shared.Config.Tungs)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local IndexPanel = {}

local TABS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret", "Mythic", "Mutations" }

local function card(parent: Instance, t: Tungs.Tung, entry: any?, order: number)
	local color = Tungs.Color(t)
	local found = entry ~= nil
	local f = Lib.new("Frame", { Size = UDim2.fromOffset(150, 206), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ClipsDescendants = true, Parent = parent })
	Lib.corner(f, 18)
	Lib.gradient(f, if found then color:Lerp(Color3.new(1, 1, 1), 0.5) else Color3.fromRGB(78, 72, 128), if found then color:Lerp(Color3.new(0, 0, 0), 0.1) else Color3.fromRGB(36, 32, 70), 90)
	local stroke = Lib.stroke(f, if t.rarity == "Secret" then Color3.new(1, 1, 1) else color, 4)
	if t.rarity == "Secret" then
		Lib.new("UIGradient", { Color = Rarities.RAINBOW, Parent = stroke })
	end
	if found and Rarities.Order(t.rarity) >= Rarities.Order("Epic") then
		local rays = Lib.rays(f, Color3.new(1, 1, 1), 190, 8)
		rays.Position = UDim2.new(0.5, 0, 0, 62)
		Lib.sparkles(f, 3)
	end
	local vf = Lib.tungViewport(f, t.id, Mutations.NONE, UDim2.new(1, -10, 0, 118), UDim2.fromOffset(5, 4), found)
	if not found then
		vf.ImageColor3 = Color3.new(0, 0, 0)
		vf.ImageTransparency = 0.15
		local q = Lib.label({ Text = "?", Size = UDim2.fromOffset(70, 80), Position = UDim2.new(0.5, 0, 0, 62), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Color3.new(1, 1, 1), Parent = f })
		if t.rarity == "Mythic" then
			local s = q:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = Color3.fromRGB(255, 90, 20)
				s.Thickness = 5
			end
			Lib.label({ Text = "🔥", Size = UDim2.fromOffset(36, 36), Position = UDim2.new(0.5, 0, 0, 22), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = f })
		end
	end
	Lib.label({ Text = if found then t.name else "???", Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 122), Parent = f })
	local r = Lib.label({ Text = Tungs.RarityLabel(t), Font = Lib.FontTitle, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 146), Parent = f })
	Lib.rarityText(r, t)
	if found then
		Lib.label({ Text = Economy.IncomeText(t.id, nil), Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 165), TextColor3 = Color3.fromRGB(255, 230, 110), Parent = f })
		local icons = {}
		for _, m in Mutations.List do
			if entry.m and entry.m[m.key] then
				table.insert(icons, m.icon)
			end
		end
		Lib.label({ Text = "Found " .. os.date("%d %b %Y", entry.t) .. (if #icons > 0 then "  " .. table.concat(icons) else ""), Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 184), Parent = f })
	end
end

function IndexPanel.Build(): any
	local win = Lib.window("Index", Vector2.new(1000, 660), Lib.Colors.Orange, "📖")
	local body = win.body

	-- progress bar
	local progressLabel = Lib.label({ Text = "", Size = UDim2.new(1, 0, 0, 30), Dark = true, Parent = body })
	local _, setProgress = Lib.bar(body, UDim2.new(1, -40, 0, 18), UDim2.new(0, 20, 0, 34), C.Gold, C.Gold2)

	local tabHolder = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 60), BackgroundTransparency = 1, Parent = body })
	local rewardLabel = Lib.label({ Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 116), Dark = true, TextColor3 = C.SubText, Parent = body })
	local content = Lib.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -146),
		Position = UDim2.fromOffset(0, 146),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Wood2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	})
	local current = "All"

	local function clear()
		for _, c in content:GetChildren() do
			c:Destroy()
		end
	end

	local function renderMutations()
		local d = State.data
		Lib.list(content, 10, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top
		Lib.padding(content, 6)
		for i, m in Mutations.List do
			local found = 0
			for _, t in Tungs.IndexList do
				local e = d.index[t.id]
				if e and e.m and e.m[m.key] then
					found += 1
				end
			end
			local unlocked = d.indexRewards["Mut_" .. m.key] == true
			local row = Lib.card(content, { Size = UDim2.new(1, -20, 0, 92), LayoutOrder = i })
			Lib.label({ Text = m.icon, Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 11), Stroke = false, Parent = row })
			Lib.label({ Text = m.name .. "  ·  x" .. m.mult .. " income  ·  " .. string.format("%.1f%%", m.chance * 100) .. " chance", Size = UDim2.new(0.55, 0, 0, 30), Position = UDim2.fromOffset(90, 8), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, Parent = row })
			Lib.label({ Text = found .. " / " .. #Tungs.IndexList .. " found  ·  Reward: " .. m.name .. " avatar aura", Size = UDim2.new(0.55, 0, 0, 22), Position = UDim2.fromOffset(90, 40), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = C.SubText, Parent = row })
			local _, set = Lib.bar(row, UDim2.new(0.55, 0, 0, 14), UDim2.fromOffset(90, 68), m.color, m.color:Lerp(Color3.new(0, 0, 0), 0.3))
			set(found / #Tungs.IndexList)
			local equipped = d.aura == m.key
			Lib.button({
				Text = if not unlocked then "🔒 Locked" elseif equipped then "Unequip" else "Equip Aura",
				Size = UDim2.fromOffset(170, 60),
				Position = UDim2.new(1, -14, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = if not unlocked then C.Grey elseif equipped then C.Red else C.Green,
				Parent = row,
				OnClick = function()
					if unlocked then
						State.Request("EquipAura", m.key)
					end
				end,
			})
		end
		local master = d.indexRewards.Master == true
		local row = Lib.card(content, { Size = UDim2.new(1, -20, 0, 80), LayoutOrder = 10, BackgroundColor3 = if master then Color3.fromRGB(255, 236, 170) else C.Cream })
		Lib.label({ Text = "🏆", Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(12, 10), Stroke = false, Parent = row })
		Lib.label({ Text = if master then "You are a TUNG MASTER! Golden base unlocked." else "Find all " .. #Tungs.IndexList .. " Tungs: \"Tung Master\" title + golden base skin", Size = UDim2.new(1, -100, 0, 50), Position = UDim2.fromOffset(84, 15), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, Parent = row })
	end

	local function render()
		local d = State.data
		if not d then
			return
		end
		clear()
		local total = #Tungs.IndexList
		local found = 0
		for _, t in Tungs.IndexList do
			if d.index[t.id] then
				found += 1
			end
		end
		progressLabel.Text = "📖 " .. found .. " / " .. total .. " Tungs found (" .. math.floor(found / total * 100 + 0.5) .. "%)"
		setProgress(found / total)

		if current == "Mutations" then
			rewardLabel.Text = "Find every Tung with a mutation to unlock that mutation's avatar aura"
			renderMutations()
			return
		end
		if current == "All" then
			rewardLabel.Text = "Complete a rarity tab: +5% money forever + a badge  ·  your bonus: +" .. math.floor(Economy.IndexBonus(d) * 100) .. "%"
		else
			local done = d.indexRewards[current] == true
			rewardLabel.Text = if done then "✅ Tab complete! +5% money forever" else "Complete this tab for +5% money forever + a badge"
		end
		Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 206), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })
		Lib.padding(content, 6)
		for i, t in Tungs.IndexList do
			if current == "All" or t.rarity == current then
				card(content, t, d.index[t.id], i)
			end
		end
	end

	local tabColors: { [string]: Color3 } = {}
	for _, r in Rarities.List do
		tabColors[r.key] = if r.key == "Secret" then Color3.fromRGB(90, 80, 110) else r.color
	end
	tabColors.Mutations = C.Pink
	local select = Lib.tabs(tabHolder, TABS, 46, function(name)
		current = name
		render()
	end, tabColors)

	win.onOpen = function()
		select(current)
	end
	-- only rebuild when something the Index shows actually changed
	local lastSig = ""
	local function signature(d: any): string
		local parts = { d.aura or "" }
		for _, t in Tungs.IndexList do
			local e = d.index[t.id]
			if e then
				local n = 0
				for _ in e.m or {} do
					n += 1
				end
				table.insert(parts, t.id .. n)
			end
		end
		for k in d.indexRewards do
			table.insert(parts, k)
		end
		table.sort(parts)
		return table.concat(parts, ",")
	end
	State.On("Changed", function(full)
		local d = State.data
		if full and d and win.isOpen() then
			local sig = signature(d)
			if sig ~= lastSig then
				lastSig = sig
				render()
			end
		end
	end)
	return win
end

return IndexPanel
