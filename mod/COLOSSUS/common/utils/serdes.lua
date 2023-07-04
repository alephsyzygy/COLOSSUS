-- serdes: serialize/deserialize - convert between formats

Zlib = require("lib.zlibdeflate")
Base64 = require("lib.base64")
JSON = require("lib.JSON")
-- IO = require("io")
IO = nil

require("common.utils.utils")
require("common.utils.objects")

---Serdes objects can be serialized and deserialized
---@class Serdes : BaseClass
---@field export_name string
Serdes = InheritsFrom(nil)
Serdes.export_name = "error"

---Create a new Serdes
---@param name string
---@param data table
---@return Serdes
function Serdes.new(name, data)
    local self = Serdes:create()
    for key, value in pairs(data) do
        self[key] = value
    end
    return self
end

---export this to b64 string
---@param compress? boolean compress this defaults to true
---@param level? int compression level defaults to 9
---@return string
function Serdes:export(compress, level)
    if level == nil then
        level = 9
    end
    if compress == nil then
        compress = true
    end
    if self.export_name == nil then
        assert(false, "Export name not given")
    end
    local json_blueprint = JSON:encode { [self.export_name] = self:to_dict() }
    if compress then
        local compressed_blueprint = Zlib.Zlib.Compress(json_blueprint, { level = level })
        local b64_blueprint = Base64.encode(compressed_blueprint)
        return "0" .. b64_blueprint
    else
        return json_blueprint
    end
end

---should normally be overriden
---@return table
function Serdes:to_dict()
    return self
end

---load this object from a string
---@generic T : Serdes
---@param class `T`
---@param data any
---@param versioned? boolean is this data versioned (first byte)
---@param use_export_name? boolean use the internal export_name
---@return T
function Serdes.from_string(class, data, versioned, use_export_name)
    local string_data = data
    if versioned == nil or versioned == true then
        string_data = data:sub(2)
    end

    local b64_decode = Base64.decode(string_data)
    local decompressed_blueprint = Zlib.Zlib.Decompress(b64_decode)
    local json_data = JSON:decode(decompressed_blueprint)
    if json_data ~= nil then
        local internal_data = json_data
        if versioned == nil or versioned == true or use_export_name == true then
            internal_data = json_data[class.export_name]
        end
        return class:from_obj(internal_data)
    end
    error("json_data is nil")
end

---load this object from a file
-- ---@generic T : Serdes
-- ---@param class `T` class to load this as
-- ---@param filename string
-- ---@param versioned? boolean is this versioned (first byte) default true
-- ---@return T
-- function Serdes.from_file(class, filename, versioned)
--     local file = assert(IO.open(filename, "r"))
--     local data = file:read("*a")
--     return class:from_string(data, versioned)
-- end

---should be overridden
---@generic T : Serdes
---@param class `T`
---@param data any
---@return T
function Serdes.from_obj(class, data)
    return class.new("serdes", data)
end

-- local test_blueprint =
-- "0eNqVkdFqxCAQRf9lnrU0sdu0/koJxWSH7ICOoqY0LP57Nc1DIaXQBx0ueM+9jHeY7IohEmfQd0hsgsxeLpGuTX+C7gRs9S4CzJS8XTPK9ioQL6BzXFEAzZ4T6Lfqp4WNbc68BQQNlNGBADauKZMSuslWq3RmvhGjVFDJxFdsUWUUgJwpE37zdrG98+omjHuXg5ScsVaixTlHmmXwFmtM8Kl6PR/V5ePDZW9fZ01hpOU2+TU2thqLOPH7v5ueArqDX2f5Baf+V1cdNHVu241tNfsy9Y8fE/CBMe2E/qV7Gl774flSTzeU8gXeaJyD"

-- local test = Serdes:from_string(test_blueprint)
-- print(Dump(test))
-- print(test:export())

-- test_blueprint =
-- "0eJyVkeFqAyEMgN8lf6dl3rXr5quMMbxruAY0inqj5fDdp71uDG4M9kOMhHx+SRYY7IwhEmfQC5gheTtnlIlNCMQT6BxnFICcKRMm0K/L+ri+8+wGjKCVADYOQUNyxlqJFsccaZTBW4SaRJrOg59jq+7fBASfKsxz+/ECWj7uDgKuoOtditjwu2++SQndYKuXdGY8E6PsYcNTd5z6Hdf/R1dtdfs7vm/4mqbR8zoX4hNebvNINLGxreBv83wNLUsZHaywFukfS6msugqZvZwinb46XPsrAj4wpptat3tW++NLd3w61NPhg9qX8vnRLZ1w"

-- local test_blueprint2 = test_blueprint:sub(2)

-- local data = Base64.decode(test_blueprint2)
-- -- print(Dump(data))

-- local decompressed = Zlib.Zlib.Decompress(data)
-- -- print(Dump(decompressed))
-- local json_data = JSON:decode(decompressed)
-- print(Dump(json_data))

-- -- now reverse all this

-- local encoded = JSON:encode(json_data)
-- local compressed = Zlib.Zlib.Compress(encoded)
-- local base64 = Base64.encode(compressed)
-- local final_blueprint = "0" .. base64
-- print(final_blueprint)
