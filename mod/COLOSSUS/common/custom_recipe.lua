-- custom recipes: replace a standard recipe with a custom one

require("common.factorio_objects.blueprint")
require("common.factory_components.template")
require("common.config.game_data")
require("common.factorio_objects.item")
require("common.factorio_objects.recipe")

require("common.utils.objects")
require("common.utils.utils")

---FlowrateModifier
---@class FlowrateModifier : BaseClass
---@field new_item string
---@field base_item string
---@field multiplier float
---@field exponent int
FlowrateModifier = InheritsFrom(nil)

---new_item takes flowrate from base_item times multiplier times
---  productivity to the power of exponent
---@param new_item string
---@param base_item string
---@param multiplier float
---@param exponent int
---@return FlowrateModifier
function FlowrateModifier.new(new_item, base_item, multiplier, exponent)
    local self = FlowrateModifier:create()
    self.new_item = new_item
    self.base_item = base_item
    self.multiplier = multiplier
    self.exponent = exponent
    return self
end

---CustomRecipe: a custom recipe
---@class CustomRecipe : BaseClass
---@field intermediates FlowrateModifier[]
---@field template Template
---@field recipe Recipe
---@field flowrate_multipliers FlowrateModifier[]
CustomRecipe = InheritsFrom(nil)

---Create a new CustomRecipe
---@param intermediates FlowrateModifier[]
---@param template Template
---@param recipe Recipe
---@param flowrate_multipliers FlowrateModifier[]
---@return CustomRecipe
function CustomRecipe.new(intermediates, template, recipe, flowrate_multipliers)
    local self = CustomRecipe:create()
    self.intermediates = intermediates
    self.template = template
    self.recipe = recipe
    self.flowrate_multipliers = flowrate_multipliers
    return self
end

CUSTOM_RECIPE_CATEGORY = "custom"

---Initialize a FullConfig object with custom recipes
---@param full_config FullConfig
function CustomRecipe_init(full_config)
    local rocket_part = full_config.game_data.recipes["rocket-part"]
    local rocket_recipe = Recipe.new(
        "impostor-silo-rocket-silo-item-satellite",
        Copy(rocket_part.inputs),
        { IngredientItem.new("space-science-pack", ItemType.ITEM) },
        0.0,
        CUSTOM_RECIPE_CATEGORY
    )
    table.insert(rocket_recipe.inputs, IngredientItem.new("satellite", ItemType.ITEM))

    full_config.custom_recipes = {
        ["electronic-circuit"] = CustomRecipe.new(
            { FlowrateModifier.new("copper-cable", "copper-plate", 2.0, 1) },
            -- Template.from_blueprint(full_config.blueprint_data.template_blueprints["clocked-electronic-circuit"], full_config),
            nil,
            Recipe.new("electronic-circuit",
                { IngredientItem.new("iron-plate", ItemType.ITEM),
                    IngredientItem.new("copper-plate", ItemType.ITEM) },
                { IngredientItem.new("electronic-circuit", ItemType.ITEM) },
                0.0,
                CUSTOM_RECIPE_CATEGORY),
            { FlowrateModifier.new("copper-plate", "iron-plate", 1.5, 1) }
        ),
        -- ["impostor-silo-rocket-silo-item-satellite"] = CustomRecipe.new(
        --     {},
        --     -- Template.from_blueprint(
        --     --     full_config.blueprint_data.template_blueprints["clocked-rocket-building-4-1"], full_config
        --     -- ),
        --     nil,
        --     rocket_recipe,
        --     { FlowrateModifier.new("satellite", "rocket-control-unit", 1.0 / 1000.0, 1) }
        -- ),
    }
end

---Modifies input_flowrates to set the flowrates correctly for the given productivity
---@param custom_recipe CustomRecipe
---@param input_flowrates table<string, float>
---@param productivity int
function Fix_flowrates_for_custom_recipe(custom_recipe, input_flowrates, productivity)
    for _, modifier in pairs(custom_recipe.flowrate_multipliers) do
        input_flowrates[modifier.new_item] =
            input_flowrates[modifier.base_item] * modifier.multiplier /
            ((1 + productivity) ^ modifier.exponent)
    end
    for _, modifier in ipairs(custom_recipe.intermediates) do
        input_flowrates[modifier.new_item] = nil
    end
end
