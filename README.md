# foggy

Foggy manages your multiple screens. It's an extension script for [Awesome](http://awesome.naquadah.org/), a tiling window manager. 

When foggy is invoked, it displays a popup menu that allows you to manipulate display outputs via XRandR. Most XRandR features are supported:

* relative screen positioning, as in "output X is right of output Y"
* cloning output
* rotations and reflections
* modesetting, restricted to XRandR-provided modes
* turning a display on and off
* *NEW* backlight, if supported by that particular screen and XRandR

# Planned features

* additional display properties besides backlight: typically scaling mode, aspect ratio and audio output toggling
* convenient bindable functions to adjust brightness

# Installation

## Standalone

```shell
  cd ~/.config/awesome
  git clone https://github.com/k3rni/foggy
  ln -s foggy/foggy.lua
```

## With [awesome-copcycats](/copycat-killer/awesome-copycats)

The instructions assume you went with the git-clone route. Go to .config/awesome as above, but add foggy as a submodule:

```shell
  git submodule add https://github.com/k3rni/foggy
  ln -s foggy/foggy.lua
```

## Basic usage

Edit your rc.lua, and add the following somewhere with the other require lines:

```lua
local foggy = require('foggy')
```

# Keys and widgets

Restart your DE, or call awesome's Lua prompt (default: <kbd>Win + X</kbd>) and type <code>awesome.restart()</code>.
Now you can invoke Foggy by calling the Lua prompt and typing <code>foggy.menu()</code>.

To add a keybinding, edit rc.lua and add something like the following to the global key bindings: (don't forget to add a comma if necessary)

```lua
    awful.key({ modkey, "Control" }, "p",      foggy.menu)
```

To add a widget, add something similar to where the widget box is built. Replace the icon path, and background color if necessary (or just add the imagebox
directly, without the background).

```lua
    scrnicon = wibox.widget.background(wibox.widget.imagebox('path-to-image.png'), '#313131')
    scrnicon:buttons(awful.util.table.join(
                         awful.button({ }, 1, function (c)
                           foggy.menu(s)
                         end)
                     ))
    layout:add(scrnicon)
```

Restart awesome as above. Now, clicking that icon in the bar should bring up foggy.

