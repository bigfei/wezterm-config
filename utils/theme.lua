local wezterm = require('wezterm')

local M = {
   light = 'rose-pine-dawn',
   dark = 'rose-pine-moon',
}

function M.get_appearance()
   if wezterm.gui and wezterm.gui.get_appearance then
      return wezterm.gui.get_appearance()
   end
   return 'Dark'
end

function M.is_dark(appearance)
   if not appearance then
      return true
   end
   return appearance:find('Dark') ~= nil
end

function M.scheme_for_appearance(appearance)
   if M.is_dark(appearance) then
      return M.dark
   end
   return M.light
end

return M
