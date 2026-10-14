--!strict
-- First-session tutorial (Design Doc §6.7): arrow + pulse ring that highlights
-- the Scrap counter, the crate button (free crate within 30s), then the Map.

local State = require(script.Parent.Parent.State)
local Lib = require(script.Parent.Lib)

local Onboarding = {}

function Onboarding.Run(fxGui: ScreenGui, refs: { [string]: GuiObject })
	local data = State.WaitForData()
	if data.onboarded then
		return
	end

	local ring = Lib.new("Frame", { Size = UDim2.fromOffset(100, 100), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 90, Visible = false, Parent = fxGui })
	Lib.round(ring)
	local ringStroke = Lib.new("UIStroke", { Color = Lib.Colors.Gold, Thickness = 5, Parent = ring })
	local arrow = Lib.label({ Text = "⬇️", Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 91, Stroke = false, Visible = false, Parent = fxGui })
	local tip = Lib.label({ Text = "", Size = UDim2.fromOffset(460, 50), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 91, BackgroundTransparency = 0.15, BackgroundColor3 = Lib.Colors.Panel, Visible = false, Parent = fxGui })
	Lib.corner(tip, 12)
	Lib.padding(tip, 8)

	local target: GuiObject? = nil
	local running = true
	task.spawn(function()
		local t = 0
		while running do
			t += task.wait()
			if target and target.Parent then
				local center = target.AbsolutePosition + target.AbsoluteSize / 2
				local size = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y) + 30
				local pulse = 1 + (t * 1.5) % 1 * 0.35
				ring.Position = UDim2.fromOffset(center.X, center.Y)
				ring.Size = UDim2.fromOffset(size * pulse, size * pulse)
				ringStroke.Transparency = (t * 1.5) % 1
				local above = center.Y > 300
				arrow.Text = if above then "⬇️" else "⬆️"
				arrow.AnchorPoint = if above then Vector2.new(0.5, 1) else Vector2.new(0.5, 0)
				local bob = math.sin(t * 6) * 8
				local edge = size / 2 + 6
				arrow.Position = UDim2.fromOffset(center.X, if above then center.Y - edge + bob else center.Y + edge + bob)
				tip.AnchorPoint = arrow.AnchorPoint
				tip.Position = UDim2.fromOffset(math.clamp(center.X, 240, fxGui.AbsoluteSize.X - 240), if above then center.Y - edge - 64 else center.Y + edge + 64)
			end
		end
	end)

	local function step(ref: GuiObject?, text: string)
		target = ref
		ring.Visible = ref ~= nil
		arrow.Visible = ref ~= nil
		tip.Visible = ref ~= nil
		tip.Text = text
	end

	-- Step 1: Scrap counter
	step(refs.scrap, "This is your SCRAP. Your droids earn it for you!")
	task.wait(4)

	-- Step 2: free crate
	step(refs.crate, "Open your FREE crate to get your first droid!")
	local opened = false
	local startCrates = data.stats.crates
	while not opened do
		task.wait(0.3)
		opened = State.data.stats.crates > startCrates
		if opened then
			break
		end
	end
	-- let the reveal finish
	task.wait(4)

	-- Step 3: Map
	step(refs.map, "Rebirth to unlock new worlds on the Galaxy Map!")
	task.wait(5)

	running = false
	ring:Destroy()
	arrow:Destroy()
	tip:Destroy()
	State.Request("FinishOnboarding")
	State.Fire("Toast", "Tip: click scrap piles to salvage, and keep opening crates!", "success")
end

return Onboarding
