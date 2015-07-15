local xinerama = require('foggy.xinerama')
local xrandr = require('foggy.xrandr')
local awful = require('awful')

local menu = { mt = {}, _NAME = "foggy.menu" }

-- move to util?
function menu.get_output(screen_num)
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

function screen_menu(co, add_output_name)
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
      transmenu[#transmenu + 1] = { string.format('rotate %s%s', op, flags), function() xrandr.set_rotate(co.name, op) end }
    end
  end

  for op, available in pairs(at.reflections) do
    if available then
      local flags = ''
      if ct.reflections[op] then
        flags = ' ✓'
      end
      transmenu[#transmenu + 1] = { string.format('reflect %s%s', op, flags), function() xrandr.set_reflect(co.name, op) end }
    end
  end

  local posmenu = {}
  local other_outputs = {}
  for name, _out in pairs(xrandr.info().outputs) do
    if name ~= co.name and _out.connected and _out.on then
      other_outputs[#other_outputs + 1] = name
    end
  end

  for i, dir in ipairs({ "left-of", "right-of", "above", "below", 'same-as' }) do
    local relmenu = {}
    for j, _name in ipairs(other_outputs) do
      relmenu[#relmenu + 1] = { _name, function() xrandr.set_relative_pos(co.name, dir, _name) end }
    end
    posmenu[#posmenu + 1] = { dir, relmenu }
  end

  local mainmenu = {
    { '&mode', resmenu },
  }
  if co.on then
    mainmenu[#mainmenu + 1] = { '&transform', transmenu }
    mainmenu[#mainmenu + 1] = { '&off', function() xrandr.off(co.name) end }
    mainmenu[#mainmenu + 1] = { 'po&sition', posmenu }

    if not co.primary then
      mainmenu[#mainmenu + 1] = { '&primary', function() xrandr.set_primary(co.name) end }
    end
  end

  if add_output_name then
    table.insert(mainmenu, 1, { '[' .. co.name .. ']' , nil })
  end

  mainmenu[#mainmenu + 1] = { 'i&dentify', function() xrandr.identify_outputs() end }
  
  return mainmenu
end

function build_menu(current_screen)
  local outputs = xrandr.info().outputs
  local thisout = menu.get_output(current_screen)
  local scrn_menu = screen_menu(thisout, true)
  local visible = { [thisout.name] = true }
  -- iterate over outputs, not screens
  -- otherwise menu is bugged when cloning
  for name, output in pairs(outputs) do
    if output.connected and output.on and output.name ~= thisout.name then
      scrn_menu[#scrn_menu + 1] = { name, screen_menu(output, false) }
    end
  end
  -- add connected but disabled screens
  for name, output in pairs(outputs) do
    if output.connected and (not output.on) and (not visible[name]) then
      scrn_menu[#scrn_menu + 1] = { name, screen_menu(output, false) }
    end
  end
  return scrn_menu
end


function menu.menu(current_screen)
  local current_screen = current_screen or mouse.screen
  local thismenu = build_menu(current_screen)
  awful.menu(thismenu):show()
end

function menu.mt:__call(...)
  return menu.menu(...)
end

return setmetatable(menu, menu.mt)
