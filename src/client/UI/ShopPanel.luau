--!strict
-- Shop (Design Doc §6.6 / §7): Featured | Gamepasses | Crates | Currency | Styles | Bundles

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local ShopPanel = {}

local RIBBON_COLORS = {
	["BEST VALUE"] = Color3.fromRGB(255, 70, 90),
	["LIMITED"] = Color3.fromRGB(170, 80, 255),
	["POPULAR"] = Color3.fromRGB(255, 160, 40),
	[Products.DealDiscountText] = Color3.fromRGB(255, 70, 90),
}

local function prompt(product: Products.Product)
	if product.assetId == 0 then
		State.Fire("Toast", product.name .. " is coming soon!", "info")
		return
	end
	local player = Players.LocalPlayer
	if product.kind == "Gamepass" then
		MarketplaceService:PromptGamePassPurchase(player, product.assetId)
	else
		MarketplaceService:PromptProductPurchase(player, product.assetId)
	end
end

local function itemCard(parent: Instance, product: Products.Product, order: number, big: boolean?, ribbonOverride: string?)
	local data = State.data
	local owned = product.kind == "Gamepass" and data and Economy.HasPass(data, product.key)
	local size = if big then UDim2.fromOffset(420, 300) else UDim2.fromOffset(200, 260)
	local card = Lib.new("Frame", { Size = size, BackgroundColor3 = C.Card, LayoutOrder = order, Parent = parent })
	Lib.corner(card, 18)
	Lib.stroke(card, Color3.fromRGB(10, 10, 16), 3)
	local art = Lib.new("Frame", { Size = UDim2.new(1, -16, 0, if big then 150 else 110), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
	Lib.corner(art, 14)
	local tabColor = if product.kind == "Gamepass" then C.Gold elseif product.tab == "Currency" then C.Scrap elseif product.tab == "Styles" then C.Nova else C.Green
	Lib.gradient(art, tabColor, tabColor:Lerp(Color3.new(0, 0, 0), 0.55), 45)
	Lib.label({ Text = product.icon, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = art })

	local ribbon = ribbonOverride or product.ribbon
	if ribbon then
		local r = Lib.label({ Text = ribbon, Size = UDim2.fromOffset(130, 26), Position = UDim2.new(1, 14, 0, 14), AnchorPoint = Vector2.new(1, 0), Rotation = 12, BackgroundTransparency = 0, BackgroundColor3 = RIBBON_COLORS[ribbon] or C.Red, ZIndex = 12, Parent = card })
		Lib.corner(r, 6)
	end

	local textTop = if big then 164 else 124
	Lib.label({ Text = product.name, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, textTop), Parent = card })
	Lib.label({ Text = product.description, Size = UDim2.new(1, -16, 0, if big then 54 else 52), Position = UDim2.fromOffset(8, textTop + 28), TextColor3 = C.SubText, TextWrapped = true, TextScaled = true, Font = Lib.FontBody, Stroke = false, Parent = card })

	Lib.button({
		Text = if owned then "OWNED ✓" elseif product.assetId == 0 then "COMING SOON" else Lib.ROBUX .. " " .. Format.Commas(product.price),
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.new(0, 8, 1, -52),
		Color = if owned or product.assetId == 0 then C.Grey else C.Robux,
		Parent = card,
		OnClick = function()
			if not owned then
				prompt(product)
			end
		end,
	})
	card.ClipsDescendants = true
end

function ShopPanel.Build(): any
	local win = Lib.window("Shop", Vector2.new(980, 620), C.Robux, Color3.fromRGB(20, 130, 70))
	local body = win.body
	local content = Lib.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.fromOffset(0, 56),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	})
	local current = "Featured"
	local countdownLabel: TextLabel? = nil

	local function render()
		for _, c in content:GetChildren() do
			c:Destroy()
		end
		countdownLabel = nil
		Lib.padding(content, 6)
		local grid = Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(200, 260), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })

		if current == "Featured" then
			grid:Destroy()
			Lib.list(content, 12, true)
			local deal, _ = Products.DealOfTheDay(os.time())
			local col = Lib.new("Frame", { Size = UDim2.fromOffset(420, 360), BackgroundTransparency = 1, LayoutOrder = 1, Parent = content })
			Lib.label({ Text = "⏰ DEAL OF THE DAY", Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.Gold, Parent = col })
			countdownLabel = Lib.label({ Text = "", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 30), TextColor3 = C.SubText, Parent = col })
			local holder = Lib.new("Frame", { Size = UDim2.fromOffset(420, 300), Position = UDim2.fromOffset(0, 58), BackgroundTransparency = 1, Parent = col })
			itemCard(holder, deal, 1, true, Products.DealDiscountText)
			local picks = Lib.new("Frame", { Size = UDim2.fromOffset(420, 540), BackgroundTransparency = 1, LayoutOrder = 2, Parent = content })
			Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(200, 260), CellPadding = UDim2.fromOffset(12, 12), Parent = picks })
			for i, key in { "StarterPack", "VIP", "DoubleLuck", "GenesisVault" } do
				itemCard(picks, Products.ByKey[key], i)
			end
		else
			for i, p in Products.List do
				if p.tab == current then
					itemCard(content, p, i)
				end
			end
		end
	end

	local select = Lib.tabs(body, Products.Tabs, 46, function(name)
		current = name
		render()
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if countdownLabel and countdownLabel.Parent then
				local _, left = Products.DealOfTheDay(os.time())
				countdownLabel.Text = "Ends in " .. Format.Time(left)
			end
		end
	end)

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
