--!strict
-- Main HUD (Design Doc §6.1).

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crates = require(Shared.Config.Crates)
local Economy = require(Shared.Config.Economy)
local Quests = require(Shared.Config.Quests)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local HUD = {}
HUD.refs = {} :: { [string]: GuiObject }

local C = Lib.Colors

local function counter(parent: Instance, icon: string, c1: Color3, c2: Color3, height: number, order: number): (TextLabel, TextLabel?)
	local f = Lib.new("Frame", { Size = UDim2.fromOffset(250, height), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = parent })
	Lib.corner(f, height // 2)
	Lib.gradient(f, c1, c2, 90)
	Lib.stroke(f, c2:Lerp(Color3.new(0, 0, 0), 0.5), 3)
	local iconBg = Lib.new("Frame", { Size = UDim2.fromOffset(height + 8, height + 8), Position = UDim2.new(0, -10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = f })
	Lib.round(iconBg)
	Lib.gradient(iconBg, c1:Lerp(Color3.new(1, 1, 1), 0.4), c1, 90)
	Lib.stroke(iconBg, c2:Lerp(Color3.new(0, 0, 0), 0.5), 3)
	Lib.label({ Text = icon, Size = UDim2.fromScale(0.75, 0.75), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = iconBg })
	local amount = Lib.label({ Name = "Amount", Text = "0", Size = UDim2.new(1, -height - 14, 0.62, 0), Position = UDim2.new(0, height + 6, 0.06, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	local sub = nil
	if height > 50 then
		sub = Lib.label({ Name = "Sub", Text = "+0/s", Size = UDim2.new(1, -height - 14, 0.3, 0), Position = UDim2.new(0, height + 6, 0.64, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(220, 240, 255), Parent = f })
	else
		amount.Size = UDim2.new(1, -height - 14, 0.75, 0)
		amount.Position = UDim2.new(0, height + 6, 0.12, 0)
	end
	return amount, sub
end

local function punch(obj: GuiObject)
	local s = obj:FindFirstChild("Punch") :: UIScale? or Lib.new("UIScale", { Name = "Punch", Parent = obj })
	s.Scale = 1.12
	Lib.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

function HUD.Build(gui: ScreenGui, panels: any)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	-- Top-left currency stack ------------------------------------------------------------
	local topLeft = Lib.new("Frame", { Name = "TopLeft", Size = UDim2.fromOffset(260, 200), Position = UDim2.fromOffset(24, 64), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(topLeft)
	Lib.list(topLeft, 10)
	local scrapAmount, scrapSub = counter(topLeft, "🔩", C.Scrap, C.Scrap2, 60, 1)
	local novaAmount = counter(topLeft, "💠", C.Nova, C.Nova2, 44, 2)
	HUD.refs.scrap = scrapAmount.Parent :: GuiObject
	local robux = Lib.button({ Text = Lib.ROBUX .. " SHOP", Size = UDim2.fromOffset(150, 42), Color = C.Robux, Parent = topLeft, LayoutOrder = 3, OnClick = panels.Shop.toggle })
	HUD.refs.shop = robux

	-- Top-right: settings, notifications, map ---------------------------------------------
	local topRight = Lib.new("Frame", { Name = "TopRight", Size = UDim2.fromOffset(230, 70), Position = UDim2.new(1, -16, 0, 64), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(topRight)
	Lib.list(topRight, 10, true, Enum.HorizontalAlignment.Right)
	Lib.iconButton({ Icon = "⚙️", Size = 66, Parent = topRight, LayoutOrder = 1, OnClick = panels.Settings.toggle })
	local bell = Lib.iconButton({ Icon = "🔔", Size = 66, Parent = topRight, LayoutOrder = 2, OnClick = panels.Notifications.toggle })
	local bellBadge = Lib.badge(bell)
	local map = Lib.iconButton({ Icon = "🗺️", Label = "MAP", Size = 66, Color = C.Nova, Parent = topRight, LayoutOrder = 3, OnClick = panels.Map.toggle })
	HUD.refs.map = map

	-- Bottom-left: Inventory, Droids, Quests, Leaderboard ------------------------------------
	local bottomLeft = Lib.new("Frame", { Name = "BottomLeft", Size = UDim2.fromOffset(360, 84), Position = UDim2.new(0, 16, 1, -16), AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(bottomLeft)
	Lib.list(bottomLeft, 8, true)
	Lib.iconButton({ Icon = "🎒", Label = "ITEMS", Size = 80, Parent = bottomLeft, LayoutOrder = 1, OnClick = panels.Inventory.toggle })
	local droidsBtn = Lib.iconButton({ Icon = "🔧", Label = "DROIDS", Size = 80, Color = C.Scrap, Parent = bottomLeft, LayoutOrder = 2, OnClick = panels.Droids.toggle })
	local quests = Lib.iconButton({ Icon = "📜", Label = "BOUNTY", Size = 80, Parent = bottomLeft, LayoutOrder = 3, OnClick = panels.Quests.toggle })
	local questBadge = Lib.badge(quests)
	Lib.iconButton({ Icon = "🏆", Label = "TOP", Size = 80, Parent = bottomLeft, LayoutOrder = 4, OnClick = panels.Leaderboard.toggle })
	HUD.refs.droids = droidsBtn

	-- Bottom-center: SALVAGE + OPEN CRATE --------------------------------------------------
	local center = Lib.new("Frame", { Name = "BottomCenter", Size = UDim2.fromOffset(380, 120), Position = UDim2.new(0.5, 0, 1, if touch then -110 else -16), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(center)
	local salvage = Lib.button({ Text = "⚙️\nSALVAGE", Size = UDim2.fromOffset(92, 92), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = C.Gold, Color2 = C.Gold2, Radius = 46, Parent = center })
	local crateBtn = Lib.button({ Text = "📦 OPEN CRATE", Size = UDim2.fromOffset(270, 80), Position = UDim2.new(1, 0, 1, -6), AnchorPoint = Vector2.new(1, 1), Color = C.Scrap, Color2 = C.Scrap2, Parent = center, OnClick = panels.Crates.toggle })
	local glow = Lib.new("UIStroke", { Name = "Glow", Thickness = 0, Color = C.Scrap, Transparency = 0.2, Parent = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = crateBtn }) })
	Lib.corner(glow.Parent :: Instance, 14)
	local crateBadge = Lib.badge(crateBtn)
	HUD.refs.crate = crateBtn
	local autoLabel = Lib.label({ Text = "", Size = UDim2.fromOffset(270, 22), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), TextColor3 = C.Gold, Visible = false, Parent = center })

	salvage.Activated:Connect(function()
		local ok, v = State.Request("Click")
		if ok then
			Lib.sound("Salvage", 0.3)
			State.Fire("ClickFxScreen", salvage.AbsolutePosition + salvage.AbsoluteSize / 2, v)
			punch(HUD.refs.scrap)
		end
	end)

	-- Bottom-right: Foundry + Rebirth ------------------------------------------------------
	local right = Lib.new("Frame", { Name = "BottomRight", Size = UDim2.fromOffset(170, 170), Position = UDim2.new(1, -16, 1, if touch then -150 else -16), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(right)
	Lib.button({ Text = "🏭 FOUNDRY", Size = UDim2.fromOffset(170, 56), Color = C.Green, Color2 = C.Green2, Parent = right, OnClick = panels.Foundry.toggle })
	local rebirth = Lib.button({ Text = "REBIRTH", Size = UDim2.fromOffset(170, 88), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = C.Grey, Color2 = C.Grey2, Parent = right, OnClick = panels.Rebirth.toggle })
	local rebirthLabel = rebirth
	local _, setRebirthBar = Lib.bar(rebirth, UDim2.new(1, -16, 0, 10), UDim2.new(0, 8, 1, -16), C.Gold, C.Gold2)
	rebirth.TextYAlignment = Enum.TextYAlignment.Top
	HUD.refs.rebirth = rebirth

	local rebirthReady = false
	task.spawn(function()
		-- gold pulse + confetti loop while a rebirth is available
		while gui.Parent do
			task.wait(0.35)
			if rebirthReady then
				local conf = Lib.new("Frame", {
					Size = UDim2.fromOffset(8, 12),
					Position = UDim2.new(math.random(), 0, 0, 0),
					BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1),
					Rotation = math.random(0, 360),
					ZIndex = 3,
					Parent = rebirth,
				})
				Lib.tween(conf, 1.2, { Position = UDim2.new(math.random() * 1.4 - 0.2, 0, -1.2, 0), Rotation = math.random(-360, 360), BackgroundTransparency = 1 })
				task.delay(1.2, function()
					conf:Destroy()
				end)
			end
		end
	end)

	-- Updates ----------------------------------------------------------------------------------
	local lastScrap = 0
	local glowT = 0
	local function update()
		local data = State.data
		if not data then
			return
		end
		scrapAmount.Text = Format.Number(data.scrap)
		if scrapSub then
			scrapSub.Text = "+" .. Format.Number(data.income or 0) .. "/s"
		end
		novaAmount.Text = Format.Number(data.nova)
		if data.scrap > lastScrap + (data.income or 0) * 1.5 then
			punch(HUD.refs.scrap)
		end
		lastScrap = data.scrap

		-- Crate glow: purple when a Nova crate is affordable in this world.
		local novaAffordable = false
		local worldCrates = Crates.ByWorld[data.world or 1]
		if worldCrates then
			for _, crate in worldCrates do
				if crate.currency == "Nova" and data.nova >= crate.cost then
					novaAffordable = true
				end
			end
		end
		glow.Color = if novaAffordable then C.Nova else C.Scrap
		Lib.recolor(crateBtn, if novaAffordable then C.Nova else C.Scrap, if novaAffordable then C.Nova2 else C.Scrap2)

		local free = 0
		for _, n in data.freeCrates or {} do
			free += n
		end
		crateBadge.Visible = free > 0
		crateBadge.Text = tostring(free)

		-- Bounty badge
		local claimable = 0
		for _, q in data.quests or {} do
			local t = Quests.ById[q.template]
			if t and (data.stats[t.stat] or 0) - q.start >= q.goal then
				claimable += 1
			end
		end
		questBadge.Visible = claimable > 0
		questBadge.Text = tostring(claimable)

		bellBadge.Visible = State.unread > 0
		bellBadge.Text = tostring(State.unread)

		-- Rebirth
		local cost = Economy.RebirthCost(data.rebirths)
		local ready = data.scrap >= cost or (data.tokens and (data.tokens.RebirthSkip or 0) > 0)
		setRebirthBar(data.scrap / cost)
		rebirthLabel.Text = if ready then "✨ REBIRTH ✨" else "REBIRTH\n" .. Format.Number(cost)
		if ready ~= rebirthReady then
			rebirthReady = ready
			Lib.recolor(rebirth, if ready then C.Gold else C.Grey, if ready then C.Gold2 else C.Grey2)
		end

		-- Auto-salvager timer
		local left = (data.autoClickUntil or 0) - os.time()
		autoLabel.Visible = left > 0
		if left > 0 then
			autoLabel.Text = "🤖 Auto-Salvage " .. Format.Time(left)
		end
	end

	State.On("Changed", update)
	State.On("Unread", update)

	-- Pulse animation for glowing elements
	task.spawn(function()
		while gui.Parent do
			glowT += task.wait()
			glow.Thickness = 3 + math.sin(glowT * 4) * 3
			if rebirthReady then
				local s = rebirth:FindFirstChildOfClass("UIScale")
				if s and math.floor(glowT * 10) % 15 == 0 then
					s.Scale = 1.08
					Lib.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Elastic)
				end
			end
		end
	end)
end

return HUD
