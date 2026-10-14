--!strict
-- Arena geometry, shared by the server (which builds and validates) and the
-- client (which renders the belt and effects). Studs; Y = 0 is the grass.
--
--            Z = -176 wall
--   [base1]  |drum|  [base5]
--   [base2]  |belt|  [base6]        bases face the belt; gates on the inner side
--   [base3]  |    |  [base7]        pillar + shop/sell stands in the middle (Z = 0)
--   [base4]  |hole|  [base8]
--            Z = +176 wall

local Layout = {}

Layout.CORRIDOR_HALF = 28 -- gates sit at X = ±28
Layout.PLOT_WIDTH = 76 -- along Z
Layout.PLOT_SPACING = 84
Layout.FRONT = 14 -- gate zone depth (spawn, traps, lock button)
Layout.ROW = 13 -- pad + collect button
Layout.BACK = 14 -- altar / personal belt zone
Layout.PAD_SPACING = 11
Layout.MAX_ROWS = 6
Layout.MAX_DEPTH = Layout.FRONT + Layout.MAX_ROWS * Layout.ROW + Layout.BACK -- 106
Layout.ARENA_HALF_X = Layout.CORRIDOR_HALF + Layout.MAX_DEPTH + 6 -- 140
Layout.ARENA_HALF_Z = 176
Layout.GATE_WIDTH = 16

Layout.FLOOR_TOP = 0.4 -- base floor surface
Layout.PAD_TOP = 1.0 -- where placed Tungs stand

Layout.BELT_Y = 2.2 -- belt surface (Tung feet)
Layout.BELT_WIDTH = 8
Layout.BELT_START = Vector3.new(0, Layout.BELT_Y, -152)
Layout.BELT_END = Vector3.new(0, Layout.BELT_Y, 152)
Layout.DRUM_POS = Vector3.new(0, 8, -162)
Layout.HOLE_POS = Vector3.new(0, 0, 158)

Layout.PILLAR_POS = Vector3.new(0, 0, 0)
Layout.SHOP_POS = Vector3.new(19, 0, 0)
Layout.SELL_POS = Vector3.new(-19, 0, 0)
Layout.CENTER_SPAWN = Vector3.new(14, 3, -24)

Layout.BASE_COUNT = 8

-- Gate centre of base i (1-4 on the left, 5-8 on the right), looking INTO the base.
function Layout.BaseCFrame(i: number): CFrame
	local side = if i <= 4 then -1 else 1
	local row = (i - 1) % 4
	local z = -126 + row * Layout.PLOT_SPACING
	local x = side * Layout.CORRIDOR_HALF
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x + side, 0, z))
end

-- Local point in base space: x across the base, y up, d = depth from the gate.
function Layout.Local(i: number, x: number, y: number, d: number): CFrame
	return Layout.BaseCFrame(i) * CFrame.new(x, y, -d)
end

function Layout.Rows(slots: number): number
	return math.clamp(math.ceil(slots / 6), 1, Layout.MAX_ROWS)
end

function Layout.Depth(slots: number): number
	return Layout.FRONT + Layout.Rows(slots) * Layout.ROW + Layout.BACK
end

-- Pad centre (x, d) for a slot. Rows of 6; a partial last row is centred.
function Layout.PadLocal(slot: number, slots: number): (number, number)
	local rows = Layout.Rows(slots)
	local row = math.ceil(slot / 6)
	local inRow = if row < rows then 6 else slots - (rows - 1) * 6
	local col = (slot - 1) % 6
	local x = (col - (inRow - 1) / 2) * Layout.PAD_SPACING
	local d = Layout.FRONT + (row - 1) * Layout.ROW + 8.5
	return x, d
end

-- Where a placed Tung stands (feet), facing the gate.
function Layout.PadCFrame(i: number, slot: number, slots: number): CFrame
	local x, d = Layout.PadLocal(slot, slots)
	return Layout.Local(i, x, Layout.PAD_TOP, d) * CFrame.Angles(0, math.pi, 0)
end

-- The round collect button on the floor in front of the pad.
function Layout.ButtonCFrame(i: number, slot: number, slots: number): CFrame
	local x, d = Layout.PadLocal(slot, slots)
	return Layout.Local(i, x, Layout.FLOOR_TOP, d - 6)
end

function Layout.Spawn(i: number): CFrame
	return Layout.Local(i, 0, 3.5, 7) * CFrame.Angles(0, math.pi, 0)
end

function Layout.Altar(i: number, slots: number): CFrame
	return Layout.Local(i, 0, Layout.FLOOR_TOP, Layout.Depth(slots) - 7)
end

-- Rebirth 6 perk: a short belt in the back-right corner of the base.
function Layout.PersonalBelt(i: number, slots: number): (Vector3, Vector3)
	local d = Layout.Depth(slots) - 7
	local a = Layout.Local(i, 33, 1.6, d).Position
	local b = Layout.Local(i, 13, 1.6, d).Position
	return a, b
end

-- Is a world position inside base i's fenced plot?
function Layout.InBase(i: number, slots: number, pos: Vector3): boolean
	local p = Layout.BaseCFrame(i):PointToObjectSpace(pos)
	local d = -p.Z
	return math.abs(p.X) <= Layout.PLOT_WIDTH / 2 and d >= -0.5 and d <= Layout.Depth(slots) + 0.5 and p.Y < 40
end

-- Is a position in the open corridor (where Tung Rain lands)?
function Layout.RandomCorridorPoint(rng: Random): Vector3
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local x = side * rng:NextNumber(7, Layout.CORRIDOR_HALF - 3)
	local z = rng:NextNumber(-150, 150)
	return Vector3.new(x, 0, z)
end

return Layout
