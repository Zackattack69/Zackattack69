--!strict
-- Screen effects:
--   * candy toasts
--   * compact banners that slide down just under the money and leave after 2.6 s
--     (rare spawns, steals, events)
--   * the bouncy gradient "+$12.4K" collect pop
--   * "STOLEN!" / "PURCHASED!" / "NEW!" pops
--   * the red siren flash when you're being robbed, and the rebirth flash

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local Effects = {}
local WHITE = Color3.new(1, 1, 1)

local TOAST_COLORS: { [string]: { Color3 } } = {
	info = { C.Wood, C.Wood2 },
	error = { C.Red, C.Red2 },
	success = { C.Green, C.Green2 },
	money = { C.Money, C.Money2 },
	steal = { C.Red, C.Red2 },
	stealwin = { C.Purple, C.Purple2 },
	purchase = { C.Robux, Color3.fromRGB(20, 140, 70) },
	hype = { C.Pink, C.Pink2 },
}

-- Big gradient word that pops in, wobbles and floats away.
local function bigPop(fxGui: ScreenGui, text: string, c1: Color3, c2: Color3, y: number, withRays: boolean?)
	local holder = Lib.new("Frame", { Size = UDim2.fromOffset(460, 96), Position = UDim2.fromScale(0.5, y), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 50, Parent = fxGui })
	local scale = Lib.new("UIScale", { Scale = 0.2, Parent = holder })
	if withRays then
		Lib.rays(holder, c1:Lerp(WHITE, 0.5), 240, 10, 49)
	end
	local l = Lib.label({ Text = text, Font = Lib.FontTitle, Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 51, Parent = holder })
	Lib.gradient(l, c1:Lerp(WHITE, 0.4), c2, 90)
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		st.Thickness = 4
	end
	Lib.tween(scale, 0.45, { Scale = Lib.HudScale() }, Enum.EasingStyle.Back)
	task.spawn(function()
		for _, r in { -6, 6, -4, 4, 0 } do
			l.Rotation = r
			task.wait(0.05)
		end
	end)
	task.delay(1.1, function()
		Lib.tween(holder, 0.5, { Position = UDim2.fromScale(0.5, y - 0.08) })
		Lib.tween(l, 0.5, { TextTransparency = 1 })
		if st then
			Lib.tween(st, 0.5, { Transparency = 1 })
		end
		task.wait(0.55)
		holder:Destroy()
	end)
end

function Effects.Init(fxGui: ScreenGui)
	-- Toasts -----------------------------------------------------------------------------------------------
	local toastHolder = Lib.new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(500, 220), Position = UDim2.new(0.5, 0, 0, 112), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = fxGui })
	Lib.hudFit(toastHolder)
	Lib.list(toastHolder, 6, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top
	local order = 0
	State.On("Toast", function(text: string, kind: string?)
		local k = kind or "info"
		order += 1
		if k == "error" then
			Lib.sound("Error")
		end
		if k == "stealwin" then
			bigPop(fxGui, "STOLEN!", C.Purple, C.Pink2, 0.36, true)
			Lib.sound("Jackpot")
		end
		local colors = TOAST_COLORS[k] or TOAST_COLORS.info
		local f, l = Lib.chip({ Text = text, Size = UDim2.fromOffset(480, 38), LayoutOrder = order, Parent = toastHolder }, colors[1], colors[2])
		local s = Lib.new("UIScale", { Scale = 0.3, Parent = f })
		Lib.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(3, function()
			Lib.tween(s, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.27)
			f:Destroy()
		end)
		local _ = l
		local kids = {}
		for _, c in toastHolder:GetChildren() do
			if c:IsA("Frame") then
				table.insert(kids, c)
			end
		end
		if #kids > 3 then
			table.sort(kids, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			kids[1]:Destroy()
		end
	end)

	-- Centre banners ------------------------------------------------------------------------------------------------
	local queue: { any } = {}
	local showing = false
	-- hidden well above the screen AND invisible, so no sliver of it peeks out under the top bar
	local HIDDEN = UDim2.new(0.5, 0, 0, -220)
	local SHOWN = UDim2.new(0.5, 0, 0, 40)
	local bannerRoot = Lib.new("Frame", { Name = "BannerRoot", Size = UDim2.fromOffset(540, 58), Position = HIDDEN, AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 70, Visible = false, Parent = fxGui })
	Lib.hudFit(bannerRoot)
	local banner = Lib.new("Frame", { Name = "Banner", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 70, Parent = bannerRoot })
	Lib.corner(banner, 20)
	local bannerGrad = Lib.new("UIGradient", { Color = Lib.buttonSeq(C.Gold, C.Gold2), Rotation = 90, Parent = banner })
	Lib.stroke(banner, C.Outline, 3.5)
	local bannerShine = Lib.shine(banner, 20)
	local _ = bannerShine
	local bannerText = Lib.title({ Text = "", Size = UDim2.new(1, -32, 1, -16), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 74, Parent = banner })
	local rainbowStroke = Lib.animGradient(Lib.new("UIStroke", { Thickness = 0, Color = WHITE, Parent = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 75, Parent = banner }) }), Rarities.RAINBOW, "Rainbow")
	local rainbowStrokeInst = rainbowStroke.Parent :: UIStroke

	local function nextBanner()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local b = table.remove(queue, 1)
		local color: Color3 = b.color or C.Gold
		bannerGrad.Color = Lib.buttonSeq(color:Lerp(WHITE, 0.1), color:Lerp(Color3.new(0, 0, 0), 0.3))
		rainbowStrokeInst.Thickness = if b.rainbow then 4 else 0
		bannerText.Text = b.text
		bannerRoot.Position = HIDDEN
		bannerRoot.Visible = true
		local sc = banner:FindFirstChild("Pop") :: UIScale? or Lib.new("UIScale", { Name = "Pop", Parent = banner })
		;(sc :: UIScale).Scale = 0.85
		Lib.tween(bannerRoot, 0.4, { Position = SHOWN }, Enum.EasingStyle.Back)
		Lib.tween(sc :: UIScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		if b.sound then
			Lib.sound(b.sound)
		end
		task.delay(2.6, function()
			Lib.tween(bannerRoot, 0.3, { Position = HIDDEN }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.4)
			bannerRoot.Visible = false
			showing = false
			nextBanner()
		end)
	end
	local function pushBanner(b: any)
		table.insert(queue, b)
		if #queue > 4 then
			table.remove(queue, 1)
		end
		nextBanner()
	end

	-- red siren flash around the screen edge
	local vignette = Lib.new("Frame", { Name = "Siren", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60, Parent = fxGui })
	local vStroke = Lib.new("UIStroke", { Color = C.Red2, Thickness = 0, Transparency = 0.15, Parent = vignette })
	local function siren()
		task.spawn(function()
			for _ = 1, 3 do
				Lib.sound("Siren", nil, 0.75)
				Lib.tween(vStroke, 0.2, { Thickness = 30 })
				task.wait(0.3)
				Lib.sound("Siren", nil, 0.6)
				Lib.tween(vStroke, 0.2, { Thickness = 0 })
				task.wait(0.3)
			end
		end)
	end

	Remotes.Event("Alert").OnClientEvent:Connect(function(a: any)
		pushBanner({ text = a.text, color = a.color, sound = a.sound })
		if a.kind == "steal" and a.sound == "Siren" then
			siren()
		end
	end)

	State.On("Hype", function(level: string, name: string, color: Color3)
		local text = if level == "Mythic"
			then "🔥 MYTHIC on the belt: " .. name
			elseif level == "Secret" then "🌑 SECRET on the belt: " .. name
			else "✨ LEGENDARY on the belt: " .. name
		pushBanner({ text = text, color = if level == "Secret" then Color3.fromRGB(60, 50, 90) else color, sound = "Spawn" .. level, rainbow = level == "Secret" or level == "Mythic" })
	end)

	State.On("Purchased", function(name: string)
		bigPop(fxGui, "PURCHASED!", C.Money, C.Money2, 0.66, false)
		local _ = name
	end)

	-- Collect pop: big bouncy "+$X" -------------------------------------------------------------------------------------
	State.On("CollectPop", function(amount: number)
		Lib.sound("ChaChing")
		local holder = Lib.new("Frame", { Size = UDim2.fromOffset(340, 76), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 50, Parent = fxGui })
		local l = Lib.label({ Text = "+" .. Format.Money(amount), Font = Lib.FontTitle, Size = UDim2.fromScale(1, 1), ZIndex = 51, Parent = holder })
		Lib.gradient(l, Color3.fromRGB(220, 255, 170), Color3.fromRGB(50, 220, 70), 90)
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			st.Thickness = 5
		end
		local s = Lib.new("UIScale", { Scale = 0.3, Parent = holder })
		Lib.tween(s, 0.35, { Scale = Lib.HudScale() }, Enum.EasingStyle.Back)
		task.delay(0.6, function()
			Lib.tween(holder, 0.6, { Position = UDim2.fromScale(0.5, 0.3) })
			Lib.tween(l, 0.6, { TextTransparency = 1 })
			if st then
				Lib.tween(st, 0.6, { Transparency = 1 })
			end
			task.wait(0.65)
			holder:Destroy()
		end)
		State.Fire("MoneyGlow")
	end)

	-- Rebirth flash ----------------------------------------------------------------------------------------------------------
	State.On("RebirthFlash", function()
		Lib.sound("Rebirth")
		local f = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 90, Parent = fxGui })
		Lib.tween(f, 1.4, { BackgroundTransparency = 1 })
		bigPop(fxGui, "✨ REBIRTH! ✨", C.Gold, C.Gold2, 0.4, true)
		for _ = 1, 60 do
			local conf = Lib.new("Frame", { Size = UDim2.fromOffset(10, 16), Position = UDim2.new(math.random(), 0, -0.05, 0), BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1), Rotation = math.random(0, 360), ZIndex = 92, Parent = fxGui })
			Lib.tween(conf, 1.6 + math.random(), { Position = UDim2.new(math.random(), 0, 1.1, 0), Rotation = math.random(-720, 720) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(3, function()
				conf:Destroy()
			end)
		end
		task.delay(2, function()
			f:Destroy()
		end)
	end)
end

return Effects
