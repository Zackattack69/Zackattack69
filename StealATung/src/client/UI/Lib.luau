--!strict
-- UI kit in the style of the big Roblox "steal" / simulator games: candy
-- colours, chunky 3D gradient buttons with a dark lip and a shine that sweeps
-- across them, thick dark outlines, bold cartoon fonts, striped animated
-- headers, rotating light rays, twinkling sparkles, and rainbow / gold / fire
-- text that moves. Buttons squash to 0.9 and bounce back via 1.05, menus slide
-- in from the side in 0.25 s, numbers count up, taps pop, menus whoosh.

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
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
Lib.FontTitle = Enum.Font.LuckiestGuy

Lib.Colors = {
	-- surfaces (names kept from the first version so every panel keeps working)
	Cream = Color3.fromRGB(255, 255, 255), -- panel / card light
	Cream2 = Color3.fromRGB(222, 232, 255), -- panel / card gradient end
	Wood = Color3.fromRGB(120, 96, 255), -- indigo accent
	Wood2 = Color3.fromRGB(70, 48, 210),
	WoodDark = Color3.fromRGB(34, 28, 74), -- bar backgrounds, key chips
	Outline = Color3.fromRGB(22, 18, 44),
	Text = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(255, 255, 255), -- panels are dark now, so "dark" text is white too
	SubText = Color3.fromRGB(206, 210, 236),
	Panel = Color3.fromRGB(46, 46, 56), -- window body (with little studs)
	Panel2 = Color3.fromRGB(64, 64, 78), -- cards on the body
	-- candy palette
	Money = Color3.fromRGB(120, 255, 90),
	Money2 = Color3.fromRGB(26, 186, 60),
	Gold = Color3.fromRGB(255, 226, 60),
	Gold2 = Color3.fromRGB(255, 146, 20),
	Green = Color3.fromRGB(110, 240, 80),
	Green2 = Color3.fromRGB(30, 170, 50),
	Red = Color3.fromRGB(255, 92, 104),
	Red2 = Color3.fromRGB(214, 28, 60),
	Blue = Color3.fromRGB(70, 196, 255),
	Blue2 = Color3.fromRGB(30, 98, 240),
	Purple = Color3.fromRGB(196, 116, 255),
	Purple2 = Color3.fromRGB(118, 46, 236),
	Pink = Color3.fromRGB(255, 124, 214),
	Pink2 = Color3.fromRGB(226, 46, 160),
	Orange = Color3.fromRGB(255, 176, 60),
	Orange2 = Color3.fromRGB(246, 96, 26),
	Cyan = Color3.fromRGB(90, 240, 246),
	Cyan2 = Color3.fromRGB(20, 160, 220),
	Grey = Color3.fromRGB(196, 202, 224),
	Grey2 = Color3.fromRGB(122, 128, 160),
	Robux = Color3.fromRGB(90, 240, 110),
}

Lib.ROBUX = "\u{E002}" -- Roblox's built-in Robux glyph

Lib.Touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

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
		Thickness = thickness or 3,
		Color = color or Lib.Colors.Outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Lib.gradient(parent: Instance, c1: Color3, c2: Color3, rotation: number?): UIGradient
	return Lib.new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90, Parent = parent })
end

-- Animated gradient: "Shine" (gold shimmer), "Rainbow" (spinning), "Fire" (flicker).
function Lib.animGradient(parent: Instance, seq: ColorSequence, anim: string, rotation: number?): UIGradient
	local g = Lib.new("UIGradient", { Color = seq, Rotation = rotation or 90, Parent = parent })
	g:SetAttribute("Anim", anim)
	CollectionService:AddTag(g, "AnimGradient")
	return g
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

function Lib.shadow(target: GuiObject, radius: number?)
	local s = Lib.new("Frame", {
		Name = "Shadow",
		Size = target.Size,
		Position = target.Position + UDim2.fromOffset(0, 6),
		AnchorPoint = target.AnchorPoint,
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.65,
		ZIndex = math.max(0, target.ZIndex - 1),
		LayoutOrder = target.LayoutOrder,
		Parent = target.Parent,
	})
	Lib.corner(s, radius or 16)
	return s
end

-- White cartoon text with a dark outline (Stroke = false for none). `Dark` is
-- accepted for older panels; every panel is dark now, so it's white too.
function Lib.label(props: { [string]: any }): TextLabel
	local stroke = props.Stroke
	props.Stroke = nil
	props.Dark = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Lib.Colors.Text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local l = Lib.new("TextLabel", props)
	if stroke ~= false then
		Lib.textStroke(l, 2.5)
	end
	return l
end

-- Big title text: Luckiest Guy, white -> yellow, thick outline.
function Lib.title(props: { [string]: any }): TextLabel
	props.Font = props.Font or Lib.FontTitle
	local l = Lib.label(props)
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Thickness = 4
	end
	Lib.gradient(l, WHITE, Color3.fromRGB(255, 232, 110), 90)
	return l
end

function Lib.tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Slate card with a black outline (sits on the dark window body).
function Lib.card(parent: Instance?, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	local tint = p.BackgroundColor3
	p.BackgroundColor3 = WHITE
	p.Parent = parent or p.Parent
	local f = Lib.new("Frame", p)
	Lib.corner(f, 12)
	local c1 = if tint then tint:Lerp(Lib.Colors.Panel2, 0.35) else Lib.Colors.Panel2:Lerp(WHITE, 0.08)
	Lib.gradient(f, c1, c1:Lerp(BLACK, 0.25), 90)
	Lib.stroke(f, BLACK, 3)
	return f
end

-- Colourful shop card: a gradient (c1 at the top, c2 at the bottom), faint stripes and a black outline.
function Lib.shopCard(parent: Instance, size: UDim2, c1: Color3, c2: Color3, order: number?): Frame
	local f = Lib.new("Frame", { Size = size, BackgroundColor3 = WHITE, LayoutOrder = order or 0, ClipsDescendants = true, Parent = parent })
	Lib.corner(f, 10)
	Lib.gradient(f, c1, c2, 90)
	Lib.stroke(f, BLACK, 3.5)
	Lib.stripes(f, 0.93)
	return f
end

-- "-- EGGS --" section heading in gradient cartoon letters.
function Lib.section(parent: Instance, text: string, color: Color3, order: number?): TextLabel
	local l = Lib.label({ Name = "Section_" .. text, Text = "-- " .. string.upper(text) .. " --", Font = Lib.FontTitle, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = order or 0, Parent = parent })
	Lib.gradient(l, color:Lerp(WHITE, 0.45), color, 90)
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Thickness = 3.5
	end
	return l
end

-- A tilted yellow "BEST VALUE!" tag for the top-right corner of a card.
function Lib.ribbon(parent: Instance, text: string): Frame
	local f = Lib.new("Frame", { Name = "Ribbon", Size = UDim2.fromOffset(150, 30), Position = UDim2.new(1, 10, 0, 6), AnchorPoint = Vector2.new(1, 0), Rotation = 12, BackgroundColor3 = Lib.Colors.Gold, ZIndex = 20, Parent = parent })
	Lib.corner(f, 4)
	Lib.stroke(f, BLACK, 2.5)
	Lib.label({ Text = text, Font = Lib.FontTitle, Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Color3.fromRGB(30, 26, 20), Stroke = false, ZIndex = 21, Parent = f })
	return f
end

-- Little round studs all over a dark background (one text label, cheap to draw).
function Lib.studs(parent: GuiObject)
	local row = string.rep("●   ", 60)
	local rows = table.create(50, row)
	Lib.new("TextLabel", {
		Name = "Studs",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = table.concat(rows, "\n"),
		TextSize = 14,
		LineHeight = 1.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = WHITE,
		TextTransparency = 0.94,
		TextWrapped = false,
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
end

-- Coloured pill with text on top. The gradient lives on the background frame
-- only, so it doesn't tint the text. Returns (frame, label).
function Lib.chip(props: { [string]: any }, c1: Color3, c2: Color3?): (Frame, TextLabel)
	local text = props.Text or ""
	props.Text = nil
	local font = props.Font
	props.Font = nil
	props.BackgroundColor3 = WHITE
	local f = Lib.new("Frame", props)
	Lib.round(f)
	Lib.new("UIGradient", { Name = "Face", Color = Lib.buttonSeq(c1, c2), Rotation = 90, Parent = f })
	Lib.stroke(f, Lib.Colors.Outline, 3)
	local l = Lib.label({ Name = "Text", Text = text, Font = font, Size = UDim2.new(1, -18, 1, -10), Position = UDim2.new(0.5, 0, 0.5, -1), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = f.ZIndex + 1, Parent = f })
	return f, l
end

function Lib.rarityColor(t: Tungs.Tung): Color3
	return Tungs.Color(t)
end

-- Colours a label with its rarity gradient (animated for Epic+).
function Lib.rarityText(label: TextLabel, t: Tungs.Tung)
	local seq, anim = TungModel.RarityStyle(t)
	label.TextColor3 = WHITE
	if anim then
		Lib.animGradient(label, seq, anim)
	else
		Lib.new("UIGradient", { Color = seq, Rotation = 90, Parent = label })
	end
end

function Lib.rainbowIfSecret(obj: GuiObject, t: Tungs.Tung)
	if t.rarity == "Secret" then
		Lib.animGradient(obj, Rarities.RAINBOW, "Rainbow")
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
		local fallback = cue.fallback
		if fallback then
			-- uploaded sounds can be taken down; swap to the built-in fallback if it won't load
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync({ created }, function(_: string, status: Enum.AssetFetchStatus)
						if status ~= Enum.AssetFetchStatus.Success then
							created.SoundId = fallback
							created.PlaybackSpeed = cue.fallbackPitch or 1
						end
					end)
				end)
			end)
		end
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

-- Overall UI size: everything is drawn a bit smaller than the design sizes.
Lib.UI_SCALE = 0.86

-- HUD scale: phones stay big enough that 80 px design buttons are >= 52 px.
function Lib.HudScale(): number
	local vp = viewport()
	local s = math.min(vp.X / 1100, vp.Y / 620)
	return math.clamp(s, if Lib.Touch then 0.75 else 0.62, 1.2) * Lib.UI_SCALE
end

local function addScale(parent: GuiObject, fn: () -> number): UIScale
	local s = Lib.new("UIScale", { Name = "Fit", Scale = fn(), Parent = parent })
	table.insert(scales, { scale = s, fn = fn })
	return s
end

function Lib.hudFit(parent: GuiObject): UIScale
	return addScale(parent, Lib.HudScale)
end

function Lib.windowFit(parent: GuiObject, design: Vector2): UIScale
	return addScale(parent, function()
		local vp = viewport()
		local fit = math.min((vp.X - 40) / design.X, (vp.Y - 40) / design.Y)
		-- a little smaller on roomy screens; on small screens just fit
		local k = math.clamp((fit - 0.6) / 0.3, 0, 1)
		return math.clamp(math.min(fit, 1.15) * (1 + (Lib.UI_SCALE - 1) * k), 0.45, 1.15)
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

-- Special effects ------------------------------------------------------------------------------------
-- A bright diagonal shine that sweeps across an element every few seconds.
function Lib.shine(parent: GuiObject, radius: number?): Frame
	local f = Lib.new("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		ZIndex = parent.ZIndex + 1,
		Parent = parent,
	})
	if radius then
		Lib.corner(f, radius)
	else
		Lib.round(f)
	end
	Lib.new("UIGradient", {
		Rotation = 20,
		Offset = Vector2.new(-1.2, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = f,
	})
	f:SetAttribute("Seed", math.random() * 3)
	CollectionService:AddTag(f, "ShineSweep")
	return f
end

-- Rotating light rays (sunburst) centred in `parent`.
function Lib.rays(parent: Instance, color: Color3, size: number, count: number?, zindex: number?): Frame
	local holder = Lib.new("Frame", {
		Name = "Rays",
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = zindex or 1,
		Parent = parent,
	})
	local n = count or 8
	for i = 1, n do
		local ray = Lib.new("Frame", {
			Size = UDim2.new(0, math.floor(size * 0.09), 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = (i - 1) * 180 / n,
			BackgroundColor3 = color,
			ZIndex = zindex or 1,
			Parent = holder,
		})
		Lib.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.55),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(0.65, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = ray,
		})
	end
	holder:SetAttribute("Speed", 25)
	CollectionService:AddTag(holder, "UISpin")
	return holder
end

-- Little "✦" stars that twinkle around an element.
function Lib.sparkles(parent: GuiObject, count: number, color: Color3?)
	for _ = 1, count do
		local s = Lib.new("TextLabel", {
			Name = "Sparkle",
			Text = "✦",
			TextScaled = true,
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromScale(math.random(), math.random()),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			TextColor3 = color or WHITE,
			ZIndex = parent.ZIndex + 3,
			Parent = parent,
		})
		Lib.new("UIScale", { Scale = 0, Parent = s })
		s:SetAttribute("Seed", math.random() * 10)
		CollectionService:AddTag(s, "Twinkle")
	end
end

-- Diagonal stripes that slowly scroll across a header.
function Lib.stripes(parent: GuiObject, transparency: number?)
	local clip = Lib.new("Frame", {
		Name = "Stripes",
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
	local strip = Lib.new("Frame", { Name = "Strip", Size = UDim2.new(1, 120, 1, 0), BackgroundTransparency = 1, ZIndex = parent.ZIndex, Parent = clip })
	for k = 0, 40 do
		Lib.new("Frame", {
			Size = UDim2.new(0, 16, 3, 0),
			Position = UDim2.new(0, -60 + k * 40, -1, 0),
			Rotation = 30,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = transparency or 0.86,
			ZIndex = parent.ZIndex,
			Parent = strip,
		})
	end
	CollectionService:AddTag(strip, "StripeScroll")
end

-- Buttons ---------------------------------------------------------------------------------------------------
-- Candy button gradient with a darker "lip" along the bottom for a 3D look.
function Lib.buttonSeq(c1: Color3, c2: Color3?): ColorSequence
	local base2 = c2 or c1:Lerp(BLACK, 0.28)
	local light = c1:Lerp(WHITE, 0.3)
	local lip = base2:Lerp(BLACK, 0.35)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(0.45, c1),
		ColorSequenceKeypoint.new(0.8, base2),
		ColorSequenceKeypoint.new(0.81, lip),
		ColorSequenceKeypoint.new(1, lip),
	})
end

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
	b.MouseEnter:Connect(function()
		if s.Scale == 1 then
			Lib.tween(s, 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back)
		end
	end)
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
	NoShine: boolean?,
}): TextButton
	local c1 = props.Color or Lib.Colors.Green
	local b = Lib.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = WHITE,
		Text = props.Text or "",
		TextColor3 = WHITE,
		TextScaled = props.TextSize == nil,
		TextSize = props.TextSize or 14,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local radius = props.Radius or 16
	Lib.corner(b, radius)
	Lib.new("UIGradient", { Name = "Face", Color = Lib.buttonSeq(c1, props.Color2), Rotation = 90, Parent = b })
	Lib.stroke(b, Lib.Colors.Outline, 3.5)
	Lib.textStroke(b, 3)
	Lib.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 9), Parent = b })
	local gloss = Lib.new("Frame", { Name = "Gloss", Size = UDim2.new(1, 8, 0.36, 0), Position = UDim2.new(0, -4, 0, -3), BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, ZIndex = b.ZIndex, Parent = b })
	Lib.corner(gloss, radius)
	if not props.NoShine then
		local sh = Lib.shine(b, radius)
		sh.Size = UDim2.new(1, 20, 1, 14)
		sh.Position = UDim2.fromOffset(-10, -5)
	end
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
	local g = b:FindFirstChild("Face") :: UIGradient? or b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = Lib.buttonSeq(c1, c2)
	end
end

-- Big rounded-square icon button with a caption under it (HUD).
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
		Radius = math.floor(props.Size * 0.3),
	})
	Lib.label({ Name = "Icon", Text = props.Icon, Size = UDim2.fromScale(0.82, if props.Label then 0.7 else 0.82), Position = UDim2.fromScale(0.5, if props.Label then 0.42 else 0.48), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false, ZIndex = b.ZIndex + 2, Parent = b })
	if props.Label then
		Lib.label({ Name = "Caption", Text = props.Label, Font = Lib.FontTitle, Size = UDim2.new(1.35, 0, 0.32, 0), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = b.ZIndex + 3, Parent = b })
	end
	return b
end

function Lib.badge(parent: GuiObject): TextLabel
	local l = Lib.label({
		Name = "Badge",
		Text = "",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -6, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = WHITE,
		Visible = false,
		ZIndex = 8,
		Parent = parent,
	})
	l.BackgroundColor3 = Lib.Colors.Red2
	Lib.round(l)
	Lib.stroke(l, WHITE, 2.5)
	l:SetAttribute("Pulse", true)
	CollectionService:AddTag(l, "UIPulse")
	return l
end

-- Progress bar with a glossy fill; returns (frame, setFn(alpha)).
function Lib.bar(parent: Instance, size: UDim2, position: UDim2, c1: Color3, c2: Color3): (Frame, (number) -> ())
	local bg = Lib.new("Frame", { Size = size, Position = position, BackgroundColor3 = Lib.Colors.WoodDark, Parent = parent })
	Lib.round(bg)
	Lib.stroke(bg, Lib.Colors.Outline, 2.5)
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = bg })
	Lib.round(fill)
	Lib.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1:Lerp(WHITE, 0.35)), ColorSequenceKeypoint.new(0.5, c1), ColorSequenceKeypoint.new(1, c2) }), Rotation = 90, Parent = fill })
	local gloss = Lib.new("Frame", { Size = UDim2.new(1, -6, 0.35, 0), Position = UDim2.fromOffset(3, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, Parent = fill })
	Lib.round(gloss)
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
	local f = Lib.new("TextButton", { Size = UDim2.fromOffset(96, 46), Position = position, AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Lib.Colors.Grey2, Text = "", AutoButtonColor = false, Parent = parent })
	Lib.round(f)
	Lib.stroke(f, Lib.Colors.Outline, 3)
	local knob = Lib.new("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(0, 5, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = WHITE, Parent = f })
	Lib.round(knob)
	Lib.stroke(knob, Lib.Colors.Outline, 2.5)
	local on = false
	local function set(v: boolean)
		on = v
		Lib.tween(knob, 0.15, { Position = if v then UDim2.new(1, -41, 0.5, 0) else UDim2.new(0, 5, 0.5, 0) }, Enum.EasingStyle.Back)
		Lib.tween(f, 0.15, { BackgroundColor3 = if v then Lib.Colors.Green2 else Lib.Colors.Grey2 })
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
	Lib.stroke(bg, Lib.Colors.Outline, 2.5)
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = WHITE, Parent = bg })
	Lib.round(fill)
	Lib.gradient(fill, Lib.Colors.Cyan, Lib.Colors.Blue2, 90)
	local knob = Lib.new("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE, ZIndex = 3, Parent = bg })
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
		Ambient = Color3.fromRGB(215, 210, 230),
		LightColor = WHITE,
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

-- One animation loop for every UI / nameplate effect ---------------------------------------------------------------
local animGradients: { [UIGradient]: number } = {}
local function trackGradient(g: Instance)
	if g:IsA("UIGradient") then
		animGradients[g] = math.random() * 10
	end
end
for _, g in CollectionService:GetTagged("AnimGradient") do
	trackGradient(g)
end
CollectionService:GetInstanceAddedSignal("AnimGradient"):Connect(trackGradient)
CollectionService:GetInstanceRemovedSignal("AnimGradient"):Connect(function(g)
	animGradients[g :: UIGradient] = nil
end)

local accum = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for k = #spinners, 1, -1 do
		local s = spinners[k]
		if not s.vf.Parent then
			table.remove(spinners, k)
		elseif s.vf.Visible then
			s.model:PivotTo(s.base * CFrame.Angles(0, math.sin(t * 0.9 + s.offset) * 0.7, 0) + Vector3.new(0, math.abs(math.sin(t * 2 + s.offset)) * 0.25, 0))
		end
	end
	accum += dt
	if accum < 1 / 40 then
		return
	end
	accum = 0
	for g, seed in animGradients do
		local mode = g:GetAttribute("Anim")
		if mode == "Rainbow" then
			g.Rotation = (t * 140 + seed * 36) % 360
		elseif mode == "Shine" then
			g.Rotation = 90 + math.sin(t * 2.4 + seed) * 50
		elseif mode == "Fire" then
			g.Rotation = 90 + math.sin(t * 7 + seed) * 12
			g.Offset = Vector2.new(0, math.sin(t * 5 + seed) * 0.12)
		end
	end
	for _, f in CollectionService:GetTagged("ShineSweep") do
		local g = f:FindFirstChildOfClass("UIGradient")
		if g then
			local phase = (t + ((f:GetAttribute("Seed") :: number?) or 0)) % 3.2
			g.Offset = Vector2.new(if phase < 0.8 then -1.2 + phase / 0.8 * 2.4 else -1.2, 0)
		end
	end
	for _, r in CollectionService:GetTagged("UISpin") do
		if r:IsA("GuiObject") then
			r.Rotation = (t * ((r:GetAttribute("Speed") :: number?) or 30)) % 360
		end
	end
	for _, s in CollectionService:GetTagged("Twinkle") do
		local sc = s:FindFirstChildOfClass("UIScale")
		if sc and s:IsA("GuiObject") then
			local seed = (s:GetAttribute("Seed") :: number?) or 0
			local phase = ((t * 0.8 + seed) % 2) / 2
			sc.Scale = math.max(0, math.sin(phase * math.pi)) * 1.2
			s.Rotation = phase * 180
			if phase < 0.02 then
				s.Position = UDim2.fromScale(math.random(), math.random())
			end
		end
	end
	for _, strip in CollectionService:GetTagged("StripeScroll") do
		if strip:IsA("GuiObject") then
			strip.Position = UDim2.fromOffset(-((t * 22) % 40), 0)
		end
	end
	for _, b in CollectionService:GetTagged("UIPulse") do
		if b:IsA("GuiObject") and b.Visible then
			local sc = b:FindFirstChild("PulseScale") :: UIScale? or Lib.new("UIScale", { Name = "PulseScale", Parent = b })
			;(sc :: UIScale).Scale = 1 + math.abs(math.sin(t * 4)) * 0.18
		end
	end
end)

-- Windows --------------------------------------------------------------------------------------------------------------
local openPanel: any = nil
local panelRoot: ScreenGui? = nil

function Lib.SetPanelRoot(gui: ScreenGui)
	panelRoot = gui
end

-- A shop-style window: dark studded body with a thick black outline, a bright
-- striped header bar with the title on the left and a square red X on the
-- right. Slides in from the side. Panels can add icon tabs down the right
-- side with win.sideNav(...).
-- Returns { frame, body, header, title, open(), close(), toggle(), isOpen(), sideNav(), onOpen, onClose }
function Lib.window(title: string, size: Vector2, accent: Color3?, icon: string?): any
	local c = Lib.Colors
	local col = accent or c.Blue
	local holder = Lib.new("Frame", {
		Name = title .. "Window",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.new(-0.8, 0, 0.53, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = c.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = panelRoot,
	})
	Lib.corner(holder, 14)
	Lib.stroke(holder, BLACK, 5)
	Lib.windowFit(holder, size + Vector2.new(160, 40))
	local shadow = Lib.new("Frame", { Name = "Shadow", Size = UDim2.new(1, 6, 1, 6), Position = UDim2.fromOffset(-3, 10), BackgroundColor3 = BLACK, BackgroundTransparency = 0.55, ZIndex = 9, Parent = holder })
	Lib.corner(shadow, 16)
	-- studs, clipped to the body
	local back = Lib.new("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 10, Parent = holder })
	Lib.corner(back, 14)
	Lib.studs(back)

	local header = Lib.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = WHITE, ZIndex = 11, Parent = holder })
	Lib.corner(header, 12)
	Lib.new("UIGradient", { Color = ColorSequence.new(col:Lerp(WHITE, 0.25), col:Lerp(BLACK, 0.12)), Rotation = 90, Parent = header })
	-- square off the header's bottom corners and draw the dark line under it
	local filler = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = col:Lerp(BLACK, 0.1), ZIndex = 11, Parent = header })
	local _ = filler
	Lib.new("Frame", { Name = "Line", Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = BLACK, ZIndex = 12, Parent = header })
	Lib.stripes(header, 0.82)
	local titleLabel = Lib.label({
		Name = "Title",
		Text = (if icon then icon .. " " else "") .. title,
		Font = Lib.FontTitle,
		Size = UDim2.new(1, -120, 0, 44),
		Position = UDim2.new(0, 18, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = header,
	})
	local ts = titleLabel:FindFirstChildOfClass("UIStroke")
	if ts then
		ts.Thickness = 4
	end

	local body = Lib.new("Frame", { Name = "Body", Size = UDim2.new(1, -32, 1, -86), Position = UDim2.fromOffset(16, 76), BackgroundTransparency = 1, ZIndex = 11, Parent = holder })

	local win: any = { frame = holder, body = body, header = header, title = titleLabel }
	local isOpen = false
	local popScale = Lib.new("UIScale", { Name = "Pop", Parent = holder })

	function win.close()
		if not isOpen then
			return
		end
		isOpen = false
		if openPanel == win then
			openPanel = nil
		end
		local tw = Lib.tween(holder, 0.2, { Position = UDim2.new(-0.8, 0, 0.53, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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
		holder.Position = UDim2.new(-0.8, 0, 0.53, 0)
		popScale.Scale = 0.92
		Lib.tween(holder, 0.25, { Position = UDim2.new(0.5, 0, 0.53, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Lib.tween(popScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
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

	-- Big icons with labels down the outside of the right edge. Returns select(name).
	function win.sideNav(items: { { name: string, icon: string, color: Color3? } }, onSelect: (string) -> ()): (string) -> ()
		local nav = Lib.new("Frame", { Name = "SideNav", Size = UDim2.new(0, 120, 1, -40), Position = UDim2.new(1, 14, 0, 30), BackgroundTransparency = 1, ZIndex = 11, Parent = holder })
		Lib.list(nav, 6, false, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Top
		local buttons: { [string]: TextButton } = {}
		local function select(name: string)
			for n, b in buttons do
				local s = b:FindFirstChild("Sel") :: UIScale?
				if s then
					Lib.tween(s, 0.2, { Scale = if n == name then 1.12 else 0.92 }, Enum.EasingStyle.Back)
				end
			end
			onSelect(name)
		end
		for k, item in items do
			local b = Lib.new("TextButton", { Name = item.name, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(110, 92), BackgroundTransparency = 1, LayoutOrder = k, ZIndex = 12, Parent = nav })
			Lib.new("UIScale", { Name = "Sel", Scale = 0.92, Parent = b })
			Lib.label({ Text = item.icon, Size = UDim2.fromOffset(64, 60), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Stroke = false, ZIndex = 13, Parent = b })
			local l = Lib.label({ Text = item.name, Font = Lib.FontTitle, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -28), ZIndex = 13, Parent = b })
			if item.color then
				Lib.gradient(l, item.color:Lerp(WHITE, 0.5), item.color, 90)
			end
			b.Activated:Connect(function()
				Lib.sound("Pop")
				select(item.name)
			end)
			buttons[item.name] = b
		end
		return select
	end

	-- square red X on the right of the header
	local x = Lib.new("TextButton", { Name = "Close", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(50, 46), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = WHITE, ZIndex = 14, Parent = header })
	Lib.corner(x, 6)
	Lib.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 70, 70), Color3.fromRGB(190, 20, 30)), Rotation = 90, Parent = x })
	Lib.stroke(x, BLACK, 3)
	Lib.label({ Text = "X", Font = Lib.FontTitle, Size = UDim2.fromScale(0.62, 0.7), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 15, Parent = x })
	Lib.bouncy(x)
	x.Activated:Connect(function()
		Lib.sound("Pop")
		win.close()
	end)
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
		Size = UDim2.new(1, 0, 0, height + 10),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
		Parent = parent,
	})
	Lib.list(strip, 8, true)
	Lib.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 2), Parent = strip })
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for n, b in buttons do
			local col = if colors and colors[n] then colors[n] else Lib.Colors.Gold
			local s = b:FindFirstChild("Bounce") :: UIScale?
			if n == name then
				Lib.recolor(b, col)
				if s then
					s.Scale = 1.08
					Lib.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			else
				Lib.recolor(b, Color3.fromRGB(78, 78, 96), Color3.fromRGB(52, 52, 66))
			end
		end
		onSelect(name)
	end
	local width = if #names > 5 then 116 else 200
	for i, n in names do
		buttons[n] = Lib.button({
			Text = n,
			Size = UDim2.fromOffset(width, height),
			Color = Lib.Colors.Grey,
			Parent = strip,
			LayoutOrder = i,
			ZIndex = 11,
			NoShine = true,
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
