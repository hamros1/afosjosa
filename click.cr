CLICK_BORDER = 0
CLICK_DECORATION = 1
CLICK_INSIDE = 2

def tiling_resize_for_border(con, border, event)
	second = nil
	first = con
	case border
	when BORDER_LEFT
		search_direction = D_LEFT
		break
	when BORDER_RIGHT
		search_direction = D_RIGHT
		break
	when BORDER_TOP
		search_direction = D_UP
		break
	when BORDER_BOTTOM
		search_direction = D_DOWN
		break
	else
		break
	end

	res = resize_find_tiling_participants(first, second, search_direction, false)
	return false if !res

	if search_direction == D_UP || search_direction == D_LEFT
		tmp = first
		first = second
		second = tmp
	end

	orientation = (border == BORDER_LEFT || border == BORDER_RIGHT) ? HORIZ : VERT

	resize_graphical_handler(first, second, orientation, event)

	tree_render()

	return true
end

def floating_mod_on_tiled_client(con, event)
	to_right = con.rect.width - event.event_x
	to_left = event.event_x
	to_top = event.event_y
	to_bottom = con.rect.height - event.event_y

	return tiling_resize_for_border(con, BORDER_RIGHT, event) if to_right < to_left && to_right < to_top && to_right < to_bottom
	return tiling_resize_for_border(con, BORDER_RIGHT, event) if to_top < to_right && to_top < to_left && to_top < to_bottom
	return tiling_resize_for_border(con, BORDER_RIGHT, event) if to_bottom < to_left && to_bottom < to_left && to_bottom < to_top

	return false
end

def tiling_resize(con, event, dest)
	bsr = con_border_style_rect(con)

	if dest == CLICK_DECORATION
		check_con = con

		if con_is_leaf(check_con) && check_con.parent.type == CT_CON
			check_con = check_con.parent
		end

		return false if (check_con.layout == L_STACKED || check_con.layout == L_TABBED || con_orientation(check_con) == HORIZ) && con_num_children(check_con) > 1
		return tiling_resize_for_border(con, BORDER_TOP, event)
	end

	return tiling_resize_for_border(con, BORDER_LEFT, event) if event.event_x >= 0 && event.event_x <= bsr.x && event.event_y >= bsr.y && event.event_y <= (con.rect.height + bsr.height)
	return tiling_resize_for_border(con, BORDER_RIGHT, event) if event.event_x >= (con.window_rect.x + con.window_rect.width) && event.event_y >= bsr.y && event.event_y <= (con.rect.height + bsr.height)
	return tiling_resize_for_border(con, BORDER_BOTTOM, event) if event.event_y >= (con.window_rect.y + con.window_rect.height)
end

def route_click(con, event, mod_pressed, dest)
	if con.parent.type == CT_DOCKAREA
		xcb_allow_events(conn, XCB_ALLOW_REPLAY_POINTER, event.time)
		xcb_flush(conn)
		tree_render()
		return 0
	end

	is_left_or_right_click = event.detail == XCB_BUTTON_CLICK_LEFT || event.detail == XCB_BUTTON_CLICK_RIGHT

	if dest == CLICK_DECORATION || dest == CLICK_INSIDE || dest == CLICK_BORDER
		bind = get_binding_from_xcb_event(event)
		if !bind.nil? && ((dest == CLICK_DECORATION && !bind.exclude_titlebar) || (dest == CLICK_INSIDE && bind.whole_window) || (dest == CLICK_BORDER && bind.border))
			result = run_binding(bind, con)

			xcb_allow_events(conn, XCB_ALLOW_ASYNC_POINTER, event.time)
			xcb_flush(conn)

			command_result_free(result)
			return 0
		end
	end

	if event.response_type == XCB_BUTTON_RELEASE
		xcb_allow_events(conn, XCB_ALLOW_REPLAY_POINTER, event.time)
		xcb_flush(conn)
		tree_render()
		return 0
	end

	ws = con_get_workspace(con)
	focused_workspace = con_get_workspace(focused)

	if !ws
		ws = output_get_content(con_get_output(con).focus_head)
		if !ws
			xcb_allow_events(conn, XCB_ALLOW_REPLAY_POINTER, event.time)
			xcb_flush(conn)
			tree_render()
			return 0
		end
	end

	if ws != focused_workspace
		workspace_show(ws)
	end

	floating_con = con_inside_floating(con)
	proportional = event.state & XCB_KEY_BUT_MASK_SHIFT == XCB_KEY_BUT_MASK_SHIFT
	in_stacked = con.parent.layout == L_STACKED || con.parent.layout == L_STACKED

	if in_stacked && dest == CLICK_DECORATION && (event.detail == XCB_BUTTON_SCROLL_UP || event.detail == XCB_BUTTON_DOWN || event.detail == XCB_BUTTON_SCROLL_LEFT || event.detail == XCB_BUTTON_SCROLL_RIGHT)
		orientation = con.parent.layout == L_STACKED ? VERT : HORIZ
		focused = con.parent
		con_activate(focused)
		scroll_prev_possible = nodes_head.prev
		scroll_next_possible = focused.next
		if event.detail == XCB_BUTTON_SCROLL_UP || event.detail == XCB_BUTTON_SCROLL_LEFT && scroll_next_possible
			tree_next('p', orientation)
		else
			tree_next('n', orientation)
		end

		xcb_allow_events(conn, XCB_ALLOW_REPLAY_POINTER, event.time)
		xcb_flush(conn)
		tree_render()
		return 0
	end

	con_activate(con)

	fs = ws ? con_get_fullscreen(ws, CF_OUTPUT) : nil
	if !floatingcon.nil? && fs != con
		if mod_pressed && event.detail == XCB_BUTTON_CLICK_LEFT
			floating_drag_window(floatingcon, event)
			return 1
		end

		if !in_stacked && dest == CLICK_DECORATION && is_left_or_right_click
			floating_drag_window(floatingcon, proportional, event)
			return 1
		end

		if !in_stacked && dest == CLICK_DECORATION && event.detail == XCB_BUTTON_CLICK_LEFT
			floating_drag_window(floatingcon, event)
			return 1
		end

		xcb_allow_events(conn, XCB_ALLOW_REPLAY_POINTER, event.time)
		xcb_flush(conn)
		tree_render()
		return 0
	end

	if in_stacked
		con = con.parent
	end

	if dest == CLICK_INSIDE && mod_pressed && event.detail == XCB_BUTTON_CLICK_RIGHT
		return 1 if floating_mod_on_tiled_client(con, event)
	elsif (dest == CLICK_BORDER || dest == CLICK_DECORATION) && is_left_or_right_click
		tiling_resize(con, event, dest)
	end
end

def handle_button_press(event)
	last_timestamp = event.time

	mod = config.floating_modifier & 0xFFFF
	mod_pressed = mod != 0 && (event.state & mod) == mod
	return route_click(con, event, mod_pressed, CLICK_INSIDE) if con = con_by_window_id(event.event)

	if con = con_by_frame_id(event.event)
		if event.event == root
			bind = get_binding_from_xcb_event(event.as(XcbGenericEvent))
			if !bind.nil? && bind.whole_window
				result = run_binding(bind, nil)
				command_result_free(result)
			end
		end

		if event.event == root && event.response_type == XCB_BUTTON_PRESS
			croot.nodes_head.each do |output|
				next if con_is_internal(output) || !rect_contains(output.rect, event.event_x, event.event_y)

				ws = output_get_content(output).focus_head.first
				if ws != con_get_workspace(focused)
					workspace_show(ws)
					tree_render()
				end
				return 1
			end
			return 0
		end

		xcb_allow_events(conn, XCB_ALLOW_REPLAY_POINTER, event.time)
		xcb_flush(conn)
	end

	con.nodes_head.each do |child|
		next if !rect_contains(child.deco_rect, event.event_x, event.event_y)

		return route_click(child, event, mod_pressed, CLICK_DECORATION)
	end

	return route_click(con, event, mod_pressed, CLICK_INSIDE) if event.child != XCB_NONE

	return route_click(con, event, mod_pressed, CLICK_BORDER)
end
