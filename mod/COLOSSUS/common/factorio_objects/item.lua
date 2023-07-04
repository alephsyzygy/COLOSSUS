-- represents items

require("common.utils.objects")

---ItemType: either item or fluid
---@enum ItemType
ItemType = {
    ITEM = "item",
    FLUID = "fluid",
    FUEL = "fuel",
}

---Item: represents an item
---@class Item : BaseClass
---@field name string
---@field item_type ItemType
Item = InheritsFrom(nil)

---Create a new Item
---@param name string
---@param item_type ItemType
---@return Item
function Item.new(name, item_type)
    local self = Item:create()
    self.name = name
    self.item_type = item_type
    return self
end

--- IngredientItem: An item that is part of an ingredient
--- has some extra fields.
---@class IngredientItem : Item
---@field fluidbox_index int|nil
---@field amount int
---@field amount_min int
---@field amount_max int
---@field probability float
---@field catalyst_amount int
IngredientItem = InheritsFrom(nil)

---Create a new IngredientItem
---@param name string
---@param item_type ItemType
---@param fluidbox_index? int
---@return IngredientItem
function IngredientItem.new(name, item_type, fluidbox_index)
    local self = IngredientItem:create()
    self.name = name
    self.item_type = item_type
    self.fluidbox_index = fluidbox_index
    self.probability = 1
    self.catalyst_amount = 0
    self.amount = 0
    self.amount_max = 0
    self.amount_min = 0
    return self
end

---Create an IngredientItem from a JSON object
---@param item any
---@param fluidbox_index_default? int
---@return IngredientItem
function IngredientItem.from_json(item, fluidbox_index_default)
    local fluidbox_index = nil
    if item["type"] == ItemType.FLUID then
        fluidbox_index = item["fluidbox_index"]
    end
    if fluidbox_index == nil then
        fluidbox_index = fluidbox_index_default
    end
    local ingredient = IngredientItem.new(item["name"], item["type"], fluidbox_index)
    ingredient.probability = item["probability"] or 1
    ingredient.amount = item["amount"] or 0
    ingredient.amount_max = item["amount_max"] or 0
    ingredient.amount_min = item["amount_min"] or 0
    ingredient.catalyst_amount = item["catalyst_amount"] or 0
    return ingredient
end

---Get the average amount of this ingredient
---@return float
function IngredientItem:get_average_amount()
    if self.amount ~= 0 then
        return self.amount * self.probability
    else
        return (self.amount_max + self.amount_min) * self.probability / 2.0
    end
end

---Return the amount that can be modified by productivity
---@return float
function IngredientItem:get_productive_amount()
    local amount = self.amount
    if amount == 0 then
        amount = (self.amount_max + self.amount_min) / 2.0
    end
    if amount > self.catalyst_amount then
        return (amount - self.catalyst_amount) * self.probability
    else
        return amount * self.probability
    end
end

local json = { type = "fluid", name = "test", fluidbox_index = 3 }
assert(IngredientItem.from_json(json, 0).fluidbox_index == 3)
