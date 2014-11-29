if not awesome then
  require('luarocks.loader')
  inspect = require('inspect')
  naughty = { notify = function(args)
    print(args.text)
  end }
else
  inspect = function(...) end
  local naughty = require('naughty')
end

local xrandr = {}
local xinerama = {}
foggy = { mt = {} }

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
        on = true,
        primary = (matches[2] == 'primary'),
        modes = {}
      }
      info.outputs[matches[1]] = current_output
    end,
    ['^(%g+) connected %(([%a%s]+)%)$'] = function(matches)
      -- connected but off
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
    ['^(%g+) disconnected %(([%a%s]+)%)$'] = function(matches)
      info.outputs[matches[1]] = {
        available_transformations = xrandr.parse_transformations(matches[2], false),
        connected = false, on = false
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
          current_output.current_mode = mode
        end
        if symbols:find('%+') then
          current_output.default_mode = mode
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

function xrandr.set_mode(name, mode)
  xrandr.cmd(string.format('xrandr --output %s --mode %dx%d --rate %d', name, mode[1], mode[2], mode[3]))
end

function xrandr.auto_mode(name)
  xrandr.cmd(string.format('xrandr --output %s --auto', name))
end

function xrandr.off(name)
  xrandr.cmd(string.format('xrandr --output %s --off', name))
end

function xrandr.set_rotate(name, rot)
  xrandr.cmd(string.format('xrandr --output %s --rotate %s', name, rot))
end

function xrandr.set_reflect(name, refl)
  xrandr.cmd(string.format('xrandr --output %s --reflect %s', name, refl))
end

function xrandr.set_relative_pos(name, relation, other)
  xrandr.cmd(string.format('xrandr --output %s --%s %s', name, relation, other))
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

function foggy.get_output(screen_num)
  local xinerama = xinerama.info()
  local xrinfo = xrandr.info()
  -- awesome always uses xinerama screen order, but 1-numbered
  local xs = xinerama.heads[tostring(screen_num - 1)]
  -- probably horribly wrong on advanced setups:
  -- the current xrandr output is the one that matches current screen's resolution + offset
  local co = nil
  for name, output in pairs(xrinfo.outputs) do
    if output.connected and output.on then
      if (output.resolution[0] == xs.resolution[0]) and (output.resolution[1] == xs.resolution[1])
        and (output.offset[0] == xs.offset[0] and output.offset[1] == xs.offset[1]) then
        co = output 
      end
    end
  end
  return co
end

function foggy.screen_menu(co, add_output_name)
  local add_output_name = add_output_name or false
  local co = co

  local resmenu = { { '&auto', function() xrandr.auto_mode(co.name) end } }
  for i, mode in ipairs(co.modes) do
    local prefix = ' '
    local suffix = ''
    if mode == co.current_mode then
      prefix = '✓'
    end
    if mode == co.default_mode then
      suffix = ' *'
    end
    resmenu[#resmenu + 1] = { string.format('%s%dx%d@%2.0f%s', prefix, mode[1], mode[2], mode[3], suffix), function() xrandr.set_mode(co.name, mode) end }
  end

  local transmenu = {}
  local at = co.available_transformations
  local ct = co.transformations

  for op, available in pairs(at.rotations) do
    if available then
      local flags = ''
      if ct.rotations[op] then
        flags = ' ✓'
      end
      transmenu[#transmenu + 1] = { string.format('%s%s', op, flags), function() xrandr.set_rotate(co.name, op) end }
    end
  end

  for op, available in pairs(at.reflections) do
    if available then
      local flags = ''
      if ct.reflections[op] then
        flags = ' ✓'
      end
      transmenu[#transmenu + 1] = { string.format('%s%s', op, flags), function() xrandr.set_reflect(co.name, op) end }
    end
  end

  local posmenu = {}
  local other_outputs = {}
  for name, _out in pairs(xrandr.info().outputs) do
    if name ~= co.name and _out.connected and _out.on then
      other_outputs[#other_outputs + 1] = name
    end
  end

  for i, dir in ipairs({ "left-of", "right-of", "above", "below" }) do
    local relmenu = {}
    for j, _name in ipairs(other_outputs) do
      relmenu[#relmenu + 1] = { _name, function() xrandr.set_relative_pos(co.name, dir, _name) end }
    end
    posmenu[#posmenu + 1] = { dir, relmenu }
  end

  local menu = {
    { '&mode', resmenu },
  }
  if co.on then
    menu[#menu + 1] = { '&transform', transmenu }
    menu[#menu + 1] = { '&off', function() xrandr.off(co.name) end }
    menu[#menu + 1] = { 'po&sition', posmenu }

    if not co.primary then
      menu[#menu + 1] = { '&primary', function() xrandr.set_primary(co.name) end }
    end
  end

  if add_output_name then
    table.insert(menu, 1, { '[' .. co.name .. ']' , nil })
  end

  menu[#menu + 1] = { 'i&dentify', function() xrandr.identify_outputs() end }
  
  return menu
end

function foggy.build_menu(screen_count, current_screen)
  local thisout = foggy.get_output(current_screen)
  local menu = foggy.screen_menu(thisout, true)
  local visible = { [thisout.name] = true }
  for i = 1, screen_count do
    if i ~= current_screen then
      local out = foggy.get_output(i)
      visible[out.name] = true
      menu[#menu + 1] = { out.name, foggy.screen_menu(out, false) }
    end
  end
  -- add connected but disabled screens
  local outputs = xrandr.info().outputs
  for name, output in pairs(outputs) do
    if output.connected and (not output.on) and (not visible[name]) then
      menu[#menu + 1] = { name, foggy.screen_menu(output, false) }
    end
  end
  return menu
end

if awesome then
  local awful = require('awful')
  xrandr.cmd = awful.util.spawn_with_shell
  function foggy.menu(current_screen)
    local current_screen = current_screen or mouse.screen
    local menu = foggy.build_menu(screen.count(), current_screen)
    awful.menu(menu):show()
  end
  function foggy.mt:__call(...)
      return foggy.menu(...)
  end
  return setmetatable(foggy, foggy.mt)
else
  -- print(inspect(xrandr.info()))
  local v = foggy.build_menu(2, 1)
  print(inspect(v))
end
