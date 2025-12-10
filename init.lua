local function minimap(cols)
  local columns = cols or 80
  local bossview = view:split(true)
  local miniview = view
  local window_height = 0
  local one_char_width
  
  s = view.styles[view.STYLE_DEFAULT]
  s.font = "Minimap" -- https://github.com/davestewart/minimap-font
  s.size = 1
  s.hot_spot = true
  s.changeable = false
  miniview:set_styles()
  
  miniview.extra_ascent = -1
  miniview.extra_descent = -1
  miniview.hotspot_active_underline = false
  miniview.margins = 0
  miniview.margin_left = 1
  miniview.virtual_space_options = miniview.VS_RECTANGULARSELECTION
	miniview.scroll_width_tracking = false
	miniview.scroll_width = 1
  
  local fixed_width = miniview:text_width(miniview.STYLE_DEFAULT, string.rep('W', columns))
  miniview.width = fixed_width
  
  local one_char_width = miniview:text_width(miniview.STYLE_DEFAULT, 'W')
  
  -- Rectangular select the portion of the buffer displayed in the boss view
  local function update_window(updated)
    local bv, mv = bossview, miniview
		-- updated should be number but is boolean?
    -- if not updated & bv.UPDATE_V_SCROLL then return end
    local start = bv.first_visible_line
    local ending = start + bv.lines_on_screen
    window_height = ending - start
    mv:goto_line(start)
    mv.rectangular_selection_anchor = mv.current_pos
    mv.rectangular_selection_caret = mv.line_end_position[ending]
    mv.rectangular_selection_caret_virtual_space =
		  columns - math.min(mv:line_length(ending), columns)
	end
	events.connect(events.UPDATE_UI, update_window)
  
	-- Jump to the clicked position in the minimap
	-- FIXME: HOT_SPOT_CLICK apparently always returns 1 for position right now.
	-- I wonder if position is actually an index of which hotspot? And the whole
	-- thing is one big hotspot right now. Needs further testing.
  local function jump_to_click(position, mods)
		local bv, mv = bossview, miniview
		local line = mv:line_from_position(position)
		-- ui.print(position, mods)
		bv:scroll_range(bv:position_from_line(line - window_height//2),
			bv:position_from_line(line + window_height//2))
		mv.scroll_width = 1
  end
  events.connect(events.HOT_SPOT_CLICK, jump_to_click)
  
  -- Do a binary search to find how many chars the window is wide
  local function chars_from_width(width, chars)
		local next_chars
		local test_width = miniview:text_width(miniview.STYLE_DEFAULT, string.rep('W', chars))
		if test_width > width then
			next_chars = chars - chars//2
		else
			next_chars = chars + chars//2
		end
		-- base case
		if math.abs(width - test_width) <= one_char_width then
			return next_chars
		end
		-- tail call
		return chars_from_width(view, width, next_chars)
  end
  --[[events.connect(events.RESIZE, function (view)
		if view == miniview then
			columns = chars_from_width(miniview.width, columns)
		end
	end)]]

	-- Cleanup code not implemented yet.
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
end

return minimap
