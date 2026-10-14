--!strict
-- Trading: pick a friend in the server and send a request. In the trade
-- window each side taps Tungs from their base to offer (up to 6). Both must
-- press Accept, then both must press Confirm; any change resets the accepts.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local TradePanel = {}

local player = Players.LocalPlayer

local function tungTile(parent: Instance, id: string, mut: string, order: number, selected: boolean, onClick: (() -> ())?): Frame
	local t = Tungs.Get(id)
	local color = if t then Tungs.Color(t) else C.Grey
	local f = Lib.new("TextButton", { Size = UDim2.fromOffset(108, 132), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, LayoutOrder = order, Parent = parent })
	Lib.corner(f, 14)
	Lib.gradient(f, color:Lerp(Color3.new(1, 1, 1), 0.5), color:Lerp(Color3.new(1, 1, 1), 0.15), 90)
	Lib.stroke(f, if selected then C.Gold else C.Wood2, if selected then 5 else 3)
	Lib.tungViewport(f, id, mut, UDim2.new(1, -6, 0, 82), UDim2.fromOffset(3, 2), false)
	Lib.label({ Text = Mutations.Prefix(mut) .. (if t then t.name else id), Size = UDim2.new(1, -6, 0, 22), Position = UDim2.fromOffset(3, 84), Parent = f })
	Lib.label({ Text = Format.Money((if t then t.income else 0) * Mutations.Mult(mut)) .. "/s", Size = UDim2.new(1, -6, 0, 18), Position = UDim2.fromOffset(3, 108), TextColor3 = Color3.fromRGB(255, 230, 110), Parent = f })
	if selected then
		Lib.label({ Text = "✅", Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -2, 0, 2), AnchorPoint = Vector2.new(1, 0), Stroke = false, Parent = f })
	end
	if onClick then
		Lib.bouncy(f)
		f.Activated:Connect(function()
			Lib.sound("Pop")
			onClick()
		end)
	end
	return f
end

function TradePanel.Build(popupGui: ScreenGui): any
	local win = Lib.window("Trade", Vector2.new(960, 640), Color3.fromRGB(255, 200, 230), "🤝")
	local body = win.body

	local lobby = Lib.new("Frame", { Name = "Lobby", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	Lib.label({ Text = if GameConfig.TradeFriendsOnly then "Trade Tungs with your friends in this server" else "Trade Tungs with players in this server", Size = UDim2.new(1, 0, 0, 32), Dark = true, Parent = lobby })
	local playerList = Lib.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 44), BackgroundTransparency = 1, ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = lobby })
	Lib.list(playerList, 8, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top

	local tradeView = Lib.new("Frame", { Name = "TradeView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = body })
	local stageLabel = Lib.label({ Text = "", Size = UDim2.new(1, 0, 0, 30), Dark = true, Parent = tradeView })
	local function side(x: number, title: string): (TextLabel, ScrollingFrame)
		local f = Lib.card(tradeView, { Size = UDim2.new(0.5, -6, 1, -120), Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 36) })
		local head = Lib.label({ Text = title, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 6), Dark = true, Parent = f })
		local grid = Lib.new("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -46), Position = UDim2.fromOffset(8, 40), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = f })
		Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(108, 132), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		return head, grid
	end
	local myHead, myGrid = side(0, "Your Tungs (tap to offer)")
	local theirHead, theirGrid = side(0.5, "Their offer")
	local acceptBtn = Lib.button({ Text = "ACCEPT", Size = UDim2.fromOffset(300, 70), Position = UDim2.new(0.5, 8, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = C.Green, Parent = tradeView, OnClick = function()
		State.Request("TradeAccept")
	end })
	Lib.button({ Text = "CANCEL", Size = UDim2.fromOffset(220, 70), Position = UDim2.new(0.5, -8, 1, 0), AnchorPoint = Vector2.new(1, 1), Color = C.Red, Parent = tradeView, OnClick = function()
		State.Request("TradeCancel")
	end })

	local trade: any = nil
	local selected: { [number]: boolean } = {}

	local function renderLobby()
		for _, c in playerList:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local n = 0
		for _, p in Players:GetPlayers() do
			if p == player then
				continue
			end
			n += 1
			local row = Lib.card(playerList, { Size = UDim2.new(1, -20, 0, 76), LayoutOrder = n })
			local img = Lib.new("ImageLabel", { Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = C.Cream2, Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150", Parent = row })
			Lib.round(img)
			Lib.label({ Text = p.DisplayName, Size = UDim2.new(0.5, 0, 0, 34), Position = UDim2.new(0, 84, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, Parent = row })
			Lib.button({ Text = "Request trade", Size = UDim2.fromOffset(220, 56), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Pink, Parent = row, OnClick = function()
				local ok, msg = State.Request("TradeRequest", p.UserId)
				if ok and msg then
					State.Fire("Toast", msg, "success")
				end
			end })
		end
		if n == 0 then
			Lib.label({ Text = "Nobody else is here yet!", Size = UDim2.new(1, 0, 0, 40), Dark = true, TextColor3 = C.SubText, Parent = playerList })
		end
	end

	local function renderTrade()
		if not trade then
			return
		end
		for _, g in { myGrid, theirGrid } do
			for _, c in g:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
		end
		selected = {}
		for _, it in trade.me.offer do
			selected[it.slot] = true
		end
		local d = State.data
		local order = 0
		if d then
			for k, s in d.slots do
				local slot = tonumber(k) :: number
				local t = Tungs.Get(s.id)
				if t and not t.bound then
					order += 1
					tungTile(myGrid, s.id, s.m, if selected[slot] then order else order + 100, selected[slot] == true, function()
						if selected[slot] then
							selected[slot] = nil
						else
							selected[slot] = true
						end
						local list = {}
						for sl in selected do
							table.insert(list, sl)
						end
						State.Request("TradeOffer", list)
					end)
				end
			end
		end
		for i, it in trade.them.offer do
			tungTile(theirGrid, it.id, it.m, i, true, nil)
		end
		myHead.Text = "Your Tungs (tap to offer)" .. (if trade.me.accepted then "  ✅" else "")
		theirHead.Text = trade.them.name .. "'s offer" .. (if trade.them.accepted then "  ✅" else "")
		local stage2 = trade.stage == 2
		stageLabel.Text = if stage2 then "Step 2 of 2: both players press CONFIRM" else "Step 1 of 2: both players press ACCEPT"
		acceptBtn.Text = if trade.me.accepted then "WAITING..." elseif stage2 then "CONFIRM" else "ACCEPT"
		Lib.recolor(acceptBtn, if trade.me.accepted then C.Grey elseif stage2 then C.Gold else C.Green)
	end

	-- Incoming request popup
	local popup = Lib.card(popupGui, { Name = "TradeRequest", Size = UDim2.fromOffset(460, 150), Position = UDim2.new(0.5, 0, 0, 300), AnchorPoint = Vector2.new(0.5, 0), Visible = false, ZIndex = 40 })
	Lib.hudFit(popup)
	local popupText = Lib.label({ Text = "", Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 10), Dark = true, ZIndex = 41, Parent = popup })
	local fromId = 0
	Lib.button({ Text = "Accept", Size = UDim2.fromOffset(200, 60), Position = UDim2.new(0.5, -6, 1, -12), AnchorPoint = Vector2.new(1, 1), Color = C.Green, ZIndex = 41, Parent = popup, OnClick = function()
		popup.Visible = false
		State.Request("TradeRespond", fromId, true)
	end })
	Lib.button({ Text = "Decline", Size = UDim2.fromOffset(200, 60), Position = UDim2.new(0.5, 6, 1, -12), AnchorPoint = Vector2.new(0, 1), Color = C.Red, ZIndex = 41, Parent = popup, OnClick = function()
		popup.Visible = false
		State.Request("TradeRespond", fromId, false)
	end })

	Remotes.Event("Trade").OnClientEvent:Connect(function(msg)
		if msg.type == "request" then
			fromId = msg.from
			popupText.Text = "🤝 " .. msg.name .. " wants to trade!"
			popup.Visible = true
			Lib.sound("Purchase")
			task.delay(25, function()
				if fromId == msg.from then
					popup.Visible = false
				end
			end)
		elseif msg.type == "open" then
			lobby.Visible = false
			tradeView.Visible = true
			if not win.isOpen() then
				win.open()
			end
		elseif msg.type == "update" then
			trade = msg
			lobby.Visible = false
			tradeView.Visible = true
			renderTrade()
		elseif msg.type == "close" then
			trade = nil
			tradeView.Visible = false
			lobby.Visible = true
			if msg.reason and msg.reason ~= "done" then
				State.Fire("Toast", msg.reason, "info")
			end
			renderLobby()
		end
	end)

	win.onOpen = function()
		if trade then
			renderTrade()
		else
			renderLobby()
		end
	end
	win.onClose = function()
		if trade then
			State.Request("TradeCancel")
		end
	end
	State.On("Changed", function(full)
		if full and trade and win.isOpen() then
			renderTrade()
		end
	end)
	return win
end

return TradePanel
