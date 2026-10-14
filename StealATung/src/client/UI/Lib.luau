--!strict
-- UI kit. Smooth, bouncy and premium: cream and wood-brown panels with rarity
-- colours as accents, rounded corners and soft shadows everywhere, one chunky
-- rounded font (Fredoka One), buttons that squash to 0.9 and bounce back via
-- 1.05, menus that slide in from the side in 0.25 s, numbers that count up,
-- a soft "pop" on every tap and a "whoosh" when a menu opens.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Sounds = require(Shared.Config.Sounds)
local Tungs = require(Shared.Config.Tungs)
local TungModel = require(Shared.TungModel)
local State = require(script.Parent.Parent.State)

local Lib = {}

Lib.Font = Enum.Font.FredokaOne

Lib.Colors = {
	Cream = Color3.fromRGB(255, 247, 230),
	Cream2 = Color3.fromRGB(244, 228, 196),
	Wood = Color3.fromRGB(168, 110, 64),
	Wood2 = Color3.fromRGB(118, 74, 40),
	WoodDark = Color3.fromRGB(84, 52, 28),
	Outline = Color3.fromRGB(74, 44, 22),
	Text = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(86, 54, 30),
	SubText = Color3.fromRGB(150, 112, 78),
	Money = Color3.fromRGB(110, 225, 90),
	Money2 = Color3.fromRGB(40, 150, 50),
	Gold = Color3.fromRGB(255, 205, 60),
	Gold2 = Color3.fromRGB(230, 140, 20),
	Green = Color3.fromRGB(120, 220, 90),
	Green2 = Color3.fromRGB(45, 150, 55),
	Red = Color3.fromRGB(255, 96, 96),
	Red2 = Color3.fromRGB(205, 40, 55),
	Blue = Color3.fromRGB(90, 180, 255),
	Blue2 = Color3.fromRGB(40, 105, 225),
	Purple = Color3.fromRGB(190, 120, 255),
	Purple2 = Color3.fromRGB(120, 55, 220),
	Pink = Color3.fromRGB(255, 140, 200),
	Pink2 = Color3.fromRGB(215, 65, 150),
	Grey = Color3.fromRGB(196, 190, 182),
	Grey2 = Color3.fromRGB(128, 120, 112),
	Robux = Color3.fromRGB(110, 230, 120),
}

Lib.ROBUX = "\u{E002}" -- Roblox's built-in Robux glyph

Lib.Touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Instance helpers ---------------------------------------------------------------------------
function Lib.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		if not props or props.Font == nil then
			(inst :: any).Font = Lib.Font
		end
	end
	if inst:IsA("GuiObject") and (not props or props.BorderSizePixel == nil) then
		(inst :: GuiObject).BorderSizePixel = 0
	end
	inst.Parent = parent
	return inst
end

function Lib.corner(parent: Instance, radius: number?): UICorner
	return Lib.new("UICorner", { CornerRadius = UDim.new(0, radius or 16), Parent = parent })
end

function Lib.round(parent: Instance): UICorner
	return Lib.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

function Lib.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return Lib.new("UIStroke", {
		Name = "Border",
		Color = color or Lib.Colors.Outline,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Lib.textStroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	return Lib.new("UIStroke", {
		Thickness = thickness or 2.5,
		Color = color or Lib.Colors.Outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Lib.gradient(parent: Instance, c1: Color3, c2: Color3, rotation: number?): UIGradient
	return Lib.new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90, Parent = parent })
end

function Lib.padding(parent: Instance, px: number)
	Lib.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function Lib.list(parent: Instance, padding: number, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return Lib.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = parent,
	})
end

-- Soft drop shadow behind a rounded element.
function Lib.shadow(target: GuiObject, radius: number?)
	local s = Lib.new("Frame", {
		Name = "Shadow",
		Size = target.Size,
		Position = target.Position + UDim2.fromOffset(0, 5),
		AnchorPoint = target.AnchorPoint,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.72,
		ZIndex = math.max(0, target.ZIndex - 1),
		LayoutOrder = target.LayoutOrder,
		Parent = target.Parent,
	})
	Lib.corner(s, radius or 16)
	return s
end

-- White outlined text. Pass Dark = true for dark-brown text on cream.
function Lib.label(props: { [string]: any }): TextLabel
	local stroke = props.Stroke
	local dark = props.Dark
	props.Stroke = nil
	props.Dark = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or (if dark then Lib.Colors.TextDark else Lib.Colors.Text)
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local l = Lib.new("TextLabel", props)
	if stroke ~= false and not dark then
		Lib.textStroke(l, 2.5)
	end
	return l
end

function Lib.tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Cream card with a wood outline.
function Lib.card(parent: Instance?, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	p.BackgroundColor3 = p.BackgroundColor3 or Lib.Colors.Cream
	p.Parent = parent or p.Parent
	local f = Lib.new("Frame", p)
	Lib.corner(f, 16)
	Lib.stroke(f, Lib.Colors.Wood2, 3)
	return f
end

-- Rarity colouring for a label/frame (Secret gets the rainbow).
function Lib.rarityColor(t: Tungs.Tung): Color3
	return Tungs.Color(t)
end

function Lib.rainbowIfSecret(obj: GuiObject, t: Tungs.Tung)
	if t.rarity == "Secret" then
		Lib.new("UIGradient", { Color = Rarities.RAINBOW, Parent = obj })
	end
end

-- Sounds --------------------------------------------------------------------------------------------
local soundTemplates: { [string]: Sound } = {}
local function template(name: string): Sound?
	local cue = Sounds[name]
	if not cue or cue.id == "" then
		return nil
	end
	local s = soundTemplates[name]
	if not s then
		local created = Instance.new("Sound")
		created.SoundId = cue.id
		created.PlaybackSpeed = cue.pitch or 1
		soundTemplates[name] = created
		s = created
	end
	return s
end

function Lib.sound(name: string, volume: number?, pitch: number?)
	local vol = State.settings.sfx
	if vol <= 0 then
		return
	end
	local t = template(name)
	local cue = Sounds[name]
	if not t or not cue then
		return
	end
	local s = t:Clone()
	s.Volume = (volume or cue.volume or 0.5) * vol * 1.6
	if pitch then
		s.PlaybackSpeed = pitch
	end
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(8, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Positional sound at a world point (rolls off with distance).
function Lib.sound3D(name: string, pos: Vector3, volume: number?, pitch: number?)
	local vol = State.settings.sfx
	local t = template(name)
	local cue = Sounds[name]
	if vol <= 0 or not t or not cue then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = pos
	holder.Parent = Workspace.Terrain
	local s = t:Clone()
	s.Volume = (volume or cue.volume or 0.5) * vol * 1.6
	if pitch then
		s.PlaybackSpeed = pitch
	end
	s.RollOffMaxDistance = 140
	s.RollOffMinDistance = 12
	s.Parent = holder
	s:Play()
	task.delay(6, function()
		holder:Destroy()
	end)
end

-- Responsive scaling ------------------------------------------------------------------------------------
local function viewport(): Vector2
	local cam = Workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 800)
end

type ScaleEntry = { scale: UIScale, fn: () -> number }
local scales: { ScaleEntry } = {}

-- HUD scale: phones stay big enough that 80 px design buttons are >= 60 px.
function Lib.HudScale(): number
	local vp = viewport()
	local s = math.min(vp.X / 1100, vp.Y / 620)
	return math.clamp(s, if Lib.Touch then 0.75 else 0.62, 1.2)
end

local function addScale(parent: GuiObject, fn: () -> number): UIScale
	local s = Lib.new("UIScale", { Name = "Fit", Scale = fn(), Parent = parent })
	table.insert(scales, { scale = s, fn = fn })
	return s
end

function Lib.hudFit(parent: GuiObject): UIScale
	return addScale(parent, Lib.HudScale)
end

-- Window scale: fit a design size on screen.
function Lib.windowFit(parent: GuiObject, design: Vector2): UIScale
	return addScale(parent, function()
		local vp = viewport()
		return math.clamp(math.min((vp.X - 40) / design.X, (vp.Y - 40) / design.Y), 0.45, 1.15)
	end)
end

task.spawn(function()
	local cam = Workspace.CurrentCamera
	while not cam do
		task.wait()
		cam = Workspace.CurrentCamera
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		for _, e in scales do
			if e.scale.Parent then
				e.scale.Scale = e.fn()
			end
		end
	end)
end)

-- Buttons ---------------------------------------------------------------------------------------------------
-- Press: 0.9; release: bounce to 1.05, then settle at 1.0.
function Lib.bouncy(b: GuiButton)
	local scale = b:FindFirstChild("Bounce") :: UIScale? or Lib.new("UIScale", { Name = "Bounce", Parent = b })
	local s = scale :: UIScale
	b.MouseButton1Down:Connect(function()
		Lib.tween(s, 0.08, { Scale = 0.9 })
	end)
	local function release()
		if s.Scale < 1 then
			local tw = Lib.tween(s, 0.1, { Scale = 1.05 }, Enum.EasingStyle.Quad)
			tw.Completed:Once(function()
				Lib.tween(s, 0.12, { Scale = 1 }, Enum.EasingStyle.Quad)
			end)
		end
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
end

function Lib.button(props: {
	Text: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Color2: Color3?,
	Parent: Instance?,
	TextSize: number?,
	LayoutOrder: number?,
	Name: string?,
	OnClick: (() -> ())?,
	Radius: number?,
	ZIndex: number?,
}): TextButton
	local c1 = props.Color or Lib.Colors.Green
	local c2 = props.Color2 or c1:Lerp(Color3.new(0, 0, 0), 0.28)
	local b = Lib.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = props.Text or "",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = props.TextSize == nil,
		TextSize = props.TextSize or 14,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local radius = props.Radius or 16
	Lib.corner(b, radius)
	Lib.gradient(b, c1, c2, 90)
	Lib.stroke(b, Lib.Colors.Outline, 3)
	Lib.textStroke(b, 2.5)
	Lib.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = b })
	local gloss = Lib.new("Frame", { Name = "Gloss", Size = UDim2.new(1, 12, 0.42, 0), Position = UDim2.new(0, -6, 0, -6), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, ZIndex = b.ZIndex, Parent = b })
	Lib.corner(gloss, radius)
	Lib.bouncy(b)
	b.Activated:Connect(function()
		Lib.sound("Pop")
		if props.OnClick then
			props.OnClick()
		end
	end)
	return b
end

function Lib.recolor(b: GuiObject, c1: Color3, c2: Color3?)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(c1, c2 or c1:Lerp(Color3.new(0, 0, 0), 0.28))
	end
end

-- Big round icon button with a caption under it (HUD).
function Lib.iconButton(props: { Icon: string, Label: string?, Size: number, Color: Color3?, Color2: Color3?, Parent: Instance?, Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number?, OnClick: () -> () }): TextButton
	local b = Lib.button({
		Size = UDim2.fromOffset(props.Size, props.Size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = props.Color or Lib.Colors.Wood,
		Color2 = props.Color2,
		Parent = props.Parent,
		LayoutOrder = props.LayoutOrder,
		OnClick = props.OnClick,
		Radius = math.floor(props.Size / 2),
	})
	Lib.label({ Name = "Icon", Text = props.Icon, Size = UDim2.fromScale(0.86, if props.Label then 0.7 else 0.86), Position = UDim2.fromScale(0.5, if props.Label then 0.42 else 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = b })
	if props.Label then
		Lib.label({ Name = "Caption", Text = props.Label, Size = UDim2.new(1.3, 0, 0.3, 0), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = b })
	end
	return b
end

function Lib.badge(parent: GuiObject): TextLabel
	local l = Lib.label({
		Name = "Badge",
		Text = "",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -6, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = Lib.Colors.Red2,
		Visible = false,
		ZIndex = 6,
		Parent = parent,
	})
	Lib.round(l)
	Lib.stroke(l, Color3.new(1, 1, 1), 2)
	return l
end

-- Progress bar; returns (frame, setFn(alpha)).
function Lib.bar(parent: Instance, size: UDim2, position: UDim2, c1: Color3, c2: Color3): (Frame, (number) -> ())
	local bg = Lib.new("Frame", { Size = size, Position = position, BackgroundColor3 = Lib.Colors.WoodDark, Parent = parent })
	Lib.round(bg)
	Lib.stroke(bg, Lib.Colors.Outline, 2)
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bg })
	Lib.round(fill)
	Lib.gradient(fill, c1, c2, 90)
	return bg, function(a: number)
		Lib.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(a, 0, 1), 1) })
	end
end

-- Circular progress ring (used for the base-lock cooldown). Returns setter(0..1).
function Lib.radial(parent: GuiObject, color: Color3, transparency: number?): (number) -> ()
	local halves = {}
	for k = 1, 2 do
		local clip = Lib.new("Frame", {
			Name = "RadialHalf" .. k,
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(if k == 1 then 0.5 else 0, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = parent.ZIndex + 2,
			Parent = parent,
		})
		local circle = Lib.new("Frame", {
			Size = UDim2.fromScale(2, 1),
			Position = UDim2.fromScale(if k == 1 then -1 else 0, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = transparency or 0.35,
			ZIndex = parent.ZIndex + 2,
			Parent = clip,
		})
		Lib.round(circle)
		local g = Lib.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.499, 0),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = circle,
		})
		halves[k] = g
	end
	-- right half covers 0..50% (12 -> 6 o'clock), left half 50..100%
	return function(p: number)
		local angle = math.clamp(p, 0, 1) * 360
		halves[1].Rotation = math.clamp(angle, 0, 180)
		halves[2].Rotation = math.clamp(angle, 180, 360)
		halves[1].Parent.Parent.Visible = p > 0
		halves[2].Parent.Parent.Visible = p > 0.5
	end
end

-- Number that counts up/down smoothly instead of jumping.
function Lib.countUp(label: TextLabel, format: (number) -> string): (number) -> ()
	local value = Instance.new("NumberValue")
	local current = 0
	local tw: Tween? = nil
	value.Changed:Connect(function(v)
		current = v
		label.Text = format(v)
	end)
	return function(target: number)
		if tw then
			tw:Cancel()
		end
		if math.abs(target - current) < 1e-6 then
			label.Text = format(target)
			return
		end
		value.Value = current
		tw = TweenService:Create(value, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
		;(tw :: Tween):Play()
	end
end

-- Toggle switch. Returns (frame, set(bool)).
function Lib.toggle(parent: Instance, position: UDim2, onChange: (boolean) -> ()): (Frame, (boolean) -> ())
	local f = Lib.new("TextButton", { Size = UDim2.fromOffset(92, 44), Position = position, AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Lib.Colors.Grey, Text = "", AutoButtonColor = false, Parent = parent })
	Lib.round(f)
	Lib.stroke(f, Lib.Colors.Outline, 3)
	local knob = Lib.new("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 5, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f })
	Lib.round(knob)
	local on = false
	local function set(v: boolean)
		on = v
		Lib.tween(knob, 0.15, { Position = if v then UDim2.new(1, -39, 0.5, 0) else UDim2.new(0, 5, 0.5, 0) }, Enum.EasingStyle.Back)
		Lib.tween(f, 0.15, { BackgroundColor3 = if v then Lib.Colors.Green2 else Lib.Colors.Grey })
	end
	f.Activated:Connect(function()
		Lib.sound("Pop")
		set(not on)
		onChange(on)
	end)
	return f, set
end

-- Horizontal slider (tap or drag). Returns (frame, set(0..1)).
function Lib.slider(parent: Instance, size: UDim2, position: UDim2, onChange: (number) -> ()): (Frame, (number) -> ())
	local bg = Lib.new("TextButton", { Size = size, Position = position, AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Lib.Colors.WoodDark, Text = "", AutoButtonColor = false, Parent = parent })
	Lib.round(bg)
	Lib.stroke(bg, Lib.Colors.Outline, 2)
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bg })
	Lib.round(fill)
	Lib.gradient(fill, Lib.Colors.Gold, Lib.Colors.Gold2, 90)
	local knob = Lib.new("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = bg })
	Lib.round(knob)
	Lib.stroke(knob, Lib.Colors.Outline, 3)
	local function set(v: number)
		v = math.clamp(v, 0, 1)
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
	end
	local dragging = false
	local function fromX(x: number)
		local v = math.clamp((x - bg.AbsolutePosition.X) / math.max(1, bg.AbsoluteSize.X), 0, 1)
		set(v)
		onChange(v)
	end
	bg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	return bg, set
end

-- Tung 3D viewport ------------------------------------------------------------------------------------------------
type Spinner = { vf: ViewportFrame, model: Model, base: CFrame, offset: number }
local spinners: { Spinner } = {}

function Lib.tungViewport(parent: Instance, id: string, mut: string?, size: UDim2, position: UDim2?, spin: boolean?): ViewportFrame
	local vf = Lib.new("ViewportFrame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 180),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Parent = parent,
	})
	local model = TungModel.Build(id, mut, { aura = false })
	model:PivotTo(CFrame.identity)
	model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	local cf, ext = model:GetBoundingBox()
	local dist = math.max(ext.X, ext.Y, ext.Z) * 2.05
	local center = cf.Position
	cam.CFrame = CFrame.lookAt(center + Vector3.new(0, ext.Y * 0.12, -dist), center)
	if spin then
		table.insert(spinners, { vf = vf, model = model, base = model:GetPivot(), offset = math.random() * 6 })
	end
	return vf
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for k = #spinners, 1, -1 do
		local s = spinners[k]
		if not s.vf.Parent then
			table.remove(spinners, k)
		elseif s.vf.Visible then
			s.model:PivotTo(s.base * CFrame.Angles(0, math.sin(t * 0.9 + s.offset) * 0.7, 0) + Vector3.new(0, math.abs(math.sin(t * 2 + s.offset)) * 0.25, 0))
		end
	end
end)

-- Windows --------------------------------------------------------------------------------------------------------------
local openPanel: any = nil
local panelRoot: ScreenGui? = nil

function Lib.SetPanelRoot(gui: ScreenGui)
	panelRoot = gui
end

-- A wooden-framed cream window that slides in from the side.
-- Returns { frame, body, header, open(), close(), toggle(), isOpen(), onOpen, onClose }
function Lib.window(title: string, size: Vector2, accent: Color3?, icon: string?): any
	local c = Lib.Colors
	local holder = Lib.new("Frame", {
		Name = title .. "Window",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.new(-0.8, 0, 0.52, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = c.Wood,
		Visible = false,
		ZIndex = 10,
		Parent = panelRoot,
	})
	Lib.corner(holder, 28)
	Lib.gradient(holder, c.Wood, c.Wood2, 90)
	Lib.stroke(holder, c.Outline, 4)
	Lib.windowFit(holder, size + Vector2.new(30, 30))
	-- soft shadow
	local shadow = Lib.new("Frame", { Name = "Shadow", Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, 6), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7, ZIndex = 9, Parent = holder })
	Lib.corner(shadow, 30)

	local inner = Lib.new("Frame", { Name = "Inner", Size = UDim2.new(1, -20, 1, -82), Position = UDim2.fromOffset(10, 72), BackgroundColor3 = c.Cream, ZIndex = 10, Parent = holder })
	Lib.corner(inner, 20)
	Lib.gradient(inner, c.Cream, c.Cream2, 90)

	local header = Lib.new("Frame", { Name = "Header", Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 9), BackgroundTransparency = 1, ZIndex = 11, Parent = holder })
	local titleLabel = Lib.label({ Name = "Title", Text = (if icon then icon .. "  " else "") .. title, Size = UDim2.new(1, -80, 1, -6), Position = UDim2.fromOffset(12, 3), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = header })
	if accent then
		titleLabel.TextColor3 = accent
	end

	local body = Lib.new("Frame", { Name = "Body", Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 11, Parent = inner })

	local win: any = { frame = holder, body = body, header = header, title = titleLabel }
	local isOpen = false

	function win.close()
		if not isOpen then
			return
		end
		isOpen = false
		if openPanel == win then
			openPanel = nil
		end
		local tw = Lib.tween(holder, 0.2, { Position = UDim2.new(-0.8, 0, 0.52, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Once(function()
			if not isOpen then
				holder.Visible = false
			end
		end)
		if win.onClose then
			win.onClose()
		end
	end

	function win.open()
		if openPanel and openPanel ~= win then
			openPanel.close()
		end
		openPanel = win
		isOpen = true
		holder.Visible = true
		holder.Position = UDim2.new(-0.8, 0, 0.52, 0)
		Lib.tween(holder, 0.25, { Position = UDim2.new(0.5, 0, 0.52, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Lib.sound("Whoosh")
		if win.onOpen then
			win.onOpen()
		end
	end

	function win.toggle()
		if isOpen then
			win.close()
		else
			win.open()
		end
	end

	function win.isOpen()
		return isOpen
	end

	Lib.button({
		Text = "✕",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(1, 14, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		Color = c.Red,
		Color2 = c.Red2,
		Radius = 30,
		ZIndex = 12,
		Parent = holder,
		OnClick = win.close,
	})
	return win
end

function Lib.closeAll()
	if openPanel then
		openPanel.close()
	end
end

-- Tab strip. Returns select(name).
function Lib.tabs(parent: Instance, names: { string }, height: number, onSelect: (string) -> (), colors: { [string]: Color3 }?): (string) -> ()
	local strip = Lib.new("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, height + 8),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
		Parent = parent,
	})
	Lib.list(strip, 6, true)
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for n, b in buttons do
			local col = if colors and colors[n] then colors[n] else Lib.Colors.Gold
			if n == name then
				Lib.recolor(b, col)
			else
				Lib.recolor(b, Lib.Colors.Grey, Lib.Colors.Grey2)
			end
		end
		onSelect(name)
	end
	local width = if #names > 5 then 112 else 200
	for i, n in names do
		buttons[n] = Lib.button({
			Text = n,
			Size = UDim2.fromOffset(width, height),
			Color = Lib.Colors.Grey,
			Parent = strip,
			LayoutOrder = i,
			ZIndex = 11,
			OnClick = function()
				select(n)
			end,
		})
	end
	return select
end

function Lib.player(): Player
	return Players.LocalPlayer
end

return Lib
