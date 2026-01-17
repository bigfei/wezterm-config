local wezterm = require('wezterm')
local mux = wezterm.mux
local resurrect = require('events.resurrect')

local M = {}

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local restored = false
      if resurrect and resurrect.resurrect_on_gui_startup then
         local ok = resurrect.resurrect_on_gui_startup()
         restored = ok == true
      end

      if not restored then
         local _, _, window = mux.spawn_window(cmd or {})
         window:gui_window():maximize()
      end
   end)
end

return M
