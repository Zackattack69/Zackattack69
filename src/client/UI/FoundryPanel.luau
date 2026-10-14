--!strict
-- Foundry upgrades (reset on rebirth).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Names = require(Shared.Config.StarWarsNames)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local FoundryPanel = {}

function FoundryPanel.Build(): any
	local win = Lib.window("Foundry Upgrades", Vector2.new(720, 480), C.Green, C.Green2, "🏭")
	local body = win.body
	Lib.list(body, 10)

	local rows = {}
	for i, u in Economy.Upgrades do
		local row = Lib.card(nil, { Size = UDim2.new(1, 0, 0, 104), BackgroundColor3 = C.Card, LayoutOrder = i, Parent = body })
		Lib.corner(row, 16)
		Lib.label({ Text = u.icon, Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(10, 12), Stroke = false, Parent = row })
		local name = Lib.label({ Text = u.name, Size = UDim2.new(1, -330, 0, 34), Position = UDim2.fromOffset(100, 12), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local desc = Lib.label({ Text = u.description, Size = UDim2.new(1, -330, 0, 24), Position = UDim2.fromOffset(100, 50), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local btn = Lib.button({
			Text = "",
			Size = UDim2.fromOffset(200, 70),
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = C.Green,
			Color2 = C.Green2,
			Parent = row,
			OnClick = function()
				if State.Request("BuyUpgrade", u.id) then
					Lib.sound("Purchase", 0.5)
				end
			end,
		})
		rows[u.id] = { name = name, desc = desc, btn = btn }
	end
	Lib.label({ Text = "Upgrades reset when you Rebirth — but your multiplier makes them cheap to rebuy!", Size = UDim2.new(1, 0, 0, 24), TextColor3 = C.SubText, LayoutOrder = 10, Parent = body })

	local function render()
		local data = State.data
		if not data then
			return
		end
		for _, u in Economy.Upgrades do
			local r = rows[u.id]
			local level = data.upgrades[u.id] or 0
			r.name.Text = u.name .. "  Lv " .. level .. (if level >= u.maxLevel then " (MAX)" else "")
			if level >= u.maxLevel then
				r.btn.Text = "MAXED"
				Lib.recolor(r.btn, C.Grey, C.Grey2)
			else
				local cost = Economy.UpgradeCost(u.id, level, data.rebirths)
				r.btn.Text = Names.CurrencyIcon.Scrap .. " " .. Format.Number(cost)
				local ok = data.scrap >= cost
				Lib.recolor(r.btn, if ok then C.Green else C.Grey, if ok then C.Green2 else C.Grey2)
			end
		end
	end

	win.onOpen = render
	State.On("Changed", function()
		if win.isOpen() then
			render()
		end
	end)
	return win
end

return FoundryPanel
