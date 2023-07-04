SpecialSignal = {}

---convert a signal to a number
---returns nil if it is not of the form signal-#
---@param signal string
---@return number?
function SpecialSignal.to_number(signal)
    if string.find(signal, "signal-", 0) ~= nil then
        return tonumber(string.sub(signal, 8, 9))
    end
    return nil
end

assert(SpecialSignal.to_number("signal-9") == 9)
assert(SpecialSignal.to_number("signal-0") == 0)
assert(SpecialSignal.to_number("signal-X") == nil)
assert(SpecialSignal.to_number("signal-") == nil)
assert(SpecialSignal.to_number("other") == nil)
