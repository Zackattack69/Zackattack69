--!strict
-- The leaderboard pillar in the middle of the arena:
--   front / back faces: this server's top earners and top thieves
--   left face:  global top earners      right face: global top thieves + highest rebirth
-- Global boards use OrderedDataStores (money is stored log-encoded so huge
-- numbers fit in an integer).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local GLOBAL_INTERVAL = 120
local ROWS = 10

type Row = { name: string, value: string }

local stores: { [string]: OrderedDataStore } = {}
do
	for _, name in { "Earned", "Steals", "Rebirths" } do
		local ok, s = pcall(function()
			return DataStoreService:GetOrderedDataStore("StealATung_Top" .. name .. "_v1")
		end)
		if ok then
			stores[name] = s
		end
	end
end

local function encodeMoney(n: number): number
	return math.floor(math.log10(math.max(n, 0) + 1) * 1e6)
end

local function decodeMoney(v: number): number
	return 10 ^ (v / 1e6) - 1
end

local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local name = if ok and n then n else "Player"
	nameCache[userId] = name
	return name
end

-- Board drawing ------------------------------------------------------------------------------------------
local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		(l :: any)[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Thickness = 3.5
	s.Color = Color3.fromRGB(20, 16, 34)
	s.Parent = l
	l.Parent = parent
	return l
end

local function column(gui: SurfaceGui, x: number, width: number, title: string, color: Color3): { TextLabel }
	label(gui, { Text = title, Size = UDim2.fromOffset(width, 60), Position = UDim2.fromOffset(x, 100), TextColor3 = color })
	local rows = {}
	for r = 1, ROWS do
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromOffset(width, 62)
		bg.Position = UDim2.fromOffset(x, 170 + (r - 1) * 68)
		bg.BackgroundColor3 = if r == 1 then Color3.fromRGB(255, 196, 40) elseif r == 2 then Color3.fromRGB(190, 200, 225) elseif r == 3 then Color3.fromRGB(230, 140, 70) elseif r % 2 == 0 then Color3.fromRGB(110, 70, 220) else Color3.fromRGB(130, 90, 240)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(20, 16, 34)
		stroke.Parent = bg
		bg.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = bg
		bg.Parent = gui
		local medal = if r == 1 then "🥇" elseif r == 2 then "🥈" elseif r == 3 then "🥉" else "#" .. r
		table.insert(rows, label(bg, { Text = medal .. "  —", Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5), TextXAlignment = Enum.TextXAlignment.Left }))
	end
	return rows
end

local function setRows(rows: { TextLabel }, data: { Row })
	for r, l in rows do
		local d = data[r]
		local medal = if r == 1 then "🥇" elseif r == 2 then "🥈" elseif r == 3 then "🥉" else "#" .. r
		l.Text = if d then medal .. "  " .. d.name .. "  ·  " .. d.value else medal .. "  —"
	end
end

local boards: { [string]: { TextLabel } } = {}

local function buildBoards()
	local arena = Workspace:WaitForChild("Arena")
	local pillar = arena:WaitForChild("Pillar")
	local block = pillar:WaitForChild("Block")
	local gold = Color3.fromRGB(255, 210, 70)
	local red = Color3.fromRGB(255, 110, 110)
	local blue = Color3.fromRGB(120, 200, 255)
	for _, face in { "BoardFront", "BoardBack" } do
		local gui = block:WaitForChild(face) :: SurfaceGui
		label(gui, { Text = "🏆 SERVER TOP 🏆", Size = UDim2.fromOffset(700, 90), Position = UDim2.fromOffset(10, 6), TextColor3 = gold, Font = Enum.Font.LuckiestGuy })
		boards[face .. "Earn"] = column(gui, 10, 345, "💰 Earners", gold)
		boards[face .. "Steal"] = column(gui, 365, 345, "🦹 Thieves", red)
	end
	local left = block:WaitForChild("BoardLeft") :: SurfaceGui
	label(left, { Text = "🌍 GLOBAL EARNERS", Size = UDim2.fromOffset(700, 90), Position = UDim2.fromOffset(10, 6), TextColor3 = gold, Font = Enum.Font.LuckiestGuy })
	boards.GlobalEarn = column(left, 60, 600, "All-time money earned", gold)
	local right = block:WaitForChild("BoardRight") :: SurfaceGui
	label(right, { Text = "🌍 GLOBAL TOP", Size = UDim2.fromOffset(700, 90), Position = UDim2.fromOffset(10, 6), TextColor3 = gold, Font = Enum.Font.LuckiestGuy })
	boards.GlobalSteal = column(right, 10, 345, "🦹 Thieves", red)
	boards.GlobalRebirth = column(right, 365, 345, "♻️ Rebirths", blue)
end

-- Updates ---------------------------------------------------------------------------------------------------
local function updateServer()
	local earn: { { name: string, n: number } } = {}
	local steal: { { name: string, n: number } } = {}
	for player, p in DataService.All() do
		table.insert(earn, { name = player.DisplayName, n = p.data.totalEarned })
		table.insert(steal, { name = player.DisplayName, n = p.data.stats.steals })
	end
	table.sort(earn, function(a, b)
		return a.n > b.n
	end)
	table.sort(steal, function(a, b)
		return a.n > b.n
	end)
	local earnRows, stealRows = {}, {}
	for _, e in earn do
		table.insert(earnRows, { name = e.name, value = Format.Money(e.n) })
	end
	for _, s in steal do
		table.insert(stealRows, { name = s.name, value = tostring(s.n) })
	end
	for _, face in { "BoardFront", "BoardBack" } do
		if boards[face .. "Earn"] then
			setRows(boards[face .. "Earn"], earnRows)
			setRows(boards[face .. "Steal"], stealRows)
		end
	end
end

local function write(player: Player)
	local p = DataService.Get(player)
	if not p then
		return
	end
	local key = tostring(player.UserId)
	local values: { [string]: number } = {
		Earned = encodeMoney(p.data.totalEarned),
		Steals = p.data.stats.steals,
		Rebirths = p.data.rebirths,
	}
	for name, v in values do
		local s = stores[name]
		if s and v > 0 then
			pcall(s.SetAsync, s, key, v)
		end
	end
end

local function read(name: string, decode: (number) -> string): { Row }
	local s = stores[name]
	if not s then
		return {}
	end
	local ok, pages = pcall(s.GetSortedAsync, s, false, ROWS)
	if not ok or not pages then
		return {}
	end
	local rows = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local uid = tonumber(entry.key)
		if uid then
			table.insert(rows, { name = nameOf(uid), value = decode(entry.value) })
		end
	end
	return rows
end

local function updateGlobal()
	for player in DataService.All() do
		write(player)
	end
	local earn = read("Earned", function(v)
		return Format.Money(decodeMoney(v))
	end)
	local steal = read("Steals", function(v)
		return tostring(v)
	end)
	local reb = read("Rebirths", function(v)
		return tostring(v)
	end)
	if boards.GlobalEarn then
		setRows(boards.GlobalEarn, earn)
		setRows(boards.GlobalSteal, steal)
		setRows(boards.GlobalRebirth, reb)
	end
end

function LeaderboardService.Init()
	task.spawn(function()
		buildBoards()
		task.spawn(function()
			while true do
				pcall(updateServer :: any)
				task.wait(5)
			end
		end)
		task.wait(20)
		while true do
			pcall(updateGlobal :: any)
			task.wait(GLOBAL_INTERVAL)
		end
	end)
	DataService.OnReleasing(function(profile)
		task.spawn(write, profile.player)
	end)
end

return LeaderboardService
