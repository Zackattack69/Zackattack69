--!strict
-- Crate menu: this planet's 3 crates shown like simulator eggs — a droid
-- preview for every rarity inside with its % chance — plus the Crate Vault.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crates = require(Shared.Config.Crates)
local Droids = require(Shared.Config.Droids)
local Economy = require(Shared.Config.Economy)
local Names = require(Shared.Config.StarWarsNames)
local Rarities = require(Shared.Config.Rarities)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)

local State = require(script.Parent.Parent.State)
local CrateReveal = require(script.Parent.CrateReveal)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local CratePanel = {}

local ICONS = { Salvage = "📦", Nova = "💎", Relic = "🏛️", Guaranteed = "🎁" }

local function openCrate(win: any, crateId: string, useFree: boolean)
	if CrateReveal.IsPlaying() then
		return
	end
	local ok, result = State.Request("OpenCrate", crateId, useFree)
	if ok and result then
		win.close()
		CrateReveal.Play(result, function()
			win.open() -- straight back to the menu for fast repeat opening
		end)
	else
		Lib.sound("Error", 0.4)
	end
end

local function pct(x: number): string
	if x >= 10 then
		return string.format("%d%%", math.floor(x + 0.5))
	elseif x >= 1 then
		return string.format("%.1f%%", x)
	end
	return string.format("%.2f%%", x)
end

-- One rarity tile: rarity-coloured background, spinning droid preview, chance.
local function rarityTile(parent: Instance, rarityName: string, chance: number, world: number, order: number)
	local r = Rarities.Get(rarityName)
	local pool = Droids.Pool(rarityName, world)
	local sample = pool[1]
	local tile = Lib.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = parent })
	Lib.corner(tile, 12)
	Lib.gradient(tile, r.color:Lerp(Color3.new(1, 1, 1), 0.35), r.color2, 90)
	Lib.stroke(tile, C.Outline, 2.5)
	if sample then
		Lib.viewport(tile, sample.id, "Standard", UDim2.new(1, 0, 1, -22), UDim2.fromOffset(0, 0), false)
	end
	Lib.label({ Text = pct(chance), Size = UDim2.new(1, -4, 0, 22), Position = UDim2.new(0, 2, 1, -23), Parent = tile })
	if rarityName == "Iconic" or rarityName == "Mythic" then
		Lib.label({ Text = string.upper(rarityName), Size = UDim2.new(1, -4, 0, 14), Position = UDim2.fromOffset(2, 2), TextColor3 = r.color, Parent = tile })
	end
end

function CratePanel.Build(): any
	local win = Lib.window("Crates", Vector2.new(940, 600), C.Blue, C.Blue2, "📦")
	local body = win.body

	local cardsRow = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 380), BackgroundTransparency = 1, Parent = body })
	Lib.list(cardsRow, 16, true, Enum.HorizontalAlignment.Center)

	local vaultCard = Lib.card(body, { Size = UDim2.new(1, 0, 0, 104), Position = UDim2.fromOffset(0, 392), BackgroundColor3 = C.Inset })
	Lib.label({ Text = "🗄️ CRATE VAULT", Size = UDim2.fromOffset(200, 26), Position = UDim2.fromOffset(14, -14), Parent = vaultCard })
	local vault = Lib.new("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -24),
		Position = UDim2.fromOffset(10, 16),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = vaultCard,
	})
	Lib.list(vault, 10, true)

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
		win.header.Title.Text = "📦  Crates — " .. world.name
		local luck = Economy.Luck(data)

		for i, crate in Crates.ByWorld[data.world] do
			local card = Lib.card(cardsRow, { Size = UDim2.fromOffset(282, 380), LayoutOrder = i })
			local top = Lib.new("Frame", { Size = UDim2.new(1, -12, 0, 60), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
			Lib.corner(top, 12)
			Lib.gradient(top, crate.color, crate.color:Lerp(Color3.new(0, 0, 0), 0.35), 90)
			Lib.stroke(top, C.Outline, 2.5)
			Lib.label({ Text = ICONS[crate.kind] or "📦", Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Stroke = false, Parent = top })
			Lib.label({ Text = crate.name, Size = UDim2.new(1, -66, 0, 34), Position = UDim2.new(0, 60, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left, Parent = top })

			-- rarity tiles
			local tiles = Lib.new("Frame", { Size = UDim2.new(1, -16, 0, 230), Position = UDim2.fromOffset(8, 76), BackgroundTransparency = 1, Parent = card })
			Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 108), CellPadding = UDim2.fromOffset(6, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = tiles })
			local odds, total = Crates.EffectiveOdds(crate, luck)
			local jackpot = (crate.mythicChance + crate.iconicChance) * luck
			for _, r in Rarities.List do
				local w = odds[r.name]
				if w then
					rarityTile(tiles, r.name, w / total * 100 * (1 - jackpot), data.world, r.index)
				end
			end
			rarityTile(tiles, "Mythic", crate.mythicChance * luck * 100, data.world, 10)
			rarityTile(tiles, "Iconic", crate.iconicChance * luck * 100, data.world, 11)

			local isNova = crate.currency == "Nova"
			local afford = if isNova then data.nova >= crate.cost else data.scrap >= crate.cost
			local icon = if isNova then Names.CurrencyIcon.Nova else Names.CurrencyIcon.Scrap
			Lib.button({
				Text = "OPEN  " .. icon .. " " .. Format.Number(crate.cost),
				Size = UDim2.new(1, -20, 0, 56),
				Position = UDim2.new(0, 10, 1, -66),
				Color = if not afford then C.Grey elseif isNova then C.Purple else C.Green,
				Color2 = if not afford then C.Grey2 elseif isNova then C.Purple2 else C.Green2,
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
				Lib.button({
					Text = (ICONS[crate.kind] or "🎁") .. " " .. crate.name .. "  x" .. n,
					Size = UDim2.fromOffset(250, 64),
					Color = crate.color,
					Parent = vault,
					OnClick = function()
						openCrate(win, crateId, true)
					end,
				})
			end
		end
		if not any then
			Lib.label({ Text = "Empty! Rebirths and the Shop add free crates here.", Dark = true, TextColor3 = C.SubText, Size = UDim2.fromOffset(600, 30), Parent = vault })
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
