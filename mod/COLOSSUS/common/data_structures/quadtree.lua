--- Quadtrees

-- This assumes that y increases going south

require("common.utils.objects")

--- Represents a point with a tag
---@class Point : BaseClass
---@field x float
---@field y float
---@field tag any
Point = InheritsFrom(nil)

---Create a new Point
---@param x float
---@param y float
---@param tag? any
---@return Point
function Point.new(x, y, tag)
    local self = Point:create()
    self.x = x
    self.y = y
    self.tag = tag
    return self
end

---Return the squared difference to another point
---@param other Point
---@return float
function Point:distance_squared(other)
    return (self.x - other.x) ^ 2 + (self.y - other.y) ^ 2
end

--_A rectangle with centre, width, and height
---@class Rect : BaseClass
---@field centre_x float
---@field centre_y float
---@field width float
---@field height float
---@field north float
---@field east float
---@field south float
---@field west float
Rect = InheritsFrom(nil)

---Create a new Rect
---@param centre_x float centre x coord
---@param centre_y float centre y coord
---@param width float width
---@param height float height
---@return Rect
function Rect.new(centre_x, centre_y, width, height)
    local self = Rect:create()
    self.centre_x = centre_x
    self.centre_y = centre_y
    self.width = width
    self.height = height
    self.north = centre_y - height / 2
    self.east = centre_x + width / 2
    self.south = centre_y + height / 2
    self.west = centre_x - width / 2
    return self
end

---Does the Rect contain the given Point
---@param point Point
---@return boolean
function Rect:contains(point)
    return point.x >= self.west and point.x <= self.east and point.y <= self.south and point.y >= self.north
end

---Does the Rect contain the given x, y coordinates
---@param x float
---@param y float
---@return boolean
function Rect:contains_xy(x, y)
    return x >= self.west and x <= self.east and y <= self.south and y >= self.north
end

---Do the two Rect's intersect each other?
---@param other Rect
---@return boolean
function Rect:intersects(other)
    return not (other.west >= self.east or other.east <= self.west or other.north >= self.south or other.south <= self.north)
end

---Represents a quad tree
---@class QuadTree : BaseClass
---@field boundary Rect for containing points in this node
---@field max_points int maximum number of points for this node
---@field points Point[]
---@field depth int how deep in the quadtree
---@field divided boolean has this node been divided yet
---@field northeast? QuadTree
---@field southeast? QuadTree
---@field southwest? QuadTree
---@field northwest? QuadTree
QuadTree = InheritsFrom(nil)

---Create a new QuadTree
---@param boundary Rect boundary for this node
---@param max_points? int number of points to store in this node
---@param depth? int depth of this node
---@return QuadTree
function QuadTree.new(boundary, max_points, depth)
    if max_points == nil then
        max_points = 4
    end
    if depth == nil then
        depth = 0
    end
    local self = QuadTree:create()
    self.boundary = boundary
    self.max_points = max_points
    self.points = {}
    self.depth = depth
    self.divided = false
    return self
end

---Divide this node into four children nodes
function QuadTree:divide()
    local w = self.boundary.width / 2
    local h = self.boundary.height / 2
    local x = self.boundary.centre_x
    local y = self.boundary.centre_y
    self.northeast = QuadTree.new(Rect.new(x + w / 2, y - h / 2, w, h), self.max_points, self.depth + 1)
    self.southeast = QuadTree.new(Rect.new(x + w / 2, y + h / 2, w, h), self.max_points, self.depth + 1)
    self.southwest = QuadTree.new(Rect.new(x - w / 2, y + h / 2, w, h), self.max_points, self.depth + 1)
    self.northwest = QuadTree.new(Rect.new(x - w / 2, y - h / 2, w, h), self.max_points, self.depth + 1)
    self.divided = true
end

---Insert a point into this QuadTree.  Returns true if successful
---@param point Point
---@return boolean
function QuadTree:insert(point)
    if not self.boundary:contains(point) then
        -- point is not inside this boundary
        return false
    end
    if #self.points <= self.max_points then
        -- add the point to this node
        table.insert(self.points, point)
        return true
    end
    -- now we have to divide
    if not self.divided then
        self:divide()
    end

    return (self.northeast:insert(point) or
        self.southeast:insert(point) or
        self.southwest:insert(point) or
        self.northwest:insert(point))
end

---Find all points of the QuadTree inside the given boundary
---@param boundary Rect
---@param output Point[] output array
function QuadTree:query(boundary, output)
    if not self.boundary:intersects(boundary) then
        -- no points in this node can lie in the boundary
        return
    end
    -- check stored points
    for _, point in ipairs(self.points) do
        if boundary:contains(point) then
            table.insert(output, point)
        end
    end
    -- recurse into subnodes
    if self.divided then
        self.northeast:query(boundary, output)
        self.southeast:query(boundary, output)
        self.southwest:query(boundary, output)
        self.northwest:query(boundary, output)
    end
end

---Find all points of the Quadtree inside the boundary and within radius of the centre
---@param boundary Rect Bounding Rect of the circle
---@param centre Point Centre of the circle
---@param radius_squared float Radius squared of the circle
---@param output Point[] output array
function QuadTree:query_circle(boundary, centre, radius_squared, output)
    if not self.boundary:intersects(boundary) then
        -- no points in this node can lie in the boundary
        return
    end
    -- check stored points
    for _, point in ipairs(self.points) do
        if boundary:contains(point) and point:distance_squared(centre) <= radius_squared then
            table.insert(output, point)
        end
    end
    -- recurse into subnodes
    if self.divided then
        self.northeast:query_circle(boundary, centre, radius_squared, output)
        self.southeast:query_circle(boundary, centre, radius_squared, output)
        self.southwest:query_circle(boundary, centre, radius_squared, output)
        self.northwest:query_circle(boundary, centre, radius_squared, output)
    end
end

---Find the points of the QuadTree within the given radius of the centre
---@param centre Point
---@param radius float
---@param output Point[]
---@return nil
function QuadTree:query_radius(centre, radius, output)
    local boundary = Rect.new(centre.x, centre.y, 2 * radius, 2 * radius)
    return self:query_circle(boundary, centre, radius * radius, output)
end

TestQuadTree = {}
function TestQuadTree.test1()
    local lu = require('lib.luaunit')
    local point_data = { { 0, 0 }, { 5, 5 }, { 2, 3 }, { 7, 9 }, { 8, 6 }, { 3, 4 }, { 20, 19 }, { 22, 22 }, { 23, 18 } }
    local points = {}
    for _, point in ipairs(point_data) do
        table.insert(points, Point.new(point[1], point[2]))
    end
    local boundary = Rect.new(0, 0, 100, 100)
    lu.assertIsTrue(boundary:contains(Point.new(0, 0)), "Boundary should contain the origin")

    local quadtree = QuadTree.new(boundary)
    for idx, point in ipairs(points) do
        lu.assertIsTrue(quadtree:insert(point), "Insertion failed")
    end
    local output = {}
    quadtree:query_radius(Point.new(20, 20), 3, output)
    lu.assertEquals(#output, 2)
    output = {}
    quadtree:query_radius(Point.new(20, 20), 4, output)
    lu.assertEquals(#output, 3)
    output = {}
    quadtree:query_radius(Point.new(40, 40), 4, output)
    lu.assertEquals(#output, 0)
end
