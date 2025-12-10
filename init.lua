local M = {}

M.cols = 80

local function minimap()
  local bossview = view:split(true)
  local miniview = view
  
  s = view.styles[view.STYLE_DEFAULT]
  s.font = "Minimap" -- https://github.com/davestewart/minimap-font
  s.size = 1
  s.hot_spot = true
  s.changeable = false
  
  miniview.extra_ascent = -1
  miniview.extra_descent = -1
  miniview.hotspot_active_underline = false
  miniview.margins = 0
  miniview.margin_left = 1
  miniview.scroll_width_tracking = false
	miniview.scroll_width = 1
  miniview.virtual_space_options = miniview.VS_RECTANGULARSELECTION
  miniview:set_styles()
  
  local fixed_width = miniview:text_width(miniview.STYLE_DEFAULT, string.rep('W', M.cols))
  miniview.width = fixed_width
  
  -- Rectangular select the portion of the buffer displayed in the boss view
  local function update_window()
    local bv, mv = bossview, miniview
    local start = bv.first_visible_line
    local ending = start + bv.lines_on_screen
    mv:goto_line(start)
    mv.rectangular_selection_anchor = mv.current_pos
    mv.rectangular_selection_caret = mv.line_end_position[ending]
    mv.rectangular_selection_caret_virtual_space = M.cols - mv:line_length(ending)
  end
  events.connect(events.UPDATE_UI, update_window)
  --[[
  local update = false
  local function before_switch()
    if view == masterview then update = true end
  end
  local function after_switch()
    if update then
      update = false
      miniview:goto_buffer(masterview.buffer)
    end
  end
  local function cleanup()
      events.disconnect(events.BUFFER_BEFORE_SWITCH, before_switch)
      events.disconnect(events.BUFFER_AFTER_SWITCH, after_switch)
      events.disconnect("view_unsplit", cleanup)
  end
  events.connect(events.BUFFER_BEFORE_SWITCH, before_switch)
  events.connect(events.BUFFER_AFTER_SWITCH, after_switch)
  events.connect("view_unsplit", cleanup)

  local old_unsplit = view.unsplit
  local function new_unsplit(self)
    emit("view_unsplit", self)
    old_unsplit(self)
  end
  view.unsplit = new_unsplit]]
  
  -- Make a rectangular selection in the minimap to show location based on
  -- masterview.first_visible_line
  -- masterview:lines_on_screen()
  -- miniview.virtual_space_options = miniview.VS_RECTANGULAR
  -- calculate virtual space width based on binary search (start with x chars then search up and/or down)
  -- iterate over lines setting selection to vs width - char width.
end

return minimap
