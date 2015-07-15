local rawget = rawget
local util = {}

-- Looted from lain
function util.wrequire(table, key)
    local module = rawget(table, key)
    return module or require(table._NAME .. '.' .. key)
end

return util
