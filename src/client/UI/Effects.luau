--!strict
-- Screen effects: toasts, floating "+Scrap", hyperspace jump, server
-- announcements (HoloNet broadcast), rebirth celebration.

local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Styles = require(Shared.Config.Styles)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local CrateReveal = require(script.Parent.CrateReveal)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local Effects = {}

local TOAST_COLORS = {
	info = { C.Blue, C.Blue2 },
	error = { C.Red, C.Red2 },
	success = { C.Green, C.Green2 },
	scrap = { C.Scrap, C.Scrap2 },
	nova = { C.Nova, C.Nova2 },
	purchase = { C.Robux, Color3.fromRGB(20, 130, 70) },
	rebirth = { C.Gold, C.Gold2 },
}

function Effects.Init(gui: ScreenGui, fxGui: ScreenGui)
	-- Toasts ---------------------------------------------------------------------------------
	local toastHolder = Lib.new("Frame", { Size = UDim2.fromOffset(520, 300), Position = UDim2.new(0.5, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = fxGui })
	Lib.fit(toastHolder)
	Lib.list(toastHolder, 6, false, Enum.HorizontalAlignment.Center)
	local order = 0
	State.On("Toast", function(text: string, kind: string?)
		kind = kind or "info"
		order += 1
		if kind ~= "error" then
			table.insert(State.notifications, { text = text, kind = kind :: string, t = os.time() })
			if #State.notifications > 40 then
				table.remove(State.notifications, 1)
			end
			State.unread += 1
			State.Fire("Unread")
		else
			Lib.sound("Error", 0.35)
		end
		local colors = TOAST_COLORS[kind :: string] or TOAST_COLORS.info
		local t = Lib.label({ Text = text, Size = UDim2.fromOffset(500, 44), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = toastHolder })
		Lib.corner(t, 14)
		Lib.gradient(t, colors[1], colors[2], 90)
		Lib.padding(t, 8)
		local s = Lib.new("UIScale", { Scale = 0.4, Parent = t })
		Lib.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(3.2, function()
			Lib.tween(t, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
			task.wait(0.3)
			t:Destroy()
		end)
	end)

	-- Floating +Scrap ------------------------------------------------------------------------
	local function floatText(pos: Vector2, text: string, color: Color3)
		local l = Lib.label({ Text = text, Size = UDim2.fromOffset(160, 40), Position = UDim2.fromOffset(pos.X, pos.Y), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = color, Parent = fxGui })
		local s = Lib.new("UIScale", { Scale = 0.5, Parent = l })
		Lib.tween(s, 0.2, { Scale = 1.2 }, Enum.EasingStyle.Back)
		Lib.tween(l, 0.9, { Position = UDim2.fromOffset(pos.X + math.random(-30, 30), pos.Y - 90), TextTransparency = 1 })
		task.delay(0.9, function()
			l:Destroy()
		end)
	end
	State.On("ClickFxScreen", function(pos: Vector2, value: number)
		floatText(pos, "+" .. Format.Number(value) .. " 🪙", C.Gold)
	end)
	Remotes.Event("ClickFx").OnClientEvent:Connect(function(worldPos: Vector3, value: number)
		local cam = Workspace.CurrentCamera
		local screen, visible = cam:WorldToViewportPoint(worldPos)
		if visible then
			Lib.sound("Salvage", 0.3)
			floatText(Vector2.new(screen.X, screen.Y), "+" .. Format.Number(value) .. " 🪙", C.Gold)
		end
	end)

	-- Hyperspace jump ------------------------------------------------------------------------------
	local jumping = false
	State.On("Hyperspace", function()
		if jumping then
			return
		end
		jumping = true
		Lib.sound("Hyperspace", 0.7)
		local overlay = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 10, 30), BackgroundTransparency = 1, ZIndex = 80, Parent = fxGui })
		Lib.tween(overlay, 0.4, { BackgroundTransparency = 0.05 })
		local streaks = {}
		for i = 1, 70 do
			local ang = math.random() * 360
			local holder = Lib.new("Frame", { Size = UDim2.fromOffset(2, 2), Position = UDim2.fromScale(0.5, 0.5), Rotation = ang, BackgroundTransparency = 1, ZIndex = 81, Parent = overlay })
			local streak = Lib.new("Frame", {
				Size = UDim2.fromOffset(2, 4),
				Position = UDim2.fromOffset(math.random(20, 120), 0),
				BackgroundColor3 = Color3.fromRGB(190, 225, 255),
				ZIndex = 81,
				Parent = holder,
			})
			local _ = i
			table.insert(streaks, streak)
			Lib.tween(streak, 0.9, { Size = UDim2.fromOffset(math.random(200, 600), 3), Position = UDim2.fromOffset(math.random(300, 900), 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.wait(1.1)
		Lib.tween(overlay, 0.3, { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 })
		task.wait(0.3)
		for _, s in streaks do
			s:Destroy()
		end
		Lib.tween(overlay, 0.6, { BackgroundTransparency = 1 })
		task.wait(0.6)
		overlay:Destroy()
		jumping = false
	end)

	-- HoloNet broadcast: server-wide unbox announcements ---------------------------------------
	local banner = Lib.label({ Text = "", Size = UDim2.fromOffset(700, 50), Position = UDim2.new(0.5, 0, 0, -60), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 70, Parent = fxGui })
	Lib.corner(banner, 14)
	local bannerGrad = Lib.gradient(banner, C.Gold, C.Gold2, 0)
	Lib.padding(banner, 8)
	Lib.fit(banner)
	Remotes.Event("Announce").OnClientEvent:Connect(function(a: any)
		local rarity = Rarities.Get(a.rarity)
		local style = Styles.Get(a.style)
		local color = if a.style ~= "Standard" then style.color else rarity.color
		bannerGrad.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.4))
		banner.Text = "🎉 " .. a.text
		Lib.tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, 120) }, Enum.EasingStyle.Back)
		task.delay(5, function()
			Lib.tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, -60) })
		end)
		if a.epic then
			CrateReveal.Fireworks(fxGui)
		end
		-- also post into chat
		pcall(function()
			local channels = TextChatService:FindFirstChild("TextChannels")
			local sys = channels and channels:FindFirstChild("RBXSystem") :: TextChannel?
			if sys then
				local hex = color:ToHex()
				sys:DisplaySystemMessage('<font color="#' .. hex .. '">[HoloNet] 🎉 ' .. a.text .. "</font>")
			end
		end)
	end)

	-- Rebirth celebration ------------------------------------------------------------------------------
	State.On("RebirthFx", function()
		local f = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Gold, BackgroundTransparency = 0.1, ZIndex = 75, Parent = fxGui })
		Lib.tween(f, 1.2, { BackgroundTransparency = 1 })
		local l = Lib.label({ Text = "✨ REBIRTH ✨", Size = UDim2.fromOffset(700, 120), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 76, Parent = fxGui })
		local s = Lib.new("UIScale", { Scale = 0.3, Parent = l })
		Lib.tween(s, 0.6, { Scale = 1 }, Enum.EasingStyle.Elastic)
		CrateReveal.Fireworks(fxGui)
		task.delay(2.2, function()
			Lib.tween(l, 0.4, { TextTransparency = 1 })
			task.wait(0.4)
			l:Destroy()
			f:Destroy()
		end)
	end)

	local _ = gui
end

return Effects
