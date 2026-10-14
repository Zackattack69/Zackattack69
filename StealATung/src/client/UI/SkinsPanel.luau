--!strict
-- Base Skins menu (opened at the Skins stand next to the Rebirth Altar).
-- Colours are free. Rarity styles unlock by collecting enough Tungs of that
-- rarity; Tung Master unlocks with a complete Index. The server re-checks
-- every unlock when you pick one.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BaseSkins = require(Shared.Config.BaseSkins)
local Rarities = require(Shared.Config.Rarities)

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local SkinsPanel = {}

-- A little picture of the base in that skin: wall, window band, frame, trim.
local function preview(parent: Instance, skin: BaseSkins.Skin)
	local holder = Lib.new("Frame", { Size = UDim2.new(1, -16, 0, 92), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = skin.wall, Parent = parent })
	Lib.corner(holder, 12)
	Lib.stroke(holder, C.Outline, 2.5)
	Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = skin.trim, BorderSizePixel = 0, Parent = holder })
	local band = Lib.new("Frame", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 20), BackgroundColor3 = skin.glass, BorderSizePixel = 0, Parent = holder })
	Lib.new("UIStroke", { Color = skin.frame, Thickness = 3, Parent = band })
	for k = 1, 3 do
		Lib.new("Frame", { Size = UDim2.new(0, 3, 1, 0), Position = UDim2.fromScale(k / 4, 0), BackgroundColor3 = skin.frame, BorderSizePixel = 0, Parent = band })
	end
	-- red laser bars along the bottom, like the front of a real base
	local lasers = Lib.new("Frame", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 60), BackgroundTransparency = 1, Parent = holder })
	for k = 0, 9 do
		Lib.new("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.fromScale(k / 9, 0), BackgroundColor3 = Color3.fromRGB(255, 50, 60), BorderSizePixel = 0, Parent = lasers })
	end
end

function SkinsPanel.Build(): any
	local win = Lib.window("Base Skins", Vector2.new(900, 620), C.Purple, "🎨")
	local body = win.body
	Lib.label({ Text = "Colours are free. Collect Tungs of a rarity to unlock its style!", Size = UDim2.new(1, 0, 0, 28), Dark = true, TextColor3 = C.SubText, Parent = body })
	local grid = Lib.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -40), Position = UDim2.fromOffset(0, 40), BackgroundTransparency = 1, ScrollBarThickness = 8, ScrollBarImageColor3 = C.Wood2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body })

	local function render()
		local d = State.data
		if not d then
			return
		end
		for _, c in grid:GetChildren() do
			c:Destroy()
		end
		Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 206), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
		Lib.padding(grid, 6)
		local current = BaseSkins.Get(d.baseSkin).key
		for _, skin in BaseSkins.List do
			local unlocked, how = BaseSkins.Unlocked(d, skin)
			local equipped = skin.key == current
			local f = Lib.card(grid, { Size = UDim2.fromOffset(196, 206), LayoutOrder = skin.order })
			preview(f, skin)
			local nameLabel = Lib.label({ Text = skin.name, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 104), Dark = true, Parent = f })
			if skin.rarity then
				nameLabel.TextColor3 = Rarities.Get(skin.rarity).color
				nameLabel.Text = skin.name .. " style"
			end
			Lib.label({ Text = if unlocked then (skin.desc or (if skin.kind == "Color" then "Free colour" else "")) else how, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 128), Dark = true, TextColor3 = C.SubText, Parent = f })
			Lib.button({
				Text = if equipped then "✔ Using" elseif unlocked then "Use" else "🔒 Locked",
				Size = UDim2.new(1, -12, 0, 48),
				Position = UDim2.new(0, 6, 1, -54),
				Color = if equipped then C.Green elseif unlocked then C.Purple else C.Grey,
				Color2 = if equipped then C.Green2 elseif unlocked then C.Purple2 else C.Grey2,
				NoShine = not unlocked,
				Parent = f,
				OnClick = function()
					if equipped then
						return
					end
					if not unlocked then
						State.Fire("Toast", "🔒 " .. how, "error")
						return
					end
					local ok = State.Request("SetSkin", skin.key)
					if ok then
						Lib.sound("Purchase")
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

return SkinsPanel
