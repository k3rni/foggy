#! /usr/bin/env lua

require('luarocks.loader')
local inspect = require('inspect')
local xrandr = {}
local xinerama = {}
local foggy = {}

function xrandr.parse_transformations(text, assume_normal)
  local rot = { normal = (assume_normal or false), left = false, right = false, inverted = false}
  local refl = { x = false, y = false }
  for word in text:gmatch("(%w+)") do
    for k, _v in pairs(rot) do
      if k == word then rot[k] = true end
    end
    for k, _v in pairs(refl) do
      if k == word:lower() then refl[k] = true end
    end
  end
  return { rotations = rot, reflections = refl }
end

function xrandr.info()
  local info = { screens = {}, outputs = {} }
  local current_output
  local pats = { 
    ['^Screen (%d+): minimum (%d+) x (%d+), current (%d+) x (%d+), maximum (%d+) x (%d+)$'] = function(matches)
      info.screens[tonumber(matches[1])] = { 
        minimum = { tonumber(matches[2]), tonumber(matches[3]) },
        resolution = { tonumber(matches[4]), tonumber(matches[5]) },
        maximum = { tonumber(matches[6]), tonumber(matches[7]) } 
      }
    end,
    ['^(%g+) connected ([%S]-)%s*(%d+)x(%d+)+(%d+)+(%d+)([^%(]*)%(([%a%s]+)%) (%d+)mm x (%d+)mm$'] = function(matches)
      current_output = {
        name = matches[1],
        resolution = { tonumber(matches[3]), tonumber(matches[4]) },
        offset = { tonumber(matches[5]), tonumber(matches[6]) },
        transformations = xrandr.parse_transformations(matches[7]),
        available_transformations = xrandr.parse_transformations(matches[8], false),
        physical_size = { tonumber(matches[9]), tonumber(matches[10]) },
        connected = true,
        primary = (matches[2] == 'primary'),
        modes = {}
      }
      info.outputs[matches[1]] = current_output
    end,
    ['^(%g+) disconnected %(([%a%s]+)%)$'] = function(matches)
      info.outputs[matches[1]] = {
        available_transformations = xrandr.parse_transformations(matches[2], false),
        connected = false
      }
    end,
    ['^%s+(%d+)x(%d+)%s+(.+)$'] = function(matches)
      local w = tonumber(matches[1])
      local h = tonumber(matches[2])
      for refresh, symbols in matches[3]:gmatch('([%d.]+)(..)') do
        local mode = { w, h, tonumber(refresh) }
        local modes = current_output.modes
        modes[#modes + 1] = mode
        if symbols:find('%*') then
          current_output.default_mode = mode
        elseif symbols:find('%+') then
          current_output.current_mode = mode
        end
      end
    end
  }

  local fp = io.popen('xrandr --query', 'r')
  for line in fp:lines() do
    for pat, func in pairs(pats) do
      local res 
      res = {line:find(pat)}
      if #res > 0 then
        table.remove(res, 1)
        table.remove(res, 1)
        func(res)
        break
      end
    end
  end
  return info
end

function xinerama.info()
  local info = { heads = {} }
  local pats = {
    ['^%s+head #(%d+): (%d+)x(%d+) @ (%d+),(%d+)$'] = function(matches)
      info.heads[matches[1]] = { 
        resolution = { tonumber(matches[2]), tonumber(matches[3]) },
        offset = { tonumber(matches[4]), tonumber(matches[5]) }
      }
    end
  }
  local fp = io.popen('xdpyinfo -ext XINERAMA')
  for line in fp:lines() do
    for pat, func in pairs(pats) do
      local res 
      res = {line:find(pat)}
      if #res > 0 then
        table.remove(res, 1)
        table.remove(res, 1)
        func(res)
        break
      end
    end
  end
  return info
end

function foggy.screen_menu(current_screen)
  local xinerama = xinerama.info()
  local xrandr = xrandr.info()
  -- awesome always uses xinerama screen order, but 1-numbered
  local xs = xinerama.heads[tostring(current_screen - 1)]
  -- horribly wrong on advanced setups:
  -- the current xrandr output is the one that matches current screen's resolution + offset
  local co = nil
  for name, output in pairs(xrandr.outputs) do
    if output.connected then
      if (output.resolution[0] == xs.resolution[0]) and (output.resolution[1] == xs.resolution[1])
        and (output.offset[0] == xs.offset[0] and output.offset[1] == xs.offset[1]) then
        co = output 
      end
    end
  end

  local menu = {}
  -- TODO
  -- 1. submenu resolutions
  -- 2. submenu transformacji
  -- 3. off
  -- 4. pozostałe outputy
end

function foggy.build_menu(screen_count, current_screen)

end

local v = foggy.build_menu(3, 1)
print(inspect(v))
