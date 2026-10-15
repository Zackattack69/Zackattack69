--!strict
-- Main screen, in candy simulator style:
--   top centre   big green money counter (counts up, shakes + glows + sparkles
--                when it rises) with income/s, up in the Roblox top-bar row
--   right edge   event / luck / boost chips, stacked in the empty middle
--   top right    rebirth badge + multiplier, next-goal chip, shield, friend boost
--   left         chunky square buttons: Index, Shop, Rebirth, Quests, Trade, Settings
--   bottom right Lock Base with a circular cooldown, Collect All, Bonk (touch)
--                (lifted above the jump button on phones)
--   centre       status chips: carrying a stolen Tung / Tungs following you / gifts waiting

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Events = require(Shared.Config.Events)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local HUD = {}
local C = Lib.Colors
local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)

-- Chip with text that we can show/hide and retext. Returns (frame, label).
local function chip(parent: Instance, order: number, width: number, height: number, c1: Color3, c2: Color3): (Frame, TextLabel)
	local f, l = Lib.chip({ Size = UDim2.fromOffset(width, height), LayoutOrder = order, Visible = false, Parent = parent }, c1, c2)
	return f, l
end

function HUD.Build(gui: ScreenGui, panels: any)
	-- Money (top centre) -----------------------------------------------------------------------------------
	-- the money sits in its own ScreenGui that ignores the top-bar inset, so it can go right up to the top
	local topGui = Instance.new("ScreenGui")
	topGui.Name = "TungTop"
	topGui.ResetOnSpawn = false
	topGui.IgnoreGuiInset = true
	topGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	topGui.DisplayOrder = gui.DisplayOrder
	topGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	topGui.Parent = gui.Parent
	local top = Lib.new("Frame", { Name = "Top", Size = UDim2.fromOffset(420, 96), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = topGui })
	Lib.hudFit(top)
	local moneyPill = Lib.new("Frame", { Name = "Money", Size = UDim2.fromOffset(340, 84), Position = UDim2.new(0.5, 22, 0, 4), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08, Parent = top })
	Lib.round(moneyPill)
	local moneyStroke = Lib.stroke(moneyPill, C.Outline, 4)
	local glow = Lib.new("UIStroke", { Name = "Glow", Color = C.Money, Thickness = 0, Transparency = 0.15, Parent = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = moneyPill }) })
	Lib.round(glow.Parent :: Instance)
	local coin = Lib.new("Frame", { Size = UDim2.fromOffset(96, 96), Position = UDim2.new(0, -46, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = WHITE, ZIndex = 3, Parent = moneyPill })
	Lib.round(coin)
	Lib.new("UIGradient", { Color = Lib.buttonSeq(C.Gold, C.Gold2), Rotation = 90, Parent = coin })
	Lib.stroke(coin, C.Outline, 4.5)
	Lib.title({ Text = "$", Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.5, 0.48), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = coin })
	Lib.shine(coin)
	local moneyLabel = Lib.label({ Text = "$0", Font = Lib.FontTitle, Size = UDim2.new(1, -70, 0.62, 0), Position = UDim2.fromOffset(60, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = moneyPill })
	Lib.gradient(moneyLabel, Color3.fromRGB(200, 255, 150), Color3.fromRGB(70, 230, 70), 90)
	local ms = moneyLabel:FindFirstChildOfClass("UIStroke")
	if ms then
		ms.Thickness = 4
	end
	local incomeLabel = Lib.label({ Text = "+$0/s", Size = UDim2.new(1, -72, 0.3, 0), Position = UDim2.new(0, 62, 0.64, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = moneyPill })
	Lib.gradient(incomeLabel, Color3.fromRGB(255, 250, 180), Color3.fromRGB(255, 205, 40), 90)
	local moneySparkles = Lib.new("Frame", { Size = UDim2.new(1, 20, 1, 20), Position = UDim2.fromOffset(-10, -10), BackgroundTransparency = 1, Visible = false, ZIndex = 6, Parent = moneyPill })
	Lib.sparkles(moneySparkles, 6, Color3.fromRGB(255, 255, 160))
	local setMoney = Lib.countUp(moneyLabel, function(v)
		return Format.Money(math.floor(v))
	end)
	local _ = moneyStroke

	-- events, luck and boosts: stacked against the right edge, in the empty middle of the screen
	local pills = Lib.new("Frame", { Name = "Pills", Size = UDim2.fromOffset(300, 130), Position = UDim2.new(1, -10, 0.42, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(pills)
	Lib.list(pills, 6, false, Enum.HorizontalAlignment.Right).VerticalAlignment = Enum.VerticalAlignment.Center
	local eventChip, eventText = chip(pills, 1, 300, 36, C.Purple, C.Purple2)
	local luckChip, luckText = chip(pills, 2, 300, 34, C.Green, C.Green2)
	local boostChip, boostText = chip(pills, 3, 300, 34, C.Orange, C.Orange2)

	-- Rebirth badge & goals (top right) ------------------------------------------------------------------------
	local topRight = Lib.new("Frame", { Name = "TopRight", Size = UDim2.fromOffset(280, 200), Position = UDim2.new(1, -14, 0, 8), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(topRight)
	Lib.list(topRight, 6, false, Enum.HorizontalAlignment.Right).VerticalAlignment = Enum.VerticalAlignment.Top
	local rebirthChip, rebirthText = chip(topRight, 1, 270, 50, C.Pink, C.Pink2)
	rebirthChip.Visible = true
	rebirthText.Font = Lib.FontTitle
	Lib.shine(rebirthChip)
	local goalChip, goalText = chip(topRight, 2, 270, 36, C.Wood, C.Wood2)
	goalChip.Visible = true
	local shieldChip, shieldText = chip(topRight, 3, 270, 36, C.Blue, C.Blue2)
	local friendChip, friendText = chip(topRight, 4, 270, 34, C.Cyan, C.Cyan2)

	-- Left buttons ------------------------------------------------------------------------------------------------
	local left = Lib.new("Frame", { Name = "Left", Size = UDim2.fromOffset(200, 440), Position = UDim2.new(0, 22, 0.55, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(left)
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 84), CellPadding = UDim2.fromOffset(16, 28), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	local function leftButton(icon: string, label: string, c1: Color3, c2: Color3, order: number, onClick: () -> ()): TextButton
		return Lib.iconButton({ Icon = icon, Label = label, Size = 84, Color = c1, Color2 = c2, Parent = left, LayoutOrder = order, OnClick = onClick })
	end
	leftButton("📖", "Index", C.Orange, C.Orange2, 1, panels.Index.toggle)
	leftButton("🛒", "Shop", C.Green, C.Green2, 2, panels.Shop.toggle)
	local rebirthBtn = leftButton("♻️", "Rebirth", C.Gold, C.Gold2, 3, panels.Rebirth.toggle)
	local questBtn = leftButton("📜", "Quests", C.Blue, C.Blue2, 4, panels.Quests.toggle)
	leftButton("🤝", "Trade", C.Pink, C.Pink2, 5, panels.Trade.toggle)
	leftButton("⚙️", "Settings", C.Purple, C.Purple2, 6, panels.Settings.toggle)
	-- ADMIN button: only visible to admins / the owner (the server sets IsAdmin)
	local adminBtn = leftButton("👑", "Admin", C.Red, C.Red2, 7, panels.Admin.toggle)
	adminBtn.Visible = player:GetAttribute("IsAdmin") == true
	player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		adminBtn.Visible = player:GetAttribute("IsAdmin") == true
	end)
	local questBadge = Lib.badge(questBtn)
	local rebirthBadgeDot = Lib.badge(rebirthBtn)
	rebirthBadgeDot.Text = "!"

	-- Bottom right: Lock / Collect All / Bonk --------------------------------------------------------------------------
	local br = Lib.new("Frame", { Name = "BottomRight", Size = UDim2.fromOffset(240, 130), Position = UDim2.new(1, -18, 1, if Lib.Touch then -170 else -22), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(br)
	local lockRays = Lib.rays(br, Color3.fromRGB(255, 240, 140), 190, 8)
	lockRays.Position = UDim2.new(1, -56, 1, -56)
	lockRays.Visible = false
	local lock = Lib.button({ Name = "Lock", Size = UDim2.fromOffset(112, 112), Position = UDim2.new(1, 0, 1, 0), AnchorPoint = Vector2.new(1, 1), Color = C.Purple, Color2 = C.Purple2, Radius = 56, Parent = br, OnClick = function()
		local ok = State.Request("Lock")
		if ok then
			Lib.sound("Lock")
		end
	end })
	Lib.label({ Text = "🔒", Size = UDim2.fromScale(0.5, 0.44), Position = UDim2.fromScale(0.5, 0.34), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, ZIndex = 6, Parent = lock })
	local lockText = Lib.label({ Text = "LOCK", Font = Lib.FontTitle, Size = UDim2.fromScale(0.95, 0.28), Position = UDim2.fromScale(0.5, 0.78), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = lock })
	local setRadial = Lib.radial(lock, Color3.fromRGB(15, 8, 30), 0.4)
	local autoTag = Lib.label({ Text = "AUTO", Size = UDim2.fromOffset(64, 24), Position = UDim2.new(0.5, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.Green2, ZIndex = 7, Visible = false, Parent = lock })
	Lib.round(autoTag)
	Lib.stroke(autoTag, C.Outline, 2.5)

	local collectAll = Lib.button({ Name = "CollectAll", Size = UDim2.fromOffset(92, 92), Position = UDim2.new(1, -124, 1, 0), AnchorPoint = Vector2.new(1, 1), Color = C.Money, Color2 = C.Money2, Radius = 46, Parent = br, OnClick = function()
		State.Request("CollectAll")
	end })
	Lib.label({ Text = "🧲", Size = UDim2.fromScale(0.5, 0.46), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, ZIndex = 6, Parent = collectAll })
	Lib.label({ Text = "ALL", Font = Lib.FontTitle, Size = UDim2.fromScale(0.8, 0.28), Position = UDim2.fromScale(0.5, 0.78), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = collectAll })
	collectAll.Visible = false

	if Lib.Touch then
		local swing = Lib.button({ Name = "Swing", Size = UDim2.fromOffset(92, 92), Position = UDim2.new(1, 0, 0, -14), AnchorPoint = Vector2.new(1, 1), Color = C.Red, Color2 = C.Red2, Radius = 46, Parent = br, OnClick = function()
			State.Request("Swing")
		end })
		Lib.label({ Text = "🏏", Size = UDim2.fromScale(0.5, 0.46), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, ZIndex = 6, Parent = swing })
		Lib.label({ Text = "BONK", Font = Lib.FontTitle, Size = UDim2.fromScale(0.9, 0.28), Position = UDim2.fromScale(0.5, 0.78), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = swing })
	end

	-- Status chips (centre) ---------------------------------------------------------------------------------------------
	local strips = Lib.new("Frame", { Name = "Strips", Size = UDim2.fromOffset(600, 140), Position = UDim2.new(0.5, 0, 0, 236), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(strips)
	Lib.list(strips, 6, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top
	local carryChip, carryText = chip(strips, 1, 580, 46, C.Red, C.Red2)
	carryText.Font = Lib.FontTitle
	Lib.shine(carryChip)
	local holdChip, holdText = chip(strips, 2, 580, 40, C.Blue, C.Blue2)
	local followChip, followText = chip(strips, 2, 560, 38, C.Blue, C.Blue2)
	local pendingChip, pendingText = chip(strips, 3, 540, 36, C.Orange, C.Orange2)

	-- Updates ---------------------------------------------------------------------------------------------------------------
	local lastMoney = -1
	local function shakeMoney()
		Lib.tween(glow, 0.12, { Thickness = 10 })
		task.delay(0.25, function()
			Lib.tween(glow, 0.45, { Thickness = 0 })
		end)
		moneySparkles.Visible = true
		task.delay(1.2, function()
			moneySparkles.Visible = false
		end)
		task.spawn(function()
			for _, r in { -4, 4, -3, 3, -1, 0 } do
				moneyPill.Rotation = r
				task.wait(0.04)
			end
		end)
		local s = coin:FindFirstChild("Pop") :: UIScale? or Lib.new("UIScale", { Name = "Pop", Parent = coin })
		;(s :: UIScale).Scale = 1.25
		Lib.tween(s :: UIScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	State.On("MoneyGlow", shakeMoney)

	local function update()
		local d = State.data
		if not d then
			return
		end
		setMoney(d.money)
		if lastMoney >= 0 and d.money > lastMoney + math.max(1, (d.income or 0) * 1.5) then
			shakeMoney()
		end
		lastMoney = d.money
		incomeLabel.Text = "+" .. Format.Money(d.income or 0) .. "/s"

		local info = Economy.Rebirth(d.rebirths)
		rebirthText.Text = "♻️ REBIRTH " .. d.rebirths .. "  ·  x" .. (math.floor((d.mult or info.mult) * 100 + 0.5) / 100)
		local found = 0
		for _, t in Tungs.IndexList do
			if d.index and d.index[t.id] then
				found += 1
			end
		end
		local nextCost = Economy.Rebirth(d.rebirths + 1).cost
		goalText.Text = "📖 " .. found .. "/" .. #Tungs.IndexList .. "   ♻️ " .. math.min(100, math.floor(d.money / nextCost * 100)) .. "% to Rebirth " .. (d.rebirths + 1)
		local shield = d.shieldLeft or 0
		shieldChip.Visible = shield > 0
		shieldText.Text = "🛡️ Protected " .. Format.Time(shield)
		local fb = d.friendBoost or 0
		friendChip.Visible = fb > 0
		friendText.Text = "👫 Friend boost +" .. math.floor(fb * 100) .. "%"

		collectAll.Visible = Economy.CanCollectAll(d)
		autoTag.Visible = Economy.HasPass(d, "AutoLock")

		local nextInfo = Economy.Rebirth(d.rebirths + 1)
		local canRebirth = Economy.CanRebirth(d, (d.tokens and d.tokens.SkipRebirth or 0) > 0 and d.money < nextInfo.cost)
		rebirthBadgeDot.Visible = canRebirth

		local claimable = 0
		if d.quests and d.quests.list then
			for _, q in d.quests.list do
				if not q.claimed and q.progress >= q.goal then
					claimable += 1
				end
			end
		end
		if d.loginCanClaim then
			claimable += 1
		end
		questBadge.Visible = claimable > 0
		questBadge.Text = tostring(claimable)

		local pending = if d.pending then #d.pending else 0
		pendingChip.Visible = pending > 0
		pendingText.Text = "🎁 " .. pending .. " Tung" .. (if pending == 1 then " is" else "s are") .. " waiting for a free slot"
	end
	State.On("Changed", update)

	-- live timers (events, luck, boosts, lock, chips)
	task.spawn(function()
		while gui.Parent do
			local d = State.data
			local t = Workspace:GetServerTimeNow()
			-- event chip
			local ev = Workspace:GetAttribute("Event") :: string?
			eventChip.Visible = true
			if Workspace:GetAttribute("AdminAbuse") then
				local e = Events.ByKey.AdminAbuse
				eventText.Text = e.icon .. " " .. e.name .. "  " .. Format.Time(((Workspace:GetAttribute("AdminAbuseEnds") :: number?) or t) - t)
				Lib.recolor(eventChip, C.Pink, C.Pink2)
			elseif ev and Events.ByKey[ev] then
				local e = Events.ByKey[ev]
				eventText.Text = e.icon .. " " .. string.upper(e.name) .. "  " .. Format.Time(((Workspace:GetAttribute("EventEnds") :: number?) or t) - t)
				Lib.recolor(eventChip, e.color)
			else
				local nextAt = (Workspace:GetAttribute("NextEvent") :: number?) or t
				eventText.Text = "⏰ Next event in " .. Format.Time(nextAt - t)
				Lib.recolor(eventChip, C.Purple, C.Purple2)
			end
			-- luck chip
			local serverLuck = (Workspace:GetAttribute("ServerLuck") :: number?) or 1
			local personal = if d then Economy.PersonalLuck(d, os.time()) else 1
			luckChip.Visible = serverLuck > 1 or personal > 1
			local lt = "🍀 Luck x" .. (math.floor(serverLuck * personal * 100 + 0.5) / 100)
			local potionEnds = (Workspace:GetAttribute("LuckPotionEnds") :: number?) or 0
			if potionEnds > t then
				lt ..= "  (potion " .. Format.Time(potionEnds - t) .. ")"
			end
			luckText.Text = lt
			-- boosts chip
			if d and d.boosts then
				local now = os.time()
				local parts = {}
				if (d.boosts.Money2x or 0) > now then
					table.insert(parts, "💸 2x Money " .. Format.Time(d.boosts.Money2x - now))
				end
				if (d.boosts.Luck2x or 0) > now then
					table.insert(parts, "🍀 Potion " .. Format.Time(d.boosts.Luck2x - now))
				end
				boostChip.Visible = #parts > 0
				boostText.Text = table.concat(parts, "  ")
			end
			-- lock button
			local locked = player:GetAttribute("Locked") == true
			local lockEnds = (player:GetAttribute("LockEnds") :: number?) or 0
			local lockReady = (player:GetAttribute("LockReady") :: number?) or 0
			local ready = false
			if ev == "ThiefNight" then
				lockText.Text = "OFF"
				setRadial(1)
				Lib.recolor(lock, C.Grey, C.Grey2)
			elseif locked then
				local dur = if d then Economy.LockDuration(d) else 60
				lockText.Text = Format.Time(lockEnds - t)
				setRadial(math.clamp((lockEnds - t) / dur, 0, 1))
				Lib.recolor(lock, C.Red, C.Red2)
			elseif t < lockReady then
				lockText.Text = Format.Time(lockReady - t)
				setRadial(math.clamp((lockReady - t) / Economy.LOCK_COOLDOWN, 0, 1))
				Lib.recolor(lock, C.Grey, C.Grey2)
			else
				lockText.Text = "LOCK"
				setRadial(0)
				Lib.recolor(lock, C.Purple, C.Purple2)
				ready = true
			end
			lockRays.Visible = ready
			-- carrying / following chips
			local carrying = player:GetAttribute("Carrying") :: string?
			carryChip.Visible = carrying ~= nil and carrying ~= ""
			if carryChip.Visible and carrying then
				local id, mut = string.match(carrying, "^([^|]+)|?(.*)$")
				local tung = id and Tungs.Get(id)
				carryText.Text = "🦹 CARRYING " .. string.upper(Mutations.Prefix(mut) .. (if tung then tung.name else "TUNG")) .. "! RUN HOME!"
			end
			local held = player:GetAttribute("Holding") :: string?
			holdChip.Visible = held ~= nil and held ~= ""
			if holdChip.Visible and held then
				local id, mut = string.match(held, "^([^|]+)|?(.*)$")
				local tung = id and Tungs.Get(id)
				holdText.Text = "🐾 " .. Mutations.Prefix(mut) .. (if tung then tung.name else "Your Tung") .. " is with you. Press Place Here on any pad!"
			end
			local following = (player:GetAttribute("Following") :: string?) or ""
			local nFollow = if following == "" then 0 else #string.split(following, ",")
			followChip.Visible = nFollow > 0
			followText.Text = "🐾 " .. nFollow .. " Tung" .. (if nFollow == 1 then " is" else "s are") .. " following you. Walk into your base!"
			task.wait(0.25)
		end
	end)
end

return HUD
