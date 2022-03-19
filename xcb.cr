def create_window(conn, dims, depth, visual, window_class, cursor, map, mask, values)
	result = xcb_generate_id(conn)
	
	if window_class == XCB_WINDOW_CLASS_INPUT_ONLY
		depth = XCB_COPY_FROM_PARENT
		visual = XCB_COPY_FROM_PARENT
	end

	gc_cookie = xcb_create_window(conn, depth, result, root, dims.x, dims.y, dims.width, dims.height, 0, window_class, visual, mask, values)

	error = xcb_request_check(conn, gc_cookie)

	if xcursor_supported
		mask = XCB_CW_CURSOR
		values[0] = xcursor_get_cursor(cursor)
		xcb_change_window_attributes(conn, result, mask, values)
	else
		cursor_id = xcb_generate_id(conn)
		cursor_font = load_font("cursor", false)
		xcb_cursor = xcursor_get_xcb_cursor(cursor)
		xcb_create_glyph_cursor(conn, cursor_id, cursor_font.specific.xcb.id, cursor_font.specific.xcb.id, xcb_cursor, xcb_cursor + 1, 0, 0, 0, 65535, 65535, 65535)
		xcb_change_window_attributes(conn, result, XCB_CW_CURSOR, pointerof(cursor_id))
		xcb_free_cursor(conn, cursor_id)
	end

	if map
		xcb_map_window(conn, result)
	end

	return result
end

def fake_absolute_configure_notify(con)
	return if con.window.nil?

	absolute.x = con.rect.x + con.window_rect.x
	absolute.y = con.rect.y + con.window_rect.y
	absolute.width = con.window_rect.width
	absolute.height = con.window_rect.height

	fake_configure_notify(conn, absolute, con.window.id, con.border_width)
end

def send_take_focus(window, timestamp)
	ev = XcbClientMessageEvent.new(
		response_type: XCB_CLIENT_MESSAGE,
		window: window,
		type: A_WM_PROTOCOLS,
		format: 32,
		data: XcbClientMessageData.new(
			data32: [A_WM_TAKE_FOCUS, timestamp]
		)
	)

	xcb_send_event(conn, false, window, XCB_EVENT_MASK_NO_EVENT, ev.as(Char*))
end

def xcb_set_window_rect(conn, window, r)
	cookie = xcb_configure_window(conn, window, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y | XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, pointerof(r.x))
	add_ignore_event(cookie.sequence, -1)
end

def xcb_get_preferred_window_type(reply)
	return XCB_NONE if reply.nil? || xcb_get_property_value_length(reply) == 0
	return XCB_NONE if atoms = xcb_get_property_vaslue(reply).nil?

	(xcb_get_propery_value_length(reply) / (reply.format / 8)).times do |index|
		if atoms[index] == A__NET_WM_WINDOW_TYPE_NORMAL ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_DIALOG ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_UTILITY ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_TOOLBAR ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_SPLASH ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_MENU ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_DROPDOWN_MENU ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_POPUP_MENU ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_TOOLTIP ||
				atoms[index] == A__NET_WM_WINDOW_TYPE_NOTIFICATION
			return atoms[index]
		end
	end

	return XCB_NONE
end

def xcb_reply_contains_atom(prop, atom)
	return false if prop.nil? || xcb_get_property_value_length(prop) == 0
	return false if atoms = xcb_get_property_value(prop).nil?

	(xcb_get_property_value_length(prop) / (prop.format / 8)).times do |index|
		return true if atoms[index] == atom
	end

	return false
end

def get_visual_depth(visual_id)
	depth_iter = xcb_screen_allowed_depths_iterator(root_screen)
	until !depth_iter.rem
		visual_iter = xcb_depth_visuals_iterator(depth_iter.data)
		until !visual_iter.rem
			return depth_iter.data.depth if visual_id == visual_iter.data.visual_id
			xcb_visualtype_next(pointerof(visual_iter))
		end
		xcb_depth_next(pointerof(defpth_iter))
	end

	return 0
end

def get_visualtype_by_id(visual_id)
	depth_iter = xcb_screen_allowed_depths_iterator(root_screen)
	until !depth_iter.rem
		visual_iter = xcb_depth_visuals_iterator(depth_iter.data)
		until !visual_iter.rem
			return visual_iter.data if visual_id == visual_iter.data.visual_id
			xcb_visualtype_next(depth_iter.data)
		end
		xcb_depth_next(pointerof(depth_iter))
	end

	return 0
end

def get_visualid_by_depth(depth)
	depth_iter = xcb_screen_allowed_depths_iterator(root_screen)
	until !depth_iter.rem
		next if depth_iter.data.depth != depth
		visual_iter = xcb_depth_visuals_iterator(depth_iter.data)
		next if !visual_iter.rem
		return visual_iter.data.visual_id
	end

	return 0
end

def xcb_add_property_atom(conn, window, property, atom)
	xcb_change_property(conn, XCB_PROP_MODE_APPEND, window, property, XCB_ATOM_ATOM, 32, 1, atom.as(UInt32[]))
end

def xcb_remove_property_atom(conn, window, property, atom)
	xcb_grab_server(conn)

	reply = xcb_get_property_reply(conn, xcb_get_property(conn, false, window, property, XCB_GET_PROPERTY_TYPE_ANY, 0, 4096, nil))

	if reply.nil? || xcb_get_property_value_length(reply) == 0
		xcb_ungrab_server(conn)
	end
	if atoms = xcb_get_property_value(reply).nil?
		xcb_ungrab_server(conn)
	end
	num = 0
	current_size = xcb_get_property_value_length(reply) / (reply.format / 8)
	current_size.times do |index|
		if atoms[index] != atom
			values[num += 1] = atoms[index]
		end

		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, window, property, XCB_ATOM_ATOM, 32, num, values)
	end

	xcb_ungrab_server(conn)
end

def xcb_grab_buttons(conn, window, buttons)
	index = 0
	until buttons[index] == 0
		xcb_grab_button(conn, false, window, XCB_EVENT_MASK_BUTTON_PRESS, XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC, root, XCB_NONE, buttons[index], XCB_BUTTON_MASK_ANY)
		index += 1
	end
end
