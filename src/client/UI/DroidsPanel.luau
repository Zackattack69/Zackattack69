--!strict
-- Droid inventory in the big-simulator style: search bar, filter chips,
-- rarity-gradient cards with a green ✓ on equipped (stationed) droids, and a
-- detail card for Equip, Fuse, Style Tokens and Recycle.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Droids = require(Shared.Config.Droids)
local Economy = require(Shared.Config.Economy)
local Names = require(Shared.Config.StarWarsNames)
local Rarities = require(Shared.Config.Rarities)
local Styles = require(Shared.Config.Styles)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local DroidsPanel = {}

local PAGE_SIZE = 15
local RARITY_FILTERS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Iconic" }
local STYLE_FILTERS = { "All", "Standard", "Gold", "Diamond", "Shadow", "Neon", "Rainbow" }
local SORTS = { "Best", "Newest", "Rarity" }

function DroidsPanel.Build(): any
	local win = Lib.window("Droids", Vector2.new(1020, 640), C.Blue, C.Blue2, "🤖")
	local body = win.body

	local filters = { rarity = 1, style = 1, sort = 1, search = "" }
	local page = 1
	local selected: string? = nil
	local confirmRecycle = false
	local rebuild: () -> ()

	-- Toolbar ------------------------------------------------------------------------------
	local toolbar = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = body })
	Lib.list(toolbar, 8, true)
	local searchBg = Lib.card(toolbar, { Size = UDim2.fromOffset(230, 46), LayoutOrder = 0 })
	Lib.label({ Text = "🔍", Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 8), Stroke = false, Parent = searchBg })
	local search = Lib.new("TextBox", {
		Size = UDim2.new(1, -46, 1, -10),
		Position = UDim2.fromOffset(40, 5),
		BackgroundTransparency = 1,
		PlaceholderText = "Search droids...",
		PlaceholderColor3 = C.SubText,
		Text = "",
		TextColor3 = C.TextDark,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = searchBg,
	})
	search:GetPropertyChangedSignal("Text"):Connect(function()
		filters.search = string.lower(search.Text)
		page = 1
		rebuild()
	end)

	local function chip(text: string, order: number, color: Color3, onClick: () -> ()): TextButton
		return Lib.button({ Text = text, Size = UDim2.fromOffset(150, 46), Color = color, Parent = toolbar, LayoutOrder = order, OnClick = onClick })
	end
	local rarityBtn = chip("All Rarities", 1, C.Purple, function()
		filters.rarity = filters.rarity % #RARITY_FILTERS + 1
		page = 1
		rebuild()
	end)
	local styleBtn = chip("All Styles", 2, C.Pink, function()
		filters.style = filters.style % #STYLE_FILTERS + 1
		page = 1
		rebuild()
	end)
	local sortBtn = chip("Sort: Best", 3, C.Blue, function()
		filters.sort = filters.sort % #SORTS + 1
		rebuild()
	end)
	Lib.button({ Text = "⚡ EQUIP BEST", Size = UDim2.fromOffset(190, 46), Color = C.Green, Color2 = C.Green2, Parent = toolbar, LayoutOrder = 4, OnClick = function()
		if State.Request("EquipBest") then
			State.Fire("Toast", "Best droids equipped!", "success")
		end
	end })

	-- Grid ----------------------------------------------------------------------------------
	local gridCard = Lib.card(body, { Size = UDim2.new(0, 600, 1, -112), Position = UDim2.fromOffset(0, 58), BackgroundColor3 = C.Inset })
	local grid = Lib.new("Frame", { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1, Parent = gridCard })
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(108, 118), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

	local footer = Lib.new("Frame", { Size = UDim2.new(0, 600, 0, 46), Position = UDim2.new(0, 0, 1, -46), BackgroundTransparency = 1, Parent = body })
	local counts = Lib.label({ Text = "", Size = UDim2.fromOffset(330, 34), Position = UDim2.new(0, 76, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left, Parent = footer })
	local pageLabel = Lib.label({ Text = "1/1", Size = UDim2.fromOffset(80, 34), Position = UDim2.new(1, -76, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = footer })
	Lib.button({ Text = "◀", Size = UDim2.fromOffset(64, 44), Color = C.Blue, Parent = footer, OnClick = function()
		page = math.max(1, page - 1)
		rebuild()
	end })
	Lib.button({ Text = "▶", Size = UDim2.fromOffset(64, 44), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Color = C.Blue, Parent = footer, OnClick = function()
		page += 1
		rebuild()
	end })

	-- Detail -------------------------------------------------------------------------------
	local detail = Lib.card(body, { Size = UDim2.new(1, -614, 1, -58), Position = UDim2.new(0, 614, 0, 58) })

	local function filtered(data: any): { { uid: string, inst: any } }
		local list = {}
		for uid, inst in data.droids do
			local d = Droids.Get(inst.id)
			if d then
				local okR = filters.rarity == 1 or d.rarity == RARITY_FILTERS[filters.rarity]
				local okS = filters.style == 1 or inst.style == STYLE_FILTERS[filters.style]
				local okQ = filters.search == "" or string.find(string.lower(d.name), filters.search, 1, true) ~= nil
				if okR and okS and okQ then
					table.insert(list, { uid = uid, inst = inst })
				end
			end
		end
		local sort = SORTS[filters.sort]
		table.sort(list, function(a, b)
			if sort == "Newest" then
				local ta, tb = tonumber(a.uid:sub(2)) or 0, tonumber(b.uid:sub(2)) or 0
				return ta > tb
			elseif sort == "Rarity" then
				local ra = Rarities.Get((Droids.Get(a.inst.id) :: any).rarity).index
				local rb = Rarities.Get((Droids.Get(b.inst.id) :: any).rarity).index
				if ra ~= rb then
					return ra > rb
				end
			end
			local sa, sb = Economy.DroidScore(a.inst), Economy.DroidScore(b.inst)
			if sa ~= sb then
				return sa > sb
			end
			return a.uid < b.uid
		end)
		return list
	end

	local function copiesOf(data: any, uid: string): number
		local target = data.droids[uid]
		local n = 0
		for _, inst in data.droids do
			if inst.id == target.id and inst.style == target.style and inst.fuse == target.fuse then
				n += 1
			end
		end
		return n
	end

	local function renderDetail()
		for _, c in detail:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local data = State.data
		local inst = selected and data.droids[selected]
		if not inst then
			Lib.label({ Text = "👈 Pick a droid!", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 0.45, 0), Dark = true, TextColor3 = C.SubText, Parent = detail })
			return
		end
		local uid = selected :: string
		local droid = Droids.Get(inst.id) :: Droids.Droid
		local rarity = Rarities.Get(droid.rarity)
		local style = Styles.Get(inst.style)

		local stage = Lib.new("Frame", { Size = UDim2.new(1, -16, 0, 170), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), Parent = detail })
		Lib.corner(stage, 14)
		Lib.gradient(stage, rarity.color:Lerp(Color3.new(1, 1, 1), 0.4), rarity.color2, 90)
		Lib.stroke(stage, C.Outline, 2.5)
		Lib.viewport(stage, droid.id, inst.style, UDim2.fromScale(1, 1), nil, true)
		local tag = Lib.label({ Text = string.upper(rarity.name), Size = UDim2.fromOffset(130, 26), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 0, BackgroundColor3 = rarity.color2, Parent = stage })
		Lib.corner(tag, 8)
		Lib.stroke(tag, C.Outline, 2)

		Lib.label({ Text = droid.name, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 184), TextColor3 = rarity.color, Parent = detail })
		local styleText = if style.name ~= "Standard" then style.badge .. " " .. style.name .. " (+" .. math.floor(style.bonus * 100) .. "%)" else "Standard style"
		local fuseText = if inst.fuse > 0 then "   " .. string.rep("★", inst.fuse) else ""
		Lib.label({ Text = styleText .. fuseText, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 218), Dark = true, TextColor3 = if style.name ~= "Standard" then style.color:Lerp(C.TextDark, 0.3) else C.SubText, Parent = detail })

		local origin = if droid.world > 0 then Worlds.Get(droid.world).name else (if droid.exclusive then "Exclusive" else "Anywhere in the galaxy")
		local here = data.world
		local incomeHere = Economy.DroidIncome(inst, here) * Economy.GlobalMultiplier(data)
		local status = if inst.station then "✅ Equipped on " .. Worlds.Get(inst.station).name else "Not equipped"
		Lib.label({
			Text = "🪐 From: " .. origin .. "\n" .. status .. "\n" .. Names.CurrencyIcon.Scrap .. " +" .. Format.Number(incomeHere) .. "/s here" .. (if droid.world == here then " (home +25%)" else ""),
			Size = UDim2.new(1, -20, 0, 66),
			Position = UDim2.fromOffset(10, 244),
			Dark = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = detail,
		})

		local actions = Lib.new("Frame", { Size = UDim2.new(1, -20, 0, 160), Position = UDim2.fromOffset(10, 316), BackgroundTransparency = 1, Parent = detail })
		Lib.new("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 46), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = actions })

		if inst.station == here then
			Lib.button({ Text = "UNEQUIP", Color = C.Grey, Color2 = C.Grey2, Size = UDim2.new(), Parent = actions, LayoutOrder = 1, OnClick = function()
				State.Request("Station", uid, nil)
			end })
		else
			Lib.button({ Text = "EQUIP", Color = C.Green, Color2 = C.Green2, Size = UDim2.new(), Parent = actions, LayoutOrder = 1, OnClick = function()
				State.Request("Station", uid, here)
			end })
		end

		local copies = copiesOf(data, uid)
		local canFuse = copies >= Economy.FUSE_COPIES and inst.fuse < Economy.MAX_FUSE
		Lib.button({
			Text = if inst.fuse >= Economy.MAX_FUSE then "MAX FUSE" else "FUSE " .. math.min(copies, Economy.FUSE_COPIES) .. "/" .. Economy.FUSE_COPIES,
			Color = if canFuse then C.Purple else C.Grey,
			Color2 = if canFuse then C.Purple2 else C.Grey2,
			Size = UDim2.new(),
			Parent = actions,
			LayoutOrder = 2,
			OnClick = function()
				if State.Request("Fuse", uid) then
					State.Fire("Toast", droid.name .. " fused to ★" .. (inst.fuse + 1) .. "!", "success")
				end
			end,
		})

		for i, tokenStyle in Styles.TokenStyles do
			local n = data.tokens[tokenStyle] or 0
			if n > 0 and inst.style ~= tokenStyle then
				local s = Styles.Get(tokenStyle)
				Lib.button({ Text = s.badge .. " " .. tokenStyle .. " x" .. n, Color = s.color, Size = UDim2.new(), Parent = actions, LayoutOrder = 2 + i, OnClick = function()
					State.Request("ApplyToken", uid, tokenStyle)
				end })
			end
		end

		local recycleBtn = Lib.button({
			Text = if confirmRecycle then "SURE? +" .. Format.Number(Economy.RecycleValue(inst) * Economy.RebirthMultiplier(data.rebirths)) else "♻ RECYCLE",
			Color = C.Red,
			Color2 = C.Red2,
			Size = UDim2.new(),
			Parent = actions,
			LayoutOrder = 20,
		})
		recycleBtn.Activated:Connect(function()
			if not confirmRecycle then
				confirmRecycle = true
				renderDetail()
				return
			end
			confirmRecycle = false
			local ok, msg = State.Request("Recycle", { uid })
			if ok then
				selected = nil
				State.Fire("Toast", msg or "Recycled", "scrap")
			end
		end)
	end

	rebuild = function()
		local data = State.data
		if not data then
			return
		end
		rarityBtn.Text = if filters.rarity == 1 then "All Rarities" else RARITY_FILTERS[filters.rarity]
		styleBtn.Text = if filters.style == 1 then "All Styles" else STYLE_FILTERS[filters.style]
		sortBtn.Text = "Sort: " .. SORTS[filters.sort]

		local total, equipped, discovered = 0, 0, 0
		for _, inst in data.droids do
			total += 1
			if inst.station then
				equipped += 1
			end
		end
		for _ in data.discovered do
			discovered += 1
		end
		counts.Text = "✅ " .. equipped .. "/" .. data.slots .. "    📖 " .. discovered .. "/" .. Droids.RosterSize
		win.header.Title.Text = "🤖  Droids  " .. total .. "/" .. Economy.MAX_INVENTORY

		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local list = filtered(data)
		local pages = math.max(1, math.ceil(#list / PAGE_SIZE))
		page = math.clamp(page, 1, pages)
		pageLabel.Text = page .. "/" .. pages

		for i = (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #list) do
			local entry = list[i]
			local inst = entry.inst
			local droid = Droids.Get(inst.id) :: Droids.Droid
			local rarity = Rarities.Get(droid.rarity)
			local style = Styles.Get(inst.style)
			local card = Lib.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, Parent = grid })
			Lib.corner(card, 14)
			Lib.gradient(card, rarity.color:Lerp(Color3.new(1, 1, 1), 0.45), rarity.color2, 90)
			Lib.stroke(card, if entry.uid == selected then Color3.new(1, 1, 1) else C.Outline, if entry.uid == selected then 4 else 3)
			Lib.viewport(card, droid.id, inst.style, UDim2.new(1, 0, 1, -24), UDim2.fromOffset(0, 2), false)
			Lib.label({ Text = droid.name, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 1, -23), Parent = card })
			if style.badge ~= "" then
				Lib.label({ Text = style.badge, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -28, 0, 3), Stroke = false, Parent = card })
			end
			if inst.station then
				local check = Lib.label({ Text = "✓", Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 0, BackgroundColor3 = C.Green2, Parent = card })
				Lib.round(check)
				Lib.stroke(check, C.Outline, 2)
			end
			if inst.fuse > 0 then
				Lib.label({ Text = string.rep("★", inst.fuse), Size = UDim2.fromOffset(70, 18), Position = UDim2.new(0, 4, 1, -42), TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			end
			local s = Lib.new("UIScale", { Parent = card })
			card.MouseEnter:Connect(function()
				Lib.tween(s, 0.1, { Scale = 1.05 }, Enum.EasingStyle.Back)
			end)
			card.MouseLeave:Connect(function()
				Lib.tween(s, 0.1, { Scale = 1 })
			end)
			card.Activated:Connect(function()
				Lib.sound("Click", 0.3)
				selected = entry.uid
				confirmRecycle = false
				rebuild()
			end)
		end
		if #list == 0 then
			Lib.label({ Text = "No droids here yet — open some crates!", Dark = true, TextColor3 = C.SubText, LayoutOrder = 1, Parent = grid })
		end
		renderDetail()
	end

	win.onOpen = rebuild
	State.On("Changed", function(full)
		if full and win.isOpen() then
			rebuild()
		end
	end)
	return win
end

return DroidsPanel
