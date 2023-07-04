--- Write data to the clipboard
-- IO = require("io")
IO = nil
-- OS = require("os")
OS = nil
CLIPBOARD_FILENAME = "clip.txt"

---Copy some text to the clipboard
---Note: creates a file called "clip.txt"
---@param text string text to copy to clipboard
function Copy_to_clipboard(text, keep_file)
    if keep_file == nil then
        keep_file = false
    end
    local file = assert(IO.open(CLIPBOARD_FILENAME, "w"))
    file:write(text)
    file:close()
    local command = "clip < " .. CLIPBOARD_FILENAME
    OS.execute(command)
    if not keep_file then
        OS.remove(CLIPBOARD_FILENAME)
    end
end
