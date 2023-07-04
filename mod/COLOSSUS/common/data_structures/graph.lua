--- Represents a graph data structure

require("common.utils.objects")
require("common.data_structures.disjointset")
require("common.data_structures.binaryheap")
require("common.utils.utils")

---An edge of a graph
---@class Edge : BaseClass
---@field source int
---@field target int
---@field weight float
Edge = InheritsFrom(nil)

---Create a new Edge, ensuring that source and target are different
---@param source int
---@param target int
---@param weight float
---@return Edge
function Edge.new(source, target, weight)
    local self = Edge:create()
    if source == target then
        error("Source and target should be different")
    end
    self.source = math.min(source, target)
    self.target = math.max(source, target)
    self.weight = weight
    return self
end

---An adjancency list graph
---@class Graph : BaseClass
---@field nodes any[]
---@field edges Edge[]
---@field adjacent table<int, Edge[]>
Graph = InheritsFrom(nil)

---Create a new Graph
---@param nodes? any[]
---@param edges? Edge[]
---@return Graph
function Graph.new(nodes, edges)
    local self = Graph:create()
    if nodes == nil then
        self.nodes = {}
    else
        self.nodes = nodes
    end
    if edges == nil then
        self.edges = {}
    else
        self.edges = edges
    end
    self.adjacent = {}
    for idx, _ in ipairs(self.nodes) do
        self.adjacent[idx] = {}
    end
    for _, edge in ipairs(self.edges) do
        table.insert(self.adjacent[edge.source], edge)
        table.insert(self.adjacent[edge.target], edge)
    end
    return self
end

function Graph:to_string()
    local out = {}
    -- table.insert(out, table.concat(self.nodes, ", "))
    for _, edge in ipairs(self.edges) do
        table.insert(out, edge.source .. " " .. edge.target .. " " .. edge.weight)
    end

    return table.concat(out, "\n")
end

---Perform Kruskal's algorithm on the graph to find a
---Minimum Spanning Tree.  If there are already connections
---you wish to keep then pass in a DisjointSet with those connected
---components.
---@param disjointset? DisjointSet Existing disjoint set, so you can include existing connections
---@return table
function Graph:kruskal(disjointset)
    local output = {}
    if disjointset == nil then
        disjointset = DisjointSet.new(self.nodes)
    end
    -- sort the edges
    ---@type Edge[]
    local edges = Copy(self.edges)
    table.sort(edges, function(x, y) return x.weight < y.weight end)
    for _, edge in ipairs(edges) do
        if disjointset:find_idx(edge.source) ~= disjointset:find_idx(edge.target) then
            table.insert(output, edge)
            disjointset:union_idx(edge.source, edge.target)
        end
    end
    return output
end

---Calculate the generalized minimum spanning forest
---Based on:
--- Wu, Y.F., Widmayer, P. & Wong, C.K. A faster approximation algorithm for the Steiner problem in graphs.
--- Acta Informatica 23, 223-229 (1986). https://doi.org/10.1007/BF00289500
---@param s_array int[] list of nodes that must be in the MST
---@param disjointset? DisjointSet Existing disjoint set, so you can include existing connections
---@return int[] the generalized MST
function Graph:generalized_minimum_spanning_forest(s_array, disjointset)
    local S = Set.from_array(s_array)
    -- the closest node in S to the given node
    ---@type table<int, int>
    local source = {}
    -- the distance from a node to S
    ---@type table<int, float>
    local length = {}
    -- predecessors, initially all nil.
    -- elements of S will always be nil
    ---@type table<int, int>
    local pred = {}

    -- initialize source and length, pred is already initialized
    for q, _ in pairs(S) do
        source[q] = q
        length[q] = 0
    end

    -- initialize the queue
    local queue = BinaryHeap.new()
    for node, _ in pairs(S) do
        for _, edge in ipairs(self.adjacent[node]) do
            local target
            if edge.source == edge.target then
                error("source equals target")
            end
            if edge.source == node then
                target = edge.target
            else
                target = edge.source
            end
            if (S[target] ~= true) then
                queue:insert(edge.weight,
                    { t = target, d = edge.weight, s = node, p1 = node, p2 = nil })
                pred[target] = node
            elseif (node < target) then
                queue:insert(edge.weight,
                    { t = target, d = edge.weight, s = node, p1 = node, p2 = target })
            end
        end
    end

    if disjointset == nil then
        disjointset = DisjointSet.new(self.nodes)
    end

    -- are all s in the same set?
    local function s_is_one_component()
        local one_component = true
        local prev = nil
        for t, _ in pairs(S) do
            if one_component then
                if prev ~= nil then
                    if disjointset:find_idx(t) ~= disjointset:find_idx(prev) then
                        one_component = false
                    end
                end
                prev = t
            end
        end
        return one_component
    end

    local mst = {}

    -- now we run the algorithm
    while not s_is_one_component() do
        local min = queue:extract_min()
        if min == nil then
            -- we have a spanning forest
            break
        end
        local t, d, s, p1, p2 = min.value.t, min.value.d, min.value.s, min.value.p1, min.value.p2
        if source[t] == nil then
            if S[t] == true then
                error("t: " .. t .. " is in S")
            end
            source[t] = s
            length[t] = d
            pred[t] = p1
            for _, edge in ipairs(self.adjacent[t]) do
                if edge.source == t then
                    queue:insert(edge.weight + d,
                        { t = edge.target, d = edge.weight + d, s = s, p1 = edge.source, p2 = nil })
                elseif edge.target == t then
                    queue:insert(edge.weight + d,
                        { t = edge.source, d = edge.weight + d, s = s, p1 = edge.target, p2 = nil })
                end
            end
        elseif disjointset:find_idx(source[t]) == disjointset:find_idx(s) then
            -- do nothing
        else
            if S[t] == true then
                disjointset:union_idx(s, t)
                if p2 == nil then
                    table.insert(mst, Edge.new(p1, t, d))
                else
                    table.insert(mst, Edge.new(p1, p2, d))
                end
            else
                queue:insert(d + length[t],
                    { t = source[t], d = d + length[t], s = s, p1 = p1, p2 = t })
            end
        end
    end

    -- now we expand out the generalized edges above into a full generalized
    -- minimum spanning tree
    local out = {}
    for _, edge in ipairs(mst) do
        -- follow the source predecessors
        local prev = pred[edge.source]
        local current = edge.source
        local seen = { current = true }
        while prev ~= nil do
            if seen[prev] == true then
                error("Seen " .. prev .. " before")
            end
            table.insert(out, Edge.new(prev, current, 0.0))
            current = prev
            seen[current] = true
            prev = pred[current]
        end
        -- add this edge
        table.insert(out, edge)
        -- follow the target predecessors
        prev = pred[edge.target]
        current = edge.target
        local seen = { current = true }
        while prev ~= nil do
            if seen[prev] == true then
                error("Seen " .. prev .. " before")
            end
            table.insert(out, Edge.new(prev, current, 0.0))
            current = prev
            seen[current] = true
            prev = pred[current]
        end
    end

    return out
end

TestGraph = {}
function TestGraph.test_kruskal()
    local lu = require('lib.luaunit')
    local nodes = { "A", "B", "C", "D", "E", "F", "G" }
    local edge_data = { { 1, 2, 7 }, { 1, 4, 5 }, { 2, 3, 8 }, { 2, 4, 9 }, { 2, 5, 7 },
        { 3, 5, 5 }, { 4, 5, 15 }, { 4, 6, 6 }, { 5, 6, 8 }, { 5, 7, 9 }, { 6, 7, 11 } }
    local edges = {}
    for _, edge in ipairs(edge_data) do
        table.insert(edges, Edge.new(edge[1], edge[2], edge[3]))
    end
    local graph = Graph.new()
    graph.nodes = nodes
    graph.edges = edges
    local mst = graph:kruskal()

    lu.assertTableContains(mst, Edge.new(3, 5, 5))
    lu.assertTableContains(mst, Edge.new(1, 4, 5))
    lu.assertTableContains(mst, Edge.new(4, 6, 6))
    lu.assertTableContains(mst, Edge.new(2, 5, 7))
    lu.assertTableContains(mst, Edge.new(1, 2, 7))
    lu.assertTableContains(mst, Edge.new(5, 7, 9))
end

function TestGraph.test_gmst()
    local lu = require('lib.luaunit')
    -- this example is taken from the paper
    local nodes = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "z", "d", "b", "i", "e", "g" }
    local edge_data = {
        { 1,  10, 8 },
        { 1,  2,  2 },
        { 1,  6,  3 },
        { 1,  13, 3 },
        { 1,  9,  6 },

        { 2,  3,  2 },
        { 2,  6,  2 },
        { 2,  12, 1 },

        { 3,  10, 6 },
        { 3,  6,  1 },
        { 3,  11, 3 },

        { 4,  11, 1 },
        { 4,  6,  2 },
        { 4,  5,  1 },
        { 4,  7,  3 },
        { 4,  8,  4 },

        { 5,  6,  1 },
        { 5,  12, 3 },
        { 5,  14, 1 },
        { 5,  8,  3 },

        { 6,  11, 1 },
        { 6,  15, 5 },
        { 6,  12, 7 },

        { 7,  8,  1 },
        { 7,  15, 2 },
        { 7,  12, 4 },
        { 7,  14, 1 },

        { 8,  15, 2 },

        { 9,  13, 2 },
        { 9,  15, 3 },

        { 12, 14, 2 },
        { 12, 15, 4 },
        { 12, 13, 1 },

        { 13, 15, 3 }
    }
    local edges = {}
    for _, edge in ipairs(edge_data) do
        table.insert(edges, Edge.new(edge[1], edge[2], edge[3]))
    end
    local S = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
    local graph = Graph.new(nodes, edges)
    local mst = graph:generalized_minimum_spanning_forest(S)

    lu.assertEquals(#mst, 11)
    lu.assertTableContains(mst, Edge.new(3, 6, 1))
    lu.assertTableContains(mst, Edge.new(5, 6, 1))
    lu.assertTableContains(mst, Edge.new(7, 8, 1))
    lu.assertTableContains(mst, Edge.new(4, 5, 1))
    lu.assertTableContains(mst, Edge.new(7, 14, 2))
    lu.assertTableContains(mst, Edge.new(5, 14, 0))
    lu.assertTableContains(mst, Edge.new(1, 2, 2))
    lu.assertTableContains(mst, Edge.new(2, 3, 2))
    lu.assertTableContains(mst, Edge.new(9, 13, 4))
    lu.assertTableContains(mst, Edge.new(12, 13, 0))
    lu.assertTableContains(mst, Edge.new(2, 12, 0))
end
