require("factorio.dump_data")
require("factorio.main")

-- register remote interfaces
remote.add_interface("COLOSSUS", {
    dump_data = Dump_data,
    main = Main
})

local function command_dump_data(event)
    remote.call("COLOSSUS", "dump_data", event.player_index)
end

commands.add_command("COLOSSUS_dump_data", "/COLOSSUS_dump_data will dump necessary info to your script-output directory",
    command_dump_data)
