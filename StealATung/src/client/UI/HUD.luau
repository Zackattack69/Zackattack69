--!strict
-- Main screen:
--   top centre   money (counts up, shakes + glows when it rises) and income/s,
--                with event / luck / boost pills below
--   top right    rebirth level badge + multiplier, new-player shield
--   left         big round buttons: Index, Shop, Rebirth, Quests, Trade, Settings
--   bottom right Lock Base with a circular cooldown, Collect All, Swing (touch)
--                (lifted above the jump button on phones)
--   centre       status strips: carrying a stolen Tung / Tungs following you / gifts waiting

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

local function pill(parent: Instance, order: number, c1: Color3, c2: Color3): TextLabel
	local l = Lib.label({ Text = "", Size = UDim2.fromOffset(250, 34), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Visible = false, Parent = parent })
	Lib.round(l)
	Lib.gradient(l, c1, c2, 90)
	Lib.stroke(l, C.Outline, 2.5)
	Lib.padding(l, 5)
	return l
end

function HUD.Build(gui: ScreenGui, panels: any)
	-- Money (top centre) -----------------------------------------------------------------------------------
	local top = Lib.new("Frame", { Name = "Top", Size = UDim2.fromOffset(380, 200), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(top)
	local moneyPill = Lib.new("Frame", { Name = "Money", Size = UDim2.fromOffset(330, 74), Position = UDim2.new(0.5, 18, 0, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = top })
	Lib.round(moneyPill)
	Lib.gradient(moneyPill, C.Cream, C.Cream2, 90)
	local moneyStroke = Lib.stroke(moneyPill, C.Outline, 4)
	local glow = Lib.new("UIStroke", { Name = "Glow", Color = C.Gold, Thickness = 0, Transparency = 0.2, Parent = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = moneyPill }) })
	Lib.round(glow.Parent :: Instance)
	local coin = Lib.new("Frame", { Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0, -40, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = moneyPill })
	Lib.round(coin)
	Lib.gradient(coin, C.Gold, C.Gold2, 90)
	Lib.stroke(coin, C.Outline, 4)
	Lib.label({ Text = "$", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = coin })
	local moneyLabel = Lib.label({ Text = "$0", Size = UDim2.new(1, -66, 0.6, 0), Position = UDim2.fromOffset(54, 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Money, Parent = moneyPill })
	local incomeLabel = Lib.label({ Text = "+$0/s", Size = UDim2.new(1, -66, 0.3, 0), Position = UDim2.new(0, 56, 0.64, 0), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = C.SubText, Parent = moneyPill })
	local setMoney = Lib.countUp(moneyLabel, function(v)
		return Format.Money(math.floor(v))
	end)
	local _ = moneyStroke

	local pills = Lib.new("Frame", { Name = "Pills", Size = UDim2.fromOffset(380, 120), Position = UDim2.fromOffset(0, 84), BackgroundTransparency = 1, Parent = top })
	Lib.list(pills, 5, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top
	local eventPill = pill(pills, 1, C.Purple, C.Purple2)
	local luckPill = pill(pills, 2, C.Green, C.Green2)
	local boostPill = pill(pills, 3, C.Gold, C.Gold2)

	-- Rebirth badge + shield (top right) ------------------------------------------------------------------------
	local topRight = Lib.new("Frame", { Name = "TopRight", Size = UDim2.fromOffset(260, 120), Position = UDim2.new(1, -14, 0, 8), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(topRight)
	Lib.list(topRight, 6, false, Enum.HorizontalAlignment.Right).VerticalAlignment = Enum.VerticalAlignment.Top
	local rebirthBadge = Lib.label({ Text = "♻️ Rebirth 0 · x1", Size = UDim2.fromOffset(250, 44), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1, Parent = topRight })
	Lib.round(rebirthBadge)
	Lib.gradient(rebirthBadge, C.Wood, C.Wood2, 90)
	Lib.stroke(rebirthBadge, C.Outline, 3)
	Lib.padding(rebirthBadge, 6)
	local goalPill = pill(topRight, 2, C.Wood, C.Wood2)
	goalPill.Visible = true
	local shieldPill = pill(topRight, 3, C.Blue, C.Blue2)
	local friendPill = pill(topRight, 4, C.Pink, C.Pink2)

	-- Left buttons ------------------------------------------------------------------------------------------------
	local left = Lib.new("Frame", { Name = "Left", Size = UDim2.fromOffset(190, 300), Position = UDim2.new(0, 20, 0.5, -10), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(left)
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(80, 80), CellPadding = UDim2.fromOffset(18, 24), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	local function leftButton(icon: string, label: string, c1: Color3, c2: Color3, order: number, onClick: () -> ()): TextButton
		return Lib.iconButton({ Icon = icon, Label = label, Size = 80, Color = c1, Color2 = c2, Parent = left, LayoutOrder = order, OnClick = onClick })
	end
	leftButton("📖", "Index", Color3.fromRGB(196, 140, 84), C.Wood2, 1, panels.Index.toggle)
	leftButton("🛒", "Shop", C.Green, C.Green2, 2, panels.Shop.toggle)
	local rebirthBtn = leftButton("♻️", "Rebirth", C.Gold, C.Gold2, 3, panels.Rebirth.toggle)
	local questBtn = leftButton("📜", "Quests", C.Blue, C.Blue2, 4, panels.Quests.toggle)
	leftButton("🤝", "Trade", C.Pink, C.Pink2, 5, panels.Trade.toggle)
	leftButton("⚙️", "Settings", C.Grey, C.Grey2, 6, panels.Settings.toggle)
	local questBadge = Lib.badge(questBtn)
	local rebirthBadgeDot = Lib.badge(rebirthBtn)
	rebirthBadgeDot.Text = "!"

	-- Bottom right: Lock / Collect All / Swing ----------------------------------------------------------------------
	local br = Lib.new("Frame", { Name = "BottomRight", Size = UDim2.fromOffset(230, 120), Position = UDim2.new(1, -16, 1, if Lib.Touch then -170 else -20), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(br)
	local lock = Lib.button({ Name = "Lock", Size = UDim2.fromOffset(104, 104), Position = UDim2.new(1, 0, 1, 0), AnchorPoint = Vector2.new(1, 1), Color = C.Purple, Color2 = C.Purple2, Radius = 52, Parent = br, OnClick = function()
		local ok = State.Request("Lock")
		if ok then
			Lib.sound("Lock")
		end
	end })
	Lib.label({ Text = "🔒", Size = UDim2.fromScale(0.5, 0.42), Position = UDim2.fromScale(0.5, 0.34), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, ZIndex = 5, Parent = lock })
	local lockText = Lib.label({ Text = "LOCK", Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.5, 0.76), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = lock })
	local setRadial = Lib.radial(lock, Color3.fromRGB(20, 10, 30), 0.45)
	local autoTag = Lib.label({ Text = "AUTO", Size = UDim2.fromOffset(60, 22), Position = UDim2.new(0.5, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.Green2, ZIndex = 6, Visible = false, Parent = lock })
	Lib.round(autoTag)

	local collectAll = Lib.button({ Name = "CollectAll", Size = UDim2.fromOffset(86, 86), Position = UDim2.new(1, -118, 1, 0), AnchorPoint = Vector2.new(1, 1), Color = C.Money, Color2 = C.Money2, Radius = 43, Parent = br, OnClick = function()
		State.Request("CollectAll")
	end })
	Lib.label({ Text = "🧲", Size = UDim2.fromScale(0.5, 0.45), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = collectAll })
	Lib.label({ Text = "ALL", Size = UDim2.fromScale(0.8, 0.26), Position = UDim2.fromScale(0.5, 0.76), AnchorPoint = Vector2.new(0.5, 0.5), Parent = collectAll })
	collectAll.Visible = false

	if Lib.Touch then
		local swing = Lib.button({ Name = "Swing", Size = UDim2.fromOffset(86, 86), Position = UDim2.new(1, 0, 0, -10), AnchorPoint = Vector2.new(1, 1), Color = C.Red, Color2 = C.Red2, Radius = 43, Parent = br, OnClick = function()
			State.Request("Swing")
		end })
		Lib.label({ Text = "🏏", Size = UDim2.fromScale(0.5, 0.45), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = swing })
		Lib.label({ Text = "BONK", Size = UDim2.fromScale(0.85, 0.26), Position = UDim2.fromScale(0.5, 0.76), AnchorPoint = Vector2.new(0.5, 0.5), Parent = swing })
	end

	-- Status strips (centre) ---------------------------------------------------------------------------------------------
	local strips = Lib.new("Frame", { Name = "Strips", Size = UDim2.fromOffset(560, 130), Position = UDim2.new(0.5, 0, 0, 206), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
	Lib.hudFit(strips)
	Lib.list(strips, 6, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top
	local carryStrip = pill(strips, 1, C.Red, C.Red2)
	carryStrip.Size = UDim2.fromOffset(540, 40)
	local followStrip = pill(strips, 2, C.Blue, C.Blue2)
	followStrip.Size = UDim2.fromOffset(540, 36)
	local pendingStrip = pill(strips, 3, C.Wood, C.Wood2)
	pendingStrip.Size = UDim2.fromOffset(540, 34)

	-- Updates ---------------------------------------------------------------------------------------------------------------
	local lastMoney = -1
	local function shakeMoney()
		Lib.tween(glow, 0.12, { Thickness = 8 })
		task.delay(0.25, function()
			Lib.tween(glow, 0.4, { Thickness = 0 })
		end)
		task.spawn(function()
			for _, r in { -3, 3, -2, 2, 0 } do
				moneyPill.Rotation = r
				task.wait(0.04)
			end
		end)
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
		rebirthBadge.Text = "♻️ Rebirth " .. d.rebirths .. "  ·  x" .. (math.floor((d.mult or info.mult) * 100 + 0.5) / 100)
		local found = 0
		for _, t in Tungs.IndexList do
			if d.index and d.index[t.id] then
				found += 1
			end
		end
		local nextCost = Economy.Rebirth(d.rebirths + 1).cost
		goalPill.Text = "📖 " .. found .. "/" .. #Tungs.IndexList .. "  ·  ♻️ " .. math.min(100, math.floor(d.money / nextCost * 100)) .. "% to Rebirth " .. (d.rebirths + 1)
		local shield = d.shieldLeft or 0
		shieldPill.Visible = shield > 0
		shieldPill.Text = "🛡️ Protected " .. Format.Time(shield)
		local fb = d.friendBoost or 0
		friendPill.Visible = fb > 0
		friendPill.Text = "👫 Friend boost +" .. math.floor(fb * 100) .. "%"

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
		pendingStrip.Visible = pending > 0
		pendingStrip.Text = "🎁 " .. pending .. " Tung" .. (if pending == 1 then " is" else "s are") .. " waiting for a free slot"
	end
	State.On("Changed", update)

	-- live timers (events, luck, boosts, lock, strips)
	task.spawn(function()
		while gui.Parent do
			local d = State.data
			local t = Workspace:GetServerTimeNow()
			-- event pill
			local ev = Workspace:GetAttribute("Event") :: string?
			if Workspace:GetAttribute("AdminAbuse") then
				local e = Events.ByKey.AdminAbuse
				eventPill.Text = e.icon .. " " .. e.name .. " " .. Format.Time(((Workspace:GetAttribute("AdminAbuseEnds") :: number?) or t) - t)
				eventPill.Visible = true
			elseif ev and Events.ByKey[ev] then
				local e = Events.ByKey[ev]
				eventPill.Text = e.icon .. " " .. string.upper(e.name) .. " " .. Format.Time(((Workspace:GetAttribute("EventEnds") :: number?) or t) - t)
				eventPill.Visible = true
			else
				local nextAt = (Workspace:GetAttribute("NextEvent") :: number?) or t
				eventPill.Text = "⏰ Next event in " .. Format.Time(nextAt - t)
				eventPill.Visible = true
			end
			-- luck pill
			local serverLuck = (Workspace:GetAttribute("ServerLuck") :: number?) or 1
			local personal = if d then Economy.PersonalLuck(d, os.time()) else 1
			luckPill.Visible = serverLuck > 1 or personal > 1
			local luckText = "🍀 Luck x" .. (math.floor(serverLuck * personal * 100 + 0.5) / 100)
			local potionEnds = (Workspace:GetAttribute("LuckPotionEnds") :: number?) or 0
			if potionEnds > t then
				luckText ..= "  (potion " .. Format.Time(potionEnds - t) .. ")"
			end
			luckPill.Text = luckText
			-- boosts pill
			if d and d.boosts then
				local now = os.time()
				local parts = {}
				if (d.boosts.Money2x or 0) > now then
					table.insert(parts, "💸 2x Money " .. Format.Time(d.boosts.Money2x - now))
				end
				if (d.boosts.Luck2x or 0) > now then
					table.insert(parts, "🍀 Potion " .. Format.Time(d.boosts.Luck2x - now))
				end
				boostPill.Visible = #parts > 0
				boostPill.Text = table.concat(parts, "  ")
			end
			-- lock button
			local locked = player:GetAttribute("Locked") == true
			local lockEnds = (player:GetAttribute("LockEnds") :: number?) or 0
			local lockReady = (player:GetAttribute("LockReady") :: number?) or 0
			local thiefNight = ev == "ThiefNight"
			if thiefNight then
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
			end
			-- carrying / following strips
			local carrying = player:GetAttribute("Carrying") :: string?
			carryStrip.Visible = carrying ~= nil and carrying ~= ""
			if carryStrip.Visible and carrying then
				local id, mut = string.match(carrying, "^([^|]+)|?(.*)$")
				local tung = id and Tungs.Get(id)
				carryStrip.Text = "🦹 You're carrying a " .. Mutations.Prefix(mut) .. (if tung then tung.name else "Tung") .. "! Run it back to your base!"
			end
			local following = (player:GetAttribute("Following") :: string?) or ""
			local nFollow = if following == "" then 0 else #string.split(following, ",")
			followStrip.Visible = nFollow > 0
			followStrip.Text = "🐾 " .. nFollow .. " Tung" .. (if nFollow == 1 then " is" else "s are") .. " following you. Walk into your base!"
			task.wait(0.25)
		end
	end)
end

return HUD
