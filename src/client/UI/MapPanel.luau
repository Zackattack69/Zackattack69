--!strict
-- Map Select (Design Doc §6.2): horizontal carousel of 8 world cards, locked
-- cards greyed with a padlock, per-world player bubbles, and a detail strip.

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

function MapPanel.Build(): any
	local win = Lib.window("Galaxy Map", Vector2.new(980, 580), C.Nova, C.Nova2)
	local body = win.body
	local selectedWorld = 1

	local carousel = Lib.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 300),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = body,
	})
	Lib.padding(carousel, 6)
	Lib.list(carousel, 14, true)

	local detail = Lib.new("Frame", { Size = UDim2.new(1, 0, 1, -312), Position = UDim2.fromOffset(0, 312), BackgroundColor3 = C.Card, Parent = body })
	Lib.corner(detail, 16)

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
		detail:ClearAllChildren()
		Lib.corner(detail, 16)
		Lib.padding(detail, 14)
		local data = State.data
		local world = Worlds.Get(selectedWorld)
		local unlocked = Worlds.IsUnlocked(world.index, data.rebirths, data.allMaps)

		Lib.label({ Text = world.name, Size = UDim2.new(0.55, 0, 0, 36), TextColor3 = world.colors.accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		Lib.label({ Text = world.planet, Size = UDim2.new(0.55, 0, 0, 44), Position = UDim2.fromOffset(0, 38), TextColor3 = C.SubText, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		Lib.label({
			Text = "Station bonus: x" .. world.incomeMult .. " income  •  Home droids +25%",
			Size = UDim2.new(0.55, 0, 0, 24),
			Position = UDim2.fromOffset(0, 88),
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = detail,
		})

		-- Droid pool preview
		local pool = Lib.new("Frame", { Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.fromScale(0.58, 0), BackgroundTransparency = 1, Parent = detail })
		Lib.list(pool, 2)
		Lib.label({ Text = "DROID POOL", Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = pool })
		for _, r in Rarities.List do
			if r.name ~= "Mythic" then
				local list = Droids.Pool(r.name, world.index)
				local owned = 0
				for _, d in list do
					if data.discovered[tostring(d.id)] then
						owned += 1
					end
				end
				local sample = if list[1] then list[1].name .. (if list[2] then ", " .. list[2].name else "") else ""
				Lib.label({ Text = string.format("%s %d/%d — %s…", r.name, owned, #list, sample), Size = UDim2.new(1, 0, 0, 20), TextColor3 = r.color, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = r.index, Parent = pool })
			end
		end

		if data.world == world.index then
			Lib.button({ Text = "YOU ARE HERE", Size = UDim2.fromOffset(260, 56), Position = UDim2.new(0, 0, 1, -56), Color = C.Grey, Parent = detail })
		elseif unlocked then
			Lib.button({ Text = "🚀 TRAVEL HERE", Size = UDim2.fromOffset(260, 56), Position = UDim2.new(0, 0, 1, -56), Color = C.Green, Color2 = C.Green2, Parent = detail, OnClick = function()
				win.close()
				if State.Request("Travel", world.index) then
					State.Fire("Hyperspace", world.index)
				end
			end })
		else
			Lib.button({ Text = "🔒 Reach Rebirth " .. world.unlockRebirth, Size = UDim2.fromOffset(260, 56), Position = UDim2.new(0, 0, 1, -56), Color = C.Grey, Parent = detail })
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
			local card = Lib.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(200, 280), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = world.index, Parent = carousel })
			Lib.corner(card, 18)
			Lib.gradient(card, world.colors.fog, world.colors.ground:Lerp(Color3.new(0, 0, 0), 0.5), 90)
			local st = Lib.stroke(card, if world.index == selectedWorld then C.Gold else Color3.new(0, 0, 0), if world.index == selectedWorld then 5 else 3)
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

			-- planet thumbnail
			local planet = Lib.new("Frame", { Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0, 20), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
			Lib.round(planet)
			Lib.gradient(planet, world.colors.accent, world.colors.ground, 45)
			local ring = Lib.new("Frame", { Size = UDim2.fromOffset(170, 14), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -15, BackgroundColor3 = world.colors.accent2, BackgroundTransparency = 0.3, Parent = planet })
			Lib.round(ring)
			Lib.label({ Text = world.index .. ". " .. world.name, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 150), Parent = card })
			Lib.label({ Text = world.theme, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 180), TextColor3 = Color3.fromRGB(230, 230, 240), Parent = card })

			-- server population bubbles (up to 10 per server)
			local bubbles = Lib.new("Frame", { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 1, -40), BackgroundTransparency = 1, Parent = card })
			Lib.list(bubbles, -8, true, Enum.HorizontalAlignment.Center)
			for i, p in playersIn(world.index) do
				local img = Lib.new("ImageLabel", { Size = UDim2.fromOffset(30, 30), BackgroundColor3 = C.Panel, Image = "", LayoutOrder = i, Parent = bubbles })
				Lib.round(img)
				Lib.stroke(img, Color3.new(1, 1, 1), 2)
				task.spawn(function()
					img.Image = avatar(p.UserId)
				end)
			end

			if not unlocked then
				local lock = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 20, 25), BackgroundTransparency = 0.35, ZIndex = 12, Parent = card })
				Lib.corner(lock, 18)
				Lib.label({ Text = "🔒", Size = UDim2.fromOffset(70, 70), Position = UDim2.fromScale(0.5, 0.35), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, ZIndex = 13, Parent = lock })
				Lib.label({ Text = "Reach Rebirth " .. world.unlockRebirth, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.new(0, 5, 0.58, 0), ZIndex = 13, Parent = lock })
			end
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
