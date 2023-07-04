require("common.data_structures.graph")
require("common.factorio_objects.blueprint")
require("common.bus.post_processing")
require("common.optimizer")

require("cli.initialize")

OS = require("os")

local lu = require('lib.luaunit')

local function test_blueprint(blueprint, processor, optimizers)
    if processor == nil then
        processor = PostProcessing.connect_electrical_grids
    end
    if optimizers == nil then
        optimizers = {}
    end
    local config = Config.new()
    local full_config = Initialize_game_data(config)
    ---@type Blueprint
    local factory_object = Blueprint:from_string(blueprint, true)
    local primitive = factory_object:to_primitive(full_config.game_data.size_data)


    local output_blueprint = Primitives_to_blueprint({ primitive.primitive }, {}, optimizers, { processor }, full_config)

    local data = output_blueprint.entities

    -- smoke test this
    local blueprint_string = output_blueprint:export()
    -- print(blueprint_string)
    return data
end

local function sum_neighbours(data)
    local out = 0
    for _, entity in ipairs(data) do
        if entity.neighbours ~= nil then
            local neighbour_set = {}
            for _, neighbour in ipairs(entity.neighbours) do
                neighbour_set[neighbour] = true
            end
            for _, _ in pairs(neighbour_set) do
                out = out + 1
            end
        end
    end
    return out
end

local function sum_wires(data)
    local out = 0
    for _, entity in ipairs(data) do
        if entity.connections ~= nil and entity.connections[1] ~= nil and entity.connections[1].green ~= nil then
            local neighbour_set = {}
            for _, neighbour in ipairs(entity.connections[1].green) do
                neighbour_set[neighbour.entity_id] = true
            end
            for _, _ in pairs(neighbour_set) do
                out = out + 1
            end
        end
    end
    return out
end

TestMST = {}
function TestMST.test1()
    local blueprint =
    "0eNqd1NtqhDAQBuB3metkMfHsqyyleBgkoIloLJUl715NqxZqumRvhIDz+U/i5AFVN+MwCqmheMAky4FqRdtRNNv6EwpGYFmfhkBZTaqbNdLtrUHIFgo9zkhA1EpOUNzXetHKstsq9TIgFCA09kBAlv226rERc0+xw1qPoqaD6hBWWcgGt0+ZNwIotdACvz27WN7l3Fc42iz/SQQGNa3FSv5kp9EttvFpGN9iY8gfkXuK2Q7y/BoMfSOGh5hei5GvyNKDDK/J2JPkz8DEN+MZkV+LqXfXbCeZYyOzl4/GJeav/j0ukAXebSeHyRym79ScYuAQuXfKYysdc8h85ybYwcQB+o4N489E36mh50Y6xOTFpu25rHelvV2LX1c4gQ8cJ1vAMxalOU+TnAdZyI35AtKe7oY="
    local data = test_blueprint(blueprint)
    lu.assertEquals(#data, 16)
    lu.assertEquals(sum_neighbours(data), (16 - 1) * 2)
end

function TestMST.test2()
    local blueprint =
    "0eNqd1V2KgzAQAOC7zHNcTGL9u0pZFm2DDMQoGpctxbtvTLWUNmmJTxJwPmcyZnKFWk6iH1BpKK8wqqqPdBc1A56X9R+UnBK4mEc2E6jqsZOTFtHyXo+qgVIPkyCAp06NUB6NgI2q5BKrL72AElCLFgioql1WNTaRkOKkBzxFfScFGBbVWZgv0Zl8jB+netSVxk49BLL5m4BQGjWKWxZ2cflRU1uLwcj3+FaccWqfUiDQdyNa9FZz/HWwRZvnvCT1xLFAjvL3HneV96JwSzAXkAQmxNI1odSd0CG0wGT1creXvun/K8YsRWOXlO3sJGXuzPLQnfsEFqFbdwe5G6RxoLj1lnqaQene7npFtvf/84o8NMcVZIkHDD4iW9Hs4BFDD8kGcs8UoGlozfmWYuERQ08Ljz+JoeeFbo3hvsYUIbOBFSvmHMvx3g3kdg6aS8ReNuXDnUhAVrWQCzlJjavzK4bRMiynSVawLC1YnHMzm/8B2yFmpw=="
    local data = test_blueprint(blueprint)
    lu.assertEquals(#data, 20)
    lu.assertEquals(sum_neighbours(data), (20 - 1) * 2 + 2) -- 2 for the large pole connections
end

function TestMST.test3()
    local blueprint =
    "0eNqdlduKgzAQht9lruNiEqvGVyll0Tq4AY2icdlSfPeNqZbSxpZ4FYLON/8cMnOFoh6x66XSkF1hUHkX6DaoelnO9z/IOCVwMUcyEciLoa1HjcH8XydVBZnuRyQgz60aIDsagqxUXs+2+tIhZCA1NkBA5c18K2QVYI1n3ctz0LU1gsFKVaLxRCfy0X4Yi0HnWrbqwZBNJwKotNQSbyrs5fKtxqbA3pDv9g2WcmyeJBDo2kFa6C3m8OtggzbnNIt6wjFPHOXvedwV3guFWwRzASJPQSxeBMVuQQffAKOFl7p58Zv6v8KYRdHQRUp2VpIyt7LUN3OfgMI3dXegaRLT0gpl9VO0Yz83Mg0JpSeHF/PBz81acJq+ehFbTujeNnB5MZKF0wvb27x0o9so99W9AFm0AfR+X2si2GGD6PvCViDfGCE09o05XSWKDaLvU+PhJ6LvY6NrYfhWYYTPYGFigTlnerg3gdwOUbOB7KbKHhYqgTov0CwzMOtRGRqWt81K4Bf7wbJYSqNEsCQWLEy5me7/Ba97lg=="
    local data = test_blueprint(blueprint)
    lu.assertEquals(#data, 20)
    lu.assertEquals(sum_neighbours(data), (20 - 1) * 2 + 2 + 2) -- +2 for the large pole connections, +2 for existing connection
end

function TestMST.test_gmst1()
    local blueprint =
    "0eNqllctugzAQRf9l1qTCD2xg28+oqggSK7IEBoGpGkX8ew1VACV20aQ7jDWHO9x53KCsBtV22ljIb6BPjekh/7hBry+mqKZ39toqyEFbVUMEpqinU6kvB1Wpk+306dA2lYIxAm3O6htyMka78f1Q9rawujGbQDp+RqCM1VarXxXz4Xo0Q12qzpGX+Fqd9VA/SIigbXo9Q913HZCJtySCK+SHlLvHcRL2gKRIJM92kcyX5bO27I7xQvgKqYuq2pMlNplSv6wEmamgKzL2IwUSmcQLkqV+pPyjxJ7NSO806WOlr5cL4355GTbjfSSJsSW4YbIAE9spfDWbBpwh9HW3g0z2elEGmRxru1yZgd4h6ObZ5E4CTIFrcZYsSBJKXWJtX2WSwDQj2C5K+MqUASa2jTbjLcSk6DZabScB2ynBTCOx4JgXRv/xI+cB7LbjvEXzzdKOoCpK5RYtvDfGOJ6LP1rVTzdfqutnHE0JlxmVIqNxyug4/gBhNpZY"
    local data = test_blueprint(blueprint, PostProcessing.connect_small_electic_poles)
    lu.assertEquals(#data, 22)
    lu.assertEquals(sum_neighbours(data), 16)
end

function TestMST.test_gmst2()
    local blueprint =
    "0eNql1u9ugjAQAPB3uc+40D9Q4FXMYkAb06QUAmWZMbz7KkYg2s4d+yaa/rzjetdeodKDbDtlLBRXUMfG9FDsr9Crsyn17Tt7aSUUoKysIQJT1renSp13Usuj7dRx1zZawhiBMif5DQUZo7fr+6HqbWlVY1YL6fgZgTRWWSXvUUwPl4MZ6kp2Tp7X1/KkhvophAjaplcT6v7XgSz9SCK4QLHLuPs43gJ7IimS5PlbkvmyfI0tfzBehC9IXWqNyZT5w0pwYroSqV9Mke8upQsZ+0mBJJN4JlnmJ7NfNu1rebOHJnxWvn0DMu4Pj8TYlP9gYhuFr8zA9iHoTlmqTQOlIWx7uYMm374rg2aCrbtYzEDzEHT3rHInAVMgp0YykySUeoYt+xImCQxIgm2jhC+mCMxxbBut5lvQRLfRUnYSKDulmHGUzhzzYuwfLzIwgSnffE7cSXeGT2d9sbpaRKDLSrrrALgLhnGeW3+wsrfU/fQlu37yaEa4yKlIcxpnjI7jDyOxzBA="
    local data = test_blueprint(blueprint, PostProcessing.connect_small_electic_poles)
    lu.assertEquals(#data, 24)
    lu.assertEquals(sum_neighbours(data), 30)
end

function TestMST.test_gmst3()
    local blueprint =
    "0eNql1e9ugyAQAPB3uc+0kT+i+CrLsmhLGhJEo7isaXz3qU3FdDBH9xETft5xHHeDSg+y7ZSxUNxAnRrTQ/F2g15dTKnnb/baSihAWVkDAlPW86pSl4PU8mQ7dTq0jZYwIlDmLL+gwCPa3d8PVW9Lqxqz2UjGdwTSWGWVvEexLK4fZqgr2U2y21+XWj9FgKBterWY028nj4pjiuAKxSFn+TEd57ieRLKKtTyrod4luSO5n6SRJBO7JPOdmyfdB+NF0rjD49SFxfxh8chMOXFk4iezSDJNVpIGSpz/cml/FiN/aJnPEq9fFxo4RJzEpvwHE8fewY1JA2ZsqzBXbRIoDaavlztostgaZc4kATOyd2i6klgEyNjmYS51HHgmcHT3MGdmATOPbXK+b4qYluQrR70vePKPpAOvEIkcNNucF3KaY8u8KzbjFYEuK6nnOAdt50lrJvT+kn/Krl84kmOWCZJxQZKcknH8Br5teqU="
    local data = test_blueprint(blueprint, PostProcessing.connect_small_electic_poles)
    lu.assertEquals(#data, 21)
    lu.assertEquals(sum_neighbours(data), 24)
end

function TestMST.test_wire1()
    local blueprint =
    "0eNqVk9tuhCAQht9lrmGjqHh4lc2mUXeyJUEwgG2N4d0LNulp6abeMQPzfZD8bDDIBWcjlINuAzFqZaE7b2DFTfUy9tw6I3QgHE5AQPVTrJzplZ21cXRA6cATEOqKb9Dl/kIAlRNO4AdpL9YntUwDmnDgLwaBWdswplW0BhTNs+pUEVjDssnrU+U9ucOxT9yEV7FMFCWOzoiRzlpiEpr9hAYAitvzoBcTL1xcEpbiqKUtviT8XsJImdKURzUNf6gpSJXSVEc1dftQUxKe0vDDGvZQk3xL/f848fZXmkJS91R33z4BAdmH+dgLFPoqDFKHNm68oLE7jjV5Wbes5i3LmoJ5/w7pCBBH"
    local data = test_blueprint(blueprint, PostProcessing.connect_belts)
    lu.assertEquals(#data, 7)
    lu.assertEquals(sum_wires(data), 12)
end

function TestMST.underground_pipes()
    local blueprint =
    "0eNqV01+LwyAMAPDvkmc7qq2286scx7GtYQRWFWuPK8XvfnZ9GewP5M1I/CUEs8L5NmOI5BLYFeji3QT2a4WJru502+7SEhAsUMIRBLjTuEWBAlbJV9foZzdAFkBuwD+wMn8LQJcoEe7SPVh+3DyeMZaEd4aA4KfyzLutaqEq2cqDFrCUY1+bgy5VBop42XNMFk+4YuCN+YCrF3jDwTWz85aD10xcc3DJHIth4Eoz8Y6Dt8yx9By8/th5+fT3BbEP+yTgF+O0J/Sy7Y6qM0dV943K+R+vUhvT"
    local data = test_blueprint(blueprint, PostProcessing.connect_belts, { Optimizations.optimize_underground_pipes })
    lu.assertEquals(#data, 4)
    blueprint =
    "0eNqV09uKwyAQBuB3mWtT0pzjq5RlSZohDCSjGLNsKL57TUJhYVvQG2HQ+fwZ9AH9tKI2xBbkAxbudGJVMhoa9voX5FXA5lcnoOsXNa0Wk/2UJh5BWrOiALorXkDefD+N3E17p900ggSyOIMA7ua90qTx5NXKA3iTeMD9EvclANmSJTylo9i+eZ17NEeK94YArRbfpviV91IeidNL6f2BDN7P3cqJf2wWzKaf2OwNmwezbQxbhA8hjZlCGe7mMXmrcLeIyVuHu3VM3ibcbT7n9S/5ePXyz9cS8INmOS9urkXdZnXVZmmTZ849AYRsJXw="
    data = test_blueprint(blueprint, PostProcessing.connect_belts, { Optimizations.optimize_underground_pipes })
    lu.assertEquals(#data, 6)
    blueprint =
    "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"
    data = test_blueprint(blueprint, PostProcessing.connect_belts, { Optimizations.optimize_underground_pipes })
end

function TestMST.underground_pipes2()
    -- this test has 6 pipe-to-undergrounds.  If it results in two then there is an error, since the furthest ones are too far away to join
    local blueprint =
    "0eNqV0ktqxDAMBuC7aO2UyWOSjK9SSkkmIggS2fhRGgbfvXbSRaEz4GxshKXP/0IPGBeP2hA7kA+wPOjCqWI2NKX6G2QpYItnEDCMVi3eYZG6NPEM0hmPAuiu2IJ8j/M087CkSbdpBAnkcAUBPKyp0qTx4JXnCaJJPGH6JHwIQHbkCA9pL7ZP9uuIZk/x3BCglY1jin/zXt6ue+J4R38ig/fjtQ3iH1tls80Zts5m61ds9YRtstn+TNprNtudSdtms2X52o17se+Q/LOoAr7Q2KOhL5vuVnXtrbr0dRXCD6Zg6+c="
    local data = test_blueprint(blueprint, PostProcessing.connect_belts, { Optimizations.optimize_underground_pipes })
    lu.assertEquals(#data, 4)
end

---@diagnostic disable-next-line: undefined-field
if _G.ALL_TESTS == nil then
    OS.exit(lu.LuaUnit.run())
end
