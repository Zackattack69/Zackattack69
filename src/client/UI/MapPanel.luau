--!strict
-- Galaxy Map: a starfield with a carousel of planet cards. Locked planets are
-- greyed out with a padlock; each card shows who is on that planet right now.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Droids = require(Shared.Config.Droids)
local Rarities = require(Shared.Config.Rarities)
local Worlds = require(Shared.Config.Worlds)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local MapPanel = {}

local thumbCache: { [number]: string } = {}
local function avatar(userId: number): string
	if thumbCache[userId] then
		return thumbCache[userId]
	end
	local ok, img = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	thumbCache[userId] = if ok then img else ""
	return thumbCache[userId]
end

-- A shaded planet: gradient sphere + highlight + optional ring.
local function planetArt(parent: Instance, world: Worlds.World, size: number, y: number)
	local planet = Lib.new("Frame", { Size = UDim2.fromOffset(size, size), Position = UDim2.new(0.5, 0, 0, y), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent })
	Lib.round(planet)
	Lib.gradient(planet, world.colors.accent:Lerp(Color3.new(1, 1, 1), 0.25), world.colors.ground:Lerp(Color3.new(0, 0, 0), 0.35), 45)
	Lib.stroke(planet, C.Outline, 3)
	local shine = Lib.new("Frame", { Size = UDim2.fromScale(0.32, 0.22), Position = UDim2.fromScale(0.22, 0.16), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, Rotation = -30, Parent = planet })
	Lib.round(shine)
	if world.index == 5 or world.index == 2 then
		local ringF = Lib.new("Frame", { Size = UDim2.fromScale(1.45, 0.14), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -18, BackgroundColor3 = world.colors.accent2, BackgroundTransparency = 0.15, Parent = planet })
		Lib.round(ringF)
		Lib.stroke(ringF, C.Outline, 2)
	end
	Lib.label({ Text = world.icon, Size = UDim2.fromScale(0.42, 0.42), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = planet })
	return planet
end

function MapPanel.Build(): any
	local win = Lib.window("Galaxy Map", Vector2.new(1000, 620), C.Pink, C.Purple2, "🪐")
	local body = win.body
	local selectedWorld = 1

	-- starfield backdrop
	local space = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 330), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = body })
	Lib.corner(space, 18)
	Lib.gradient(space, Color3.fromRGB(25, 20, 60), Color3.fromRGB(8, 8, 25), 90)
	Lib.stroke(space, C.Outline, 3)
	local rng = Random.new(42)
	for _ = 1, 90 do
		local s = rng:NextInteger(1, 3)
		local star = Lib.new("Frame", { Size = UDim2.fromOffset(s, s), Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber()), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = rng:NextNumber(0, 0.6), Parent = space })
		Lib.round(star)
	end

	local carousel = Lib.new("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = space,
	})
	Lib.padding(carousel, 10)
	Lib.list(carousel, 16, true)

	local detail = Lib.card(body, { Size = UDim2.new(1, 0, 1, -344), Position = UDim2.fromOffset(0, 344) })

	local function playersIn(index: number): { Player }
		local list = {}
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("World") == index then
				table.insert(list, p)
			end
		end
		return list
	end

	local rebuild: () -> ()

	local function renderDetail()
		for _, c in detail:GetChildren() do
			if c:IsA("GuiObject") or c:IsA("UIPadding") then
				c:Destroy()
			end
		end
		Lib.padding(detail, 16)
		local data = State.data
		local world = Worlds.Get(selectedWorld)
		local unlocked = Worlds.IsUnlocked(world.index, data.rebirths, data.allMaps)

		Lib.label({ Text = world.icon .. " " .. world.name, Font = Lib.FontTitle, Size = UDim2.new(0.56, 0, 0, 40), TextColor3 = world.colors.accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		Lib.label({ Text = world.planet, Size = UDim2.new(0.56, 0, 0, 48), Position = UDim2.fromOffset(0, 44), Dark = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
		Lib.label({ Text = "💰 x" .. world.incomeMult .. " income here  •  🏠 home droids +25%", Size = UDim2.new(0.56, 0, 0, 24), Position = UDim2.fromOffset(0, 98), TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })

		-- droid pool preview
		local pool = Lib.new("Frame", { Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.fromScale(0.58, 0), BackgroundTransparency = 1, Parent = detail })
		Lib.list(pool, 2)
		Lib.label({ Text = "📖 DROIDS FOUND HERE", Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = pool })
		for _, r in Rarities.List do
			if r.name ~= "Mythic" and r.name ~= "Iconic" then
				local list = Droids.Pool(r.name, world.index)
				local owned = 0
				for _, d in list do
					if data.discovered[tostring(d.id)] then
						owned += 1
					end
				end
				Lib.label({ Text = string.format("%s  %d/%d", r.name, owned, #list), Size = UDim2.new(1, 0, 0, 22), TextColor3 = r.color, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = r.index, Parent = pool })
			end
		end

		local btnPos = UDim2.new(0, 0, 1, -58)
		if data.world == world.index then
			Lib.button({ Text = "📍 YOU ARE HERE", Size = UDim2.fromOffset(300, 58), Position = btnPos, Color = C.Grey, Color2 = C.Grey2, Parent = detail })
		elseif unlocked then
			Lib.button({ Text = "🚀 JUMP TO HYPERSPACE", Size = UDim2.fromOffset(300, 58), Position = btnPos, Color = C.Green, Color2 = C.Green2, Parent = detail, OnClick = function()
				win.close()
				if State.Request("Travel", world.index) then
					State.Fire("Hyperspace", world.index)
				end
			end })
		else
			Lib.button({ Text = "🔒 Reach Rebirth " .. world.unlockRebirth, Size = UDim2.fromOffset(300, 58), Position = btnPos, Color = C.Grey, Color2 = C.Grey2, Parent = detail })
		end
	end

	rebuild = function()
		local data = State.data
		if not data then
			return
		end
		for _, c in carousel:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, world in Worlds.List do
			local unlocked = Worlds.IsUnlocked(world.index, data.rebirths, data.allMaps)
			local isSel = world.index == selectedWorld
			local card = Lib.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(190, 290), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = world.index, Parent = carousel })
			Lib.corner(card, 20)
			Lib.gradient(card, Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 225, 245), 90)
			Lib.stroke(card, if isSel then C.Gold else C.Outline, if isSel then 5 else 3)
			planetArt(card, world, 120, 16)
			Lib.label({ Text = world.name, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 146), TextColor3 = world.colors.accent, Parent = card })
			Lib.label({ Text = world.theme, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 178), Dark = true, TextColor3 = C.SubText, Parent = card })
			Lib.label({ Text = "x" .. world.incomeMult .. " 💰", Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 202), TextColor3 = C.Gold, Parent = card })

			local bubbles = Lib.new("Frame", { Size = UDim2.new(1, -12, 0, 34), Position = UDim2.new(0, 6, 1, -44), BackgroundTransparency = 1, Parent = card })
			Lib.list(bubbles, -8, true, Enum.HorizontalAlignment.Center)
			for i, p in playersIn(world.index) do
				local img = Lib.new("ImageLabel", { Size = UDim2.fromOffset(32, 32), BackgroundColor3 = C.Blue, Image = "", LayoutOrder = i, Parent = bubbles })
				Lib.round(img)
				Lib.stroke(img, Color3.new(1, 1, 1), 2)
				task.spawn(function()
					img.Image = avatar(p.UserId)
				end)
			end

			if not unlocked then
				local lock = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 32, 50), BackgroundTransparency = 0.3, ZIndex = 12, Parent = card })
				Lib.corner(lock, 20)
				Lib.label({ Text = "🔒", Size = UDim2.fromOffset(70, 70), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, ZIndex = 13, Parent = lock })
				Lib.label({ Text = "Rebirth " .. world.unlockRebirth, Size = UDim2.new(1, -10, 0, 30), Position = UDim2.new(0, 5, 0.58, 0), ZIndex = 13, Parent = lock })
			end
			local s = Lib.new("UIScale", { Parent = card })
			card.MouseEnter:Connect(function()
				Lib.tween(s, 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back)
			end)
			card.MouseLeave:Connect(function()
				Lib.tween(s, 0.12, { Scale = 1 })
			end)
			card.Activated:Connect(function()
				Lib.sound("Click", 0.3)
				selectedWorld = world.index
				rebuild()
			end)
		end
		renderDetail()
	end

	win.onOpen = function()
		if State.data then
			selectedWorld = State.data.world
		end
		rebuild()
	end
	State.On("Changed", function(full)
		if full and win.isOpen() then
			rebuild()
		end
	end)
	return win
end

return MapPanel
