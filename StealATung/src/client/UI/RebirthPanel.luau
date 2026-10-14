--!strict
-- Rebirth menu (opened from the Rebirth Altar or the HUD): what you lose on the
-- left in red, what you gain on the right in green, the requirements, and a big
-- REBIRTH button that needs a second confirm tap.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local RebirthPanel = {}

function RebirthPanel.Build(): any
	local win = Lib.window("Rebirth", Vector2.new(860, 600), Lib.Colors.Gold, "♻️")
	local body = win.body

	local function column(x: number, title: string, c1: Color3, c2: Color3): Frame
		local f = Lib.new("Frame", { Size = UDim2.new(0.5, -8, 0, 290), Position = UDim2.new(x, if x > 0 then 8 else 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = body })
		Lib.corner(f, 20)
		Lib.gradient(f, c1, c2, 90)
		Lib.stroke(f, c2:Lerp(Color3.new(0, 0, 0), 0.4), 3)
		Lib.label({ Text = title, Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 8), Parent = f })
		local list = Lib.new("Frame", { Name = "List", Size = UDim2.new(1, -24, 1, -60), Position = UDim2.fromOffset(12, 54), BackgroundTransparency = 1, Parent = f })
		Lib.list(list, 6).VerticalAlignment = Enum.VerticalAlignment.Top
		return list
	end
	local loseList = column(0, "❌ YOU LOSE", Color3.fromRGB(235, 90, 90), Color3.fromRGB(150, 30, 45))
	local gainList = column(0.5, "✅ YOU GAIN", Color3.fromRGB(90, 205, 100), Color3.fromRGB(30, 120, 55))

	local reqLabel = Lib.label({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 300), Dark = true, Parent = body })
	local needLabel = Lib.label({ Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 334), Dark = true, Parent = body })
	local _, setCostBar = Lib.bar(body, UDim2.new(0.7, 0, 0, 18), UDim2.new(0.15, 0, 0, 368), C.Gold, C.Gold2)

	local useSkip = false
	local skipBtn = Lib.button({ Text = "", Size = UDim2.fromOffset(360, 46), Position = UDim2.new(0.5, 0, 1, -94), AnchorPoint = Vector2.new(0.5, 1), Color = C.Purple, Parent = body })
	local rebirthBtn = Lib.button({ Text = "REBIRTH", Size = UDim2.fromOffset(420, 80), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), Color = C.Gold, Color2 = C.Gold2, Radius = 24, Parent = body })

	local function line(parent: Instance, text: string, order: number)
		Lib.label({ Text = text, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = parent })
	end

	local confirmUntil = 0
	local function render()
		local d = State.data
		if not d then
			return
		end
		for _, l in { loseList, gainList } do
			for _, c in l:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
		end
		local count, best = 0, nil :: Tungs.Tung?
		for _, s in d.slots do
			local t = Tungs.Get(s.id)
			if t and not t.bound then
				count += 1
				if not best or t.income > best.income then
					best = t
				end
			end
		end
		local cur = Economy.Rebirth(d.rebirths)
		local nextInfo = Economy.Rebirth(d.rebirths + 1)
		line(loseList, "💵 " .. Format.Money(d.money) .. " money", 1)
		line(loseList, "🪵 " .. count .. " Tung" .. (if count == 1 then "" else "s") .. " in your base", 2)
		if best then
			line(loseList, "   (including your " .. best.name .. ")", 3)
		end
		line(loseList, "📖 You KEEP your Index, items & VIP/Group Tungs", 4)

		line(gainList, "✖️ Money x" .. cur.mult .. "  →  x" .. nextInfo.mult .. " forever", 1)
		line(gainList, "🟫 Slots " .. cur.slots .. "  →  " .. nextInfo.slots, 2)
		line(gainList, "🏢 Floors " .. Layout.Floors(cur.slots) .. "  →  " .. Layout.Floors(nextInfo.slots), 3)
		local perk = Economy.PERKS[d.rebirths + 1]
		if perk then
			line(gainList, "⭐ Perk: " .. perk, 4)
		end
		line(gainList, "🎆 Fireworks! (your base skin stays the same)", 5)

		local skips = d.tokens and d.tokens.SkipRebirth or 0
		local enoughMoney = d.money >= nextInfo.cost
		skipBtn.Visible = skips > 0 and not enoughMoney
		useSkip = skipBtn.Visible and useSkip
		skipBtn.Text = (if useSkip then "✅ " else "⏩ ") .. "Use Skip Rebirth token (" .. skips .. ")"
		Lib.recolor(skipBtn, if useSkip then C.Green else C.Purple)

		reqLabel.Text = "💵 Cost: " .. Format.Money(nextInfo.cost) .. (if useSkip then "  (skipped with token)" else "  ·  you have " .. Format.Money(d.money))
		setCostBar(if useSkip then 1 else d.money / nextInfo.cost)
		if nextInfo.needRarity then
			local have = Economy.CountAtLeast(d, nextInfo.needRarity)
			local ok = have >= nextInfo.needCount
			needLabel.Text = (if ok then "✅ " else "❌ ") .. "Own " .. nextInfo.needCount .. " " .. nextInfo.needRarity .. "+ Tung" .. (if nextInfo.needCount > 1 then "s" else "") .. " in your base (" .. math.min(have, nextInfo.needCount) .. "/" .. nextInfo.needCount .. ")"
		else
			needLabel.Text = ""
		end
		local can = Economy.CanRebirth(d, useSkip)
		if os.clock() < confirmUntil then
			rebirthBtn.Text = "TAP AGAIN TO CONFIRM!"
			Lib.recolor(rebirthBtn, C.Red, C.Red2)
		else
			rebirthBtn.Text = if can then "REBIRTH ♻️" else "NOT READY YET"
			Lib.recolor(rebirthBtn, if can then C.Gold else C.Grey, if can then C.Gold2 else C.Grey2)
		end
	end

	skipBtn.Activated:Connect(function()
		useSkip = not useSkip
		render()
	end)
	rebirthBtn.Activated:Connect(function()
		local d = State.data
		if not d then
			return
		end
		local can, why = Economy.CanRebirth(d, useSkip)
		if not can then
			State.Fire("Toast", why or "Not ready", "error")
			return
		end
		if os.clock() > confirmUntil then
			confirmUntil = os.clock() + 3
			render()
			task.delay(3.05, render)
			return
		end
		confirmUntil = 0
		local ok = State.Request("Rebirth", useSkip)
		if ok then
			win.close()
		end
		render()
	end)

	win.onOpen = render
	State.On("Changed", function()
		if win.isOpen() then
			render()
		end
	end)
	return win
end

return RebirthPanel
