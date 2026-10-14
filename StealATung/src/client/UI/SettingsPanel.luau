--!strict
-- Settings: music volume, sound effects volume, low graphics mode (turns off
-- auras for weak phones), and "hide other players' auras".

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local C = Lib.Colors
local SettingsPanel = {}

function SettingsPanel.Build(): any
	local win = Lib.window("Settings", Vector2.new(640, 470), Color3.fromRGB(255, 240, 210), "⚙️")
	local body = win.body
	Lib.list(body, 14, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top

	local function row(order: number, icon: string, text: string, sub: string): Frame
		local f = Lib.card(body, { Size = UDim2.new(1, -10, 0, 80), LayoutOrder = order })
		Lib.label({ Text = icon, Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Stroke = false, Parent = f })
		Lib.label({ Text = text, Size = UDim2.new(0.5, 0, 0, 32), Position = UDim2.fromOffset(74, 10), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, Parent = f })
		Lib.label({ Text = sub, Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromOffset(74, 44), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = C.SubText, Parent = f })
		return f
	end

	local musicRow = row(1, "🎵", "Music", "The tung tung tung theme")
	local _, setMusic = Lib.slider(musicRow, UDim2.fromOffset(220, 22), UDim2.new(1, -24, 0.5, 0), function(v)
		State.settings.music = v
		State.Fire("Settings")
	end)
	local sfxRow = row(2, "🔊", "Sound effects", "Pops, knocks and cha-chings")
	local _, setSfx = Lib.slider(sfxRow, UDim2.fromOffset(220, 22), UDim2.new(1, -24, 0.5, 0), function(v)
		State.settings.sfx = v
		State.Fire("Settings")
	end)
	local lowRow = row(3, "📱", "Low graphics mode", "Turns off auras and effects for weak phones")
	local _, setLow = Lib.toggle(lowRow, UDim2.new(1, -24, 0.5, 0), function(v)
		State.SetSetting("low", v)
	end)
	local hideRow = row(4, "🙈", "Hide other players' auras", "Only your own Tungs glow")
	local _, setHide = Lib.toggle(hideRow, UDim2.new(1, -24, 0.5, 0), function(v)
		State.SetSetting("hideAuras", v)
	end)

	win.onOpen = function()
		setMusic(State.settings.music)
		setSfx(State.settings.sfx)
		setLow(State.settings.low)
		setHide(State.settings.hideAuras)
	end
	-- save volumes once when the window closes (sliders fire continuously)
	win.onClose = function()
		task.spawn(State.Request, "Settings", State.settings)
	end
	return win
end

return SettingsPanel
