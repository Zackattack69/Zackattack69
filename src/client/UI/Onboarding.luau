--!strict
-- First-session tutorial (Design Doc §6.7): arrow + pulse ring that highlights
-- the Scrap counter, the crate button (free crate within 30s), then the Map.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Names = require(Shared.Config.StarWarsNames)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local Onboarding = {}

-- Space-opera opening crawl. Tap SKIP (or anywhere) to jump straight in.
function Onboarding.Crawl(fxGui: ScreenGui)
	local crawl = Names.Crawl
	local root = Lib.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 95, Parent = fxGui })
	local rng = Random.new(7)
	for _ = 1, 140 do
		local s = rng:NextInteger(1, 3)
		Lib.new("Frame", { Size = UDim2.fromOffset(s, s), Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber()), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = rng:NextNumber(0, 0.5), ZIndex = 95, Parent = root })
	end
	local skipped = false
	root.Activated:Connect(function()
		skipped = true
	end)
	Lib.button({ Text = "SKIP ⏩", Size = UDim2.fromOffset(140, 50), Position = UDim2.new(1, -24, 1, -24), AnchorPoint = Vector2.new(1, 1), Color = Lib.Colors.Grey, Color2 = Lib.Colors.Grey2, Parent = root, OnClick = function()
		skipped = true
	end })

	local function waitOrSkip(t: number)
		local start = os.clock()
		while not skipped and os.clock() - start < t do
			task.wait()
		end
	end

	-- 1. "A long time ago..." in calm blue
	local intro = Lib.new("TextLabel", { Text = crawl[1], Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(75, 213, 238), TextTransparency = 1, BackgroundTransparency = 1, TextScaled = true, Size = UDim2.fromScale(0.7, 0.08), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 96, Parent = root })
	Lib.tween(intro, 1, { TextTransparency = 0 })
	waitOrSkip(3)
	Lib.tween(intro, 0.8, { TextTransparency = 1 })
	waitOrSkip(1)

	-- 2. giant yellow logo that shrinks away into space
	local logo = Lib.new("TextLabel", { Text = Names.GameTitle, Font = Lib.FontTitle, TextColor3 = Color3.fromRGB(255, 232, 31), BackgroundTransparency = 1, TextScaled = true, Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 96, Parent = root })
	local ls = Lib.new("UIScale", { Scale = 1.6, Parent = logo })
	Lib.tween(ls, 7, { Scale = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Lib.sound("Hyperspace", 0.6)

	-- 3. the yellow crawl scrolling up
	local text = table.concat(crawl, "\n\n", 2)
	local body = Lib.new("TextLabel", { Text = text, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 232, 31), BackgroundTransparency = 1, TextScaled = true, TextWrapped = true, Size = UDim2.fromScale(0.5, 0.75), Position = UDim2.fromScale(0.5, 1.05), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 96, Parent = root })
	task.delay(1.5, function()
		if body.Parent then
			Lib.tween(body, 13, { Position = UDim2.fromScale(0.5, -0.8) }, Enum.EasingStyle.Linear)
		end
	end)
	waitOrSkip(13)
	Lib.tween(root, 0.6, { BackgroundTransparency = 1 })
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			Lib.tween(d, 0.5, { TextTransparency = 1 })
		elseif d:IsA("Frame") then
			Lib.tween(d, 0.5, { BackgroundTransparency = 1 })
		end
	end
	task.wait(0.6)
	root:Destroy()
end

function Onboarding.Run(fxGui: ScreenGui, refs: { [string]: GuiObject })
	local data = State.WaitForData()
	if data.onboarded then
		return
	end
	Onboarding.Crawl(fxGui)

	local ring = Lib.new("Frame", { Size = UDim2.fromOffset(100, 100), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 90, Visible = false, Parent = fxGui })
	Lib.round(ring)
	local ringStroke = Lib.new("UIStroke", { Color = Lib.Colors.Gold, Thickness = 5, Parent = ring })
	local arrow = Lib.label({ Text = "⬇️", Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 91, Stroke = false, Visible = false, Parent = fxGui })
	local tip = Lib.label({ Text = "", Size = UDim2.fromOffset(480, 56), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 91, BackgroundTransparency = 0, BackgroundColor3 = Lib.Colors.Blue2, Visible = false, Parent = fxGui })
	Lib.stroke(tip, Lib.Colors.Outline, 3)
	Lib.corner(tip, 12)
	Lib.padding(tip, 8)

	local target: GuiObject? = nil
	local running = true
	task.spawn(function()
		local t = 0
		while running do
			t += task.wait()
			if target and target.Parent then
				local center = target.AbsolutePosition + target.AbsoluteSize / 2
				local size = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y) + 30
				local pulse = 1 + (t * 1.5) % 1 * 0.35
				ring.Position = UDim2.fromOffset(center.X, center.Y)
				ring.Size = UDim2.fromOffset(size * pulse, size * pulse)
				ringStroke.Transparency = (t * 1.5) % 1
				local above = center.Y > 300
				arrow.Text = if above then "⬇️" else "⬆️"
				arrow.AnchorPoint = if above then Vector2.new(0.5, 1) else Vector2.new(0.5, 0)
				local bob = math.sin(t * 6) * 8
				local edge = size / 2 + 6
				arrow.Position = UDim2.fromOffset(center.X, if above then center.Y - edge + bob else center.Y + edge + bob)
				tip.AnchorPoint = arrow.AnchorPoint
				tip.Position = UDim2.fromOffset(math.clamp(center.X, 240, fxGui.AbsoluteSize.X - 240), if above then center.Y - edge - 64 else center.Y + edge + 64)
			end
		end
	end)

	local function step(ref: GuiObject?, text: string)
		target = ref
		ring.Visible = ref ~= nil
		arrow.Visible = ref ~= nil
		tip.Visible = ref ~= nil
		tip.Text = text
	end

	-- Step 1: Scrap counter
	step(refs.scrap, "These are your " .. string.upper(Names.Currency.Scrap) .. ". Your droids earn them for you!")
	task.wait(4)

	-- Step 2: free crate
	step(refs.crate, "Open your FREE crate to get your first droid!")
	local opened = false
	local startCrates = data.stats.crates
	while not opened do
		task.wait(0.3)
		opened = State.data.stats.crates > startCrates
		if opened then
			break
		end
	end
	-- let the reveal finish
	task.wait(4)

	-- Step 3: Map
	step(refs.map, "Rebirth to unlock new planets on the Galaxy Map!")
	task.wait(5)

	running = false
	ring:Destroy()
	arrow:Destroy()
	tip:Destroy()
	State.Request("FinishOnboarding")
	State.Fire("Toast", "Tip: click junk piles to salvage, and keep opening crates for ICONIC droids!", "success")
end

return Onboarding
