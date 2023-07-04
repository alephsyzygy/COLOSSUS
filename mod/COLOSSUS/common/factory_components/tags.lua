--- All the tags used in this mod

-- The idea is that whenever we look for a tag we use this, to ensure that all tags are properly recorded

-- we may want more metadata about the tags later
local function create(name, category)
    if category == nil then category = "metadata" end
    local function get_tag(entity)
        return entity[name]
    end
    local function set_tag(entity, tag)
        entity[name] = tag
    end
    local function get_tag_array(entity)
        return Split_string(entity[name])
    end
    return {
        name = name,
        get_tag = get_tag,
        set_tag = set_tag,
        get_tag_array = get_tag_array,
        description = { "colossus.tags." .. category .. "." .. name }
    }
end

local function create_entity(name, category)
    if category == nil then category = "entity" end
    local function get_tag(entity)
        return entity.tags[name]
    end
    local function set_tag(entity, tag)
        entity.tags[name] = tag
    end
    local function get_tag_array(entity)
        return Split_string(entity.tags[name])
    end
    return {
        name = name,
        get_tag = get_tag,
        set_tag = set_tag,
        get_tag_array = get_tag_array,
        description = { "colossus.tags." .. category .. "." .. name }
    }
end

local function create_region(x) return create_entity(x, "region") end

DELETE_TAG = "delete"

MetadataTags = {
    ["crafting-categories"] = create("crafting-categories"),
    priority = create("priority"),
    ["custom-recipe"] = create("custom-recipe"),
    ["fluid-inputs"] = create("fluid-inputs"),
    ["item-inputs"] = create("item-inputs"),
    ["fluid-outputs"] = create("fluid-outputs"),
    ["item-outputs"] = create("item-outputs"),
    buffer = create("buffer"), -- fluid or item
    machines = create("machines"),
    ["machine-heights"] = create("machine-heights"),
    ["machine-widths"] = create("machine-widths"),
    mods = create("mods"),
    ["envelope-up"] = create("envelope-up"),
    ["envelope-down"] = create("envelope-down"),
    ["machine-entity"] = create("machine-entity"),
    ["item-loops"] = create("item-loops"),
    ["fluid-loops"] = create("fluid-loops"),
    ["uses-logistic-network"] = create("uses-logistic-network"),
    -- TODO custom recipe metadata
}
RowTags = {
    output = create("output", "row"),
    ["port-number"] = create("port-number", "row"),
    type = create("type", "row"),
    input = create("input", "row"),
    priority = create("priority", "row"),
    name = create("name", "row"),
    item = create("item", "row"),
}
ColTags = {
    machine = create("machine", "col"),
    ["machine-end"] = create("machine-end", "col"),
}
EntityTags = {
    ["beacon-number"] = create_entity("beacon-number"),
    clocked = create_entity("clocked"),
    ["clocked-reset"] = create_entity("clocked-reset"),
    ["clocked-start"] = create_entity("clocked-start"),
    ["clocked-red-wire"] = create_entity("clocked-red-wire"),
    ["unclocked-remove-red-wire"] = create_entity("unclocked-remove-red-wire"),
    ["clocked-fluid"] = create_entity("clocked-fluid"),
    beacon = create_entity("beacon"),
    ["belt-end"] = create_entity("belt-end"),
    [DELETE_TAG] = create_entity(DELETE_TAG),
    blocker = create_entity("blocker"),
    reader = create_entity("reader"),
    ["port-name"] = create_entity("port-name"),
    ["bulk-inserter"] = create_entity("bulk-inserter"),                 -- TODO for use with item buffers
    ["splitter-right-filter"] = create_entity("splitter-right-filter"), -- if a port with this number exists, set the right filter to that item.
    -- otherwise replace with a belt on the left part of the splitter
    ["splitter-left-filter"] = create_entity("splitter-left-filter"),
    machine = create_entity("machine"),
    parent = create_entity("parent")
}
RegionTags = {
    tile = create_region("tile"),
    recipe = create_region("recipe"),
    clocked = create_region("clocked"),
    ["clocked-red-wire"] = create_region("clocked-red-wire"),
    lane = create_region("lane"),
}
