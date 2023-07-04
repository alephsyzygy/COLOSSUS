-- Post-processing functions

require("common.data_structures.quadtree")
require("common.data_structures.graph")

PostProcessing = {}

---Find the bounding Rect of a CoordTable
---@param coordtable CoordTable<any>
---@return Rect
local function coord_to_rect(coordtable)
    local min_x, min_y, max_x, max_y = nil, nil, nil, nil
    CoordTable.iterate(coordtable, function(_x, _y, entity)
        local x, y = entity.position.x, entity.position.y
        if min_x == nil then
            min_x = x
        end
        if max_x == nil then
            max_x = x
        end
        if min_y == nil then
            min_y = y
        end
        if max_y == nil then
            max_y = y
        end
        min_x = math.min(min_x, x)
        max_x = math.max(max_x, x)
        min_y = math.min(min_y, y)
        max_y = math.max(max_y, y)
    end)

    return Rect.new((min_x + max_x) / 2, (min_y + max_y) / 2, max_x - min_x, max_y - min_y)
end


---Build a connection graph from the current primitive
---Calls process for each wire length, passing the current wire length,
--- all entities with at least this range, and the current QuadTree
---@param primitive CoordTable<any>
---@param full_config FullConfig
---@param entities Set<string>
---@param tags CoordTable<any>[] also include entities with these tags
---@param boundary? Rect
---@param process fun(range:float, entities: any[], quadtree: QuadTree)
local function build_connection_graph(primitive, full_config, entities, tags, process, boundary)
    if boundary == nil then
        boundary = coord_to_rect(primitive)
    end
    ---@type Set<int>
    local wire_length_set = {}

    -- find all possible wire lengths, assumed to cover tags too
    for pole_name, _ in pairs(entities) do
        local max_wire_distance = full_config.game_data.entities[pole_name].max_wire_distance
        if max_wire_distance ~= nil then
            wire_length_set[max_wire_distance] = true
        end
    end

    -- convert from a set to an array
    local wire_lengths = {}
    for length, _ in pairs(wire_length_set) do
        table.insert(wire_lengths, length)
    end

    -- we work with the biggest wire lengths first
    table.sort(wire_lengths, function(x, y) return x > y end)

    local pole_entities = {}
    for _, wire_length in pairs(wire_lengths) do
        pole_entities[wire_length] = {}
    end
    CoordTable.iterate(primitive, function(_x, _y, entity)
        if entities[entity.name] == true and boundary:contains_xy(entity.position.x, entity.position.y) then
            -- if this is a pole add it to all appropriate wire lengths
            local wire_distance = full_config.game_data.entities[entity.name].max_wire_distance
            if wire_distance ~= nil then
                for _, wire_length in pairs(wire_lengths) do
                    if wire_distance >= wire_length then
                        table.insert(pole_entities[wire_length], entity)
                    end
                end
            end
        end
    end)
    -- now do tags
    for _, coord_table in ipairs(tags) do
        CoordTable.iterate(coord_table, function(x, y, value)
            local entity = CoordTable.get(primitive, x, y)
            if entity and boundary:contains_xy(entity.position.x, entity.position.y) then
                -- if this is a pole add it to all appropriate wire lengths
                local wire_distance = full_config.game_data.entities[entity.name].max_wire_distance
                if wire_distance ~= nil then
                    for _, wire_length in pairs(wire_lengths) do
                        if wire_distance >= wire_length then
                            table.insert(pole_entities[wire_length], entity)
                        end
                    end
                end
            end
        end)
    end

    -- loop through wire lengths, largest first
    for _, range in ipairs(wire_lengths) do
        local current_pole_entities = pole_entities[range]
        if #current_pole_entities > 0 then
            local quadtree = QuadTree.new(boundary)

            for _, pole in pairs(current_pole_entities) do
                quadtree:insert(Point.new(pole.position.x, pole.position.y, pole))
            end
            process(range, current_pole_entities, quadtree)
        end
    end
end

---Connect up the power poles via a minimum spanning tree
---@param intermediate IntermediateType
---@param regions Region[]
---@param tags TagType
---@param lookup LookupType
---@param full_config FullConfig
---@return IntermediateType
function PostProcessing.connect_electrical_grids(intermediate, regions, tags, lookup, full_config)
    -- the idea here is that we create a collection of minimum spanning forests, one for each write length
    -- the largest wire lengths have their own forest
    -- the next largest length also includes the largest and has another forest
    -- right to the end where all electrical poles are put into a minimum spanning forest

    -- by having these multiple forests we can ensure that the long range poles are connected and won't
    -- disconnect the grid when smaller range poles are removed.

    -- to create these forests we collect all the entities of the appropriate type
    -- put them into a QuadTree (may need a coord change)
    -- From the QuadTree build a graph of possible wire connections
    -- Run Kruskal's algorithm to get the minimum spanning forest
    -- From this connect up the appropriate entities

    local final_connections = {}

    local function process(range, current_pole_entities, quadtree)
        -- store entity_number to node number lookups
        ---@type table<int, int>
        local entity_to_node = {}
        local nodes = {}
        local idx = 1
        for _, pole in pairs(current_pole_entities) do
            table.insert(nodes, pole)
            entity_to_node[pole.entity_number] = idx
            idx = idx + 1
        end
        -- disjoint set for existing connections
        local disjointset = DisjointSet.new(nodes)

        -- now we create the graph.
        local edges = {}
        local neighbours
        for _, pole in pairs(current_pole_entities) do
            local node_number = entity_to_node[pole.entity_number]
            neighbours = {}
            quadtree:query_radius(Point.new(pole.position.x, pole.position.y), range, neighbours)

            -- add all the nearby poles to the graph
            for _, neighbour in pairs(neighbours) do
                local neighbour_number = entity_to_node[neighbour.tag.entity_number]
                if node_number < neighbour_number then
                    table.insert(edges,
                        Edge.new(node_number, neighbour_number,
                            (pole.position.x - neighbour.x) ^ 2 +
                            (pole.position.y - neighbour.y) ^ 2))
                end
            end

            -- now we go through existing connections and update the disjoint set
            -- this is so we don't add MST connections if we don't need to, i.e.
            -- they are already connected
            for _, nbh_entity_num in ipairs(pole.neighbours) do
                local target_number = entity_to_node[nbh_entity_num]
                if target_number ~= nil then
                    disjointset:union_idx(node_number, target_number)
                end
            end
        end


        local graph = Graph.new(nodes, edges)
        local mst = graph:kruskal(disjointset)

        -- record the neighbours using the MST
        -- we won't perform these yet, we will wait for the other wire
        -- lengths to finish
        for _, edge in pairs(mst) do
            table.insert(final_connections, { first = nodes[edge.source], second = nodes[edge.target] })
        end
    end

    build_connection_graph(intermediate, full_config, full_config.game_data.electric_poles, {}, process)

    -- finally update all the neighbours
    -- this may have duplicates, but hopefully the game will ignore them
    for _, edge in pairs(final_connections) do
        table.insert(edge.first.neighbours, edge.second.entity_number)
        table.insert(edge.second.neighbours, edge.first.entity_number)
    end

    return intermediate
end

---Build a full graph from the given data
---@param intermediate CoordTable<any>
---@param full_config FullConfig
---@param wire_types Set<string>
---@param tags? CoordTable<any>[]
---@param boundary? Rect
---@return Graph
---@return table<integer, integer> entity lookup
local function build_full_graph(intermediate, full_config, wire_types, tags, boundary)
    if tags == nil then tags = {} end
    local nodes = {}
    -- store entity_number to node number lookups
    ---@type table<int, int>
    local entity_to_node = {}
    local idx = 1
    local edges = {}
    ---@type table<int, Set<int>>
    local seen_edges = {}

    local function process(range, current_pole_entities, quadtree)
        for _, pole in pairs(current_pole_entities) do
            if entity_to_node[pole.entity_number] == nil then
                table.insert(nodes, pole)
                seen_edges[idx] = {}
                entity_to_node[pole.entity_number] = idx
                idx = idx + 1
            end
        end

        local neighbours
        for _, pole in pairs(current_pole_entities) do
            local node_number = entity_to_node[pole.entity_number]
            neighbours = {}
            quadtree:query_radius(Point.new(pole.position.x, pole.position.y), range, neighbours)

            -- add all the nearby poles to the graph
            for _, neighbour in pairs(neighbours) do
                local neighbour_number = entity_to_node[neighbour.tag.entity_number]
                if node_number < neighbour_number and seen_edges[node_number][neighbour_number] ~= true then
                    table.insert(edges,
                        Edge.new(node_number, neighbour_number,
                            (pole.position.x - neighbour.x) ^ 2 +
                            (pole.position.y - neighbour.y) ^ 2))
                    -- this isn't strictly necessary for the test to succeed
                    seen_edges[node_number][neighbour_number] = true
                end
            end
        end
    end

    build_connection_graph(intermediate, full_config, wire_types, tags, process, boundary)

    return Graph.new(nodes, edges), entity_to_node
end

---Connect up only the small power poles via a minimum spanning tree.  Used for testing only.
---@param intermediate IntermediateType
---@param regions Region[]
---@param tags TagType
---@param lookup LookupType
---@param full_config FullConfig
---@return IntermediateType
function PostProcessing.connect_small_electic_poles(intermediate, regions, tags, lookup, full_config)
    local graph, entity_to_node = build_full_graph(intermediate, full_config, full_config.game_data.electric_poles)

    -- find small-electric-poles
    local small_poles = {}
    CoordTable.iterate(intermediate, function(x, y, entity)
        if entity.name == "small-electric-pole" then
            table.insert(small_poles, entity_to_node[entity.entity_number])
        end
    end)

    -- find the gmst for small poles
    local gmst = graph:generalized_minimum_spanning_forest(small_poles)

    -- now hook up small poles
    for _, edge in pairs(gmst) do
        local first = graph.nodes[edge.source]
        local second = graph.nodes[edge.target]
        table.insert(first.neighbours, second.entity_number)
        table.insert(second.neighbours, first.entity_number)
    end

    return intermediate
end

---Testing: Connect up only the small power poles via a minimum spanning tree
---@param intermediate IntermediateType
---@param regions Region[]
---@param tags TagType
---@param lookup LookupType
---@param full_config FullConfig
---@return IntermediateType
function PostProcessing.connect_belts(intermediate, regions, tags, lookup, full_config)
    local wire_types = Copy(full_config.game_data.electric_poles)
    wire_types["transport-belt"] = true

    local graph, entity_to_node = build_full_graph(intermediate, full_config, wire_types)

    -- find belts
    local belts = {}
    CoordTable.iterate(intermediate, function(x, y, entity)
        if entity.name == "transport-belt" then
            table.insert(belts, entity_to_node[entity.entity_number])
        end
    end)

    -- find the gmst for small poles
    local gmst = graph:generalized_minimum_spanning_forest(belts)

    -- now hook up small poles
    for _, edge in pairs(gmst) do
        local first = graph.nodes[edge.source]
        local second = graph.nodes[edge.target]
        local path = { "connections", 1, "green" }

        table.insert(Get_path_default(first, path, {}), { entity_id = second.entity_number })
        table.insert(Get_path_default(second, path, {}), { entity_id = first.entity_number })
    end

    return intermediate
end

local function ensure_entity_numbers_unique(primitive)
    local numbers = {}
    local connections = {}
    local neighbours = {}
    CoordTable.iterate(primitive, function(x, y, entity)
        if numbers[entity.entity_number] ~= nil then
            error(Dump(entity))
        end
        if neighbours[entity.neighbours] ~= nil then
            error(Dump(entity))
        end
        if connections[entity.connections] ~= nil then
            print(connections[entity.connections] .. "  " .. entity.entity_number)
            error(Dump(entity))
        end
        numbers[entity.entity_number] = entity.entity_number
        connections[entity.connections] = entity.entity_number
        neighbours[entity.neighbours] = entity.entity_number
    end)
end

---Connect up the clocked poles with red wires
---@param intermediate IntermediateType
---@param regions Region[]
---@param tags TagType
---@param lookup LookupType
---@param full_config FullConfig
---@return IntermediateType
function PostProcessing.connect_clocked_poles(intermediate, regions, tags, lookup, full_config)
    -- ensure_entity_numbers_unique(intermediate)
    -- for each region, if the region is called "clocked_pole" then we join all clocked poles inside that region
    local wire_types = full_config.game_data.electric_poles

    for _, region in ipairs(regions) do
        if EntityTags["clocked-red-wire"].get_tag(region) == true then
            -- create a Rect, taking into account the coordinate shift
            ---@diagnostic disable-next-line: param-type-mismatch
            local rect = Rect.new((region.min_x + region.max_x + 1.0) / 2.0, (region.min_y + region.max_y + 1.0) / 2.0,
                ---@diagnostic disable-next-line: param-type-mismatch
                region.max_x - region.min_x, region.max_y - region.min_y)
            local graph, entity_to_node = build_full_graph(intermediate, full_config, wire_types,
                { tags["reader"], tags["blocker"] }, rect)

            -- find clocked poles
            local clocked_poles = {}
            local function load_entities(tag)
                if tags[tag] == nil then return end
                CoordTable.iterate(tags[tag], function(x, y, value)
                    if value and region:contains_point(x, y) then
                        assert(rect:contains_xy(x + 0.5, y + 0.5))
                        local entity = CoordTable.get(intermediate, x, y)
                        if not entity then error("Entity not found") end
                        table.insert(clocked_poles, entity_to_node[entity.entity_number])
                    end
                end)
            end
            load_entities("clocked-red-wire")
            load_entities("reader")
            load_entities("blocker")

            -- find the gmst for poles
            local gmst = graph:generalized_minimum_spanning_forest(clocked_poles)

            -- now hook up poles
            for _, edge in pairs(gmst) do
                local first = graph.nodes[edge.source]
                local second = graph.nodes[edge.target]
                local path = { "connections", "1", "red" }

                table.insert(Get_path_default(first, path, {}), { entity_id = second.entity_number })
                table.insert(Get_path_default(second, path, {}), { entity_id = first.entity_number })
            end

            -- delete unused poles
            for _, node in ipairs(graph.nodes) do
                if Table_empty(node.connections) and Table_empty(node.neighbours) then
                    node[DELETE_TAG] = true
                end
            end
        end
    end

    return intermediate
end
