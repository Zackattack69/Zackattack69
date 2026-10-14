--!strict
-- Droid inventory (Design Doc §6.4): grid filterable by Rarity / Style / Map /
-- Newest, with a detail panel for Station, Fuse, Style Tokens and Recycle.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Droids = require(Shared.Config.Droids)
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local Styles = require(Shared.Config.Styles)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local DroidsPanel = {}

local PAGE_SIZE = 20
local RARITY_FILTERS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local STYLE_FILTERS = { "All", "Standard", "Gold", "Diamond", "Shadow", "Neon", "Rainbow" }
local SORTS = { "Best", "Newest", "Rarity" }

function DroidsPanel.Build(): any
	local win = Lib.window("Droids", Vector2.new(980, 600), C.Scrap, C.Scrap2)
	local body = win.body

	local filters = { rarity = 1, style = 1, world = 0, sort = 1 }
	local page = 1
	local selected: string? = nil
	local confirmRecycle = false

	-- Toolbar ------------------------------------------------------------------------------
	local toolbar = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = body })
	Lib.list(toolbar, 6, true)
	local rarityBtn, styleBtn, worldBtn, sortBtn
	local rebuild: () -> ()

	local function cycleButton(text: string, order: number, onClick: () -> ()): TextButton
		return Lib.button({ Text = text, Size = UDim2.fromOffset(130, 40), Color = C.Card, Parent = toolbar, LayoutOrder = order, OnClick = onClick })
	end
	rarityBtn = cycleButton("Rarity: All", 1, function()
		filters.rarity = filters.rarity % #RARITY_FILTERS + 1
		page = 1
		rebuild()
	end)
	styleBtn = cycleButton("Style: All", 2, function()
		filters.style = filters.style % #STYLE_FILTERS + 1
		page = 1
		rebuild()
	end)
	worldBtn = cycleButton("Map: All", 3, function()
		filters.world = (filters.world + 1) % (Worlds.Count + 1)
		page = 1
		rebuild()
	end)
	sortBtn = cycleButton("Sort: Best", 4, function()
		filters.sort = filters.sort % #SORTS + 1
		rebuild()
	end)
	Lib.button({ Text = "⚡ EQUIP BEST", Size = UDim2.fromOffset(150, 40), Color = C.Green, Color2 = C.Green2, Parent = toolbar, LayoutOrder = 5, OnClick = function()
		if State.Request("EquipBest") then
			State.Fire("Toast", "Best droids stationed!", "success")
		end
	end })
	local counts = Lib.label({ Text = "", Size = UDim2.fromOffset(200, 40), TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = 6, Parent = toolbar })

	-- Grid ----------------------------------------------------------------------------------
	local grid = Lib.new("Frame", { Size = UDim2.new(0, 560, 1, -100), Position = UDim2.fromOffset(0, 50), BackgroundColor3 = C.Panel2, Parent = body })
	Lib.corner(grid, 14)
	Lib.padding(grid, 8)
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 112), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

	local pager = Lib.new("Frame", { Size = UDim2.new(0, 560, 0, 40), Position = UDim2.new(0, 0, 1, -42), BackgroundTransparency = 1, Parent = body })
	local pageLabel = Lib.label({ Text = "1/1", Size = UDim2.fromOffset(160, 36), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), Parent = pager })
	Lib.button({ Text = "◀", Size = UDim2.fromOffset(60, 38), Color = C.Card, Parent = pager, OnClick = function()
		page = math.max(1, page - 1)
		rebuild()
	end })
	Lib.button({ Text = "▶", Size = UDim2.fromOffset(60, 38), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Color = C.Card, Parent = pager, OnClick = function()
		page += 1
		rebuild()
	end })

	-- Detail -------------------------------------------------------------------------------
	local detail = Lib.new("Frame", { Size = UDim2.new(1, -572, 1, -50), Position = UDim2.new(0, 572, 0, 50), BackgroundColor3 = C.Card, Parent = body })
	Lib.corner(detail, 16)

	local function filtered(data: any): { { uid: string, inst: any } }
		local list = {}
		for uid, inst in data.droids do
			local d = Droids.Get(inst.id)
			if d then
				local okR = filters.rarity == 1 or d.rarity == RARITY_FILTERS[filters.rarity]
				local okS = filters.style == 1 or inst.style == STYLE_FILTERS[filters.style]
				local okW = filters.world == 0 or d.world == filters.world
				if okR and okS and okW then
					table.insert(list, { uid = uid, inst = inst })
				end
			end
		end
		local sort = SORTS[filters.sort]
		table.sort(list, function(a, b)
			if sort == "Newest" then
				if a.inst.t ~= b.inst.t then
					return (a.inst.t or 0) > (b.inst.t or 0)
				end
				return tonumber(a.uid:sub(2)) > tonumber(b.uid:sub(2))
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
		detail:ClearAllChildren()
		Lib.corner(detail, 16)
		local data = State.data
		local inst = selected and data.droids[selected]
		if not inst then
			Lib.label({ Text = "Select a droid", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.45), TextColor3 = C.SubText, Parent = detail })
			return
		end
		local uid = selected :: string
		local droid = Droids.Get(inst.id) :: Droids.Droid
		local rarity = Rarities.Get(droid.rarity)
		local style = Styles.Get(inst.style)
		Lib.stroke(detail, rarity.color, 3)

		Lib.viewport(detail, droid.id, inst.style, UDim2.new(1, 0, 0, 170), UDim2.fromOffset(0, 4), true)
		Lib.label({ Text = droid.name, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 176), TextColor3 = rarity.color, Parent = detail })
		local styleText = if style.name ~= "Standard" then style.badge .. " " .. style.name .. " " else ""
		local fuseText = if inst.fuse > 0 then "  " .. string.rep("★", inst.fuse) else ""
		Lib.label({ Text = styleText .. rarity.name .. fuseText, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 208), TextColor3 = if style.name ~= "Standard" then style.color else C.SubText, Parent = detail })

		local origin = if droid.world > 0 then Worlds.Get(droid.world).name else (if droid.exclusive then "Exclusive" else "Anywhere")
		local here = data.world
		local incomeHere = Economy.DroidIncome(inst, here) * Economy.GlobalMultiplier(data)
		local status = if inst.station then "📍 Stationed: " .. Worlds.Get(inst.station).name else "Not stationed"
		Lib.label({
			Text = "Origin: " .. origin .. "\n" .. status .. "\nIn " .. Worlds.Get(here).name .. ": +" .. Format.Number(incomeHere) .. "/s" .. (if droid.world == here then " (home +25%)" else ""),
			Size = UDim2.new(1, -20, 0, 66),
			Position = UDim2.fromOffset(10, 232),
			TextColor3 = C.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = detail,
		})

		local actions = Lib.new("Frame", { Size = UDim2.new(1, -20, 0, 200), Position = UDim2.fromOffset(10, 304), BackgroundTransparency = 1, Parent = detail })
		Lib.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = actions })

		if inst.station == here then
			Lib.button({ Text = "UNSTATION", Color = C.Grey, Size = UDim2.new(), Parent = actions, LayoutOrder = 1, OnClick = function()
				State.Request("Station", uid, nil)
			end })
		else
			Lib.button({ Text = "STATION HERE", Color = C.Green, Color2 = C.Green2, Size = UDim2.new(), Parent = actions, LayoutOrder = 1, OnClick = function()
				State.Request("Station", uid, here)
			end })
		end

		local copies = copiesOf(data, uid)
		Lib.button({
			Text = if inst.fuse >= Economy.MAX_FUSE then "MAX FUSE" else "FUSE " .. math.min(copies, Economy.FUSE_COPIES) .. "/" .. Economy.FUSE_COPIES,
			Color = if copies >= Economy.FUSE_COPIES and inst.fuse < Economy.MAX_FUSE then C.Nova else C.Grey,
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
				Lib.button({ Text = s.badge .. " " .. tokenStyle .. " (" .. n .. ")", Color = s.color, Size = UDim2.new(), Parent = actions, LayoutOrder = 2 + i, OnClick = function()
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
		rarityBtn.Text = "Rarity: " .. RARITY_FILTERS[filters.rarity]
		styleBtn.Text = "Style: " .. STYLE_FILTERS[filters.style]
		worldBtn.Text = if filters.world == 0 then "Map: All" else "Map: " .. Worlds.Get(filters.world).name
		sortBtn.Text = "Sort: " .. SORTS[filters.sort]

		local total, stationed, discovered = 0, 0, 0
		for _, inst in data.droids do
			total += 1
			if inst.station then
				stationed += 1
			end
		end
		for _ in data.discovered do
			discovered += 1
		end
		counts.Text = "📍 " .. stationed .. "/" .. data.slots .. "   📖 " .. discovered .. "/" .. Droids.RosterSize
		win.header.Title.Text = "Droids (" .. total .. "/" .. Economy.MAX_INVENTORY .. ")"

		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local list = filtered(data)
		local pages = math.max(1, math.ceil(#list / PAGE_SIZE))
		page = math.clamp(page, 1, pages)
		pageLabel.Text = page .. " / " .. pages

		for i = (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #list) do
			local entry = list[i]
			local inst = entry.inst
			local droid = Droids.Get(inst.id) :: Droids.Droid
			local rarity = Rarities.Get(droid.rarity)
			local style = Styles.Get(inst.style)
			local card = Lib.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.Card, LayoutOrder = i, Parent = grid })
			Lib.corner(card, 12)
			Lib.gradient(card, C.Card, rarity.color2:Lerp(C.Card, 0.55), 90)
			local st = Lib.stroke(card, rarity.color, if entry.uid == selected then 4 else 2)
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			Lib.viewport(card, droid.id, inst.style, UDim2.new(1, 0, 1, -22), UDim2.fromOffset(0, 2), false)
			Lib.label({ Text = droid.name, Size = UDim2.new(1, -6, 0, 18), Position = UDim2.new(0, 3, 1, -20), Parent = card })
			if style.badge ~= "" then
				Lib.label({ Text = style.badge, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -26, 0, 2), Stroke = false, Parent = card })
			end
			if inst.station then
				Lib.label({ Text = "📍" .. inst.station, Size = UDim2.fromOffset(34, 20), Position = UDim2.fromOffset(3, 3), Parent = card })
			end
			if inst.fuse > 0 then
				Lib.label({ Text = string.rep("★", inst.fuse), Size = UDim2.fromOffset(60, 16), Position = UDim2.new(0, 3, 1, -38), TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			end
			card.Activated:Connect(function()
				Lib.sound("Click", 0.3)
				selected = entry.uid
				confirmRecycle = false
				rebuild()
			end)
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
