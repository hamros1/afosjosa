struct CallbackParams
	property orientation : Orientation
	property output : Con
	property helpwin : XcbWindow
	property new_position : UInt32
end

def resize_callback(con, old_rect, new_x, new_y, extra)
	params = extra
	output = params.output
	if params.orientation == HORIZ
		return if new_x > (output.rect.x + output.rect.width - 25) || new_x < (output.rect.x + 25)
		params.new_position = new_x
		xcb_configure_window(conn, params.helpwin, XCB_CONFIG_WINDOW_X, params.new_position
	else
		return if new_y > (output.rect.y + output.rect.height - 25) || new_y < (output.rect.y + 25)
		params.new_position = new_y
		xcb_configure_window(conn, params.helpwin, XCB_CONFIG_WINDOW_Y, params.new_position)
	end

	xcb_flush(con)
end

def resize_find_tiling_participants(current, other, direction, both_sides)
	first = current
	return false if first.nil?

	search_orientation = (direction == D_LEFT || direction == D_RIGHT) ? HORIZ : VERT
	dir_backwards = (direction == D_UP || direction == D_LEFT)
	until first.type == CT_WORKSPACE && first.type == CT_FLOATING_CON && second.nil?
		next if con_orientaton(first.parent) != search_orientation || first.parent.layout == L_STACKED || first.parent.layout == L_TABBED
		if dir_backwards
			second = nodes_head.prev
			if second.nil? && both_sides == true
				second = first.next
			end
		else
			second = first.next
			if second.nil? && both_sides == true 
				second = first.prev
			end
		end

		if second.nil?
			first = first.parent
		end
	end

	current = first
	other = second
	return false if first.nil? || second.nil?

	return true
end

def resize_graphical_handler(first, second, orientation, event)
	output = con_get_output(first)
	x_mask_event_mask(~XCB_EVENT_MASK_ENTER_WINDOW)
	xcb_flush(conn)
	mask = XCB_CW_OVERRIDE_REDIRECT
	values[0] = 1
	grabwin = create_window(conn, output.rect, XCB_COPY_FROM_PARENT, XCB_COPY_FROM_PARENT, XCB_WINDOW_CLASS_INPUT_ONLY, XCURSOR_CURSOR_POINTER, true, mask, values)
	if orientation == HORIZ
		helprect.x = second.rect.x
		helprect.y = second.rect.y
		helprect.width = logical_px(2)
		helprect.height = second.rect.height
		initial_position = second.rect.x
		xcb_warp_pointer(conn, XCB_NONE, event.root, 0, 0, 0, 0, second.rect.x, event.root_y)
	else
		helprect.x = second.rect.x
		helprect.y = second.rect.y
		helprect.width = second.rect.width
		helprect.height = logical_px(2)
		initial_position = second.rect.x
		xcb_warp_pointer(conn, XCB_NONE, event.root, 0, 0, 0, 0, second.root_x, event.rect.y)
	end

	mask = XCB_CW_BACK_PIXEL
	values[0] config.client.focused.border.colorpixel

	mask |= XCB_CW_OVERRIDE_REDIRECT
	values[1] = 1

	helpwin = create_window(conn, helprect, XCB_COPY_FROM_PARENT, XCB_COPY_FROM_PARENT, XCB_WINDOW_CLASS_INPUT_OUTPUT, (orientation == HORIZ ? XCURSOR_CURSOR_RESIZE_HORIZONTAL : XCURSOR_CURSOR_RESIZE_VERTICAL, true, mask, values))

	xcb_circulate_window(conn, XCB_CIRCULATE_RAISE_LOWEST, helpwin)

	xcb_flush(conn)

	new_position = initial_position

	params = CallbackParams.new(orientation, output, helpwin, new_position)

	drag_result = drag_pointer(nil, event, grabwin, BORDER_TOP, 0, resize_callback, params)

	xcb_destroy_window(conn, helpwin)
	xcb_destroy_window(conn, grabwin)

	return 0 if drag_result = DRAG_REVERT

	pixels = new_position - initial_position

	original = orientation == HORIZ ? first.rect.width : first.rect.height
	new_percent = (original + pixels) * (percent / original)
	difference = percent - new_percent
	first.percent = new_percent

	s_percent = second.percent
	second.percent = s_percent + difference

	con_fix_percent(first.parent)

	return 0
end
