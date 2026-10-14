--!strict
-- Shop: Items (bat upgrades, speed coil, traps) | Boosts (2x money, luck
-- potions; some Robux products) | Game Passes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local ShopPanel = {}

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

type CardSpec = {
	icon: string,
	name: string,
	desc: string,
	button: string,
	color: Color3,
	buttonColor: Color3,
	enabled: boolean,
	onClick: () -> (),
	order: number,
}

local function card(parent: Instance, spec: CardSpec)
	local f = Lib.card(parent, { Size = UDim2.fromOffset(210, 280), LayoutOrder = spec.order })
	local art = Lib.new("Frame", { Size = UDim2.new(1, -16, 0, 104), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f })
	Lib.corner(art, 14)
	Lib.gradient(art, spec.color, spec.color:Lerp(Color3.new(0, 0, 0), 0.45), 45)
	Lib.label({ Text = spec.icon, Size = UDim2.fromScale(0.75, 0.75), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = art })
	Lib.label({ Text = spec.name, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 118), Dark = true, Parent = f })
	Lib.label({ Text = spec.desc, Size = UDim2.new(1, -16, 0, 66), Position = UDim2.fromOffset(8, 148), Dark = true, TextColor3 = C.SubText, TextWrapped = true, Parent = f })
	Lib.button({
		Text = spec.button,
		Size = UDim2.new(1, -16, 0, 52),
		Position = UDim2.new(0, 8, 1, -60),
		Color = if spec.enabled then spec.buttonColor else C.Grey,
		Parent = f,
		OnClick = function()
			if spec.enabled then
				spec.onClick()
			end
		end,
	})
end

function ShopPanel.Build(): any
	local win = Lib.window("Shop", Vector2.new(980, 640), Color3.fromRGB(190, 255, 170), "🛒")
	local body = win.body
	local tabHolder = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = body })
	local content = Lib.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.fromOffset(0, 60),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Wood2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	})
	local current = "Items"

	local function buy(key: string)
		local ok = State.Request("BuyItem", key)
		if ok then
			Lib.sound("Purchase")
		end
	end

	local function render()
		local d = State.data
		if not d then
			return
		end
		for _, c in content:GetChildren() do
			c:Destroy()
		end
		Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(210, 280), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })
		Lib.padding(content, 6)

		if current == "Items" then
			local tier = d.items.Bat or 1
			local cur = Items.Bat(tier)
			local nextBat = Items.Bats[tier + 1]
			card(content, {
				icon = "🏏",
				name = if nextBat then nextBat.name else cur.name .. " (MAX)",
				desc = if nextBat then string.format("Reach %.1f → %.1f studs, swing every %.1fs, harder knockback.", cur.reach, nextBat.reach, nextBat.cooldown) else "You have the best bat in the game!",
				button = if nextBat then Format.Money(nextBat.price) else "OWNED",
				color = if nextBat then nextBat.color else cur.color,
				buttonColor = C.Money,
				enabled = nextBat ~= nil and d.money >= nextBat.price,
				onClick = function()
					buy("Bat")
				end,
				order = 1,
			})
			for i, g in Items.Gear do
				local owned = d.items[g.key] == true
				card(content, {
					icon = g.icon,
					name = g.name,
					desc = g.desc,
					button = if owned then "OWNED ✓" else Format.Money(g.price),
					color = C.Wood,
					buttonColor = C.Money,
					enabled = not owned and d.money >= g.price,
					onClick = function()
						buy(g.key)
					end,
					order = 1 + i,
				})
			end
		elseif current == "Boosts" then
			for i, b in Items.Boosts do
				local price = Items.BoostPrice(b, d.income or 0)
				card(content, {
					icon = b.icon,
					name = b.name,
					desc = b.desc,
					button = Format.Money(price),
					color = if b.key == "Money2x" then C.Gold else C.Green,
					buttonColor = C.Money,
					enabled = d.money >= price,
					onClick = function()
						buy(b.key)
					end,
					order = i,
				})
			end
			for i, key in { "LuckPotion", "InstantTung", "SkipRebirth" } do
				local p = Products.ByKey[key]
				card(content, {
					icon = p.icon,
					name = p.name,
					desc = p.description,
					button = if p.assetId == 0 then "Coming soon" else Lib.ROBUX .. " " .. p.price,
					color = C.Purple,
					buttonColor = C.Robux,
					enabled = p.assetId ~= 0,
					onClick = function()
						promptRobux(p)
					end,
					order = 10 + i,
				})
			end
		else
			for i, p in Products.Gamepasses do
				local owned = Economy.HasPass(d, p.key)
				card(content, {
					icon = p.icon,
					name = p.name,
					desc = p.description,
					button = if owned then "OWNED ✓" elseif p.assetId == 0 then "Coming soon" else Lib.ROBUX .. " " .. p.price,
					color = C.Gold,
					buttonColor = C.Robux,
					enabled = not owned and p.assetId ~= 0,
					onClick = function()
						promptRobux(p)
					end,
					order = i,
				})
			end
		end
	end

	local select = Lib.tabs(tabHolder, { "Items", "Boosts", "Game Passes" }, 46, function(name)
		current = name
		render()
	end, { Items = C.Wood, Boosts = C.Green, ["Game Passes"] = C.Gold })

	win.onOpen = function()
		select(current)
	end
	State.On("Changed", function(full)
		if full and win.isOpen() then
			render()
		end
	end)
	return win
end

return ShopPanel
