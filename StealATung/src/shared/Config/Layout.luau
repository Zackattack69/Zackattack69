--!strict
-- Arena and base geometry, shared by the server (which builds and validates)
-- and the client (which renders the belt and effects). Studs; Y = 0 is the grass.
--
--             Z = -228 wall
--   [base1]   |drum|   [base5]
--   [base2]   |belt|   [base6]     bases face the belt; gates on the inner side
--   [base3]   |    |   [base7]     pillar + shop/sell stands in the middle (Z = 0)
--   [base4]   |hole|   [base8]
--             Z = +228 wall
--
-- A base is a building with up to 4 floors. Each floor holds 8 Tungs: 4 along
-- the left wall and 4 along the right wall, facing the middle aisle. Stairs run
-- along the front wall (alternating sides per floor). The Rebirth Altar stands
-- at the back in the middle of the ground floor.

local Layout = {}

-- Arena
Layout.CORRIDOR_HALF = 46 -- gates sit at X = ±46
Layout.PLOT_SPACING = 104 -- distance between bases along Z
Layout.ARENA_HALF_X = 46 + 64 + 44 -- 154
Layout.ARENA_HALF_Z = 228
Layout.WALL_HEIGHT = 52 -- about 10 Roblox characters
Layout.BASE_COUNT = 8

-- Base building
Layout.BASE_WIDTH = 48 -- across (local X: -24 .. 24)
Layout.BASE_DEPTH = 64 -- from the gate to the back wall
Layout.FLOOR_HEIGHT = 14
Layout.SLOTS_PER_FLOOR = 8
Layout.MAX_FLOORS = 4
Layout.GATE_WIDTH = 16
Layout.GATE_HEIGHT = 11
Layout.PAD_X = 18 -- pads along the side walls
Layout.BUTTON_X = 11.5 -- collect buttons in front of them, towards the aisle
Layout.ROW_FIRST = 14 -- depth of the first pad row
Layout.ROW_SPACING = 11
Layout.STAIR_INNER = 8 -- stairs run along the front wall from |x| = 22 (bottom) to 8 (top)
Layout.STAIR_OUTER = 22
Layout.STAIR_FRONT = 1.5 -- stairs occupy depth 1.5 .. 6.5
Layout.STAIR_BACK = 6.5
Layout.ALTAR_DEPTH = 57

Layout.FLOOR_TOP = 0.4 -- floor surface above that floor's base height
Layout.PAD_TOP = 1.0 -- where placed Tungs stand

-- Conveyor belt: each Tung rides it for 20 s (Economy.BELT_TRAVEL)
Layout.BELT_Y = 2.2 -- belt surface (Tung feet)
Layout.BELT_WIDTH = 8
Layout.BELT_START = Vector3.new(0, Layout.BELT_Y, -100)
Layout.BELT_END = Vector3.new(0, Layout.BELT_Y, 100)
Layout.DRUM_POS = Vector3.new(0, 8, -110)
Layout.HOLE_POS = Vector3.new(0, 0, 106)

Layout.PILLAR_POS = Vector3.new(0, 0, 0)
Layout.SHOP_POS = Vector3.new(26, 0, 0)
Layout.SELL_POS = Vector3.new(-26, 0, 0)
Layout.CENTER_SPAWN = Vector3.new(20, 3, -26)

-- Gate centre of base i (1-4 on the left, 5-8 on the right), looking INTO the base.
function Layout.BaseCFrame(i: number): CFrame
	local side = if i <= 4 then -1 else 1
	local row = (i - 1) % 4
	local z = (row - 1.5) * Layout.PLOT_SPACING
	local x = side * Layout.CORRIDOR_HALF
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x + side, 0, z))
end

-- Local point in base space: x across the base, y up, d = depth from the gate.
function Layout.Local(i: number, x: number, y: number, d: number): CFrame
	return Layout.BaseCFrame(i) * CFrame.new(x, y, -d)
end

function Layout.Floors(slots: number): number
	return math.clamp(math.ceil(slots / Layout.SLOTS_PER_FLOOR), 1, Layout.MAX_FLOORS)
end

function Layout.Depth(_slots: number): number
	return Layout.BASE_DEPTH
end

-- Height of the building (top of the highest floor's railing area).
function Layout.Height(slots: number): number
	return Layout.Floors(slots) * Layout.FLOOR_HEIGHT
end

-- Base height of floor f (1 = ground).
function Layout.FloorY(f: number): number
	return (f - 1) * Layout.FLOOR_HEIGHT
end

-- Pad position for a slot: (x, floorY, d, side). Slots alternate left/right,
-- front to back, 8 per floor.
function Layout.PadLocal(slot: number, _slots: number): (number, number, number, number)
	local floor = math.ceil(slot / Layout.SLOTS_PER_FLOOR)
	local j = (slot - 1) % Layout.SLOTS_PER_FLOOR
	local side = if j % 2 == 0 then -1 else 1
	local row = j // 2
	return side * Layout.PAD_X, Layout.FloorY(floor), Layout.ROW_FIRST + row * Layout.ROW_SPACING, side
end

-- Where a placed Tung stands (feet), facing the middle aisle.
function Layout.PadCFrame(i: number, slot: number, slots: number): CFrame
	local x, y, d, side = Layout.PadLocal(slot, slots)
	return Layout.Local(i, x, y + Layout.PAD_TOP, d) * CFrame.Angles(0, if side < 0 then -math.pi / 2 else math.pi / 2, 0)
end

-- The round collect button on the floor in front of the pad.
function Layout.ButtonCFrame(i: number, slot: number, slots: number): CFrame
	local _, y, d, side = Layout.PadLocal(slot, slots)
	return Layout.Local(i, side * Layout.BUTTON_X, y + Layout.FLOOR_TOP, d)
end

function Layout.Spawn(i: number): CFrame
	return Layout.Local(i, 0, 3.5, 9) * CFrame.Angles(0, math.pi, 0)
end

function Layout.Altar(i: number, _slots: number): CFrame
	return Layout.Local(i, 0, Layout.FLOOR_TOP, Layout.ALTAR_DEPTH)
end

-- Side (-1 left / 1 right) of the stair flight that goes from floor f up to f + 1.
function Layout.StairSide(f: number): number
	return if f % 2 == 1 then -1 else 1
end

-- Rebirth 6 perk: a short belt along the back wall, right of the altar.
function Layout.PersonalBelt(i: number, _slots: number): (Vector3, Vector3)
	local d = Layout.BASE_DEPTH - 3.5
	local a = Layout.Local(i, 19, 1.6, d).Position
	local b = Layout.Local(i, 7, 1.6, d).Position
	return a, b
end

-- Is a world position inside base i (any floor)?
function Layout.InBase(i: number, slots: number, pos: Vector3): boolean
	local p = Layout.BaseCFrame(i):PointToObjectSpace(pos)
	local d = -p.Z
	return math.abs(p.X) <= Layout.BASE_WIDTH / 2 + 0.5 and d >= -0.5 and d <= Layout.BASE_DEPTH + 0.5 and p.Y < Layout.Height(slots) + 8
end

-- A random point in the open corridor (where Tung Rain lands).
function Layout.RandomCorridorPoint(rng: Random): Vector3
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local x = side * rng:NextNumber(8, Layout.CORRIDOR_HALF - 4)
	local z = rng:NextNumber(-Layout.ARENA_HALF_Z + 20, Layout.ARENA_HALF_Z - 20)
	return Vector3.new(x, 0, z)
end

return Layout
