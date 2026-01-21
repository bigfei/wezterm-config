local theme = require('utils.theme')
local gpu_adapters = require('utils.gpu-adapter')
local platform = require('utils.platform')

local color_scheme = theme.scheme_for_appearance(theme.get_appearance())
local macos_window_background_blur
local kde_window_background_blur
local win32_system_backdrop
local window_background_opacity

if platform.is_mac then
   macos_window_background_blur = 30
   window_background_opacity = 0.8
elseif platform.is_linux then
   kde_window_background_blur = true
   window_background_opacity = 0.35
elseif platform.is_win then
   win32_system_backdrop = 'Acrylic'
   window_background_opacity = 0.6
end
return {
   max_fps = 120,
   front_end = 'WebGpu', ---@type 'WebGpu' | 'OpenGL' | 'Software'
   webgpu_power_preference = 'HighPerformance',
   webgpu_preferred_adapter = gpu_adapters:pick_best(),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'IntegratedGpu'),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Gl', 'Other'),
   underline_thickness = '1.5pt',

   -- cursor
   animation_fps = 120,
   cursor_blink_ease_in = 'EaseOut',
   cursor_blink_ease_out = 'EaseOut',
   default_cursor_style = 'BlinkingBlock',
   cursor_blink_rate = 650,

   -- color scheme
   color_scheme = color_scheme,

   window_background_opacity = window_background_opacity,
   macos_window_background_blur = macos_window_background_blur,
   kde_window_background_blur = kde_window_background_blur,
   win32_system_backdrop = win32_system_backdrop,

   -- scrollbar
   enable_scroll_bar = true,

   -- tab bar
   enable_tab_bar = true,
   hide_tab_bar_if_only_one_tab = true,
   use_fancy_tab_bar = false,
   tab_max_width = 1000,
   show_tab_index_in_tab_bar = false,
   switch_to_last_active_tab_when_closing_tab = true,

   -- command palette
   command_palette_fg_color = '#b4befe',
   command_palette_bg_color = '#11111b',
   command_palette_font_size = 12,
   command_palette_rows = 25,

   -- window
   window_padding = {
      left = 0,
      right = 0,
      top = 10,
      bottom = 7.5,
   },
   adjust_window_size_when_changing_font_size = false,
   window_close_confirmation = 'NeverPrompt',
   window_frame = {
      active_titlebar_bg = '#090909',
      -- font = fonts.font,
      -- font_size = fonts.font_size,
   },
   -- inactive_pane_hsb = {
   --    saturation = 0.9,
   --    brightness = 0.65,
   -- },
   inactive_pane_hsb = {
      saturation = 1,
      brightness = 1,
   },

   visual_bell = {
      fade_in_function = 'EaseIn',
      fade_in_duration_ms = 250,
      fade_out_function = 'EaseOut',
      fade_out_duration_ms = 250,
      target = 'CursorColor',
   },
}
