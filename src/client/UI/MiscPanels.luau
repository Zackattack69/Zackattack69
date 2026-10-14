--!strict
-- Smaller panels: Bounty Board, Leaderboard, Items, Settings, Notifications.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crates = require(Shared.Config.Crates)
local Economy = require(Shared.Config.Economy)
local Quests = require(Shared.Config.Quests)
local Styles = require(Shared.Config.Styles)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local MiscPanels = {}

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function scroller(parent: Instance, padding: number): ScrollingFrame
	local s = Lib.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	Lib.list(s, padding)
	Lib.padding(s, 4)
	return s
end

-- Bounty Board ------------------------------------------------------------------------------
function MiscPanels.Quests(): any
	local win = Lib.window("Bounty Board", Vector2.new(660, 460), C.Gold, C.Gold2)
	local list = scroller(win.body, 10)

	local function render()
		local data = State.data
		if not data then
			return
		end
		clear(list)
		for i, q in data.quests do
			local t = Quests.ById[q.template]
			local progress = math.max(0, (data.stats[t.stat] or 0) - q.start)
			local done = progress >= q.goal
			local row = Lib.new("Frame", { Size = UDim2.new(1, -8, 0, 110), BackgroundColor3 = C.Card, LayoutOrder = i, Parent = list })
			Lib.corner(row, 16)
			Lib.stroke(row, if done then C.Gold else Color3.fromRGB(10, 10, 16), 3)
			Lib.label({ Text = "🎯 " .. Quests.Describe(q), Size = UDim2.new(1, -220, 0, 32), Position = UDim2.fromOffset(14, 12), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local _, set = Lib.bar(row, UDim2.new(1, -230, 0, 22), UDim2.fromOffset(14, 56), C.Gold, C.Gold2)
			set(progress / q.goal)
			Lib.label({ Text = Format.Number(math.min(progress, q.goal)) .. " / " .. Format.Number(q.goal), Size = UDim2.new(1, -230, 0, 20), Position = UDim2.fromOffset(14, 82), TextColor3 = C.SubText, Parent = row })
			Lib.button({
				Text = if done then "CLAIM 💠" .. q.reward else "💠 " .. q.reward,
				Size = UDim2.fromOffset(180, 64),
				Position = UDim2.new(1, -14, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = if done then C.Nova else C.Grey,
				Color2 = if done then C.Nova2 else C.Grey2,
				Parent = row,
				OnClick = function()
					if done then
						State.Request("ClaimQuest", i)
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

-- Leaderboard -----------------------------------------------------------------------------------
function MiscPanels.Leaderboard(): any
	local win = Lib.window("Top Salvagers", Vector2.new(600, 520), C.Gold, C.Gold2)
	local list = scroller(win.body, 6)

	local function render()
		clear(list)
		local players = Players:GetPlayers()
		table.sort(players, function(a, b)
			local ra, rb = a:GetAttribute("Rebirths") or 0, b:GetAttribute("Rebirths") or 0
			if ra ~= rb then
				return ra > rb
			end
			return (a:GetAttribute("TotalScrap") or 0) > (b:GetAttribute("TotalScrap") or 0)
		end)
		for i, p in players do
			local row = Lib.new("Frame", { Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = if p == Players.LocalPlayer then C.Scrap2 else C.Card, LayoutOrder = i, Parent = list })
			Lib.corner(row, 12)
			local medal = ({ "🥇", "🥈", "🥉" })[i] or ("#" .. i)
			Lib.label({ Text = medal, Size = UDim2.fromOffset(50, 40), Position = UDim2.fromOffset(6, 7), Parent = row })
			local rebirths = (p:GetAttribute("Rebirths") or 0) :: number
			Lib.label({ Text = p.DisplayName, Size = UDim2.new(0.45, 0, 0, 30), Position = UDim2.fromOffset(62, 12), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Economy.RebirthColor(rebirths), Parent = row })
			Lib.label({
				Text = "♻ " .. rebirths .. "   🔩 " .. Format.Number((p:GetAttribute("TotalScrap") or 0) :: number) .. "   +" .. Format.Number((p:GetAttribute("Income") or 0) :: number) .. "/s",
				Size = UDim2.new(0.5, -10, 0, 26),
				Position = UDim2.new(0.5, 0, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = C.SubText,
				Parent = row,
			})
		end
	end
	win.onOpen = render
	task.spawn(function()
		while true do
			task.wait(3)
			if win.isOpen() then
				render()
			end
		end
	end)
	return win
end

-- Items: style tokens, rebirth skips, crate vault, titles ----------------------------------------
function MiscPanels.Inventory(openCrates: () -> ()): any
	local win = Lib.window("Items", Vector2.new(700, 520), C.Scrap, C.Scrap2)
	local list = scroller(win.body, 10)

	local function section(text: string, order: number)
		Lib.label({ Text = text, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = list })
	end

	local function render()
		local data = State.data
		if not data then
			return
		end
		clear(list)
		section("🎨 STYLE TOKENS — apply from a droid's detail page", 1)
		local tokens = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, LayoutOrder = 2, Parent = list })
		Lib.list(tokens, 8, true)
		for i, s in Styles.TokenStyles do
			local st = Styles.Get(s)
			local f = Lib.new("Frame", { Size = UDim2.fromOffset(120, 66), BackgroundColor3 = C.Card, LayoutOrder = i, Parent = tokens })
			Lib.corner(f, 12)
			Lib.stroke(f, st.color, 2)
			Lib.label({ Text = st.badge .. " " .. s, Size = UDim2.new(1, -8, 0, 28), Position = UDim2.fromOffset(4, 4), Parent = f })
			Lib.label({ Text = "x" .. (data.tokens[s] or 0), Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 34), TextColor3 = C.SubText, Parent = f })
		end

		section("⏩ Rebirth Skip Tokens: " .. (data.tokens.RebirthSkip or 0), 3)

		local free = 0
		for id, n in data.freeCrates do
			if Crates.Get(id) then
				free += n
			end
		end
		section("🗄️ Crate Vault: " .. free .. " crate(s)", 4)
		Lib.button({ Text = "OPEN CRATE VAULT", Size = UDim2.fromOffset(260, 46), Color = C.Scrap, LayoutOrder = 5, Parent = list, OnClick = openCrates })

		section("🏅 TITLES", 6)
		local titles = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 7, Parent = list })
		Lib.list(titles, 6)
		if #data.titles == 0 then
			Lib.label({ Text = "Rebirth to earn your first title!", Size = UDim2.new(1, 0, 0, 24), TextColor3 = C.SubText, Parent = titles })
		end
		for i, t in data.titles do
			local equipped = data.equippedTitle == t
			Lib.button({
				Text = (if equipped then "✓ " else "") .. t,
				Size = UDim2.new(1, -8, 0, 40),
				Color = if equipped then C.Gold else C.Card,
				LayoutOrder = i,
				Parent = titles,
				OnClick = function()
					State.Request("EquipTitle", if equipped then "" else t)
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

-- Settings ---------------------------------------------------------------------------------------
function MiscPanels.Settings(): any
	local win = Lib.window("Settings", Vector2.new(520, 360), C.Grey, C.Grey2)
	local list = scroller(win.body, 10)
	local options = {
		{ key = "quickOpen", text = "⚡ Quick crate opening" },
		{ key = "hideOthers", text = "🙈 Hide other players' droids" },
		{ key = "sfx", text = "🔊 Sound effects" },
	}
	local function render()
		clear(list)
		for i, o in options do
			local on = (State.settings :: any)[o.key]
			local row = Lib.new("Frame", { Size = UDim2.new(1, -8, 0, 60), BackgroundColor3 = C.Card, LayoutOrder = i, Parent = list })
			Lib.corner(row, 12)
			Lib.label({ Text = o.text, Size = UDim2.new(1, -150, 0, 32), Position = UDim2.fromOffset(14, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			Lib.button({
				Text = if on then "ON" else "OFF",
				Size = UDim2.fromOffset(110, 44),
				Position = UDim2.new(1, -10, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = if on then C.Green else C.Grey,
				Parent = row,
				OnClick = function()
					(State.settings :: any)[o.key] = not on
					State.Fire("Settings")
					render()
				end,
			})
		end
	end
	win.onOpen = render
	return win
end

-- Notifications ---------------------------------------------------------------------------------
function MiscPanels.Notifications(): any
	local win = Lib.window("Notifications", Vector2.new(560, 480), C.Scrap, C.Scrap2)
	local list = scroller(win.body, 6)
	local function render()
		clear(list)
		State.unread = 0
		State.Fire("Unread")
		if #State.notifications == 0 then
			Lib.label({ Text = "Nothing yet!", Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.SubText, Parent = list })
		end
		for i = #State.notifications, 1, -1 do
			local n = State.notifications[i]
			local row = Lib.new("Frame", { Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = C.Card, LayoutOrder = #State.notifications - i, Parent = list })
			Lib.corner(row, 10)
			Lib.label({ Text = n.text, Size = UDim2.new(1, -90, 1, -12), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = row })
			Lib.label({ Text = DateTime.fromUnixTimestamp(n.t):FormatLocalTime("LT", "en-us"), Size = UDim2.fromOffset(70, 24), Position = UDim2.new(1, -78, 0.5, -12), TextColor3 = C.SubText, Parent = row })
		end
	end
	win.onOpen = render
	return win
end

return MiscPanels
