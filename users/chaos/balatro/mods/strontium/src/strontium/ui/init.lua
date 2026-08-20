local ui = {}

-- Components
ui.panel = require('strontium.ui.panel')
ui.panel_manager = require('strontium.ui.panel_manager')
ui.components = require('strontium.ui.components')

-- Debug panels
ui.perf_graph = require('strontium.ui.perf_graph_panel')
ui.inspector = require('strontium.ui.inspector_panel')
ui.table_viewer = require('strontium.ui.table_viewer')
ui.effect_lab = require('strontium.ui.effect_lab_panel')
ui.gc_panel = require('strontium.ui.gc_panel')

return ui
