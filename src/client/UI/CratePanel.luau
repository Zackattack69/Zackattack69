--!strict
-- Crate selection: this world's 3 crates + the Crate Vault (free/purchased crates).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crates = require(Shared.Config.Crates)
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local CrateReveal = require(script.Parent.CrateReveal)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local CratePanel = {}

local ICONS = { Salvage = "📦", Nova = "🔮", Relic = "🏺", Guaranteed = "🎁" }

local function openCrate(win: any, crateId: string, useFree: boolean)
	if CrateReveal.IsPlaying() then
		return
	end
	local ok, result = State.Request("OpenCrate", crateId, useFree)
	if ok and result then
		win.close()
		CrateReveal.Play(result, function()
			-- Re-open for fast repeat opening
			win.open()
		end)
	else
		Lib.sound("Error", 0.4)
	end
end

function CratePanel.Build(): any
	local win = Lib.window("Crates", Vector2.new(860, 540), C.Scrap, C.Scrap2)
	local body = win.body

	local cardsRow = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 340), BackgroundTransparency = 1, Parent = body })
	Lib.list(cardsRow, 12, true, Enum.HorizontalAlignment.Center)

	Lib.label({ Text = "🗄️ CRATE VAULT", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 350), TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
	local vault = Lib.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 100),
		Position = UDim2.fromOffset(0, 384),
		BackgroundColor3 = C.Panel2,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = body,
	})
	Lib.corner(vault, 12)
	Lib.padding(vault, 8)
	Lib.list(vault, 8, true)

	local function rebuild()
		local data = State.data
		if not data then
			return
		end
		for _, c in cardsRow:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, c in vault:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local world = Worlds.Get(data.world)
		win.header.Title.Text = "Crates — " .. world.name

		for i, crate in Crates.ByWorld[data.world] do
			local card = Lib.new("Frame", { Size = UDim2.fromOffset(265, 340), BackgroundColor3 = C.Card, LayoutOrder = i, Parent = cardsRow })
			Lib.corner(card, 18)
			Lib.stroke(card, crate.color, 3)
			local top = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
			Lib.corner(top, 18)
			Lib.gradient(top, crate.color, crate.color:Lerp(Color3.new(0, 0, 0), 0.5), 90)
			Lib.label({ Text = ICONS[crate.kind] or "📦", Size = UDim2.fromScale(1, 0.85), Position = UDim2.fromScale(0, 0.05), Stroke = false, Parent = top })
			Lib.label({ Text = crate.kind .. " Crate", Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 116), Parent = card })

			-- Odds table
			local oddsFrame = Lib.new("Frame", { Size = UDim2.new(1, -24, 0, 120), Position = UDim2.fromOffset(12, 150), BackgroundTransparency = 1, Parent = card })
			Lib.list(oddsFrame, 2)
			local odds, total = Crates.EffectiveOdds(crate, Economy.Luck(data))
			for _, r in Rarities.List do
				local w = odds[r.name]
				if w then
					Lib.label({ Text = string.format("%s  %.1f%%", r.name, w / total * 100 * (1 - crate.mythicChance)), Size = UDim2.new(1, 0, 0, 20), TextColor3 = r.color, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = r.index, Parent = oddsFrame })
				end
			end
			Lib.label({ Text = string.format("Mythic  %.1f%%", crate.mythicChance * Economy.Luck(data) * 100), Size = UDim2.new(1, 0, 0, 20), TextColor3 = Rarities.Get("Mythic").color, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 10, Parent = oddsFrame })

			local isNova = crate.currency == "Nova"
			local afford = if isNova then data.nova >= crate.cost else data.scrap >= crate.cost
			local priceText = (if isNova then "💠 " else "🔩 ") .. Format.Number(crate.cost)
			Lib.button({
				Text = "OPEN  " .. priceText,
				Size = UDim2.new(1, -24, 0, 50),
				Position = UDim2.new(0, 12, 1, -60),
				Color = if not afford then C.Grey elseif isNova then C.Nova else C.Green,
				Color2 = if not afford then C.Grey2 elseif isNova then C.Nova2 else C.Green2,
				Parent = card,
				OnClick = function()
					openCrate(win, crate.id, false)
				end,
			})
		end

		local any = false
		for crateId, n in data.freeCrates do
			local crate = Crates.Get(crateId)
			if crate and n > 0 then
				any = true
				local b = Lib.button({
					Text = (ICONS[crate.kind] or "🎁") .. " " .. crate.name .. "  x" .. n,
					Size = UDim2.fromOffset(250, 80),
					Color = crate.color,
					Parent = vault,
					OnClick = function()
						openCrate(win, crateId, true)
					end,
				})
				local _ = b
			end
		end
		if not any then
			Lib.label({ Text = "No crates stored. Rebirths and the Shop add crates here!", Size = UDim2.fromOffset(600, 30), TextColor3 = C.SubText, Parent = vault })
		end
	end

	win.onOpen = rebuild
	State.On("Changed", function(full)
		if full and win.isOpen() then
			rebuild()
		end
	end)
	return win
end

return CratePanel
