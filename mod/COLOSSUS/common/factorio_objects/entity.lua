-- represents entities

require("common.utils.utils")
require("common.utils.objects")

-- EntityDirection: Direction of an entity
-- note: can get this from Factorio

--- @enum EntityDirection
EntityDirection = {
    UP = 0,
    RIGHT = 2,
    DOWN = 4,
    LEFT = 6,
}

-- An Entity has a name, a direction, tags, and args
--- @class Entity : BaseClass
--- @field name string
--- @field direction EntityDirection
--- @field tags table<string, any> | nil
--- @field args table | nil
Entity = InheritsFrom(nil)

---Create a new Entity
---@param name string
---@param direction EntityDirection
---@param tags? table<string, any>
---@param args? table
---@return Entity
function Entity.new(name, direction, tags, args)
    local self = Entity:create()
    if name == nil or name == "" then
        error("Entity name is empty")
    end
    self.name = name
    self.direction = direction
    if tags ~= nil then
        self.tags = tags
    else
        self.tags = {}
    end
    self.args = args
    return self
end

---Convert an Entity to a table
---@return table
function Entity:to_table()
    local out = {}
    out["name"] = self.name
    if self.direction ~= EntityDirection.UP then
        out["direction"] = self.direction
    end
    if self.args ~= nil then
        for index, value in pairs(self.args) do
            out[index] = value
        end
    end
    return out
end

---Clone an Entity
---@return Entity
function Entity:clone()
    return Entity.new(self.name, self.direction, Deepcopy(self.tags), Deepcopy(self.args))
end

assert(EntityDirection.DOWN == 4, "EntityDirection error")
-- print(Dump(Entity.new("test", EntityDirection.DOWN, { test = "" }, nil)))
-- print(Dump(Entity.new("test", EntityDirection.DOWN, { test = "" }, { a = "b" }):to_table()))
