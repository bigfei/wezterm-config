local wezterm = require('wezterm')

local LIGHT_TOKENS = { 'light', 'day', 'dawn', 'morning' }
local DARK_TOKENS = { 'dark', 'night', 'moon', 'storm', 'dusk' }
local LIGHTNESS_THRESHOLD = 0.4

local M = {
   light = 'rose-pine-dawn',
   dark = 'rose-pine-moon',
   _builtin_pairs = nil,
   _builtin_schemes = nil,
   _light_schemes = nil,
   _dark_schemes = nil,
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

function M.builtin_schemes()
   if not M._builtin_schemes then
      M._builtin_schemes = wezterm.color.get_builtin_schemes()
   end
   return M._builtin_schemes
end

function M.scheme_variant(name)
   if not name then
      return nil
   end

   local scheme = M.builtin_schemes()[name]
   if not scheme or not scheme.background then
      return nil
   end

   local ok, color = pcall(wezterm.color.parse, scheme.background)
   if not ok or not color then
      return nil
   end

   local _, _, lightness, _ = color:hsla()
   if lightness < LIGHTNESS_THRESHOLD then
      return 'dark', lightness
   end
   return 'light', lightness
end

function M.base_key(name)
   if not name then
      return ''
   end

   local key = name:lower()
   for _, token in ipairs(LIGHT_TOKENS) do
      key = key:gsub(token, '')
   end
   for _, token in ipairs(DARK_TOKENS) do
      key = key:gsub(token, '')
   end
   key = key:gsub('[%s%-%_]+', ' ')
   key = key:gsub('^%s+', ''):gsub('%s+$', '')
   return key
end

function M.build_builtin_pairs()
   if M._builtin_pairs then
      return M._builtin_pairs
   end

   local schemes = M.builtin_schemes()
   local pairs = {}
   local names = {}

   for name, _ in pairs(schemes) do
      table.insert(names, name)
   end
   table.sort(names)

   for _, name in ipairs(names) do
      local variant, lightness = M.scheme_variant(name)
      if variant then
         local key = M.base_key(name)
         if key ~= '' then
            local entry = pairs[key]
               or { light = nil, dark = nil, light_l = nil, dark_l = nil }

            if variant == 'light' then
               if not entry.light_l or lightness > entry.light_l then
                  entry.light = name
                  entry.light_l = lightness
               end
            elseif variant == 'dark' then
               if not entry.dark_l or lightness < entry.dark_l then
                  entry.dark = name
                  entry.dark_l = lightness
               end
            end

            pairs[key] = entry
         end
      end
   end

   M._builtin_pairs = pairs
   return pairs
end

function M.builtin_pair_for(name)
   local key = M.base_key(name)
   if key == '' then
      return nil
   end
   return M.build_builtin_pairs()[key]
end

function M.light_schemes()
   if M._light_schemes then
      return M._light_schemes
   end

   local schemes = M.builtin_schemes()
   local light = {}

   for name, scheme in pairs(schemes) do
      if scheme and scheme.background then
         local ok, color = pcall(wezterm.color.parse, scheme.background)
         if ok and color then
            local _, _, lightness, _ = color:hsla()
            if lightness >= LIGHTNESS_THRESHOLD then
               table.insert(light, name)
            end
         end
      end
   end

   table.sort(light)
   M._light_schemes = light
   return light
end

function M.dark_schemes()
   if M._dark_schemes then
      return M._dark_schemes
   end

   local schemes = M.builtin_schemes()
   local dark = {}

   for name, scheme in pairs(schemes) do
      if scheme and scheme.background then
         local ok, color = pcall(wezterm.color.parse, scheme.background)
         if ok and color then
            local _, _, lightness, _ = color:hsla()
            if lightness < LIGHTNESS_THRESHOLD then
               table.insert(dark, name)
            end
         end
      end
   end

   table.sort(dark)
   M._dark_schemes = dark
   return dark
end

return M
