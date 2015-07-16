local awful = require('awful')
local setmetatable = setmetatable
local cmd = awful.util.spawn_with_shell

local xrandr = { 
  _NAME = "foggy.xrandr",
}

function printf(format, ...)
  print(string.format(format, ...))
end

function xrandr.parse_transformations(text, assume_normal)
  local rot = { normal = (assume_normal or false), left = false, right = false, inverted = false}
  local refl = { x = false, y = false, normal = (assume_normal or false) }
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
  local last_property
  local pats = { 
    ['^Screen (%d+): minimum (%d+) x (%d+), current (%d+) x (%d+), maximum (%d+) x (%d+)$'] = function(matches)
      -- X screens. Usually just one, when used with Xinerama
      info.screens[tonumber(matches[1])] = { 
        minimum = { tonumber(matches[2]), tonumber(matches[3]) },
        resolution = { tonumber(matches[4]), tonumber(matches[5]) },
        maximum = { tonumber(matches[6]), tonumber(matches[7]) } 
      }
    end,
    ['^([%a%d]+) connected ([%S]-)%s*(%d+)x(%d+)+(%d+)+(%d+)(%s*)%(([%a%s]+)%) (%d+)mm x (%d+)mm$'] = function(matches)
      -- Match connected and active outputs
      current_output = {
        name = matches[1],

        resolution = { tonumber(matches[3]), tonumber(matches[4]) },
        offset = { tonumber(matches[5]), tonumber(matches[6]) },
        transformations = xrandr.parse_transformations(matches[7]),
        available_transformations = xrandr.parse_transformations(matches[8], false),
        physical_size = { tonumber(matches[9]), tonumber(matches[10]) },
        connected = true,
        on = true,
        primary = (matches[2] == 'primary'),
        modes = {},
        properties = {}
      }
      info.outputs[matches[1]] = current_output
    end,
    ['^([%a%d]+) connected %(([%a%s]+)%)$'] = function(matches)
      -- Match outputs that are connected but disabled
      current_output = {
        name = matches[1],
        available_transformations = xrandr.parse_transformations(matches[2], false),
        transformations = xrandr.parse_transformations(''),
        modes = {},
        connected = true,
        on = false
      }
      info.outputs[matches[1]] = current_output
    end,
    ['^([%a%d]+) disconnected %(([%a%s]+)%)$'] = function(matches)
      -- Match disconnected outputs
      info.outputs[matches[1]] = {
        available_transformations = xrandr.parse_transformations(matches[2], false),
        connected = false, on = false
      }
    end,
    ['^%s%s%s(%d+)x(%d+)%s+(.+)$'] = function(matches)
      -- Match modelines. Only care about resolution and refresh.
      local w = tonumber(matches[1])
      local h = tonumber(matches[2])
      for refresh, symbols in matches[3]:gmatch('([%d.]+)(..)') do
        local mode = { w, h, tonumber(refresh) }
        local modes = current_output.modes
        modes[#modes + 1] = mode
        if symbols:find('%*') then
          current_output.current_mode = mode
        end
        if symbols:find('%+') then
          current_output.default_mode = mode
        end
      end
    end,
    ['^\t(.+):%s+(.+)%s+$'] = function(matches)
      -- Match properties, which are rather freeform
      last_property = matches[1]
      local properties = current_output.properties
      properties[last_property] = { value = matches[2] }
    end,
    ['^\t\tsupported:%s+(.+)$'] = function(matches)
      -- Match supported property values, freeform but comma separated
      -- Won't match EDID dump block
      if last_property ~= nil then 
        local prop = current_output.properties[last_property]
        local supported = { }
        for word in matches[1]:gmatch('([^,]+),?%s?') do
          supported[#supported + 1] = word
        end
        prop.supported = supported
      end
    end,
    ['^\t\trange:%s+%((%d+), (%d+)%)$'] = function(matches)
      -- Match ranged property values, e.g. brightness
      if last_property ~= nil then
        local prop = current_output.properties[last_property]
        local range = { tonumber(matches[1]), tonumber(matches[2]) }
        prop.range = range
      end
    end
  }

  local fp = io.popen('xrandr --query --prop', 'r')
  for line in fp:lines() do
    print(line)
    for pat, func in pairs(pats) do
      local res 
      res = {line:find(pat)}
      if #res > 0 then
        printf('Matched %s', pat)
        table.remove(res, 1)
        table.remove(res, 1)
        func(res)
        break
      end
    end
  end
  return info
end

function xrandr.set_mode(name, mode)
  cmd(string.format('xrandr --output %s --mode %dx%d --rate %d', name, mode[1], mode[2], mode[3]))
end

function xrandr.auto_mode(name)
  cmd(string.format('xrandr --output %s --auto', name))
end

function xrandr.off(name)
  cmd(string.format('xrandr --output %s --off', name))
end

function xrandr.set_rotate(name, rot)
  cmd(string.format('xrandr --output %s --rotate %s', name, rot))
end

function xrandr.set_reflect(name, refl)
  cmd(string.format('xrandr --output %s --reflect %s', name, refl))
end

function xrandr.set_relative_pos(name, relation, other)
  cmd(string.format('xrandr --output %s --%s %s', name, relation, other))
end

function xrandr.set_primary(name)
  cmd(string.format('xrandr --output %s --primary', name))
end

function xrandr.set_property(name, prop, value)
  cmd(string.format("xrandr --display %s --set %s '%s'", name, prop, value))
end

function xrandr.identify_outputs()
  local wibox = require("wibox")
  local naughty = require('naughty')
  for name, output in pairs(xrandr.info().outputs) do
    if output.connected and output.on then
      local textbox = wibox.widget.textbox()
      local box = wibox({fg = '#ffffff', bg = '#77777700'})
      local layout = wibox.layout.fixed.horizontal()
      textbox:set_font('sans 36')
      textbox:set_markup(name)
      layout:add(textbox)
      box:set_widget(layout)
      local w, h = textbox:fit(-1, -1)
      local xoff = (output.resolution[1] - w) / 2
      local yoff = (output.resolution[2] - h) / 2
      box:geometry({x = output.offset[1] + xoff, y = output.offset[2] + yoff, width=w, height=h})

      box.ontop = true
      box.visible = true
      local tm = timer({timeout=3})
      tm:connect_signal('timeout', function()
        box.visible = false
        tm:stop()
        box = nil
        tm = nil
      end)
      tm:start()
    end
  end
end

return xrandr
