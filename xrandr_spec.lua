function keys(table)
  local keyset = {}
  for k, v in pairs(table) do
    keyset[#keyset + 1] = k
  end
  return keyset
end

describe('foggy.xrandr', function()
  local xrandr = require('xrandr')
  local fp = io.open('test/3_monitors.txt')
  local info = xrandr.info(fp)

  it('has one Xinerama screen', function() 
    
    assert.is.same({ 0 }, keys(info.screens))
    assert.is.same({ 4800, 1200 }, info.screens[0].resolution)

  end)

  it('has three connected outputs', function()
    local labels = keys(info.outputs)
    table.sort(labels)

    assert.is_same({ 'DVI-1', 'DisplayPort-0', 'HDMI-0' }, labels)
  end)

  it("doesn't parse EDID as a property", function()
    for name, output in pairs(info.outputs) do
      local properties = output.properties
      
      assert.is_nil(properties.EDID)
    end
  end)

  it("parses EDID into a separate field", function()
    for name, output in pairs(info.outputs) do
      assert.is_not_nil(output.edid)
      assert.is_not.equal('', output.edid)
      assert.is.equal(256, output.edid:len())
    end
  end)

  it("has 3 monitors of native resolution = 1600x1200", function()
    for name, output in pairs(info.outputs) do
      assert.is.same({ 1600, 1200, 60 }, output.default_mode)
    end
  end)

  it("has only one monitor as primary", function()
    local primary_count = 0
    for name, output in pairs(info.outputs) do
      if output.primary then
        primary_count = primary_count + 1
      end
    end

    assert.is.equal(1, primary_count)
  end)

end)
