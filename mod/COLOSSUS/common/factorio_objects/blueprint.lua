-- Blueprint related methods

require("common.utils.utils")
require("common.utils.objects")
require("common.utils.serdes")
require("common.schematic.coord_table")
require("common.schematic.diagram")
require("common.factorio_objects.entity")
require("common.config.game_data")
require("common.optimizer")
require("common.schematic.primitive")
require("common.factory_components.tags")



---@alias IntermediateType CoordTable<any>
---@alias TagType table<string, CoordTable<any>>
---@alias LookupType CoordTable<int>

---Create a list of tiles from the given regions
---@param tiles table[]
---@param regions Region[]
local function create_tiles(tiles, regions)
    local seen = CoordTable.new()
    for _, region in ipairs(regions) do
        if RegionTags["tile"].get_tag(region) ~= nil then
            for x = region.min_x, region.max_x do
                for y = region.min_y, region.max_y do
                    if not CoordTable.get(seen, x, y) then
                        table.insert(tiles, {
                            position = { x = x, y = y },
                            name = RegionTags["tile"].get_tag(region)
                        })
                        CoordTable.set(seen, x, y, true)
                    end
                end
            end
        end
    end
end

-- Convert a primitive of entities to a blueprint fragment
-- primitive: PrimitiveEntityType
-- post_proces?: optional array of PostProcessFunctions
--   these take an Intermediate: CoordTable of Any
--      Tag: Table of string to CoordTable of Any
--      Lookup: CoordTable of ints
--   and return an Intermediate: CoordTAble of Any
-- returns a pair of entities and tiles
---Convert a primitive of entities to a blueprint fragment
---@param primitive CoordTable<any>
---@param regions Region[]
---@param post_process (fun(x:IntermediateType, r: Region[], y:TagType, z:LookupType, s: FullConfig): IntermediateType)[]
---@param full_config FullConfig
---@return any[]
---@return any[]
local function primitive_to_blueprint_fragment(primitive, regions, post_process, full_config)
    local number = 1
    local out = {}
    local tiles = {}
    local lookup = CoordTable:new()
    local size_data = full_config.game_data.size_data

    -- populate the lookup table
    CoordTable.iterate(primitive, function(x, y, entity)
        if not EntityTags[DELETE_TAG].get_tag(entity) then
            if entity.tags and entity.tags.position_delta then
                x = x + (entity.tags.position_delta.x or 0)
                y = y + (entity.tags.position_delta.y or 0)
            end
            CoordTable.set(lookup, x, y, number)
            number = number + 1
        end
    end)

    local intermediate = CoordTable:new()
    local tags = {}
    CoordTable.iterate(primitive, function(x, y, entity)
        if EntityTags[DELETE_TAG].get_tag(entity) then
            return
        end
        if entity.tags and entity.tags.position_delta then
            x = x + (entity.tags.position_delta.x or 0)
            y = y + (entity.tags.position_delta.y or 0)
        end
        local obj = entity:to_table()
        local name = obj.name

        -- store tags for post-processing
        for tag, tag_value in pairs(entity.tags) do
            if tags[tag] == nil then
                tags[tag] = CoordTable:new()
            end
            CoordTable.set(tags[tag], x, y, tag_value)
        end

        -- set number and position
        obj.entity_number = CoordTable.get(lookup, x, y)
        obj.position = Fix_coord_inverse(name, x, y, entity.direction, size_data)

        -- fix up connections
        local new_connections = {}
        for connection_id, connection_values in pairs(obj.connections or {}) do
            local new_connection_values = {}
            for connection_color, entities in pairs(connection_values) do
                local new_entities = {}
                for _, connection_entity in pairs(entities) do
                    local relative_x = connection_entity.relative_x
                    local relative_y = connection_entity.relative_y
                    local new_entity = {}
                    -- copy all connection_entity data except relative coords
                    for key, value in pairs(connection_entity) do
                        if key ~= "relative_x" and key ~= "relative_y" then
                            new_entity[key] = value
                        end
                    end

                    -- use the offset to lookup the entity id of the target connection
                    local entity_id = CoordTable.get(lookup, x + relative_x, y + relative_y)
                    if entity_id ~= nil then
                        new_entity.entity_id = entity_id
                        table.insert(new_entities, new_entity)
                    end
                end
                new_connection_values[connection_color] = new_entities
            end
            new_connections[connection_id] = new_connection_values
        end
        -- this also ensures that empty connections have unique tables
        obj.connections = new_connections

        -- fix up neighbours
        local new_neighbours = {}
        for _, neighbour_info in pairs(obj.neighbours or {}) do
            local relative_x = neighbour_info.relative_x
            local relative_y = neighbour_info.relative_y
            local possible_entity_id = CoordTable.get(lookup, x + relative_x, y + relative_y)
            if possible_entity_id then
                table.insert(new_neighbours, possible_entity_id)
            end
        end
        obj.neighbours = new_neighbours

        -- tiles
        if full_config.tile_style == TileStyle.entity and full_config.tile then
            local tile = {
                position = { x = x, y = y },
                name = full_config.tile
            }
            table.insert(tiles, tile)
        end

        CoordTable.set(intermediate, x, y, obj)
    end)

    create_tiles(tiles, regions)

    -- post-process
    full_config.logger:info("Post-Process Statistics")
    full_config.logger:info("---------------------")
    for _, post_process_fn in pairs(post_process) do
        intermediate = post_process_fn(intermediate, regions, tags, lookup, full_config)
    end

    -- convert to array
    CoordTable.iterate(intermediate, function(_, _, value)
        if value[DELETE_TAG] ~= true then
            if value.connections and Table_empty(value.connections) then
                value.connections = nil
            end

            if value.neighbours and Table_empty(value.neighbours) then
                value.neighbours = nil
            end
            table.insert(out, value)
        end
    end)

    return out, tiles
end


--- Blueprint object
---@class Blueprint : Serdes
---@field icons any
---@field entities any[]
---@field label string
---@field snap-to-grid any
---@field absolute-snapping boolean
---@field tiles any
---@field item string
---@field version int
---@field description string
Blueprint = InheritsFrom(Serdes)

Blueprint.export_name = "blueprint"

---Create a new Blueprint
---@param data table
---@return Blueprint
function Blueprint.new(data)
    local self = Blueprint:create()
    self.icons = data.icons
    self.entities = data.entities
    self.label = data.label or ""
    self["snap-to-grid"] = data["snap-to-grid"]
    self["absolute-snapping"] = data["absolute-snapping"] or false
    self.tiles = data.tiles
    self.item = data.item or "blueprint"
    self.version = data.version or 281479276658688
    self.description = data.description or ""
    return self
end

---Convert a blueprint to a table
---@return table
function Blueprint:to_dict()
    local obj = {
        label = self.label,
        description = self.description,
        ["snap-to-grid"] = self["snap-to-grid"],
        ["absolute-snapping"] = self["absolute-snapping"],
        icons = self.icons,
        entities = self.entities,
        tiles = self.tiles,
        item = self.item,
        version = self.version,
    }
    return obj
end

---Object to Blueprint
---@param class any
---@param obj any
---@return Blueprint
function Blueprint.from_obj(class, obj)
    -- print("calling Blueprint from_obj")
    -- print(Dump(obj))
    return Blueprint.new(obj)
end

---convert a blueprint to a Primitive diagram
---@param size_data SizeData
---@return Primitive
function Blueprint:to_primitive(size_data)
    local out = CoordTable:new()

    -- entity lookup to get coords from entity id
    -- keys are ints, values are x, y tuples
    local entity_lookup = {}
    for _, entity_obj in pairs(self.entities) do
        local direction = entity_obj.direction or 0
        entity_lookup[entity_obj.entity_number] = Fix_coord(
            entity_obj.name,
            entity_obj.position.x,
            entity_obj.position.y,
            direction,
            size_data
        )
    end

    -- now we go through all the entity objects in the blueprint
    for _, entity_obj in pairs(self.entities) do
        -- do a shallow copy, avoiding some entries
        local new_obj = {}
        for key, value in pairs(entity_obj) do
            if key ~= "name" and key ~= "direction" and key ~= "entity_number"
                and key ~= "position" and key ~= "connections" then
                new_obj[key] = value
            end
        end
        local direction = entity_obj.direction or 0
        local coord = Fix_coord(
            entity_obj.name,
            entity_obj.position.x,
            entity_obj.position.y,
            direction,
            size_data
        )
        local name = entity_obj.name
        if entity_obj.direction then
            new_obj.direction = nil
        end

        -- handle connections by storing relative offsets in new coord system
        local new_connections = {}
        for connection_id, connection_values in pairs(entity_obj.connections or {}) do
            local new_connection_values = {}
            for connection_color, entities in pairs(connection_values) do
                local new_entities = {}
                for _, entity in pairs(entities) do
                    local new_entity = {}
                    for key, value in pairs(entity) do
                        if key ~= "entity_id" then
                            new_entity[key] = value
                        end
                    end
                    local target_coord = entity_lookup[entity.entity_id]
                    new_entity.relative_x = target_coord.x - coord.x
                    new_entity.relative_y = target_coord.y - coord.y
                    table.insert(new_entities, new_entity)
                end
                new_connection_values[connection_color] = new_entities
            end
            new_connections[connection_id] = new_connection_values
        end
        new_obj.connections = new_connections

        -- handle neighbours
        local new_neighbours = {}
        for _, neighbour_id in pairs(entity_obj.neighbours or {}) do
            local target_coord = entity_lookup[neighbour_id]
            table.insert(new_neighbours, {
                relative_x = target_coord.x - coord.x,
                relative_y = target_coord.y - coord.y
            })
        end
        if new_neighbours ~= {} then
            new_obj.neighbours = new_neighbours
        end
        local tags = entity_obj.tags or {}
        local entity = Entity.new(name, direction, tags, new_obj)
        CoordTable.set(out, coord.x, coord.y, ActionPair.new(entity, nil))

        -- now create delete objects
        Set_delete_entities(out, name, coord.x, coord.y, direction, size_data)
    end

    return Primitive.new(out)
end

--- BlueprintBook object
---@class BlueprintBook : Serdes
---@field icons any
---@field label string
---@field active_index int
---@field tiles any
---@field item string
---@field version int
---@field description string
---@field blueprints table<int,Blueprint|BlueprintBook>
BlueprintBook = InheritsFrom(Serdes)
BlueprintBook.export_name = "blueprint_book"

---Create a new BlueprintBook
---@param data any
---@param blueprints table<int,Blueprint|BlueprintBook>
---@return BlueprintBook
function BlueprintBook.new(data, blueprints)
    local self = BlueprintBook:create()
    self.label = data.label or ""
    self.description = data.description or ""
    self.active_index = data.active_index or 0
    self.icons = data.icons
    self.item = data.item or "blueprint-book"
    self.version = data.version or 281479276658688
    self.blueprints = blueprints
    return self
end

---Convert a BlueprintBook to a table
---@return table
function BlueprintBook:to_dict()
    local blueprints = {}
    for idx, entry in pairs(self.blueprints) do
        if entry:isa(Blueprint) then
            table.insert(blueprints, {
                [Blueprint.export_name] = entry:to_dict(),
                index = idx
            })
        else
            table.insert(blueprints, {
                [BlueprintBook.export_name] = entry:to_dict(),
                index = idx
            })
        end
    end
    local obj = {
        label = self.label,
        description = self.description or "",
        active_index = self.active_index or 0,
        icons = self.icons,
        item = self.item,
        version = self.version,
        blueprints = blueprints,
    }
    return obj
end

---Load a BlueprintBook from an object
---@param class any
---@param obj any
---@return BlueprintBook
function BlueprintBook.from_obj(class, obj)
    -- print("calling BlueprintBook from_obj")
    -- print(Dump(obj))
    local blueprints = {}
    for _, entry in pairs(obj.blueprints) do
        local index = entry.index
        local blueprint = entry.blueprint
        if blueprint ~= nil then
            blueprints[index] = Blueprint:from_obj(blueprint)
        else
            local blueprint_book = entry.blueprint_book
            if blueprint_book ~= nil then
                blueprints[index] = BlueprintBook:from_obj(blueprint_book)
            end
        end
    end
    return BlueprintBook.new(obj, blueprints)
end

---Get a Blueprint by label
---@param label string
---@return Blueprint
function BlueprintBook:get_blueprint(label)
    for _, blueprint in pairs(self.blueprints) do
        if blueprint.label == label and blueprint:isa(Blueprint) then
            return blueprint --[[@as Blueprint]]
        end
    end
    error("Could not find Blueprint " .. label)
end

---Get a BlueprintBook by label
---@param label string
---@return BlueprintBook
function BlueprintBook:get_blueprint_book(label)
    for _, blueprint in pairs(self.blueprints) do
        if blueprint.label == label and blueprint:isa(BlueprintBook) then
            return blueprint --[[@as BlueprintBook]]
        end
    end
    error("Could not find BlueprintBook " .. label)
end

---create a table with keys the blueprint labels and values the blueprints
---@return table<string, Blueprint>
function BlueprintBook:to_lookup()
    local out = {}
    for _, blueprint in pairs(self.blueprints) do
        if blueprint:isa(Blueprint) then
            out[blueprint.label] = blueprint
        end
    end
    return out
end

---Package a list of primitives into a complete blueprint
---@param primitives CoordTable<any>[]
---@param regions Region[]
---@param optimizations (fun(intermediate: CoordTable<any>, full_config: FullConfig): CoordTable<any>)[]
---@param post_process (fun(intermediate: CoordTable<any>, regions: Region[], tags: table<string, CoordTable<any>>, lookup: CoordTable<integer>, full_config: FullConfig): CoordTable<any>)[]
---@param full_config FullConfig
---@return Blueprint
function Primitives_to_blueprint(primitives, regions, optimizations, post_process, full_config)
    local full_primitive = Concat_primitives(primitives)

    full_config.logger:info("Optimizer Statistics")
    full_config.logger:info("---------------------")
    for _, optimizer in ipairs(optimizations) do
        full_primitive = optimizer(full_primitive, full_config)
    end
    local all_entities, tiles = primitive_to_blueprint_fragment(full_primitive, regions, post_process, full_config)

    local blueprint = Blueprint.new {
        icons = { { signal = { type = "item", name = "transport-belt" }, index = 1 } },
        entities = all_entities,
        tiles = tiles,
        label = full_config.blueprint_name,
    }

    full_config.logger:info("Number of entities: " .. #all_entities)
    full_config.logger:info("Number of tiles: " .. #tiles)

    return blueprint
end

---@class BlueprintData : BaseClass
---@field template_blueprints table<string, Blueprint>
---@field bypass_blueprints table<string, Blueprint>
---@field lane_blueprints table<string, Blueprint>
---@field bundle_blueprints table<string, Blueprint>
---@field misc_blueprints table<string, Blueprint>
BlueprintData = InheritsFrom(nil)


function BlueprintData.initialize(data)
    local self = BlueprintData:create()


    ---@type BlueprintBook
    local full_data_blueprint_book = BlueprintBook:from_string(data, true)
    -- self.template_blueprints = full_data_blueprint_book:get_blueprint_book("Templates"):to_lookup()
    self.bypass_blueprints = full_data_blueprint_book:get_blueprint_book("Bypasses"):to_lookup()
    self.lane_blueprints = full_data_blueprint_book:get_blueprint_book("Lanes"):to_lookup()

    ---@type table<string,Blueprint>
    self.bundle_blueprints = {}
    for _, book in pairs(full_data_blueprint_book:get_blueprint_book("Bundles").blueprints) do
        if book:isa(BlueprintBook) then
            self.bundle_blueprints[book.label] = (book --[[@as BlueprintBook]]):to_lookup()
        end
    end
    self.misc_blueprints = full_data_blueprint_book:get_blueprint_book("Misc"):to_lookup()

    return self
end

-- local test_blueprint =
-- "0eNqVkdFqxCAQRf9lnrU0sdu0/koJxWSH7ICOoqY0LP57Nc1DIaXQBx0ueM+9jHeY7IohEmfQd0hsgsxeLpGuTX+C7gRs9S4CzJS8XTPK9ioQL6BzXFEAzZ4T6Lfqp4WNbc68BQQNlNGBADauKZMSuslWq3RmvhGjVFDJxFdsUWUUgJwpE37zdrG98+omjHuXg5ScsVaixTlHmmXwFmtM8Kl6PR/V5ePDZW9fZ01hpOU2+TU2thqLOPH7v5ueArqDX2f5Baf+V1cdNHVu241tNfsy9Y8fE/CBMe2E/qV7Gl774flSTzeU8gXeaJyD"

-- local blueprint = Blueprint:from_string(test_blueprint)
-- -- print(Dump(blueprint))

-- local blueprint_book = BlueprintBook:from_file("../data/blueprint_data.bpb")
-- local template_book = blueprint_book:get_blueprint_book("Templates")
-- local template = template_book:get_blueprint("clocked-chemical-2-1")
-- -- print(Dump(template))
-- assert(template_book:to_lookup()["clocked-chemical-2-1"] ~= nil)
-- assert(template_book:to_lookup()["clocked-unknown-2-1"] == nil)
