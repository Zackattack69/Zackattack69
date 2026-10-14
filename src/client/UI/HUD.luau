--!strict
-- Main HUD, laid out like the big pet simulators:
--   left   : currency pills + a 2x3 grid of menu buttons
--   top    : current planet banner, settings & notifications
--   bottom : SALVAGE + big OPEN CRATE button
--   right  : REBIRTH (pulses gold when ready) + FOUNDRY

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crates = require(Shared.Config.Crates)
local Economy = require(Shared.Config.Economy)
local Names = require(Shared.Config.StarWarsNames)
local Quests = require(Shared.Config.Quests)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local HUD = {}
HUD.refs = {} :: { [string]: GuiObject }

local C = Lib.Colors

-- White currency pill with a coloured icon bubble.
local function pill(parent: Instance, icon: string, c1: Color3, c2: Color3, order: number, withSub: boolean): (TextLabel, TextLabel?, Frame)
	local f = Lib.new("Frame", { Size = UDim2.fromOffset(230, 56), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = parent })
	Lib.round(f)
	Lib.gradient(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 225, 245), 90)
	Lib.stroke(f, C.Outline, 3.5)
	local bubble = Lib.new("Frame", { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, -18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f })
	Lib.round(bubble)
	Lib.gradient(bubble, c1, c2, 90)
	Lib.stroke(bubble, C.Outline, 3.5)
	Lib.label({ Text = icon, Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = bubble })
	local amount = Lib.label({ Name = "Amount", Text = "0", Size = UDim2.new(1, -62, if withSub then 0.6 else 0.72, 0), Position = UDim2.new(0, 54, if withSub then 0.04 else 0.14, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = c1, Parent = f })
	local sub = nil
	if withSub then
		sub = Lib.label({ Name = "Sub", Text = "+0/s", Size = UDim2.new(1, -62, 0.32, 0), Position = UDim2.new(0, 54, 0.62, 0), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = C.SubText, Parent = f })
	end
	return amount, sub, f
end

local function punch(obj: GuiObject)
	local s = obj:FindFirstChild("Punch") :: UIScale? or Lib.new("UIScale", { Name = "Punch", Parent = obj })
	s.Scale = 1.12
	Lib.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

function HUD.Build(gui: ScreenGui, panels: any)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	-- Left column ------------------------------------------------------------------------------
	local left = Lib.new("Frame", { Name = "Left", Size = UDim2.fromOffset(250, 470), Position = UDim2.new(0, 34, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(left)
	local stack = Lib.new("Frame", { Size = UDim2.fromOffset(250, 140), BackgroundTransparency = 1, Parent = left })
	Lib.list(stack, 14)
	local scrapAmount, scrapSub, scrapPill = pill(stack, Names.CurrencyIcon.Scrap, C.Scrap, C.Scrap2, 1, true)
	local novaAmount, _, novaPill = pill(stack, Names.CurrencyIcon.Nova, C.Nova, C.Nova2, 2, false)
	HUD.refs.scrap = scrapPill
	local _ = novaPill

	local grid = Lib.new("Frame", { Size = UDim2.fromOffset(200, 310), Position = UDim2.fromOffset(4, 160), BackgroundTransparency = 1, Parent = left })
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 92), CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local droidsBtn = Lib.iconButton({ Icon = "🤖", Label = "Droids", Size = 92, Color = C.Blue, Color2 = C.Blue2, Parent = grid, LayoutOrder = 1, OnClick = panels.Droids.toggle })
	Lib.iconButton({ Icon = "🎒", Label = "Items", Size = 92, Color = C.Purple, Color2 = C.Purple2, Parent = grid, LayoutOrder = 2, OnClick = panels.Inventory.toggle })
	local shop = Lib.iconButton({ Icon = "🛒", Label = "Shop", Size = 92, Color = C.Robux, Color2 = C.Green2, Parent = grid, LayoutOrder = 3, OnClick = panels.Shop.toggle })
	local quests = Lib.iconButton({ Icon = "📜", Label = "Bounty", Size = 92, Color = C.Gold, Color2 = C.Gold2, Parent = grid, LayoutOrder = 4, OnClick = panels.Quests.toggle })
	local map = Lib.iconButton({ Icon = "🪐", Label = "Galaxy", Size = 92, Color = C.Pink, Color2 = C.Pink2, Parent = grid, LayoutOrder = 5, OnClick = panels.Map.toggle })
	Lib.iconButton({ Icon = "🏆", Label = "Top", Size = 92, Color = Color3.fromRGB(255, 165, 80), Color2 = Color3.fromRGB(230, 95, 30), Parent = grid, LayoutOrder = 6, OnClick = panels.Leaderboard.toggle })
	local questBadge = Lib.badge(quests)
	HUD.refs.droids = droidsBtn
	HUD.refs.shop = shop
	HUD.refs.map = map

	-- Top: planet banner + settings/notifications ------------------------------------------------
	local banner = Lib.new("Frame", { Name = "PlanetBanner", Size = UDim2.fromOffset(330, 54), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui })
	Lib.fit(banner)
	Lib.round(banner)
	local bannerGrad = Lib.gradient(banner, C.Blue, C.Blue2, 90)
	Lib.stroke(banner, C.Outline, 3.5)
	local bannerText = Lib.label({ Text = "", Font = Lib.FontTitle, Size = UDim2.new(1, -24, 0.78, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = banner })

	local topRight = Lib.new("Frame", { Name = "TopRight", Size = UDim2.fromOffset(150, 70), Position = UDim2.new(1, -20, 0, 70), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(topRight)
	Lib.list(topRight, 10, true, Enum.HorizontalAlignment.Right)
	Lib.iconButton({ Icon = "⚙️", Size = 64, Color = C.Grey, Color2 = C.Grey2, Parent = topRight, LayoutOrder = 1, OnClick = panels.Settings.toggle })
	local bell = Lib.iconButton({ Icon = "🔔", Size = 64, Color = C.Grey, Color2 = C.Grey2, Parent = topRight, LayoutOrder = 2, OnClick = panels.Notifications.toggle })
	local bellBadge = Lib.badge(bell)

	-- Bottom-centre: SALVAGE + OPEN CRATE ----------------------------------------------------------
	local center = Lib.new("Frame", { Name = "BottomCenter", Size = UDim2.fromOffset(420, 120), Position = UDim2.new(0.5, 0, 1, if touch then -100 else -20), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(center)
	local salvage = Lib.button({ Text = "", Size = UDim2.fromOffset(104, 104), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = C.Gold, Color2 = C.Gold2, Radius = 52, Parent = center })
	Lib.label({ Text = "⚙️", Size = UDim2.fromScale(0.6, 0.5), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = salvage })
	Lib.label({ Text = "SALVAGE", Size = UDim2.fromScale(1.1, 0.26), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), Parent = salvage })
	local crateBtn = Lib.button({ Text = "", Size = UDim2.fromOffset(296, 96), Position = UDim2.new(1, 0, 1, -4), AnchorPoint = Vector2.new(1, 1), Color = C.Blue, Color2 = C.Blue2, Radius = 22, Parent = center, OnClick = panels.Crates.toggle })
	Lib.label({ Text = "📦", Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Stroke = false, Parent = crateBtn })
	Lib.label({ Text = "OPEN CRATE", Font = Lib.FontTitle, Size = UDim2.new(1, -90, 0.62, 0), Position = UDim2.new(0, 84, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = crateBtn })
	local glow = Lib.new("UIStroke", { Name = "Glow", Thickness = 0, Color = C.Blue, Transparency = 0.3, Parent = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = crateBtn }) })
	Lib.corner(glow.Parent :: Instance, 22)
	local crateBadge = Lib.badge(crateBtn)
	HUD.refs.crate = crateBtn
	local autoLabel = Lib.label({ Text = "", Size = UDim2.fromOffset(296, 24), Position = UDim2.new(1, 0, 0, -4), AnchorPoint = Vector2.new(1, 0), TextColor3 = C.Gold, Visible = false, Parent = center })

	salvage.Activated:Connect(function()
		local ok, v = State.Request("Click")
		if ok then
			Lib.sound("Salvage", 0.3)
			State.Fire("ClickFxScreen", salvage.AbsolutePosition + salvage.AbsoluteSize / 2, v)
			punch(HUD.refs.scrap)
		end
	end)

	-- Right: REBIRTH + FOUNDRY ----------------------------------------------------------------------
	local right = Lib.new("Frame", { Name = "Right", Size = UDim2.fromOffset(150, 300), Position = UDim2.new(1, -24, 0.55, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Parent = gui })
	Lib.fit(right)
	local rebirth = Lib.button({ Text = "", Size = UDim2.fromOffset(150, 150), Color = C.Grey, Color2 = C.Grey2, Radius = 24, Parent = right, OnClick = panels.Rebirth.toggle })
	Lib.label({ Text = "♻️", Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), Stroke = false, Parent = rebirth })
	local rebirthTitle = Lib.label({ Text = "REBIRTH", Font = Lib.FontTitle, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 68), Parent = rebirth })
	local rebirthCost = Lib.label({ Text = "", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 98), Parent = rebirth })
	local _, setRebirthBar = Lib.bar(rebirth, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 1, -24), C.Gold, C.Gold2)
	HUD.refs.rebirth = rebirth
	local foundry = Lib.iconButton({ Icon = "🏭", Label = "Foundry", Size = 110, Color = C.Green, Color2 = C.Green2, Parent = right, Position = UDim2.new(0.5, 0, 1, -18), AnchorPoint = Vector2.new(0.5, 1), OnClick = panels.Foundry.toggle })
	local _ = foundry

	local rebirthReady = false
	task.spawn(function()
		-- confetti loop while a rebirth is available
		while gui.Parent do
			task.wait(0.3)
			if rebirthReady then
				local conf = Lib.new("Frame", {
					Size = UDim2.fromOffset(9, 13),
					Position = UDim2.new(math.random(), 0, 0, 0),
					BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1),
					Rotation = math.random(0, 360),
					ZIndex = 4,
					Parent = rebirth,
				})
				Lib.tween(conf, 1.2, { Position = UDim2.new(math.random() * 1.4 - 0.2, 0, -0.9, 0), Rotation = math.random(-360, 360), BackgroundTransparency = 1 })
				task.delay(1.2, function()
					conf:Destroy()
				end)
			end
		end
	end)

	-- Updates ----------------------------------------------------------------------------------
	local lastScrap = 0
	local lastWorld = 0
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

		if data.world and data.world ~= lastWorld then
			lastWorld = data.world
			local w = Worlds.Get(data.world)
			bannerText.Text = w.icon .. " " .. string.upper(w.name)
			bannerGrad.Color = ColorSequence.new(w.colors.accent, w.colors.accent:Lerp(Color3.new(0, 0, 0), 0.35))
			punch(banner)
		end

		-- Crate button turns purple when an Aura crate is affordable here.
		local novaAffordable = false
		local worldCrates = Crates.ByWorld[data.world or 1]
		if worldCrates then
			for _, crate in worldCrates do
				if crate.currency == "Nova" and data.nova >= crate.cost then
					novaAffordable = true
				end
			end
		end
		glow.Color = if novaAffordable then C.Purple else C.Blue
		Lib.recolor(crateBtn, if novaAffordable then C.Purple else C.Blue, if novaAffordable then C.Purple2 else C.Blue2)

		local free = 0
		for _, n in data.freeCrates or {} do
			free += n
		end
		crateBadge.Visible = free > 0
		crateBadge.Text = tostring(free)

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

		local cost = Economy.RebirthCost(data.rebirths)
		local ready = data.scrap >= cost or (data.tokens ~= nil and (data.tokens.RebirthSkip or 0) > 0)
		setRebirthBar(data.scrap / cost)
		rebirthTitle.Text = if ready then "REBIRTH!" else "REBIRTH"
		rebirthCost.Text = if ready then "✨ READY ✨" else Names.CurrencyIcon.Scrap .. " " .. Format.Number(cost)
		if ready ~= rebirthReady then
			rebirthReady = ready
			Lib.recolor(rebirth, if ready then C.Gold else C.Grey, if ready then C.Gold2 else C.Grey2)
		end

		local left = (data.autoClickUntil or 0) - os.time()
		autoLabel.Visible = left > 0
		if left > 0 then
			autoLabel.Text = "🤖 Auto-Salvage " .. Format.Time(left)
		end
	end

	State.On("Changed", update)
	State.On("Unread", update)

	-- pulse animations
	task.spawn(function()
		local t = 0
		while gui.Parent do
			t += task.wait()
			glow.Thickness = 4 + math.sin(t * 4) * 4
			if rebirthReady then
				local s = rebirth:FindFirstChildOfClass("UIScale")
				if s and math.floor(t * 10) % 15 == 0 then
					s.Scale = 1.08
					Lib.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Elastic)
				end
			end
		end
	end)
end

return HUD
