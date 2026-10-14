--!strict
-- Rebirth confirmation (Design Doc §6.5): "You Lose" vs "You Gain", and a gold
-- REBIRTH button that must be HELD for 2 seconds.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Names = require(Shared.Config.StarWarsNames)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local RebirthPanel = {}

local HOLD_TIME = 2

function RebirthPanel.Build(): any
	local win = Lib.window("Rebirth", Vector2.new(780, 560), C.Gold, C.Gold2, "♻️")
	local body = win.body

	local function column(x: number, title: string, c1: Color3, c2: Color3): Frame
		local f = Lib.new("Frame", { Size = UDim2.new(0.5, -8, 0, 300), Position = UDim2.new(x, if x > 0 then 8 else 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = body })
		Lib.corner(f, 18)
		Lib.gradient(f, c1, c2, 90)
		Lib.stroke(f, c2:Lerp(Color3.new(0, 0, 0), 0.5), 3)
		Lib.label({ Text = title, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 8), Parent = f })
		local list = Lib.new("Frame", { Name = "List", Size = UDim2.new(1, -24, 1, -60), Position = UDim2.fromOffset(12, 54), BackgroundTransparency = 1, Parent = f })
		Lib.list(list, 6)
		return list
	end
	local loseList = column(0, "❌ YOU LOSE", Color3.fromRGB(200, 60, 70), Color3.fromRGB(110, 20, 35))
	local gainList = column(0.5, "✅ YOU GAIN", Color3.fromRGB(60, 190, 90), Color3.fromRGB(20, 100, 45))

	local holdBtn = Lib.button({ Text = "HOLD TO REBIRTH", Size = UDim2.fromOffset(420, 80), Position = UDim2.new(0.5, 0, 1, -50), AnchorPoint = Vector2.new(0.5, 1), Color = C.Gold, Color2 = C.Gold2, Parent = body })
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, ZIndex = 2, Parent = holdBtn })
	Lib.corner(fill, 14)
	-- shimmer stripe
	local shimmer = Lib.new("Frame", { Size = UDim2.new(0, 30, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, Rotation = 15, ZIndex = 2, Parent = holdBtn })
	holdBtn.ClipsDescendants = true
	local skipToggle = Lib.button({ Text = "", Size = UDim2.fromOffset(300, 34), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), Color = C.Purple, Color2 = C.Purple2, Parent = body })
	local useSkip = false

	local function line(parent: Instance, text: string, order: number)
		Lib.label({ Text = text, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = parent })
	end

	local function render()
		local data = State.data
		if not data then
			return
		end
		for _, l in { loseList, gainList } do
			for _, c in l:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
		end
		local cost = Economy.RebirthCost(data.rebirths)
		line(loseList, Names.CurrencyIcon.Scrap .. " " .. Format.Number(data.scrap) .. " " .. Names.Currency.Scrap, 1)
		line(loseList, "🦾 Salvage Claws Lv " .. data.upgrades.Claws, 2)
		line(loseList, "🏭 Assembly Line Lv " .. data.upgrades.Assembly, 3)
		line(loseList, "🛰️ Station Bay Lv " .. data.upgrades.Bay, 4)
		line(loseList, "(You KEEP droids, " .. Names.Currency.Nova .. ", titles & planets)", 5)

		local nextR = data.rebirths + 1
		line(gainList, "✖️ Multiplier x" .. Economy.RebirthMultiplier(data.rebirths) .. " → x" .. Economy.RebirthMultiplier(nextR), 1)
		local nextWorld = Worlds.Get(nextR + 1)
		if nextWorld and not data.allMaps then
			line(gainList, "🗺️ Unlock " .. nextWorld.name, 2)
		end
		line(gainList, "🏅 " .. (Economy.RebirthTitle(nextR) or ""), 3)
		line(gainList, "🎁 1 free Rare Crate", 4)
		line(gainList, Names.CurrencyIcon.Nova .. " +" .. Economy.RebirthNovaReward(data.rebirths) .. " " .. Names.Currency.Nova, 5)
		if nextR <= 6 then
			line(gainList, "📍 +1 station slot", 6)
		end

		local skips = data.tokens.RebirthSkip or 0
		local canAfford = data.scrap >= cost
		skipToggle.Visible = skips > 0 and not canAfford
		useSkip = skips > 0 and not canAfford
		skipToggle.Text = "⏩ Using Rebirth Skip Token (" .. skips .. " left)"
		holdBtn.Text = if canAfford or useSkip then "HOLD TO REBIRTH" else "NEED " .. Format.Number(cost) .. " " .. string.upper(Names.Currency.Scrap)
		Lib.recolor(holdBtn, if canAfford or useSkip then C.Gold else C.Grey, if canAfford or useSkip then C.Gold2 else C.Grey2)
	end

	-- 2-second hold to confirm
	local holding = false
	local function release()
		holding = false
		Lib.tween(fill, 0.2, { Size = UDim2.fromScale(0, 1) })
	end
	holdBtn.MouseButton1Down:Connect(function()
		local data = State.data
		if not data or holding then
			return
		end
		if data.scrap < Economy.RebirthCost(data.rebirths) and not useSkip then
			Lib.sound("Error", 0.4)
			return
		end
		holding = true
		local start = os.clock()
		while holding do
			local a = (os.clock() - start) / HOLD_TIME
			fill.Size = UDim2.fromScale(math.min(a, 1), 1)
			if a >= 1 then
				holding = false
				fill.Size = UDim2.fromScale(0, 1)
				local ok = State.Request("Rebirth", useSkip)
				if ok then
					Lib.sound("Rebirth", 0.8)
					win.close()
					State.Fire("RebirthFx")
				end
				return
			end
			task.wait()
		end
	end)
	holdBtn.MouseButton1Up:Connect(release)
	holdBtn.MouseLeave:Connect(release)

	task.spawn(function()
		while holdBtn.Parent do
			shimmer.Position = UDim2.new(-0.1, 0, 0, 0)
			Lib.tween(shimmer, 0.9, { Position = UDim2.new(1.1, 0, 0, 0) })
			task.wait(2)
		end
	end)

	win.onOpen = render
	State.On("Changed", function()
		if win.isOpen() and not holding then
			render()
		end
	end)
	return win
end

return RebirthPanel
