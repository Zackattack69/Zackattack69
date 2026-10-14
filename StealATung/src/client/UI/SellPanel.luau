--!strict
-- Sell stand: sell unwanted Tungs for 50% of their buy price (plus whatever
-- money is waiting on their pad). Legendary and above need a second tap.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local SellPanel = {}

function SellPanel.Build(): any
	local win = Lib.window("Sell Tungs", Vector2.new(900, 620), Color3.fromRGB(255, 190, 170), "💰")
	local body = win.body
	Lib.label({ Text = "Sell for 50% of the buy price. Bound Tungs (VIP / Group) can't be sold.", Size = UDim2.new(1, 0, 0, 28), Dark = true, TextColor3 = C.SubText, Parent = body })
	local grid = Lib.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -40), Position = UDim2.fromOffset(0, 40), BackgroundTransparency = 1, ScrollBarThickness = 8, ScrollBarImageColor3 = C.Wood2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body })
	local confirmSlot, confirmUntil = 0, 0

	local function render()
		local d = State.data
		if not d then
			return
		end
		for _, c in grid:GetChildren() do
			c:Destroy()
		end
		Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 252), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
		Lib.padding(grid, 6)
		local entries = {}
		for k, s in d.slots do
			table.insert(entries, { slot = tonumber(k) :: number, s = s })
		end
		table.sort(entries, function(a, b)
			return a.slot < b.slot
		end)
		if #entries == 0 then
			grid:ClearAllChildren()
			Lib.label({ Text = "Your base is empty. Buy Tungs from the belt!", Size = UDim2.new(1, 0, 0, 40), Dark = true, Parent = grid })
			return
		end
		for _, e in entries do
			local t = Tungs.Get(e.s.id)
			if not t then
				continue
			end
			local color = Tungs.Color(t)
			local f = Lib.card(grid, { Size = UDim2.fromOffset(196, 252), LayoutOrder = e.slot })
			Lib.tungViewport(f, t.id, e.s.m, UDim2.new(1, -12, 0, 110), UDim2.fromOffset(6, 6), false)
			Lib.label({ Text = Mutations.Prefix(e.s.m) .. t.name, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 118), Dark = true, Parent = f })
			local r = Lib.label({ Text = Tungs.RarityLabel(t), Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 142), TextColor3 = if t.rarity == "Secret" then Color3.new(1, 1, 1) else color, Parent = f })
			Lib.rainbowIfSecret(r, t)
			local price = Economy.SellPrice(t.id, e.s.m) + math.floor(e.s.s or 0)
			local confirming = confirmSlot == e.slot and os.clock() < confirmUntil
			Lib.button({
				Text = if t.bound then "Can't sell" elseif confirming then "Sure? " .. Format.Money(price) else "Sell " .. Format.Money(price),
				Size = UDim2.new(1, -12, 0, 60),
				Position = UDim2.new(0, 6, 1, -66),
				Color = if t.bound then C.Grey elseif confirming then C.Red else C.Money,
				Parent = f,
				OnClick = function()
					if t.bound then
						return
					end
					local rare = Rarities.Order(t.rarity) >= Rarities.Order("Legendary") or e.s.m ~= Mutations.NONE
					if rare and not confirming then
						confirmSlot, confirmUntil = e.slot, os.clock() + 3
						render()
						return
					end
					confirmSlot = 0
					local ok = State.Request("Sell", e.slot)
					if ok then
						Lib.sound("ChaChing")
					end
				end,
			})
		end
	end

	win.onOpen = render
	State.On("Changed", function(full)
		if full and win.isOpen() then
			render()
		end
	end)
	return win
end

return SellPanel
