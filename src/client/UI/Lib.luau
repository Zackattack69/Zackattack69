--!strict
-- UI kit in the style of top simulator games: bright light panels, thick dark
-- outlines, chunky glossy gradient buttons, bubbly Fredoka text with outlines,
-- squash & stretch on every press, and a soft blur behind open windows.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DroidModel = require(Shared.DroidModel)
local Sounds = require(Shared.Config.Sounds)
local State = require(script.Parent.Parent.State)

local Lib = {}

Lib.Font = Enum.Font.FredokaOne
Lib.FontTitle = Enum.Font.LuckiestGuy
Lib.FontBody = Enum.Font.FredokaOne

Lib.Colors = {
	-- currencies / brand
	Scrap = Color3.fromRGB(255, 205, 60), -- Credits (gold coin)
	Scrap2 = Color3.fromRGB(235, 140, 20),
	Nova = Color3.fromRGB(110, 200, 255), -- Aura (diamond)
	Nova2 = Color3.fromRGB(60, 110, 240),
	Blue = Color3.fromRGB(80, 180, 255),
	Blue2 = Color3.fromRGB(40, 100, 230),
	Gold = Color3.fromRGB(255, 215, 70),
	Gold2 = Color3.fromRGB(245, 150, 25),
	Green = Color3.fromRGB(120, 235, 90),
	Green2 = Color3.fromRGB(40, 175, 60),
	Red = Color3.fromRGB(255, 95, 95),
	Red2 = Color3.fromRGB(215, 40, 60),
	Purple = Color3.fromRGB(200, 120, 255),
	Purple2 = Color3.fromRGB(125, 55, 225),
	Pink = Color3.fromRGB(255, 130, 200),
	Pink2 = Color3.fromRGB(220, 60, 150),
	Grey = Color3.fromRGB(190, 195, 210),
	Grey2 = Color3.fromRGB(125, 132, 155),
	Robux = Color3.fromRGB(110, 235, 120),
	-- surfaces
	Outline = Color3.fromRGB(28, 32, 58),
	Panel = Color3.fromRGB(240, 245, 255),
	Panel2 = Color3.fromRGB(206, 218, 242),
	Card = Color3.fromRGB(255, 255, 255),
	Card2 = Color3.fromRGB(228, 234, 248),
	Inset = Color3.fromRGB(214, 224, 244),
	Text = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(45, 52, 90),
	SubText = Color3.fromRGB(110, 120, 160),
}

Lib.ROBUX = "\u{E002}" -- Roblox's built-in Robux glyph

-- Instance helpers ----------------------------------------------------------------
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
	return Lib.new("UICorner", { CornerRadius = UDim.new(0, radius or 14), Parent = parent })
end

function Lib.round(parent: Instance): UICorner
	return Lib.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

-- Thick dark outline around a frame/button border.
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

-- Dark outline around text.
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

-- White outlined text (the classic simulator look). Pass Dark = true for dark text on white cards.
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

-- A white rounded card with a thick outline.
function Lib.card(parent: Instance?, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	p.BackgroundColor3 = p.BackgroundColor3 or Lib.Colors.Card
	p.Parent = parent or p.Parent
	local f = Lib.new("Frame", p)
	Lib.corner(f, 16)
	Lib.stroke(f, Lib.Colors.Outline, 3)
	return f
end

-- Sounds ------------------------------------------------------------------------------
local soundCache: { [string]: Sound } = {}
function Lib.sound(name: string, volume: number?)
	if not State.settings.sfx then
		return
	end
	local id = (Sounds :: any)[name]
	if not id or id == "" then
		return
	end
	local s = soundCache[name]
	if not s then
		local created = Instance.new("Sound")
		created.SoundId = id
		created.Parent = SoundService
		soundCache[name] = created
		s = created
	end
	s.Volume = volume or 0.5
	SoundService:PlayLocalSound(s)
end

-- Responsive scaling ---------------------------------------------------------------------
local fitScales: { UIScale } = {}
local function fitValue(): number
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 800)
	return math.clamp(math.min(vp.X / 1150, vp.Y / 760), 0.5, 1.15)
end
Lib.FitValue = fitValue

function Lib.fit(parent: GuiObject): UIScale
	local s = Lib.new("UIScale", { Name = "Fit", Scale = fitValue(), Parent = parent })
	table.insert(fitScales, s)
	return s
end

task.spawn(function()
	local cam = Workspace.CurrentCamera
	while not cam do
		task.wait()
		cam = Workspace.CurrentCamera
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local v = fitValue()
		for _, s in fitScales do
			if s:GetAttribute("Animating") ~= true then
				s.Scale = v
			end
		end
	end)
end)

-- Buttons ---------------------------------------------------------------------------------
-- Chunky glossy gradient button with squash & stretch.
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
}): TextButton
	local c1 = props.Color or Lib.Colors.Blue
	local c2 = props.Color2 or c1:Lerp(Color3.new(0, 0, 0), 0.3)
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
		Parent = props.Parent,
	})
	local radius = props.Radius or 14
	Lib.corner(b, radius)
	Lib.gradient(b, c1, c2, 90)
	Lib.stroke(b, Lib.Colors.Outline, 3)
	Lib.textStroke(b, 2.5)
	Lib.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), Parent = b })
	-- glossy highlight on the top half
	local gloss = Lib.new("Frame", { Name = "Gloss", Size = UDim2.new(1, 8, 0.45, 0), Position = UDim2.new(0, -4, 0, -5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.78, ZIndex = b.ZIndex, Parent = b })
	Lib.corner(gloss, radius)
	local scale = Lib.new("UIScale", { Parent = b })

	b.MouseEnter:Connect(function()
		Lib.tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	b.MouseLeave:Connect(function()
		Lib.tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	b.MouseButton1Down:Connect(function()
		Lib.tween(scale, 0.08, { Scale = 0.88 })
	end)
	b.MouseButton1Up:Connect(function()
		Lib.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Elastic)
	end)
	b.Activated:Connect(function()
		Lib.sound("Click", 0.4)
		if props.OnClick then
			props.OnClick()
		end
	end)
	return b
end

function Lib.recolor(b: GuiObject, c1: Color3, c2: Color3?)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(c1, c2 or c1:Lerp(Color3.new(0, 0, 0), 0.3))
	end
end

-- Big square menu button: gradient tile, huge emoji, outlined caption over the bottom edge.
function Lib.iconButton(props: { Icon: string, Label: string?, Size: number, Color: Color3?, Color2: Color3?, Parent: Instance?, Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number?, OnClick: () -> () }): TextButton
	local b = Lib.button({
		Size = UDim2.fromOffset(props.Size, props.Size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = props.Color or Lib.Colors.Blue,
		Color2 = props.Color2,
		Parent = props.Parent,
		LayoutOrder = props.LayoutOrder,
		OnClick = props.OnClick,
		Radius = 18,
	})
	Lib.label({ Name = "Icon", Text = props.Icon, Size = UDim2.fromScale(0.95, if props.Label then 0.8 else 0.95), Position = UDim2.fromScale(0.5, if props.Label then 0.42 else 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, Parent = b })
	if props.Label then
		Lib.label({ Name = "Caption", Text = props.Label, Size = UDim2.new(1.2, 0, 0.32, 0), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = b })
	end
	return b
end

-- Small red notification badge.
function Lib.badge(parent: GuiObject): TextLabel
	local l = Lib.label({
		Name = "Badge",
		Text = "",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -4, 0, 4),
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

-- Progress bar; returns (frame, setFn(alpha))
function Lib.bar(parent: Instance, size: UDim2, position: UDim2, c1: Color3, c2: Color3): (Frame, (number) -> ())
	local bg = Lib.new("Frame", { Size = size, Position = position, BackgroundColor3 = Color3.fromRGB(40, 45, 75), Parent = parent })
	Lib.round(bg)
	Lib.stroke(bg, Lib.Colors.Outline, 2)
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bg })
	Lib.round(fill)
	Lib.gradient(fill, c1, c2, 90)
	return bg, function(a: number)
		Lib.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(a, 0, 1), 1) })
	end
end

-- Droid viewport ------------------------------------------------------------------------------
function Lib.viewport(parent: Instance, droidId: number, style: string, size: UDim2, position: UDim2?, spin: boolean?): ViewportFrame
	local vf = Lib.new("ViewportFrame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(210, 210, 220),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Parent = parent,
	})
	local model = DroidModel.Build(droidId, style)
	model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	cam.Parent = vf
	vf.CurrentCamera = cam
	local _, ext = model:GetBoundingBox()
	local dist = math.max(ext.X, ext.Y, ext.Z) * 1.9
	local center = Vector3.new(0, ext.Y / 2, 0)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist * 0.55, dist * 0.3, -dist), center)
	if spin then
		task.spawn(function()
			local a = 0
			while vf.Parent do
				a += task.wait() * 1.2
				cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(a) * dist, dist * 0.3, -math.cos(a) * dist), center)
			end
		end)
	end
	return vf
end

-- Windows / panels ------------------------------------------------------------------------------
local openPanel: any = nil
local panelRoot: ScreenGui? = nil
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting

function Lib.SetPanelRoot(gui: ScreenGui)
	panelRoot = gui
end

-- Creates a modal window. Returns { frame, body, header, open(), close(), toggle(), isOpen() }
function Lib.window(title: string, size: Vector2, accent: Color3?, accent2: Color3?, icon: string?): any
	local c1 = accent or Lib.Colors.Blue
	local c2 = accent2 or c1:Lerp(Color3.new(0, 0, 0), 0.3)
	local holder = Lib.new("Frame", {
		Name = title .. "Window",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 10,
		Parent = panelRoot,
	})
	Lib.corner(holder, 26)
	Lib.gradient(holder, Lib.Colors.Panel, Lib.Colors.Panel2, 90)
	Lib.stroke(holder, Lib.Colors.Outline, 5)
	local fit = Lib.fit(holder)

	local header = Lib.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, -24, 0, 62),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = holder,
	})
	Lib.corner(header, 18)
	Lib.gradient(header, c1, c2, 90)
	Lib.stroke(header, Lib.Colors.Outline, 3)
	local hg = Lib.new("Frame", { Size = UDim2.new(1, -12, 0.42, 0), Position = UDim2.fromOffset(6, 4), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, Parent = header })
	Lib.corner(hg, 14)
	Lib.label({ Name = "Title", Text = (if icon then icon .. "  " else "") .. title, Font = Lib.FontTitle, Size = UDim2.new(1, -40, 0, 44), Position = UDim2.fromOffset(18, 9), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })

	local body = Lib.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -28, 1, -98),
		Position = UDim2.fromOffset(14, 86),
		BackgroundTransparency = 1,
		Parent = holder,
	})

	local win: any = { frame = holder, body = body, header = header }
	local isOpen = false

	function win.close()
		if not isOpen then
			return
		end
		isOpen = false
		if openPanel == win then
			openPanel = nil
			Lib.tween(blur, 0.2, { Size = 0 })
		end
		fit:SetAttribute("Animating", true)
		local tw = Lib.tween(fit, 0.15, { Scale = fitValue() * 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if not isOpen then
				holder.Visible = false
			end
			fit:SetAttribute("Animating", false)
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
		Lib.tween(blur, 0.25, { Size = 14 })
		fit:SetAttribute("Animating", true)
		fit.Scale = fitValue() * 0.5
		local tw = Lib.tween(fit, 0.35, { Scale = fitValue() }, Enum.EasingStyle.Back)
		tw.Completed:Connect(function()
			fit:SetAttribute("Animating", false)
		end)
		Lib.sound("Click", 0.3)
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

	-- big red X hanging off the top-right corner
	Lib.button({
		Text = "X",
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(1, 16, 0, -16),
		AnchorPoint = Vector2.new(1, 0),
		Color = Lib.Colors.Red,
		Color2 = Lib.Colors.Red2,
		Radius = 16,
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

-- Generic tab strip. Returns setter.
function Lib.tabs(parent: Instance, names: { string }, height: number, onSelect: (string) -> (), color: Color3?, color2: Color3?): (string) -> ()
	local strip = Lib.new("Frame", { Name = "Tabs", Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, Parent = parent })
	Lib.list(strip, 6, true)
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for n, b in buttons do
			if n == name then
				Lib.recolor(b, color or Lib.Colors.Gold, color2 or Lib.Colors.Gold2)
			else
				Lib.recolor(b, Lib.Colors.Grey, Lib.Colors.Grey2)
			end
		end
		onSelect(name)
	end
	for i, n in names do
		buttons[n] = Lib.button({
			Text = n,
			Size = UDim2.new(1 / #names, -6, 1, 0),
			Color = Lib.Colors.Grey,
			Parent = strip,
			LayoutOrder = i,
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
