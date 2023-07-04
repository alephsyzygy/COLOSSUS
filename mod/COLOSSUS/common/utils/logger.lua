--- various logging stuff

require("common.utils.objects")

---@class Logger : BaseClass
---@field debug_messages string[]
---@field info_messages string[]
---@field warn_messages string[]
---@field error_messages string[]
---@field structured table<string,any>
---@field warn function
---@field info function
---@field debug function
---@field error function
Logger = InheritsFrom(nil)

local function init_log_type(object, field_name)
    local message_field = field_name .. "_messages"
    object[message_field] = {}
    object[field_name] = function(self, message, ...)
        table.insert(self[message_field], string.format(message, ...))
    end
end

function Logger.new()
    local self = Logger:create()
    init_log_type(self, "debug")
    init_log_type(self, "info")
    init_log_type(self, "warn")
    init_log_type(self, "error")
    self.structured = {}
    return self
end

function Logger:log_structured_data(class, data)
    if self.structured[class] == nil then
        self.structured[class] = {}
    end
    table.insert(self.structured[class], data)
end
