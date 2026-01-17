local wezterm = require('wezterm')

local M = {}

local state = {
   themes = {},
   default_theme = nil,
   toast = true,
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

   if state.toast then
      window:toast_notification('WezTerm Theme', label .. ': ' .. theme_name, nil, 4000)
   end
end

local function current_theme(window)
   local overrides = window:get_config_overrides() or {}
   return overrides.color_scheme or window:effective_config().color_scheme
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

M.setup = function(opts)
   opts = opts or {}
   state.toast = opts.toast ~= false
   state.themes = opts.themes or build_theme_list()
   state.default_theme = opts.default_theme

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
end

return M
