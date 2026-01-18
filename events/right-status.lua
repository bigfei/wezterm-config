local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')

---@alias Event.RightStatusOptions { date_format?: string }

---Setup options for the right status bar
local EVENT_OPTS = {}

---@type OptsSchema
EVENT_OPTS.schema = {
   {
      name = 'date_format',
      type = 'string',
      default = '%a %H:%M:%S',
   },
}
EVENT_OPTS.validator = OptsValidator:new(EVENT_OPTS.schema)

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar
local ICON_NET_DOWN = nf.md_arrow_down
local ICON_NET_UP = nf.md_arrow_up

local IS_LINUX = wezterm.target_triple:find('linux') ~= nil

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   date      = { fg = '#fab387', bg = 'rgba(0, 0, 0, 0.4)' },
   net_down  = { fg = '#f38ba8', bg = 'rgba(0, 0, 0, 0.4)' },
   net_up    = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
   battery   = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   separator = { fg = '#74c7ec', bg = 'rgba(0, 0, 0, 0.4)' }
}

local cells = Cells:new()

cells
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('net_down_icon', ICON_NET_DOWN .. ' ', colors.net_down)
   :add_segment('net_down_text', '', colors.net_down, attr(attr.intensity('Bold')))
   :add_segment('net_up_icon', ICON_NET_UP .. ' ', colors.net_up)
   :add_segment('net_up_text', '', colors.net_up, attr(attr.intensity('Bold')))
   :add_segment('separator_battery', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))

local net_state = {
   last_ts = nil,
   last_rx = nil,
   last_tx = nil,
   down_bps = 0,
   up_bps = 0,
}

---@param items FormatItem[]
---@return number
local function measure_cells(items)
   local width = 0
   local column_width = wezterm.column_width or function(text)
      return #text
   end

   for _, item in ipairs(items) do
      if type(item) == 'table' and item.Text then
         width = width + column_width(item.Text)
      end
   end

   return width
end

---@return number|nil, number|nil
local function read_net_bytes()
   if not IS_LINUX then
      return nil, nil
   end

   local f = io.open('/proc/net/dev', 'r')
   if not f then
      return nil, nil
   end

   local rx, tx = 0, 0
   for line in f:lines() do
      local iface, data = line:match('^%s*([^:]+):%s*(.+)$')
      if iface and data and iface ~= 'lo' then
         local fields = {}
         for num in data:gmatch('%d+') do
            fields[#fields + 1] = num
         end
         if #fields >= 16 then
            rx = rx + tonumber(fields[1])
            tx = tx + tonumber(fields[9])
         end
      end
   end
   f:close()

   return rx, tx
end

---@param bps number
---@return string
local function format_rate(bps)
   local units = { 'B/s', 'KiB/s', 'MiB/s', 'GiB/s' }
   local idx = 1
   local value = bps

   while value >= 1024 and idx < #units do
      value = value / 1024
      idx = idx + 1
   end

   local fmt = value >= 10 and '%.0f %s' or '%.1f %s'
   return string.format(fmt, value, units[idx])
end

---@return string, string
local function net_speed()
   local rx, tx = read_net_bytes()
   if not rx then
      return 'n/a', 'n/a'
   end

   local now = os.time()
   if net_state.last_ts then
      local dt = now - net_state.last_ts
      if dt > 0 then
         local down = (rx - net_state.last_rx) / dt
         local up = (tx - net_state.last_tx) / dt
         net_state.down_bps = math.max(0, down)
         net_state.up_bps = math.max(0, up)
         net_state.last_ts = now
         net_state.last_rx = rx
         net_state.last_tx = tx
      end
   else
      net_state.last_ts = now
      net_state.last_rx = rx
      net_state.last_tx = tx
   end

   return format_rate(net_state.down_bps), format_rate(net_state.up_bps)
end

---@return string, string
local function battery_info()
   -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/battery_info.html

   local charge = ''
   local icon = ''

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

---@param opts? Event.RightStatusOptions Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   wezterm.on('update-right-status', function(window, _pane)
      local battery_text, battery_icon = battery_info()
      local net_down_text, net_up_text = net_speed()

      cells
         :update_segment_text('date_text', wezterm.strftime(valid_opts.date_format))
         :update_segment_text('net_down_text', net_down_text)
         :update_segment_text('net_up_text', net_up_text)
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)

      local right_status_items = cells:render({
         'date_icon',
         'date_text',
         'separator',
         'net_down_icon',
         'net_down_text',
         'net_up_icon',
         'net_up_text',
         'separator_battery',
         'battery_icon',
         'battery_text',
      })
      wezterm.GLOBAL.right_status_cols = measure_cells(right_status_items)
      window:set_right_status(wezterm.format(right_status_items))
   end)
end

return M
