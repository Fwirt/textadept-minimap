-- Copyright (c) 2025 Fwirt. See LICENSE.

-- A Textadept module for displaying a minimap of a buffer

-- TODO:
--  +make minimaps individually configurable
--  +close minimap on reset/Textadept close or save to session
--  +add option to display current range by changing line background
--   (for proportional fonts where rectangular select won't work)
--  +disable lexer for minimap buffer (the bossview should handle it)

local M = {}

M.min_columns = 100 -- The minimum width of the minimap window, in text columns
M.padding = 5 -- Right margin for the minimap
M.highlight_color = 0xffaaaaaa -- Color of the current location highlight
M.font = "Minimap" -- The font to use for the minimap
M.font_size = 1 -- Font size for the minimap view
M.highlight_style = "select" -- use rectangular selection or background color

-- Do a binary search to find how many chars a window is wide
--[[local function chars_from_width(chars, width, char_px)
	local test_width
	while math.abs(width - test_width) <= char_px + 1 do
		test_width = chars * chars_px
		if test_width > width then
			chars = chars - chars//2
		else
			chars = chars + chars//2
		end
	end
	return chars
end]]

function longest_line(view)
	local line, line_length = 0, 0
	local longest_line, longest_length = 0, 0
	local tab_width = view.tab_width
	local last_line = view.line_count
	repeat
		line = line + 1
		line_length = view.column[view.line_end_position[line]]
		if line_length > longest_length then
			longest_length = line_length
			longest_line = line
		end
	until line >= last_line
	return longest_line, longest_length
end

local function minimap()
	local bossview = view:split(true)
	local miniview = view
	local window_height = 0
	local one_char_width
	-- the width of the widest alphanumeric character in px
	local boss_cur_width = bossview.scroll_width

	s = view.styles[view.STYLE_DEFAULT]
	s.font = M.font -- https://github.com/davestewart/minimap-font
	s.size = M.font_size
	miniview:set_styles()

	miniview.extra_ascent = -1
	miniview.extra_descent = -1
	miniview.margins = 0
	miniview.margin_left = 1
	miniview.margin_right = 1
	miniview.tab_minimum_width = 0
	miniview.scroll_width_tracking = false
	miniview.scroll_width = 1
	miniview.virtual_space_options = miniview.VS_RECTANGULARSELECTION
	miniview.element_color[miniview.ELEMENT_SELECTION_BACK] = M.highlight_color
	miniview.h_scroll_bar = false
	miniview:set_x_caret_policy(0, -1)
	miniview:set_y_caret_policy(miniview.CARET_STRICT & miniview.CARET_EVEN, -1)
	miniview.indentation_guides = miniview.IV_NONE
	-- miniview.caret_style = miniview.CARETSTYLE_INVISIBLE

	local long_line, columns = longest_line(bossview)
	columns = math.max(columns, M.min_columns)
	--miniview.width = miniview:text_width(miniview.STYLE_DEFAULT, string.rep('W', columns)) + M.padding

	-- I really don't like this but I can't find another way to make it behave
	local function sync_views()
		local current_view = view
		if miniview.buffer ~= bossview.buffer then
			miniview:goto_buffer(bossview.buffer)
			ui.goto_view(miniview)
			bossview:goto_buffer(miniview.buffer)
			ui.goto_view(bossview)
			ui.goto_view(view)
		end
	end

	-- Highlight the portion of the buffer displayed in the boss view
	-- and adjust the window width to accomodate the widest line
	local function update_window(updated)
		local bv, mv = bossview, miniview
		sync_views()
		--if not (updated & bv.UPDATE_V_SCROLL) then return end
		local start = bv.first_visible_line
		local ending = start + bv.lines_on_screen
		local ending_start = bv:position_from_line(ending)
		local ending_end = bv.line_end_position[ending]
		local ending_length = ending_end - ending_start
		-- tabs are 1 char but take up a variable number visually, so we have to
		-- calculate virtual space accordingly
		local tabspace = mv.column[mv.line_end_position[ending]] - ending_length
		local ending_vs = columns - ending_length - tabspace

		window_height = ending - start
		mv.rectangular_selection_anchor = mv:position_from_line(start)
		mv.rectangular_selection_anchor_virtual_space = 0
		-- also adjust caret if the line is too_long
		mv.rectangular_selection_caret = ending_start +
			(ending_length + tabspace < columns and ending_length
			 or columns - tabspace)
		mv.rectangular_selection_caret_virtual_space = ending_vs
		mv.x_offset = 0
		mv.scroll_width = 1
	end

	-- Adjust the width of the mini view to accomodate
	-- the longest line of the bossview
	local function adjust_width()
		if boss_cur_width ~= bossview.scroll_width then
			boss_cur_width = bossview.scroll_width
			long_line, columns = longest_line(bossview)
			columns = math.max(columns, M.min_columns)
			--miniview.width = miniview:text_width(miniview.STYLE_DEFAULT, string.rep('W', columns)) + M.padding
		end
	end

	-- Jump to the clicked position in the minimap
	local function jump_to_click(updated)
		local bv, mv = bossview, miniview
		sync_views()
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

	-- Clear the selection before the click is passed to Scintilla
	local function clear_window()
		if view == miniview then miniview:set_empty_selection(0) end
	end

	local function reset_x()
		miniview.x_offset = 0
	end

	local function block_switch_events()
		if view == miniview then return true end
	end

	events.connect(events.VIEW_AFTER_SWITCH, clear_window)
	events.connect(events.VIEW_AFTER_SWITCH, sync_views)
	events.connect(events.UPDATE_UI, adjust_width)
	events.connect(events.UPDATE_UI, jump_to_click)
	events.connect(events.UPDATE_UI, update_window)
	events.connect(events.UPDATE_UI, reset_x)
	events.connect(events.BUFFER_AFTER_SWITCH, sync_views)
	events.connect(events.BUFFER_BEFORE_SWITCH, block_switch_events, 1)
	events.connect(events.BUFFER_AFTER_SWITCH, block_switch_events, 1)

	local function cleanup()
		events.disconnect(events.VIEW_AFTER_SWITCH, clear_window)
		events.disconnect(events.VIEW_AFTER_SWITCH, sync_views)
		events.disconnect(events.UPDATE_UI, adjust_width)
		events.disconnect(events.UPDATE_UI, jump_to_click)
		events.disconnect(events.UPDATE_UI, update_window)
		events.disconnect(events.UPDATE_UI, reset_x)
		events.disconnect(events.BUFFER_AFTER_SWITCH, sync_views)
		events.disconnect(events.BUFFER_BEFORE_SWITCH, block_switch_events)
		events.disconnect(events.BUFFER_AFTER_SWITCH, block_switch_events)
		miniview.unsplit, miniview.unsplit = miniview._unsplit, nil
		bossview.unsplit, bossview.unsplit = bossview._unsplit, nil
		events.disconnect(events.RESET_BEFORE, cleanup)
		bossview:unsplit()
	end

	miniview._unsplit, miniview.unsplit = miniview.unsplit, cleanup
	bossview._unsplit, bossview.unsplit = bossview.unsplit, cleanup

	events.connect(events.RESET_BEFORE, cleanup)
end

local meta = { __call = minimap }
setmetatable(M, meta)

return M
