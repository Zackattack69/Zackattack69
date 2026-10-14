--!strict
-- Screen effects: small toasts, big centre banners that slide down from the
-- top and fade after 3 seconds (rare spawns, steals, events), the bouncy
-- "+$12.4K" collect pop, the red siren flash when you're being robbed, and the
-- white rebirth flash.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local Effects = {}

local TOAST_COLORS: { [string]: { Color3 } } = {
	info = { C.Wood, C.Wood2 },
	error = { C.Red, C.Red2 },
	success = { C.Green, C.Green2 },
	money = { C.Money, C.Money2 },
	steal = { C.Red, C.Red2 },
	purchase = { C.Robux, Color3.fromRGB(20, 130, 70) },
	hype = { C.Purple, C.Purple2 },
}

function Effects.Init(fxGui: ScreenGui)
	-- Toasts (bottom-ish centre, above the prompts) -------------------------------------------------
	local toastHolder = Lib.new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(560, 260), Position = UDim2.new(0.5, 0, 0, 150), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = fxGui })
	Lib.hudFit(toastHolder)
	Lib.list(toastHolder, 6, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top
	local order = 0
	State.On("Toast", function(text: string, kind: string?)
		local k = kind or "info"
		order += 1
		if k == "error" then
			Lib.sound("Error")
		end
		local colors = TOAST_COLORS[k] or TOAST_COLORS.info
		local t = Lib.label({ Text = text, Size = UDim2.fromOffset(540, 44), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = toastHolder })
		Lib.corner(t, 14)
		Lib.gradient(t, colors[1], colors[2], 90)
		Lib.stroke(t, C.Outline, 2.5)
		Lib.padding(t, 8)
		local s = Lib.new("UIScale", { Scale = 0.4, Parent = t })
		Lib.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(3, function()
			Lib.tween(t, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
			local st = t:FindFirstChildOfClass("UIStroke")
			if st then
				Lib.tween(st, 0.3, { Transparency = 1 })
			end
			task.wait(0.3)
			t:Destroy()
		end)
		-- keep at most 4 toasts
		local kids = {}
		for _, c in toastHolder:GetChildren() do
			if c:IsA("TextLabel") then
				table.insert(kids, c)
			end
		end
		if #kids > 4 then
			table.sort(kids, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			kids[1]:Destroy()
		end
	end)

	-- Centre banners -------------------------------------------------------------------------------------------
	local queue: { any } = {}
	local showing = false
	local banner = Lib.new("Frame", { Name = "Banner", Size = UDim2.fromOffset(820, 96), Position = UDim2.new(0.5, 0, 0, -140), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 70, Parent = fxGui })
	Lib.hudFit(banner)
	Lib.corner(banner, 26)
	local bannerGrad = Lib.gradient(banner, C.Gold, C.Gold2, 90)
	Lib.stroke(banner, C.Outline, 4)
	local bannerText = Lib.label({ Text = "", Size = UDim2.new(1, -40, 1, -20), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 71, Parent = banner })
	local rainbow = Lib.new("UIGradient", { Color = Rarities.RAINBOW, Enabled = false, Parent = banner })

	local function nextBanner()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local b = table.remove(queue, 1)
		local color: Color3 = b.color or C.Gold
		bannerGrad.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.4))
		bannerGrad.Enabled = not b.rainbow
		rainbow.Enabled = b.rainbow == true
		bannerText.Text = b.text
		banner.BackgroundTransparency = 0
		bannerText.TextTransparency = 0
		banner.Position = UDim2.new(0.5, 0, 0, -140)
		Lib.tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, 96) }, Enum.EasingStyle.Back)
		if b.sound then
			Lib.sound(b.sound)
		end
		local textStroke = bannerText:FindFirstChildOfClass("UIStroke")
		if textStroke then
			textStroke.Transparency = 0
		end
		task.delay(3, function()
			Lib.tween(banner, 0.35, { BackgroundTransparency = 1 })
			Lib.tween(bannerText, 0.35, { TextTransparency = 1 })
			if textStroke then
				Lib.tween(textStroke, 0.35, { Transparency = 1 })
			end
			task.wait(0.4)
			banner.Position = UDim2.new(0.5, 0, 0, -140)
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
	local vStroke = Lib.new("UIStroke", { Color = C.Red2, Thickness = 0, Transparency = 0.2, Parent = vignette })
	local function siren()
		task.spawn(function()
			for _ = 1, 4 do
				Lib.sound("Siren", nil, 0.75)
				Lib.tween(vStroke, 0.2, { Thickness = 26 })
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
			then "🔥 A MYTHIC TUNG IS ON THE BELT! " .. string.upper(name) .. " 🔥"
			elseif level == "Secret" then "🌑 A SECRET TUNG IS ON THE BELT! 🌑"
			else "✨ A LEGENDARY TUNG IS ON THE BELT! ✨"
		pushBanner({ text = text, color = color, sound = "Spawn" .. level, rainbow = level == "Secret" })
	end)

	-- Collect pop: big bouncy "+$X" -----------------------------------------------------------------------------
	State.On("CollectPop", function(amount: number)
		if amount >= 1e5 then
			Lib.sound("Jackpot")
		else
			Lib.sound("ChaChing", nil, 1.3 + math.random() * 0.3)
		end
		local l = Lib.label({ Text = "+" .. Format.Money(amount), Size = UDim2.fromOffset(420, 90), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = C.Money, ZIndex = 50, Parent = fxGui })
		local s = Lib.new("UIScale", { Scale = 0.3, Parent = l })
		Lib.tween(s, 0.35, { Scale = Lib.HudScale() * 1.1 }, Enum.EasingStyle.Back)
		task.delay(0.6, function()
			Lib.tween(l, 0.6, { Position = UDim2.fromScale(0.5, 0.3), TextTransparency = 1 })
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then
				Lib.tween(st, 0.6, { Transparency = 1 })
			end
			task.wait(0.65)
			l:Destroy()
		end)
		State.Fire("MoneyGlow")
	end)

	-- Rebirth flash -------------------------------------------------------------------------------------------------
	State.On("RebirthFlash", function()
		Lib.sound("Rebirth")
		local f = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 90, Parent = fxGui })
		Lib.tween(f, 1.4, { BackgroundTransparency = 1 })
		local l = Lib.label({ Text = "✨ REBIRTH! ✨", Size = UDim2.fromOffset(760, 140), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = C.Gold, ZIndex = 91, Parent = fxGui })
		local s = Lib.new("UIScale", { Scale = 0.2, Parent = l })
		Lib.tween(s, 0.7, { Scale = Lib.HudScale() }, Enum.EasingStyle.Elastic)
		-- confetti
		for _ = 1, 50 do
			local conf = Lib.new("Frame", { Size = UDim2.fromOffset(10, 16), Position = UDim2.new(math.random(), 0, -0.05, 0), BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1), Rotation = math.random(0, 360), ZIndex = 92, Parent = fxGui })
			Lib.tween(conf, 1.6 + math.random(), { Position = UDim2.new(math.random(), 0, 1.1, 0), Rotation = math.random(-720, 720) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(3, function()
				conf:Destroy()
			end)
		end
		task.delay(2.4, function()
			Lib.tween(l, 0.4, { TextTransparency = 1 })
			task.wait(0.45)
			l:Destroy()
			f:Destroy()
		end)
	end)
end

return Effects
