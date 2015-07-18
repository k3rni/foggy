package.loaded.foggy = nil

local foggy = {
  util = require('foggy.util'),
  xrandr = require('foggy.xrandr'),
  xinerama = require('foggy.xinerama'),
  shortcuts = require('foggy.shortcuts'),
  menu = require('foggy.menu')
}

return foggy
