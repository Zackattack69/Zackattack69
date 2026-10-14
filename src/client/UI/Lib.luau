--!strict
-- Juicy UI toolkit (rounded fonts, gradients, squash & stretch buttons).

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
Lib.FontBody = Enum.Font.GothamBold

Lib.Colors = {
	Scrap = Color3.fromRGB(70, 170, 255),
	Scrap2 = Color3.fromRGB(30, 100, 230),
	Nova = Color3.fromRGB(160, 110, 255),
	Nova2 = Color3.fromRGB(90, 40, 210),
	Gold = Color3.fromRGB(255, 205, 60),
	Gold2 = Color3.fromRGB(240, 140, 20),
	Green = Color3.fromRGB(90, 230, 110),
	Green2 = Color3.fromRGB(30, 160, 70),
	Red = Color3.fromRGB(255, 80, 90),
	Red2 = Color3.fromRGB(190, 30, 50),
	Grey = Color3.fromRGB(150, 155, 170),
	Grey2 = Color3.fromRGB(90, 95, 110),
	Panel = Color3.fromRGB(28, 32, 48),
	Panel2 = Color3.fromRGB(18, 20, 32),
	Card = Color3.fromRGB(44, 50, 72),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(180, 190, 215),
	Robux = Color3.fromRGB(40, 210, 120),
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

function Lib.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return Lib.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 3,
		ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Lib.textStroke(parent: Instance, thickness: number?): UIStroke
	return Lib.new("UIStroke", { Thickness = thickness or 2, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = parent })
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
		Parent = parent,
	})
end

function Lib.label(props: { [string]: any }): TextLabel
	local stroke = props.Stroke
	props.Stroke = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Lib.Colors.Text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local l = Lib.new("TextLabel", props)
	if stroke ~= false then
		Lib.textStroke(l, 2)
	end
	return l
end

function Lib.tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
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
	return math.clamp(math.min(vp.X / 1100, vp.Y / 720), 0.5, 1.15)
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
-- A chunky gradient button with squash & stretch.
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
	local c1 = props.Color or Lib.Colors.Scrap
	local c2 = props.Color2 or c1:Lerp(Color3.new(0, 0, 0), 0.35)
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
	Lib.corner(b, props.Radius or 14)
	local grad = Lib.gradient(b, c1, c2, 90)
	local st = Lib.stroke(b, c2:Lerp(Color3.new(0, 0, 0), 0.4), 3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Name = "Border"
	Lib.textStroke(b, 2)
	Lib.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = b })
	local scale = Lib.new("UIScale", { Parent = b })

	b.MouseEnter:Connect(function()
		Lib.tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	b.MouseLeave:Connect(function()
		Lib.tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	b.MouseButton1Down:Connect(function()
		Lib.tween(scale, 0.08, { Scale = 0.9 })
	end)
	b.MouseButton1Up:Connect(function()
		Lib.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Elastic)
	end)
	b.Activated:Connect(function()
		Lib.sound("Click", 0.4)
		if props.OnClick then
			props.OnClick()
		end
	end)
	local _ = grad
	return b
end

function Lib.recolor(b: GuiObject, c1: Color3, c2: Color3?)
	local g = b:FindFirstChildOfClass("UIGradient")
	local second = c2 or c1:Lerp(Color3.new(0, 0, 0), 0.35)
	if g then
		g.Color = ColorSequence.new(c1, second)
	end
	local s = b:FindFirstChild("Border") :: UIStroke?
	if s then
		s.Color = second:Lerp(Color3.new(0, 0, 0), 0.4)
	end
end

-- Square HUD icon button with an emoji + caption.
function Lib.iconButton(props: { Icon: string, Label: string?, Size: number, Color: Color3?, Parent: Instance?, Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number?, OnClick: () -> () }): TextButton
	local b = Lib.button({
		Size = UDim2.fromOffset(props.Size, props.Size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = props.Color or Lib.Colors.Card,
		Parent = props.Parent,
		LayoutOrder = props.LayoutOrder,
		OnClick = props.OnClick,
		Radius = 16,
	})
	Lib.label({
		Name = "Icon",
		Text = props.Icon,
		Size = UDim2.fromScale(1, if props.Label then 0.68 else 1),
		Stroke = false,
		Parent = b,
	})
	if props.Label then
		Lib.label({
			Name = "Caption",
			Text = props.Label,
			Size = UDim2.fromScale(1, 0.3),
			Position = UDim2.fromScale(0, 0.7),
			Parent = b,
		})
	end
	return b
end

-- Small red badge with a number, for notification counts.
function Lib.badge(parent: GuiObject): TextLabel
	local l = Lib.label({
		Name = "Badge",
		Text = "",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -8, 0, -8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = Lib.Colors.Red,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	Lib.round(l)
	return l
end

-- Progress bar; returns (frame, setFn(alpha))
function Lib.bar(parent: Instance, size: UDim2, position: UDim2, c1: Color3, c2: Color3): (Frame, (number) -> ())
	local bg = Lib.new("Frame", { Size = size, Position = position, BackgroundColor3 = Color3.fromRGB(15, 16, 26), Parent = parent })
	Lib.round(bg)
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bg })
	Lib.round(fill)
	Lib.gradient(fill, c1, c2, 0)
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
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	local model = DroidModel.Build(droidId, style)
	model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vf
	vf.CurrentCamera = cam
	local _, ext = model:GetBoundingBox()
	local dist = math.max(ext.X, ext.Y, ext.Z) * 1.7
	local center = Vector3.new(0, ext.Y / 2, 0)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist * 0.6, dist * 0.35, -dist), center)
	if spin then
		task.spawn(function()
			local a = 0
			while vf.Parent do
				a += task.wait() * 1.2
				cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(a) * dist, dist * 0.35, -math.cos(a) * dist), center)
			end
		end)
	end
	return vf
end

-- Windows / panels ------------------------------------------------------------------------------
local openPanel: { close: () -> () }? = nil
local panelRoot: ScreenGui? = nil

function Lib.SetPanelRoot(gui: ScreenGui)
	panelRoot = gui
end

-- Creates a modal window. Returns { frame, body, open(), close(), isOpen() }
function Lib.window(title: string, size: Vector2, accent: Color3?, accent2: Color3?): any
	local holder = Lib.new("Frame", {
		Name = title .. "Window",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Lib.Colors.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = panelRoot,
	})
	Lib.corner(holder, 22)
	Lib.gradient(holder, Lib.Colors.Panel, Lib.Colors.Panel2, 90)
	Lib.stroke(holder, Color3.fromRGB(8, 8, 14), 4)
	local fit = Lib.fit(holder)

	local header = Lib.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = holder,
	})
	Lib.corner(header, 22)
	Lib.gradient(header, accent or Lib.Colors.Scrap, accent2 or Lib.Colors.Scrap2, 90)
	-- square off the header's bottom corners
	local filler = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), BackgroundColor3 = Color3.new(1, 1, 1), Parent = header })
	Lib.gradient(filler, (accent or Lib.Colors.Scrap):Lerp(accent2 or Lib.Colors.Scrap2, 0.62), accent2 or Lib.Colors.Scrap2, 90)
	Lib.label({ Name = "Title", Text = title, Size = UDim2.new(1, -120, 0, 40), Position = UDim2.fromOffset(20, 9), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })

	local body = Lib.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -24, 1, -74),
		Position = UDim2.fromOffset(12, 64),
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

	Lib.button({
		Text = "✕",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -10, 0, 7),
		AnchorPoint = Vector2.new(1, 0),
		Color = Lib.Colors.Red,
		Parent = header,
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
function Lib.tabs(parent: Instance, names: { string }, height: number, onSelect: (string) -> ()): (string) -> ()
	local strip = Lib.new("Frame", { Name = "Tabs", Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, Parent = parent })
	Lib.list(strip, 6, true)
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for n, b in buttons do
			if n == name then
				Lib.recolor(b, Lib.Colors.Gold, Lib.Colors.Gold2)
			else
				Lib.recolor(b, Lib.Colors.Card, Lib.Colors.Panel2)
			end
		end
		onSelect(name)
	end
	for i, n in names do
		buttons[n] = Lib.button({
			Text = n,
			Size = UDim2.new(1 / #names, -6, 1, 0),
			Color = Lib.Colors.Card,
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
