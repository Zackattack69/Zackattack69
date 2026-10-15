--!strict
-- Egg hatching: the egg bounces in, wobbles harder and harder, cracks with a
-- white flash, and the Tung pops out spinning with its name and rarity.
-- Also draws the little egg pictures used in the Shop.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local Tungs = require(Shared.Config.Tungs)

local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local WHITE = Color3.new(1, 1, 1)
local Hatch = {}

-- An egg drawn with frames: an oval with the egg's colours and a few spots.
function Hatch.EggShape(parent: Instance, egg: Eggs.Egg, height: number): Frame
	local f = Lib.new("Frame", {
		Name = "Egg",
		Size = UDim2.fromOffset(height * 0.78, height),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	Lib.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	if egg.key == "Rainbow" then
		Lib.new("UIGradient", { Color = Rarities.RAINBOW, Rotation = 60, Parent = f })
	else
		Lib.gradient(f, egg.color:Lerp(WHITE, 0.3), egg.color2, 90)
	end
	Lib.stroke(f, C.Outline, math.max(2, height / 45))
	for _, s in { { 0.3, 0.32, 0.2 }, { 0.68, 0.5, 0.15 }, { 0.42, 0.72, 0.13 } } do
		local spot = Lib.new("Frame", {
			Size = UDim2.fromScale(s[3], s[3] * 0.78),
			Position = UDim2.fromScale(s[1], s[2]),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.4,
			Parent = f,
		})
		Lib.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = spot })
	end
	if egg.key == "Moon" then
		Lib.label({ Text = "🌙", Size = UDim2.fromScale(0.5, 0.4), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = f })
	end
	return f
end

local queue: { any } = {}
local busy = false
local gui: ScreenGui

local function play(d: any)
	local egg = Eggs.ByKey[d.egg]
	local t = Tungs.Get(d.tung)
	if not egg or not t then
		return
	end
	local overlay = Lib.new("TextButton", { Name = "Hatch", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 8, 24), BackgroundTransparency = 1, ZIndex = 80, Parent = gui })
	Lib.tween(overlay, 0.3, { BackgroundTransparency = 0.4 })
	local holder = Lib.new("Frame", { Size = UDim2.fromOffset(420, 470), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = overlay })
	Lib.new("UIScale", { Scale = Lib.HudScale(), Parent = holder })
	local title = Lib.title({ Text = egg.name, Size = UDim2.new(1, 0, 0, 48), Parent = holder })
	local stage = Lib.new("Frame", { Size = UDim2.fromOffset(260, 270), Position = UDim2.new(0.5, 0, 0, 60), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = holder })

	-- bounce in, then wobble harder and harder
	local e = Hatch.EggShape(stage, egg, 230)
	e.Position = UDim2.fromScale(0.5, -0.8)
	Lib.tween(e, 0.5, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Bounce)
	task.wait(0.7)
	for k = 1, 11 do
		local a = 3 + k * 2
		e.Rotation = if k % 2 == 0 then a else -a
		Lib.sound("Pop", 0.2, 0.8 + k * 0.06)
		task.wait(math.max(0.07, 0.17 - k * 0.009))
	end

	-- crack!
	local flash = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 5, Parent = overlay })
	Lib.tween(flash, 0.7, { BackgroundTransparency = 1 })
	task.delay(0.8, function()
		flash:Destroy()
	end)
	e:Destroy()

	-- reveal
	local special = Rarities.Order(t.rarity) >= Rarities.Order("Legendary") or d.mut ~= Mutations.NONE
	if special then
		Lib.rays(stage, Tungs.Color(t):Lerp(WHITE, 0.4), 460, 12, 0)
		Lib.sound("Jackpot")
	else
		Lib.sound("Purchase")
	end
	local vp = Lib.tungViewport(stage, t.id, d.mut, UDim2.fromScale(1, 1), UDim2.new(), true)
	local pop = Lib.new("UIScale", { Scale = 0.3, Parent = vp })
	Lib.tween(pop, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	Lib.sparkles(stage, 8, Color3.fromRGB(255, 255, 180))
	title.Text = Mutations.Prefix(d.mut) .. t.name
	local r = Lib.label({ Text = Tungs.RarityLabel(t), Font = Lib.FontTitle, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 336), Parent = holder })
	Lib.rarityText(r, t)
	Lib.label({ Text = "Added to your base!", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 372), Parent = holder })

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Lib.tween(overlay, 0.25, { BackgroundTransparency = 1 })
		holder.Visible = false
		task.delay(0.3, function()
			overlay:Destroy()
		end)
	end
	Lib.button({ Text = "Nice!", Size = UDim2.fromOffset(200, 56), Position = UDim2.new(0.5, -100, 0, 408), Color = C.Green, Color2 = C.Green2, Parent = holder, OnClick = close })
	overlay.Activated:Connect(close)
	task.delay(7, close)
	while not closed do
		task.wait(0.1)
	end
	task.wait(0.3)
end

local function pump()
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		local d = table.remove(queue, 1)
		local ok, err = pcall(play :: any, d)
		if not ok then
			warn("[Hatch]", err)
		end
	end
	busy = false
end

function Hatch.Init(fxGui: ScreenGui)
	gui = fxGui
	Remotes.Event("Hatch").OnClientEvent:Connect(function(d)
		table.insert(queue, d)
		task.spawn(pump)
	end)
end

return Hatch
