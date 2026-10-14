--!strict
-- Quests: the 7-day login calendar (day 7 = free Legendary), today's 3 daily
-- quests, the group reward, and the countdown to the weekly Admin Abuse.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local GameConfig = require(Shared.Config.GameConfig)
local Quests = require(Shared.Config.Quests)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local QuestsPanel = {}

local function longTime(seconds: number): string
	local d = seconds // 86400
	if d > 0 then
		return d .. "d " .. Format.Time(seconds % 86400)
	end
	return Format.Time(seconds)
end

function QuestsPanel.Build(): any
	local win = Lib.window("Quests", Vector2.new(900, 640), Color3.fromRGB(190, 225, 255), "📜")
	local body = win.body

	-- Login calendar ------------------------------------------------------------------------------------
	Lib.label({ Text = "📅 Daily login streak", Size = UDim2.new(0.6, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, Parent = body })
	local cal = Lib.new("Frame", { Size = UDim2.new(1, -200, 0, 112), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, Parent = body })
	Lib.list(cal, 8, true)
	local cells: { Frame } = {}
	for i, r in Quests.Login do
		local cell = Lib.card(cal, { Size = UDim2.fromOffset(88, 108), LayoutOrder = i })
		Lib.label({ Text = "Day " .. i, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 4), Dark = true, Parent = cell })
		Lib.label({ Text = r.icon, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0.5, 0, 0, 50), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = cell })
		Lib.label({ Text = r.text, Size = UDim2.new(1, -6, 0, 30), Position = UDim2.fromOffset(3, 74), Dark = true, TextColor3 = C.SubText, TextWrapped = true, Parent = cell })
		Lib.label({ Name = "Check", Text = "✅", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -4, 0, 4), AnchorPoint = Vector2.new(1, 0), Stroke = false, Visible = false, Parent = cell })
		cells[i] = cell
	end
	local claimLogin = Lib.button({ Text = "CLAIM", Size = UDim2.fromOffset(180, 74), Position = UDim2.new(1, 0, 0, 40), AnchorPoint = Vector2.new(1, 0), Color = C.Green, Parent = body, OnClick = function()
		local ok = State.Request("ClaimLogin")
		if ok then
			Lib.sound("Jackpot")
		end
	end })

	-- Daily quests ----------------------------------------------------------------------------------------------
	local resetLabel = Lib.label({ Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 156), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, Parent = body })
	local list = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 280), Position = UDim2.fromOffset(0, 188), BackgroundTransparency = 1, Parent = body })
	Lib.list(list, 10).VerticalAlignment = Enum.VerticalAlignment.Top

	-- Footer: group reward + Admin Abuse countdown
	local groupBtn = Lib.button({ Text = "👥 Join our group → claim the free Group Tung", Size = UDim2.new(0.6, 0, 0, 52), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = C.Blue, Parent = body, OnClick = function()
		local ok = State.Request("ClaimGroup")
		if ok then
			Lib.sound("Jackpot")
		end
	end })
	groupBtn.Visible = GameConfig.GroupId ~= 0
	local abuseLabel = Lib.label({ Text = "", Size = UDim2.new(0.38, 0, 0, 44), Position = UDim2.new(1, 0, 1, -4), AnchorPoint = Vector2.new(1, 1), Dark = true, TextColor3 = C.Pink2, Parent = body })

	local function render()
		local d = State.data
		if not d then
			return
		end
		local canClaim = d.loginCanClaim == true
		local day = d.loginDay or 1
		for i, cell in cells do
			local check = cell:FindFirstChild("Check") :: TextLabel
			local claimedThisCycle = if canClaim then i < day else i <= day
			check.Visible = claimedThisCycle
			local stroke = cell:FindFirstChild("Border") :: UIStroke?
			if stroke then
				stroke.Color = if i == day and canClaim then C.Gold2 else C.Wood2
				stroke.Thickness = if i == day and canClaim then 5 else 3
			end
		end
		claimLogin.Text = if canClaim then "CLAIM DAY " .. day else "COME BACK TOMORROW"
		Lib.recolor(claimLogin, if canClaim then C.Green else C.Grey)

		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, q in (d.quests and d.quests.list or {}) do
			local row = Lib.card(list, { Size = UDim2.new(1, 0, 0, 84), LayoutOrder = i })
			Lib.label({ Text = q.text, Size = UDim2.new(0.62, 0, 0, 32), Position = UDim2.fromOffset(14, 8), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, Parent = row })
			local _, set = Lib.bar(row, UDim2.new(0.5, 0, 0, 18), UDim2.fromOffset(14, 50), C.Blue, C.Blue2)
			set(q.progress / q.goal)
			local progressText = if q.stat == "collectMoney" then Format.Money(q.progress) .. " / " .. Format.Money(q.goal) else q.progress .. " / " .. q.goal
			Lib.label({ Text = progressText, Size = UDim2.new(0.18, 0, 0, 20), Position = UDim2.new(0.52, 14, 0, 49), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = C.SubText, Parent = row })
			local reward = if q.reward == "luck" then "🍀 Luck Potion" else "💵 " .. Format.Money(q.amount)
			local done = q.progress >= q.goal
			Lib.button({
				Text = if q.claimed then "✅ Claimed" elseif done then "Claim " .. reward else reward,
				Size = UDim2.fromOffset(220, 60),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = if q.claimed then C.Grey elseif done then C.Gold else C.Wood,
				Parent = row,
				OnClick = function()
					if done and not q.claimed then
						local ok = State.Request("ClaimQuest", i)
						if ok then
							Lib.sound("ChaChing")
						end
					end
				end,
			})
		end
		groupBtn.Text = if d.flags and d.flags.groupTung then "✅ Group Tung claimed" else "👥 Join our group → claim the free Group Tung"
	end

	task.spawn(function()
		while true do
			if win.isOpen() then
				local t = os.time()
				resetLabel.Text = "📜 Daily quests  ·  new quests in " .. Format.Time(86400 - t % 86400)
				local left, live = Events.AdminAbuseStatus(t)
				abuseLabel.Text = if live then "👑 ADMIN ABUSE IS LIVE!" else "👑 Admin Abuse in " .. longTime(left)
			end
			task.wait(1)
		end
	end)

	win.onOpen = render
	State.On("Changed", function(full)
		if full and win.isOpen() then
			render()
		end
	end)
	return win
end

return QuestsPanel
