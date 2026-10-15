--!strict
-- Shop: one long scrolling page in sections, with big icon tabs down the right
-- that jump to each section (like the big simulator shops):
--   EGGS     Robux eggs; each shows every Tung inside with its chance, and
--            1 / 3 / 10 egg bundles
--   PASSES   wide colourful game-pass cards
--   BOOSTS   Robux potions, Instant Tung, Base Shield, Skip Rebirth
--   MONEY    cash packs; the amounts grow with how much money you have
--   ITEMS    things you buy with in-game cash (bat upgrades, gear, boosts)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Eggs = require(Shared.Config.Eggs)
local Items = require(Shared.Config.Items)
local Products = require(Shared.Config.Products)
local Rarities = require(Shared.Config.Rarities)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Hatch = require(script.Parent.Hatch)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local ShopPanel = {}

local SECTIONS = {
	{ name = "Eggs", icon = "🥚", color = Color3.fromRGB(255, 90, 210) },
	{ name = "Passes", icon = "🎟️", color = Color3.fromRGB(255, 210, 50) },
	{ name = "Boosts", icon = "⚡", color = Color3.fromRGB(80, 220, 255) },
	{ name = "Money", icon = "💵", color = Color3.fromRGB(110, 240, 90) },
	{ name = "Items", icon = "🏏", color = Color3.fromRGB(255, 170, 60) },
}

-- Colours for each game pass card.
local PASS_LOOK: { [string]: { Color3 } } = {
	DoubleMoney = { Color3.fromRGB(255, 232, 90), Color3.fromRGB(232, 160, 20) },
	VIP = { Color3.fromRGB(200, 120, 255), Color3.fromRGB(110, 40, 210) },
	CollectAll = { Color3.fromRGB(120, 240, 120), Color3.fromRGB(30, 160, 70) },
	AutoLock = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(40, 90, 220) },
	LuckyBelt = { Color3.fromRGB(150, 250, 140), Color3.fromRGB(40, 170, 110) },
	LockMaster = { Color3.fromRGB(110, 240, 240), Color3.fromRGB(20, 140, 180) },
	RainbowTrail = { Color3.fromRGB(255, 140, 200), Color3.fromRGB(120, 120, 255) },
	DiamondBase = { Color3.fromRGB(210, 245, 255), Color3.fromRGB(90, 180, 240) },
}

local function promptRobux(product: Products.Product)
	if product.assetId == 0 then
		State.Fire("Toast", product.name .. " is coming soon!", "info")
		return
	end
	if product.kind == "Gamepass" then
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, product.assetId)
	else
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.assetId)
	end
end

-- Green price button. Returns the button so callers can change its text later.
local function priceButton(parent: Instance, text: string, size: UDim2, position: UDim2, onClick: () -> (), color: Color3?): TextButton
	return Lib.button({
		Text = text,
		Size = size,
		Position = position,
		Color = color or C.Money,
		Color2 = if color then nil else C.Money2,
		Font = Lib.FontTitle,
		Parent = parent,
		OnClick = onClick,
	})
end

local function robuxText(p: Products.Product): string
	return Lib.ROBUX .. " " .. p.price
end

-- Big icon with light rays behind it.
local function art(parent: Instance, icon: string, size: UDim2, position: UDim2, rays: boolean?)
	local holder = Lib.new("Frame", { Size = size, Position = position, AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = parent })
	if rays ~= false then
		local r = Lib.rays(holder, WHITE, 220, 10, holder.ZIndex)
		r.BackgroundTransparency = 1
	end
	Lib.label({ Text = icon, Size = UDim2.fromScale(1, 1), Stroke = false, Parent = holder })
	return holder
end

function ShopPanel.Build(): any
	local win = Lib.window("Shop", Vector2.new(1000, 640), C.Green, nil)
	local body = win.body
	local content = Lib.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(150, 150, 170),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	})
	Lib.list(content, 10, false, Enum.HorizontalAlignment.Center)
	Lib.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 16), PaddingRight = UDim.new(0, 10), Parent = content })

	local headers: { [string]: GuiObject } = {}
	local refreshers: { () -> () } = {}
	local built = false

	local function section(order: number, name: string, color: Color3): Frame
		headers[name] = Lib.section(content, name, color, order * 10)
		local holder = Lib.new("Frame", { Name = name, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order * 10 + 1, Parent = content })
		return holder
	end

	local function grid(parent: Instance, cell: Vector2, order: number): Frame
		local g = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
		Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = g })
		return g
	end

	-- EGGS ------------------------------------------------------------------------------------------------
	local function buildEggs(order: number)
		local holder = section(order, "Eggs", SECTIONS[1].color)
		Lib.list(holder, 12, false, Enum.HorizontalAlignment.Center)
		local player = Players.LocalPlayer
		for k, egg in Eggs.List do
			local card = Lib.shopCard(holder, UDim2.new(1, -4, 0, 300), egg.color:Lerp(WHITE, 0.15), egg.color2:Lerp(BLACK, 0.25), k)
			local title = Lib.label({ Text = string.upper(egg.name), Font = Lib.FontTitle, Size = UDim2.fromOffset(460, 48), Position = UDim2.fromOffset(16, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			Lib.gradient(title, Color3.fromRGB(255, 250, 190), Color3.fromRGB(255, 200, 40), 90)
			local ts = title:FindFirstChildOfClass("UIStroke")
			if ts then
				ts.Thickness = 3.5
			end
			Lib.label({ Text = egg.desc, Size = UDim2.fromOffset(460, 24), Position = UDim2.fromOffset(18, 54), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local eggArt = Lib.new("Frame", { Size = UDim2.fromOffset(140, 160), Position = UDim2.fromOffset(14, 78), BackgroundTransparency = 1, Parent = card })
			Lib.rays(eggArt, WHITE, 230, 10, eggArt.ZIndex)
			Hatch.EggShape(eggArt, egg, 140)

			-- every Tung inside, with its exact chance (shown before buying)
			local tiles = Lib.new("Frame", { Size = UDim2.new(1, -178, 0, 150), Position = UDim2.fromOffset(166, 80), BackgroundTransparency = 1, Parent = card })
			Lib.list(tiles, 8, true)
			for n, c in egg.contents do
				local t = Tungs.Get(c.tung)
				if not t then
					continue
				end
				local tile = Lib.new("Frame", { Size = UDim2.fromOffset(86, 142), BackgroundColor3 = Color3.fromRGB(20, 18, 30), BackgroundTransparency = 0.35, LayoutOrder = n, Parent = tiles })
				Lib.corner(tile, 8)
				Lib.stroke(tile, Tungs.Color(t), 3)
				Lib.tungViewport(tile, t.id, nil, UDim2.new(1, -6, 0, 88), UDim2.fromOffset(3, 2), false)
				Lib.label({ Text = t.name, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 90), TextWrapped = true, Parent = tile })
				local pct = Lib.label({ Text = (if c.chance < 1 then tostring(c.chance) else tostring(math.floor(c.chance * 10 + 0.5) / 10)) .. "%", Font = Lib.FontTitle, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 116), TextXAlignment = Enum.TextXAlignment.Right, Parent = tile })
				if Rarities.Order(t.rarity) >= Rarities.Order("Legendary") then
					pct.TextColor3 = Color3.fromRGB(255, 230, 90)
				end
			end
			local muts = egg.mutations
			if muts then
				local parts = {}
				for _, m in muts do
					table.insert(parts, m.key .. " " .. m.chance .. "%")
				end
				Lib.label({ Text = "Mutation: " .. table.concat(parts, " · "), Size = UDim2.new(1, -190, 0, 20), Position = UDim2.fromOffset(170, 56), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 240, 170), Parent = card })
			end

			-- 1 / 3 / 10 egg buttons
			local row = Lib.new("Frame", { Size = UDim2.new(1, -32, 0, 56), Position = UDim2.new(0, 16, 1, -62), BackgroundTransparency = 1, Parent = card })
			Lib.list(row, 14, true, Enum.HorizontalAlignment.Right)
			local blocked = player:GetAttribute("NoPaidRandom") == true
			if blocked then
				Lib.label({ Text = "Eggs aren't available in your country", Size = UDim2.fromOffset(520, 40), Parent = row })
			else
				for n = #egg.bundles, 1, -1 do
					local b = egg.bundles[n]
					local p = Products.ByKey[b.product]
					local cell = Lib.new("Frame", { Size = UDim2.fromOffset(196, 56), BackgroundTransparency = 1, LayoutOrder = n, Parent = row })
					local admin = player:GetAttribute("IsAdmin") == true
					local text = if p.assetId ~= 0 then robuxText(p) elseif admin then "Test x" .. b.count else "Soon"
					priceButton(cell, text, UDim2.new(1, 0, 0, 40), UDim2.new(), function()
						if p.assetId ~= 0 then
							promptRobux(p)
						elseif admin then
							State.Request("AdminEgg", egg.key, b.count)
						else
							State.Fire("Toast", p.name .. " is coming soon!", "info")
						end
					end, if p.assetId == 0 and not admin then C.Grey else nil)
					Lib.label({ Text = b.count .. (if b.count == 1 then " Egg" else " Eggs"), Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 40), Parent = cell })
					if b.count == 10 then
						Lib.ribbon(cell, "BEST VALUE!")
					end
				end
			end
		end
	end

	-- PASSES --------------------------------------------------------------------------------------------
	local function buildPasses(order: number)
		local holder = section(order, "Passes", SECTIONS[2].color)
		local g = grid(holder, Vector2.new(452, 170), 1)
		for k, p in Products.Gamepasses do
			local look = PASS_LOOK[p.key] or { C.Gold, C.Gold2 }
			local card = Lib.shopCard(g, UDim2.fromOffset(452, 170), look[1], look[2], k)
			if p.key == "RainbowTrail" then
				local grad = card:FindFirstChildOfClass("UIGradient")
				if grad then
					grad.Color = Rarities.RAINBOW
					grad.Rotation = 20
				end
			end
			art(card, p.icon, UDim2.fromOffset(120, 120), UDim2.new(0, 76, 0, 16))
			Lib.label({ Text = p.name, Font = Lib.FontTitle, Size = UDim2.new(1, -160, 0, 38), Position = UDim2.fromOffset(150, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			Lib.label({ Text = p.description, Size = UDim2.new(1, -164, 0, 62), Position = UDim2.fromOffset(150, 46), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = card })
			local btn = priceButton(card, robuxText(p), UDim2.new(1, -164, 0, 46), UDim2.new(0, 150, 1, -56), function()
				if not Economy.HasPass(State.data or {}, p.key) then
					promptRobux(p)
				end
			end)
			table.insert(refreshers, function()
				local d = State.data
				local owned = d ~= nil and Economy.HasPass(d, p.key)
				btn.Text = if owned then "OWNED ✓" elseif p.assetId == 0 then "Coming soon" else robuxText(p)
				if owned then
					Lib.recolor(btn, C.Grey, C.Grey2)
				end
			end)
		end
	end

	-- BOOSTS (Robux) ------------------------------------------------------------------------------------
	local function buildBoosts(order: number)
		local holder = section(order, "Boosts", SECTIONS[3].color)
		local g = grid(holder, Vector2.new(296, 236), 1)
		for k, key in { "LuckPotion", "InstantTung", "BaseShield", "SkipRebirth" } do
			local p = Products.ByKey[key]
			local card = Lib.shopCard(g, UDim2.fromOffset(296, 236), Color3.fromRGB(190, 110, 255), Color3.fromRGB(90, 40, 200), k)
			art(card, p.icon, UDim2.fromOffset(96, 86), UDim2.new(0.5, 0, 0, 8))
			Lib.label({ Text = p.name, Font = Lib.FontTitle, Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 96), Parent = card })
			Lib.label({ Text = p.description, Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 128), TextWrapped = true, Parent = card })
			priceButton(card, if p.assetId == 0 then "Coming soon" else robuxText(p), UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 1, -52), function()
				promptRobux(p)
			end)
		end
	end

	-- MONEY (Robux cash packs, scaled to your money) -----------------------------------------------------------
	local function buildMoney(order: number)
		local holder = section(order, "Money", SECTIONS[4].color)
		Lib.list(holder, 12, false, Enum.HorizontalAlignment.Center)
		local top = grid(holder, Vector2.new(296, 210), 1)
		local bottom = grid(holder, Vector2.new(452, 210), 2)
		local icons = { "💵", "💵💵", "💰💵", "💰💰", "🏦" }
		for pack = 1, 5 do
			local p = Products.ByKey["Cash" .. pack]
			local parent = if pack <= 3 then top else bottom
			local w = if pack <= 3 then 296 else 452
			local card = Lib.shopCard(parent, UDim2.fromOffset(w, 210), Color3.fromRGB(130, 240, 100), Color3.fromRGB(30, 160, 60), pack)
			art(card, icons[pack], UDim2.fromOffset(150, 96), UDim2.new(0.5, 0, 0, 10))
			local amount = Lib.label({ Text = "$0", Font = Lib.FontTitle, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 104), Parent = card })
			priceButton(card, if p.assetId == 0 then "Coming soon" else robuxText(p), UDim2.new(1, -20, 0, 48), UDim2.new(0, 10, 1, -56), function()
				promptRobux(p)
			end)
			if pack == 5 then
				Lib.ribbon(card, "BEST VALUE!")
			end
			table.insert(refreshers, function()
				local d = State.data
				if d then
					amount.Text = Format.Money(Economy.CashPackAmount(pack, d.money or 0, d.income or 0))
				end
			end)
		end
		Lib.label({ Text = "Cash packs grow with how much money you have!", Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 3, TextColor3 = C.SubText, Parent = holder })
	end

	-- ITEMS (in-game cash) ------------------------------------------------------------------------------
	local itemsGrid: Frame
	local function buy(key: string)
		local ok = State.Request("BuyItem", key)
		if ok then
			Lib.sound("Purchase")
		end
	end
	local function itemCard(order: number, icon: string, name: string, desc: string, button: string, enabled: boolean, onClick: () -> ())
		local card = Lib.shopCard(itemsGrid, UDim2.fromOffset(220, 262), Color3.fromRGB(255, 190, 90), Color3.fromRGB(210, 100, 30), order)
		art(card, icon, UDim2.fromOffset(90, 80), UDim2.new(0.5, 0, 0, 8))
		Lib.label({ Text = name, Font = Lib.FontTitle, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 90), Parent = card })
		Lib.label({ Text = desc, Size = UDim2.new(1, -16, 0, 70), Position = UDim2.fromOffset(8, 122), TextWrapped = true, Parent = card })
		priceButton(card, button, UDim2.new(1, -16, 0, 44), UDim2.new(0, 8, 1, -52), function()
			if enabled then
				onClick()
			end
		end, if enabled then nil else C.Grey)
	end
	local function renderItems()
		local d = State.data
		if not d or not itemsGrid then
			return
		end
		for _, c in itemsGrid:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local tier = d.items.Bat or 1
		local cur = Items.Bat(tier)
		local nextBat = Items.Bats[tier + 1]
		itemCard(1, "🏏", if nextBat then nextBat.name else cur.name .. " (MAX)", if nextBat then string.format("Reach %.1f → %.1f studs, swing every %.1fs, harder knockback.", cur.reach, nextBat.reach, nextBat.cooldown) else "You have the best bat in the game!", if nextBat then Format.Money(nextBat.price) else "OWNED", nextBat ~= nil and d.money >= nextBat.price, function()
			buy("Bat")
		end)
		for i, g in Items.Gear do
			local owned = d.items[g.key] == true
			itemCard(1 + i, g.icon, g.name, g.desc, if owned then "OWNED ✓" else Format.Money(g.price), not owned and d.money >= g.price, function()
				buy(g.key)
			end)
		end
		for i, b in Items.Boosts do
			local price = Items.BoostPrice(b, d.income or 0)
			itemCard(20 + i, b.icon, b.name, b.desc, Format.Money(price), d.money >= price, function()
				buy(b.key)
			end)
		end
	end
	local function buildItems(order: number)
		local holder = section(order, "Items", SECTIONS[5].color)
		itemsGrid = grid(holder, Vector2.new(220, 262), 1)
		renderItems()
	end

	local function refresh()
		for _, fn in refreshers do
			fn()
		end
	end

	local function build()
		if built then
			return
		end
		built = true
		buildEggs(1)
		buildPasses(2)
		buildBoosts(3)
		buildMoney(4)
		buildItems(5)
		refresh()
	end

	-- right-side icon tabs jump to a section
	local select = win.sideNav(SECTIONS, function(name)
		local h = headers[name]
		if not h then
			return
		end
		-- screen pixels -> canvas pixels (the window is scaled to fit the screen; the body is 968 wide by design)
		local scale = body.AbsoluteSize.X / 968
		local y = (h.AbsolutePosition.Y - content.AbsolutePosition.Y) / math.max(0.1, scale) + content.CanvasPosition.Y
		Lib.tween(content, 0.35, { CanvasPosition = Vector2.new(0, math.max(0, y - 4)) })
	end)

	win.onOpen = function()
		build()
		refresh()
		renderItems()
		task.defer(select, "Eggs")
	end
	State.On("Changed", function(full)
		if win.isOpen() then
			refresh()
			if full then
				renderItems()
			end
		end
	end)
	-- money-based amounts tick along while the shop is open
	task.spawn(function()
		while true do
			task.wait(1)
			if win.isOpen() and built then
				refresh()
			end
		end
	end)
	return win
end

return ShopPanel
