-- Represents diagrams

require("common.schematic.coord_table")
require("common.utils.objects")
require("common.utils.utils")

-- An ActionPair is an object coupled with an endomorphism

----@class ActionPair<T>: { data: T, action: nil|fun(T):T }

----@generic T
---@class ActionPair<T> : BaseClass
---@field data any any piece of data
---@field action nil|fun(x:any):any
ActionPair = InheritsFrom(nil)

--- Create a new ActionPair
----@generic T
--@param data `T`
--@param action? fun(x:`T`):`T`
--@return ActionPair<`T`>
---@generic T
---@param data T
---@param action? fun(x:T):T
---@return ActionPair
function ActionPair.new(data, action)
    local self = ActionPair:create()
    self.data = data
    self.action = action
    return self
end

---perform an action on an ActionPair
-- next_action?: a function that takes data of some type and returns the same type
-- returns: an new ActionPair, or the original if next_action is nil
---comment
---@generic T
----@param next_action? fun(x:`T`):`T`
----@return ActionPair<`T`>
---@param self ActionPair
---@param next_action? fun(x:T):T
---@return ActionPair
function ActionPair.act(self, next_action)
    local next_action2 = next_action
    if next_action2 == nil then
        return self
    end
    local self_action = self.action
    if self_action == nil then
        return ActionPair.new(self.data, next_action2)
    else
        return ActionPair.new(self.data,
            function(x) return next_action2(self_action(x)) end)
    end
end

---run an internal action and return the result
---@return any
function ActionPair:run()
    if self.action ~= nil then
        return self.action(self.data)
    end
    return self.data
end

---identity function
---@generic S
---@param x S
---@return S
function ID(x)
    return x
end

---a string with an action
---only used for testing?
---@param s string
---@return ActionPair<string>
function Action_string(s)
    return ActionPair.new(s, nil)
end

local test_s = ActionPair.new("test")
assert(test_s:act(function(x) return (x .. "!") end):run() == "test!")

---An Endo is an endomorphism
---@class Endo : BaseClass
---@field endo nil|fun(x:any):any
Endo = InheritsFrom(nil)
--- Create a new Eno
---@generic T
---@param endo? fun(x:T):T
---@return Endo
function Endo.new(endo)
    local self = Endo:create()
    self.endo = endo
    return self
end

---act one Endo on another, other perfoms first
---@param other Endo
---@return Endo
function Endo:act(other)
    local _endo = self.endo
    if _endo == nil then
        return other
    else
        local _other_endo = other.endo
        if _other_endo == nil then
            return self
        end
        return Endo.new(function(x) return _endo(_other_endo(x)) end)
    end
end

---Return an identity Endo
---@return Endo
function Endo.id()
    return Endo.new(nil)
end

-- evaluate an endomorphism
-- value: data that the endomorphism can act on
-- returns same type as value
---Evaluate an endomorphism
---@generic T
---@param value T
---@return T
function Endo:eval(value)
    if self.endo == nil then
        return value
    end
    return self.endo(value)
end

local test_endo = Endo.new(function(x) return x .. '!' end)
local test_endo2 = Endo.new(function(x) return x .. '?' end)
assert(test_endo:act(test_endo2):eval("test") == "test?!")

-- An Translation represents a translation of the plane
---@class Translation : BaseClass
---@field x int
---@field y int
Translation = InheritsFrom(nil)

---Create a new Translation
---@param x int
---@param y int
---@return Translation
function Translation.new(x, y)
    local self = Translation:create()
    self.x = x
    self.y = y
    return self
end

local id_translation = Translation.new(0, 0)

---identity Translation
---@return Translation
function Translation.id()
    return id_translation
end

---compose two translations
---@param other Translation
---@return Translation
function Translation:compose(other)
    return Translation.new(self.x + other.x, self.y + other.y)
end

-- A Transformation is a translation and a mapping
---@class Transformation : BaseClass
---@field translation Translation
---@field entity_mapping nil|fun(x:any):any
---@field region_mapping nil|fun(x:any):any
Transformation = InheritsFrom(nil)

---@param translation Translation
---@param entity_mapping? fun(x:any): any
---@param region_mapping? fun(x:any): any
---@return Transformation
function Transformation.new(translation, entity_mapping, region_mapping)
    local self = Transformation:create()
    self.translation = translation
    self.entity_mapping = entity_mapping
    self.region_mapping = region_mapping
    return self
end

local function compose_mappings(map1, map2)
    if map1 ~= nil then
        if map2 ~= nil then
            return function(x) return map2(map1(x)) end
        else
            return map1
        end
    else
        return map2
    end
end

---Compose two transformations
---@param other Transformation
---@return Transformation
function Transformation:compose(other)
    local translation = self.translation:compose(other.translation)
    local entity_mapping = compose_mappings(self.entity_mapping, other.entity_mapping)
    local region_mapping = compose_mappings(self.region_mapping, other.region_mapping)
    return Transformation.new(translation, entity_mapping, region_mapping)
end

---create a translation Transformation
---@param x int
---@param y int
---@return Transformation
function Transformation.translate(x, y)
    return Transformation.new(Translation.new(x, y), nil, nil)
end

local id_transformation = Transformation.new(Translation.id(), nil, nil)
---identity transformation
---@return Transformation
function Transformation.id()
    return id_transformation
end

---create an entity mapping Transformation
---@param mapping fun(x:any):any
---@return Transformation
function Transformation.map(mapping)
    return Transformation.new(Translation.id(), mapping, nil)
end

---create a region mapping Transformation
---@param mapping fun(x:any):any
---@return Transformation
function Transformation.region_map(mapping)
    return Transformation.new(Translation.id(), nil, mapping)
end

---apply a transformation to a primitive
---@generic T
---@param p CoordTable<T>
---@param transform Transformation
---@return CoordTable<T>
local function transform_primitive(p, transform)
    local out = CoordTable.new()
    local translation = transform.translation
    CoordTable.iterate(p, function(x, y, value)
        CoordTable.set(out, x + translation.x, y + translation.y, value:act(transform.entity_mapping))
    end)
    return out
end

local test_primitive = CoordTable.from_array { { x = 1, y = 2, value = Action_string("test") } }
assert(CoordTable.get(transform_primitive(test_primitive, Transformation.translate(4, 3)), 5, 5):run() == "test")

-- A DiagramBoundingBox consists of left, right, top, bottom values
-- These are coordinates so can be negative
-- top and right are exclusive, left and bottom are inclusive
---@class DiagramBoundingBox : BaseClass
---@field left int
---@field right int
---@field top int
---@field bottom int
DiagramBoundingBox = InheritsFrom(nil)

---Create a new DiagramBoundingBox
---@param left int
---@param right int
---@param top int
---@param bottom int
---@return DiagramBoundingBox
function DiagramBoundingBox.new(left, right, top, bottom)
    local self = DiagramBoundingBox:create()
    self.left = left
    self.right = right
    self.top = top
    self.bottom = bottom
    return self
end

---An Envelope gives the minimum distance to a separating line in each
---of the four directions from the origin: left, right, up, down
---Values can be negative.
---Envelopes are inclusive
---@class Envelope : BaseClass
---@field left int
---@field right int
---@field up int
---@field down int
Envelope = InheritsFrom(nil)

---Create a new Envelope
---@param left int
---@param right int
---@param up int
---@param down int
---@return Envelope
function Envelope.new(left, right, up, down)
    local self = Envelope:create()
    self.left = left
    self.right = right
    self.up = up
    self.down = down
    return self
end

---Clone this Envelope
---@return Envelope
function Envelope:clone()
    return Envelope.new(self.left, self.right, self.up, self.down)
end

---Convert this Envelope to a Region
---@return Region
function Envelope:to_region()
    return Region.new(-self.left, self.right, -self.down, self.up)
end

---convert a DiagramBoundingBox into an Envelope
---@return Envelope
function DiagramBoundingBox:to_envelope()
    return Envelope.new(-self.left, self.right - 1, self.top - 1, -self.bottom)
end

---translate a DiagramBoundingBox
---@param x int
---@param y int
---@return DiagramBoundingBox
function DiagramBoundingBox:translate(x, y)
    return DiagramBoundingBox.new(self.left + x, self.right + x, self.top + y, self.bottom + y)
end

-- Expand the DiagramBoundingBox to include the origin
-- returns a new DiagramBoundingBox
---Expand the DiagramBoundingBox to include the origin
---@return DiagramBoundingBox
function DiagramBoundingBox:include_origin()
    return DiagramBoundingBox.new(math.min(0, self.left), math.max(0, self.right),
        math.max(0, self.top), math.min(0, self.bottom))
end

---Compose two DiagramBoundingBox
---returns a new DiagramBoundingBox which is the smallest DiagramBoundingBox containing
---  the two inputs
---@param other DiagramBoundingBox
---@return DiagramBoundingBox
function DiagramBoundingBox:compose(other)
    return DiagramBoundingBox.new(
        math.min(self.left, other.left),
        math.max(self.right, other.right),
        math.max(self.top, other.top),
        math.min(self.bottom, other.bottom)
    )
end

local test_bbox = DiagramBoundingBox.new(1, 2, 4, 3)
local test_bbox2 = DiagramBoundingBox.new(1, 2, 5, 4):include_origin()
assert(test_bbox:compose(test_bbox2).top == 5)






---convert an Envelope into a DiagramBoundingBox
---@return DiagramBoundingBox
function Envelope:to_envelope()
    return DiagramBoundingBox.new(
        math.min(self.right, -self.left),
        math.max(self.right, -self.left) + 1,
        math.max(self.up, -self.down) + 1, -
        math.min(self.up, -self.down)
    )
end

-- returns a new Envelope
---translate an Envelope
---@param x int
---@param y int
---@return Envelope
function Envelope:translate(x, y)
    return Envelope.new(
        self.left - x,
        self.right + x,
        self.up + y,
        self.down - y
    )
end

---Act with a Translation on an Envelope
---@param translation Translation
---@return Envelope
function Envelope:act(translation)
    return self:translate(translation.x, translation.y)
end

---Compose two Envelope objects
---@param other? Envelope
---@return Envelope
function Envelope:compose(other)
    if other == nil then
        return self
    end
    return Envelope.new(
        math.max(self.left, other.left),
        math.max(self.right, other.right),
        math.max(self.up, other.up),
        math.max(self.down, other.down)
    )
end

---convert a point to an Envelope
---@param x int
---@param y int
---@return Envelope
function Envelope.from_point(x, y)
    return Envelope.new(
        math.max(-x, 0),
        math.max(x, 0),
        math.max(y, 0),
        math.max(-y, 0)
    )
end

local test_envelope = DiagramBoundingBox.new(1, 2, 4, 3):to_envelope()
local test_envelope2 = DiagramBoundingBox.new(1, 2, 5, 4):include_origin():to_envelope()
assert(test_envelope:compose(test_envelope2).up == 4)



---Calculate a bounding box for a CoordTable
---@generic T
---@param p CoordTable<T>
---@return DiagramBoundingBox
function DiagramBoundingBox.calculate_bounding_box(p)
    local left, right, top, bottom
    CoordTable.iterate(p, function(x, y, _)
        if left == nil or x < left then
            left = x
        end
        if right == nil or x >= right then
            right = x + 1
        end
        if top == nil or y >= top then
            top = y + 1
        end
        if bottom == nil or y < bottom then
            bottom = y
        end
    end)
    -- if nothing, just bound the origin
    if left == nil then left = 0 end
    if right == nil then right = 1 end
    if top == nil then top = 1 end
    if bottom == nil then bottom = 0 end
    return DiagramBoundingBox.new(left, right, top, bottom)
end

---Calculate an Envelope for a CoordTable
---@generic T
---@param p CoordTable<T>
---@return Envelope
function Envelope.calculate_envelope(p)
    return DiagramBoundingBox.calculate_bounding_box(p):to_envelope()
end

local function rasterize_primitives(primitives, box)
    local out = {}
    for y = box.bottom, box.top - 1, 1 do
        local row = {}
        for x = box.left, box.right - 1, 1 do
            local val = " "
            for _, p in ipairs(primitives) do
                local tmp = CoordTable.get(p, x, y)
                if tmp ~= nil then
                    val = tmp:run()
                    break
                end
            end
            table.insert(row, val)
        end
        table.insert(out, row)
    end
    -- local result = {}
    -- for k = #out, 1, -1 do
    --     table.insert(result, out[k])
    -- end
    return out
end

local function grid_to_string(grid)
    local out = ""
    for idx, row in ipairs(grid) do
        local line = ""
        -- print(Dump(row))
        for _, entry in ipairs(row) do
            -- print(Dump(entry))
            line = line .. tostring(entry)
        end
        if line ~= "" then
            out = out .. line
            if idx ~= #grid then
                out = out .. "\n"
            end
        end
    end
    return out
end

-- convert a list of primitives into a string
-- primitives: list of primitives
-- returns string
local function primitives_to_string(primitives)
    local box = DiagramBoundingBox.new(0, 0, 0, 0)
    for _, p in ipairs(primitives) do
        box = box:compose(DiagramBoundingBox.calculate_bounding_box(p))
    end
    -- print(Dump(box))
    -- print(Dump(primitives))
    local grid = rasterize_primitives(primitives, box)
    -- print(Dump(grid))
    return grid_to_string(grid)
end

---A region is a transformable and taggable rectangle.  It is inclusive
---@class Region : BaseClass
---@field min_x int
---@field max_x int
---@field min_y int
---@field max_y int
---@field tags table<string, any>
Region = InheritsFrom(nil)

---Create a new Region
---@param min_x int
---@param max_x int
---@param min_y int
---@param max_y int
---@param tags? table<string, any>
---@return Region
function Region.new(min_x, max_x, min_y, max_y, tags)
    local self = Region:create()
    self.min_x = min_x
    self.max_x = max_x
    self.min_y = min_y
    self.max_y = max_y
    if tags == nil then
        self.tags = {}
    else
        self.tags = tags
    end
    return self
end

---Create a Region from two points
---@param first {x: int, y: int}
---@param second {x: int, y: int}
---@return Region
function Region.from_points(first, second)
    return Region.new(math.min(first.x, second.x),
        math.max(first.x, second.x),
        math.min(first.y, second.y),
        math.max(first.y, second.y))
end

---Act on a Region with a Transformation
---@param transform Transformation
---@return Region Possibly new translated region
function Region:act(transform)
    local translation = transform.translation
    local mapping = transform.region_mapping
    if translation == nil and mapping == nil then
        return self
    end
    local new_tags = self.tags
    if mapping ~= nil then
        new_tags = mapping(self.tags)
    end

    return Region.new(self.min_x + translation.x, self.max_x + translation.x,
        self.min_y + translation.y, self.max_y + translation.y, new_tags)
end

---Does this Region contain the given point
---@param x int
---@param y int
---@return boolean
function Region:contains_point(x, y)
    return self.min_x <= x and x <= self.max_x and self.min_y <= y and y <= self.max_y
end

---A Diagram is the abstract base class of all Diagrams
---@class Diagram : BaseClass
Diagram = InheritsFrom(nil)

---@class Primitive : Diagram
---@field primitive CoordTable
---@field regions Region[]
Primitive = InheritsFrom(Diagram)

---@class Empty : Diagram
Empty = InheritsFrom(Diagram)

---@class Compose : Diagram
---@field dia1 Diagram
---@field dia2 Diagram
---@field cached_envelope Envelope
Compose = InheritsFrom(Diagram)

---@class Act : Diagram
---@field transform Transformation
---@field diagram Diagram
Act = InheritsFrom(Diagram)

---@class EnvelopeDiagram : Diagram
---@field new_envelope Envelope
---@field diagram Diagram
EnvelopeDiagram = InheritsFrom(Diagram)

---@class RegionsDiagram : Diagram
---@field regions Region[]
---@field diagram Diagram
RegionsDiagram = InheritsFrom(Diagram)

function Diagram:tostring()
    return primitives_to_string(self:compile())
end

---Return the envelope, abstract method
---@return Envelope|nil
function Diagram:envelope()
    return nil
end

---internal abstract method
---@param transform Transformation
---@return Endo
---@return Region[]
function Diagram:internal_compile(transform)
    return Endo(nil), {}
end

---compose two diagrams
---@param other Diagram
---@return Diagram
function Diagram:compose(other)
    if self:isa(Empty) then
        return other
    end
    if other:isa(Empty) then
        return self
    end
    local self_envelope = self:envelope()
    if self_envelope == nil then
        return other
    end
    return Compose.new(self, other, self_envelope:compose(other:envelope()))
end

---act on a diagram
---@param transform Transformation
---@return Diagram
function Diagram:act(transform)
    return Act.new(transform, self)
end

---Change the envelope of a diagram
---@param envelope Envelope
---@return Diagram
function Diagram:set_envelope(envelope)
    return EnvelopeDiagram.new(envelope, self)
end

---Add some regions to this diagram
---@param regions Region[]
---@return Diagram
function Diagram:add_regions(regions)
    return RegionsDiagram.new(regions, self)
end

-- compile this diagram to a list of PrimitiveTypes
-- returns a list of PrimitiveTypes
---compile this diagram to a list of PrimitiveTypes
---@generic T
---@return any[]
---@return Region[]
function Diagram:compile()
    local endo, regions = self:internal_compile(Transformation.id())
    local data = endo:eval({})
    local output = {}
    for idx = #data, 1, -1 do
        table.insert(output, data[idx])
    end
    return output, regions
end

---Create a new Primitive
---@generic T
---@param primitive CoordTable<T>
---@param regions? Region[]
---@return Primitive
function Primitive.new(primitive, regions)
    local self = Primitive:create()
    self.primitive = primitive
    if regions == nil then
        self.regions = {}
    else
        self.regions = regions
    end
    return self
end

---calculate the envelope
---@return Envelope|nil
function Primitive:envelope()
    return Envelope.calculate_envelope(self.primitive)
end

---internal_compile
---@param transform Transformation
---@return Endo
---@return Region[]
function Primitive:internal_compile(transform)
    local regions = {}
    for _, region in ipairs(self.regions) do
        table.insert(regions, region:act(transform))
    end
    return Endo.new(function(x)
        -- this modifies the input, so if it was shared anywhere there would be problems
        -- however we do this for performance reasons
        table.insert(x, transform_primitive(self.primitive, transform))
        return x
    end), regions
end

---Create a new Empty Diagram
---@return Diagram
function Empty.new()
    local self = Empty:create()
    return self
end

---Envelope
---@return Envelope|nil
function Empty:envelope()
    return nil
end

---Act on an empty diagram
---@param transform Transformation
---@return Diagram
function Empty:act(transform)
    return self
end

---Internal compile
---@param transform Transformation
---@return Endo
---@return Region[]
function Empty:internal_compile(transform)
    return Endo.id(), {}
end

---Create a new Compose Diagram
---@param diagram1 Diagram
---@param diagram2 Diagram
---@param envelope Envelope
---@return Diagram
function Compose.new(diagram1, diagram2, envelope)
    local self = Compose:create()
    self.dia1 = diagram1
    self.dia2 = diagram2
    self.cached_envelope = envelope
    return self
end

---Envelope
---@return Envelope|nil
function Compose:envelope()
    return self.cached_envelope
end

---internal compile
---@param transform Transformation
---@return Endo
---@return Region[]
function Compose:internal_compile(transform)
    local endo1, regions1 = self.dia1:internal_compile(transform)
    local endo2, regions2 = self.dia2:internal_compile(transform)

    -- Warning: this does an array concat so may be slow
    return endo1:act(endo2), Concat_arrays(regions1, regions2)
end

---Create a new Act Diagram
---@param transform Transformation
---@param diagram Diagram
---@return Diagram
function Act.new(transform, diagram)
    local self = Act:create()
    self.transform = transform
    self.diagram = diagram
    return self
end

---Envelope
---@return Envelope|nil
function Act:envelope()
    local envelope = self.diagram:envelope()
    if envelope == nil then
        return nil
    end
    return envelope:act(self.transform.translation)
end

---Act
---@param transform Transformation
---@return Diagram
function Act:act(transform)
    return Act.new(self.transform:compose(transform), self.diagram)
end

---Internal compile
---@param transform Transformation
---@return Endo
---@return Region[]
function Act:internal_compile(transform)
    return self.diagram:internal_compile(transform:compose(self.transform))
end

---Create a new EnvelopeDiagram
---@param envelope Envelope
---@param diagram Diagram
---@return Diagram
function EnvelopeDiagram.new(envelope, diagram)
    local self = EnvelopeDiagram:create()
    self.new_envelope = envelope
    self.diagram = diagram
    return self
end

---Envelope
---@return Envelope
function EnvelopeDiagram:envelope()
    return self.new_envelope
end

---Internal compile
---@param transform Transformation
---@return Endo
---@return Region[]
function EnvelopeDiagram:internal_compile(transform)
    return self.diagram:internal_compile(transform)
end

---Create a new RegionsDiagram
---@param regions Region[]
---@param diagram Diagram
---@return Diagram
function RegionsDiagram.new(regions, diagram)
    local self = RegionsDiagram:create()
    self.regions = regions
    self.diagram = diagram
    return self
end

---Envelope
---@return Envelope|nil
function RegionsDiagram:envelope()
    return self.diagram:envelope()
end

---Internal compile
---@param transform Transformation
---@return Endo
---@return Region[]
function RegionsDiagram:internal_compile(transform)
    local endo, regions = self.diagram:internal_compile(transform)
    local out = {}
    for _, region in ipairs(self.regions) do
        table.insert(out, region:act(transform))
    end
    for _, region in ipairs(regions) do
        table.insert(out, region)
    end
    return endo, out
end

---Direction: Directions for a Diagram
---@enum Direction
Direction = {
    LEFT = 0,
    RIGHT = 1,
    UP = 2,
    DOWN = 3,
}

---translate a diagram by x and y
---@param x int
---@param y int
---@param dia Diagram
---@return Diagram
function Translate(x, y, dia)
    -- print("Translating by " .. x .. ", " .. y)
    return dia:act(Transformation.translate(x, y))
end

---place a diagram beside another, in the given direction, with optional gap
---@param dia1 Diagram
---@param dia2 Diagram
---@param dir? Direction
---@param optional_gap? int
---@return Diagram
function Beside(dia1, dia2, dir, optional_gap)
    local envelope1 = dia1:envelope()
    if envelope1 == nil then
        return dia2
    end
    local envelope2 = dia2:envelope()
    if envelope2 == nil then
        return dia1
    end
    local gap = optional_gap
    if gap == nil then
        gap = 0
    end
    if dir == nil or dir == Direction.RIGHT then
        return dia1:compose(Translate(envelope1.right + envelope2.left + 1 + gap, 0, dia2))
    end
    if dir == Direction.LEFT then
        return dia1:compose(Translate(-(envelope1.left + envelope2.right + 1 + gap), 0, dia2))
    end
    if dir == Direction.UP then
        return dia1:compose(Translate(0, envelope1.up + envelope2.down + 1 + gap, dia2))
    end
    if dir == Direction.DOWN then
        return dia1:compose(Translate(0, -(envelope1.down + envelope2.up + 1 + gap), dia2))
    end
    return Empty:new()
end

--[[
local test_a_dict = CoordTable.from_array {
    { x = 0, y = 0, value = Action_string("A") },
    { x = 1, y = 0, value = Action_string("B") },
    { x = 0, y = 1, value = Action_string("C") },
    { x = 1, y = 1, value = Action_string("D") }
}


local test_b_dict = CoordTable.from_array {
    { x = 0, y = 0, value = Action_string("0") },
    { x = 1, y = 0, value = Action_string("1") },
    { x = 0, y = 1, value = Action_string("2") },
    { x = 1, y = 1, value = Action_string("3") }
}
local a = Primitive.new(test_a_dict)
local b = Primitive.new(test_b_dict)
print("===")
print(a:tostring())
print("===")
print(b:tostring())
print("==RIGHT==")
local test_beside = Beside(a, b, Direction.RIGHT)
-- print(Dump(test_beside:envelope()))
print(test_beside:tostring())
print("==LEFT==")
print(Beside(a, b, Direction.LEFT):tostring())
print("==UP==")
print(Beside(a, b, Direction.UP):tostring())
print("==DOWN==")
print(Beside(a, b, Direction.DOWN):tostring())
print("==FULL==")
print(Beside(Beside(a, b, Direction.UP), Beside(a, b, Direction.DOWN), Direction.RIGHT):tostring())
print("==FULL2==")
print(Beside(Beside(a, b, Direction.UP), Translate(0, 2, Beside(a, b, Direction.DOWN)), Direction.RIGHT):tostring())
--]]
