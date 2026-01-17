local Config = require('config')
local appearance = require('config.appearance')

require('events.left-status').setup()
require('events.right-status').setup({ date_format = '%a %H:%M:%S' })
require('events.tab-title').setup({ hide_active_tab_unseen = false, unseen_icon = 'numbered_box' })
require('events.new-tab-button').setup()
require('events.theme-toggle').setup({ default_theme = appearance.color_scheme })
require('events.resurrect').setup()
require('events.gui-startup').setup()

return Config:init()
   :append(appearance)
   :append(require('config.bindings'))
   :append(require('config.domains'))
   :append(require('config.fonts'))
   :append(require('config.general'))
   :append(require('config.launch')).options
