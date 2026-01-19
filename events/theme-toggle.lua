local wezterm = require('wezterm')
local theme = require('utils.theme')

local M = {}

local state = {
   themes = {},
   default_theme = nil,
   toast = true,
   auto = false,
   auto_toast = false,
   auto_paused = false,
   auto_pause_on_manual = true,
   light_theme = nil,
   dark_theme = nil,
   debug_dump_path = '/tmp/wezterm-builtin-pairs.txt',
}

local function build_theme_list()
   local schemes = wezterm.color.get_builtin_schemes()
   local themes = {}

   for name, _ in pairs(schemes) do
      table.insert(themes, name)
   end

   table.sort(themes)
   return themes
end

local function find_theme_index(theme_name)
   for idx, name in ipairs(state.themes) do
      if name == theme_name then
         return idx
      end
   end
   return 1
end

local function apply_theme(window, theme_name, label)
   local overrides = window:get_config_overrides() or {}
   overrides.color_scheme = theme_name
   window:set_config_overrides(overrides)

   if state.auto and state.auto_pause_on_manual and label then
      state.auto_paused = true
   end

   if state.toast and label then
      window:toast_notification('WezTerm Theme', label .. ': ' .. theme_name, nil, 4000)
   end
end

local function current_theme(window)
   local overrides = window:get_config_overrides() or {}
   return overrides.color_scheme or window:effective_config().color_scheme
end

local function random_from(list)
   if not list or #list == 0 then
      return nil
   end
   math.randomseed(os.time())
   return list[math.random(1, #list)]
end

local function resolve_light_dark_target(current)
   local target = nil

   if current == state.light_theme then
      target = state.dark_theme
   elseif current == state.dark_theme then
      target = state.light_theme
   else
      local pair = theme.builtin_pair_for(current)
      if pair then
         if pair.light == current and pair.dark then
            target = pair.dark
         elseif pair.dark == current and pair.light then
            target = pair.light
         else
            local variant = theme.scheme_variant(current)
            if variant == 'dark' and pair.light then
               target = pair.light
            elseif variant == 'light' and pair.dark then
               target = pair.dark
            elseif pair.dark and pair.light then
               target = pair.dark
            end
         end
      end
   end

   if not target or target == '' then
      local variant = theme.scheme_variant(current)
      if variant == 'dark' then
         target = random_from(theme.light_schemes()) or state.light_theme
      elseif variant == 'light' then
         target = random_from(theme.dark_schemes()) or state.dark_theme
      else
         local appearance = theme.get_appearance()
         if theme.is_dark(appearance) then
            target = random_from(theme.light_schemes()) or state.light_theme
         else
            target = random_from(theme.dark_schemes()) or state.dark_theme
         end
      end
   end

   if target and target ~= '' then
      return target
   end
   return nil
end

local function toggle_light_dark(window)
   local current = current_theme(window)
   local target = resolve_light_dark_target(current)
   if target then
      apply_theme(window, target, 'Toggle light/dark')
   end
end

local function write_builtin_pairs(path)
   if not path or path == '' then
      wezterm.log_warn('theme-toggle: debug_dump_path is empty')
      return false
   end

   local pair_map = theme.build_builtin_pairs()
   local keys = {}

   for key, _ in pairs(pair_map) do
      table.insert(keys, key)
   end
   table.sort(keys)

   local file, err = io.open(path, 'w')
   if not file then
      wezterm.log_error('theme-toggle: unable to write builtin pairs: ' .. tostring(err))
      return false
   end

   for _, key in ipairs(keys) do
      local entry = pair_map[key] or {}
      file:write(
         key,
         '\t',
         tostring(entry.light),
         '\t',
         tostring(entry.dark),
         '\t',
         tostring(entry.light_l),
         '\t',
         tostring(entry.dark_l),
         '\n'
      )
   end

   file:close()
   return true
end

local function scheme_for_appearance(appearance)
   if theme.is_dark(appearance) then
      return state.dark_theme
   end
   return state.light_theme
end

local function apply_auto_theme(window)
   if not state.auto or state.auto_paused then
      return
   end

   local appearance = theme.get_appearance()
   local desired = scheme_for_appearance(appearance)
   if not desired or desired == '' then
      return
   end

   if current_theme(window) ~= desired then
      apply_theme(window, desired, state.auto_toast and 'Auto theme' or nil)
   end
end

local function ensure_default_theme(window)
   if state.default_theme then
      return
   end

   local effective = window:effective_config().color_scheme
   state.default_theme = effective ~= '' and effective or state.themes[1]
end

local function next_theme(window)
   local current = current_theme(window)
   local current_idx = find_theme_index(current)
   local next_idx = (current_idx % #state.themes) + 1
   apply_theme(window, state.themes[next_idx], 'Next theme')
end

local function prev_theme(window)
   local current = current_theme(window)
   local current_idx = find_theme_index(current)
   local prev_idx = current_idx - 1
   if prev_idx < 1 then
      prev_idx = #state.themes
   end
   apply_theme(window, state.themes[prev_idx], 'Previous theme')
end

local function random_theme(window)
   math.randomseed(os.time())

   local current = current_theme(window)
   local current_idx = find_theme_index(current)
   local new_idx = current_idx

   while new_idx == current_idx do
      new_idx = math.random(1, #state.themes)
   end

   apply_theme(window, state.themes[new_idx], 'Random theme')
end

local function default_theme(window)
   ensure_default_theme(window)
   local default_idx = find_theme_index(state.default_theme)
   apply_theme(window, state.themes[default_idx], 'Default theme')
end

M.resolve_light_dark_target = resolve_light_dark_target

M.setup = function(opts)
   opts = opts or {}
   state.toast = opts.toast ~= false
   state.themes = opts.themes or build_theme_list()
   state.default_theme = opts.default_theme
   state.auto = opts.auto == true
   state.auto_toast = opts.auto_toast == true
   state.auto_pause_on_manual = opts.auto_pause_on_manual ~= false
   state.light_theme = opts.light_theme or theme.light
   state.dark_theme = opts.dark_theme or theme.dark
   state.debug_dump_path = opts.debug_dump_path or state.debug_dump_path

   if #state.themes == 0 then
      wezterm.log_warn('theme-toggle: no themes available')
      return
   end

   wezterm.on('theme.next', function(window, _pane)
      next_theme(window)
   end)

   wezterm.on('theme.prev', function(window, _pane)
      prev_theme(window)
   end)

   wezterm.on('theme.random', function(window, _pane)
      random_theme(window)
   end)

   wezterm.on('theme.default', function(window, _pane)
      default_theme(window)
   end)

   wezterm.on('theme.toggle_light_dark', function(window, _pane)
      toggle_light_dark(window)
   end)

   wezterm.on('theme.debug.dump_pairs', function(window, _pane)
      if write_builtin_pairs(state.debug_dump_path) and state.toast then
         window:toast_notification(
            'WezTerm Theme',
            'Wrote builtin pairs: ' .. state.debug_dump_path,
            nil,
            4000
         )
      end
   end)

   if state.auto then
      wezterm.on('window-config-reloaded', function(window, _pane)
         apply_auto_theme(window)
      end)

      wezterm.on('update-right-status', function(window, _pane)
         apply_auto_theme(window)
      end)
   end
end

return M
