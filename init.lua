local M = {}

local cols = 120
local window_highlight = 0xcccccc
local line_highlight = 0xcc0000

local function minimap()
	local columns = cols
	local bossview = view:split(true)
	local miniview = view
	local window_height = 0
	local one_char_width

	s = view.styles[view.STYLE_DEFAULT]
	s.font = "Minimap" -- https://github.com/davestewart/minimap-font
	s.size = 1
	miniview:set_styles()

	miniview.extra_ascent = -1
	miniview.extra_descent = -1
	miniview.margins = 0
	miniview.margin_left = 1
	miniview.virtual_space_options = miniview.VS_RECTANGULARSELECTION
	miniview.scroll_width_tracking = false
	miniview.scroll_width = 1
	miniview.h_scroll_bar = false
	miniview:set_x_caret_policy(0, -1)
	miniview:set_y_caret_policy(miniview.CARET_STRICT & miniview.CARET_EVEN, -1)
	-- miniview.caret_style = miniview.CARETSTYLE_INVISIBLE

	local fixed_width = miniview:text_width(miniview.STYLE_DEFAULT, string.rep('W', columns)) + 20
	miniview.width = fixed_width

	local one_char_width = miniview:text_width(miniview.STYLE_DEFAULT, 'W')
	
	-- Highlight the portion of the buffer displayed in the boss view
	local function update_window(updated)
		local bv, mv = bossview, miniview
		if miniview.buffer ~= bossview.buffer then miniview:goto_buffer(bossview.buffer) end
		--if not (updated & bv.UPDATE_V_SCROLL) then return end
		local start = bv.first_visible_line
		local ending = start + bv.lines_on_screen
		local ending_start = mv:position_from_line(ending)
		local ending_end = bv.line_end_position[ending]
		local ending_length = ending_end - ending_start
		ui.statusbar_text = ending_length
		window_height = ending - start
		mv.rectangular_selection_anchor = mv:position_from_line(start)
		mv.rectangular_selection_anchor_virtual_space = 0
		mv.rectangular_selection_caret = ending_start + math.min(ending_length, columns)
		mv.rectangular_selection_caret_virtual_space =
			ending_length > columns and 0 or columns - ending_length
		mv.x_offset = 0
		mv.scroll_width = 1
	end
	
	-- Jump to the clicked position in the minimap
	local function jump_to_click(updated)
		local bv, mv = bossview, miniview
		if miniview.buffer ~= bossview.buffer then miniview:goto_buffer(bossview.buffer) end
		if (updated & mv.UPDATE_SELECTION) and (_G.view == mv) 
			and (mv.current_pos == mv.anchor) then
			local line = mv:line_from_position(mv.current_pos)
			bv.first_visible_line = line - window_height//2
			mv.current_pos = mv:position_from_line(line)
			mv.x_offset = 0
			mv.scroll_width = 1
			_G.ui.goto_view(bv)
			-- Switch away first to avoid infinite recursion
			update_window(bv.UPDATE_V_SCROLL)
		end
	end
	
	local function clear_window()
		if view == miniview then miniview:set_empty_selection(0) end
	end
	
	local function reset_x()
		miniview.x_offset = 0
	end

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
	
	events.connect(events.VIEW_AFTER_SWITCH, clear_window)
	events.connect(events.UPDATE_UI, jump_to_click)
	events.connect(events.UPDATE_UI, update_window)
	events.connect(events.UPDATE_UI, reset_x)
	
	local function cleanup()
		events.disconnect(events.VIEW_AFTER_SWITCH, clear_window)
		events.disconnect(events.UPDATE_UI, jump_to_click)
		events.disconnect(events.UPDATE_UI, update_window)
		events.disconnect(events.UPDATE_UI, reset_x)
	end
	
	local function catch_unsplit(self)
		cleanup()
		self.unsplit, self._unsplit = self._unsplit, nil
		self.unsplit(self)
	end
	miniview._unsplit, miniview.unsplit = miniview.unsplit, catch_unsplit
	bossview._unsplit, bossview.unsplit = bossview.unsplit, catch_unsplit

end

return minimap
