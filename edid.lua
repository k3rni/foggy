local edid = {
}

function a2b(str)
  return string.gsub(str, "([a-f0-9][a-f0-9])", function(m)
    return string.char(tonumber(m, 16))
  end)
end

function edid.monitor_name(edid_str)
  local edid = a2b(edid_str)
  -- We just want the descriptor blocks
  -- Source: https://en.wikipedia.org/wiki/Extended_Display_Identification_Data
  -- NOTE: these are zero-based, so we add 1 later
  local offsets = { { 54, 71 }, { 72, 89 }, { 90, 107 }, { 108, 125 } }

  for _, offset in ipairs(offsets) do
    local low = offset[1] + 1
    local high = offset[2] + 1
    local desc_type = string.byte(edid:sub(low + 3))
    if desc_type == 0xFC then -- monitor name
      local monitor_name = edid:sub(low + 5, high):gsub("[\r\n ]+$", "")
      return monitor_name
    end
  end
end

return edid
