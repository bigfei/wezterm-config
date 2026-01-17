local wezterm = require('wezterm')
local resurrect = wezterm.plugin.require('https://github.com/MLFlexer/resurrect.wezterm')

local M = {}

local function write_current_workspace()
   local workspace = wezterm.mux.get_active_workspace()
   resurrect.state_manager.write_current_state(workspace, 'workspace')
end

local function restore_opts(restore_text)
   return {
      relative = true,
      restore_text = restore_text,
      on_pane_restore = resurrect.tab_state.default_on_pane_restore,
   }
end

M.setup = function(opts)
   opts = opts or {}

   local interval_seconds = opts.interval_seconds or 60 * 5
   local restore_text = opts.restore_text ~= false
   local toast = opts.toast ~= false

   resurrect.state_manager.periodic_save({
      interval_seconds = interval_seconds,
      save_workspaces = true,
   })

   wezterm.on('resurrect.state_manager.periodic_save.finished', function()
      write_current_workspace()
   end)

   wezterm.on('resurrect.save', function(window, _pane)
      local state = resurrect.workspace_state.get_workspace_state()
      resurrect.state_manager.save_state(state)
      resurrect.state_manager.write_current_state(state.workspace, 'workspace')

      if toast then
         window:toast_notification('WezTerm', 'Saved workspace: ' .. state.workspace, nil, 4000)
      end
   end)

   wezterm.on('resurrect.restore', function(window, pane)
      resurrect.fuzzy_loader.fuzzy_load(window, pane, function(id, _label)
         local typ = string.match(id, '^([^/]+)') or 'workspace'
         id = string.match(id, '([^/]+)$') or id
         id = string.match(id, '(.+)%..+$') or id

         local opts = restore_opts(restore_text)
         if typ == 'workspace' then
            local state = resurrect.state_manager.load_state(id, 'workspace')
            opts.spawn_in_workspace = true
            resurrect.workspace_state.restore_workspace(state, opts)
         elseif typ == 'window' then
            local state = resurrect.state_manager.load_state(id, 'window')
            resurrect.window_state.restore_window(pane:window(), state, opts)
         elseif typ == 'tab' then
            local state = resurrect.state_manager.load_state(id, 'tab')
            resurrect.tab_state.restore_tab(pane:tab(), state, opts)
         end
      end)
   end)
end

M.resurrect_on_gui_startup = function()
   return resurrect.state_manager.resurrect_on_gui_startup()
end

return M
