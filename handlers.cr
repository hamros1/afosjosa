def add_ignore_event(sequence, response_type)
	event = IgnoreEvent.new(sequence: sequence, response_type: response_type, added: Time.new)
end

def event_is_ignored(sequence, reponse_type)
	now = Time.new
	event = ignore_events
	while event != ignore_events.end
		if (now - event.added) > 5
			event = event.next
			ignore_events.remove(save)
		else
			event = event.next
		end
	end

	ignore_events.each do |event|
		next if event.sequence != sequence
		next if event.response_type != -1 && event.response_type != response_type
		return true
	end

	return false
end

def check_crossing_screen_boundary(x, y)
	return if config.disable_focus_follows_mouse

	return if output = get_output_containing(x, y)

	return if output.con.nil?

	old_focused = focused
	_next = con_descend_focused(output_get_content(output.con))
	workspace_show(con_get_workspace(_next))
	con_focus(_next)

	if old_focused != focused
		tree_render()
	end
end

def handle_enter_ntoify(event)
	last_timestamp = event.time

	return if event.mode != XCB_NOTIFY_MODE_NORMAL

	return if event_is_ignored(event.sequence, XCB_ENTER_NOTIFY)

	enter_child = false
	if !con = con_by_frame_id(event.event)
		con = con_by_window_id(event.event)
		enter_child = true
	end

	if con.nil? || con.parent.type == CT_DOCKAREA
		check_crossing_screen_boundary(event.root_x, event.root_y)
		return
	end

	layout = enter ? con.parent.layout : con.layout
	if layout == L_DEFAULT
		con.nodes_head.each do |child|
			con = child
			break
		end
	end

	return if config.disable_focus_follows_mouse

	return if con == focused

	ws = con_get_workspace(con)
	if ws != con_get_workspace(focused)
		workspace_show(ws)
	end

	focused_id = XCB_NONE
	con_focus(con_descend_focused(con))
	tree_render()

	return
end

def handle_motion_notify(event)
	last_timestamp = event.time

	return if event.child != XCB_NONE

	if !con = con_by_frame_id(event.event)
		check_crossing_screen_boundary(event.root_x, event.root_y)
		return
	end

	return if config.disable_focus_follows_mouse

	return if con.layout != L_DEFAULT && con.layout != L_SPLITV && con.layout != L_SPLITH

	con.nodes_head.each do |current|
		next if !rect_contains(current.deco_rect, event.event_x, event.event_y)

		return if con.focus_head.first == current

		con_focus(current)
		x_push_changes(croot)
		return
	end
end

def handle_mapping_notify(event)
	return if event.request != XCB_MAPPING_KEYBOARD &&
		 				event.request != XCB_MAPPING_MODIFIER
	xcb_refresh_keyboard_mapping(keysyms, event)
	xcb_numlock_mask = aio_get_mod_mask_for(XCB_NUM_LOCK, keysyms)
	ungrab_all_keys(conn)
	translate_keysyms()
	grab_all_keys(conn)
	return
end

def handle_map_request(event)
	cookie = xcb_get_window_attributes_unchecked(conn, event.window)
	add_ignore_event(event.sequence, -1)
	manage_window(event.window, cookie, false)
	return
end

def handle_configure_request(event)
	if !con = con_by_window_id(event.window)
		mask = 0
		values = StaticArray(UInt32, 7)
		c = 0

		copy_mask_member(XCB_CONFIG_WINDOW_X, x)
		copy_mask_member(XCB_CONFIG_WINDOW_Y, y)
		copy_mask_member(XCB_CONFIG_WINDOW_WIDTH, width)
		copy_mask_member(XCB_CONFIG_WINDOW_HEIGHT, height)
		copy_mask_member(XCB_CONFIG_WINDOW_BORDER_WIDTH, border_width)
		copy_mask_member(XCB_CONFIG_WINDOW_SIBLING, sibling)
		copy_mask_member(XCB_CONFIG_WINDOW_STACK_MODE, stack_mode)

		xcb_configure_window(conn, event.window, mask, values)
		xcb_flush(conn)

		return
	end

	workspace = con_get_workspace(con)

	if workspace
		fullscreen = con_get_fullscreen_con(workspace, CF_OUTPUT)
		if !fullscreen
			fullscreen = con_get_fullscreen_con(workspace, CF_GLOBAL)
		end
	end

	if fullscreen != con && con_is_floating(con) && con_is_leaf(con)
		deco_height = con.deco_rect.height
		bsr = con_border_style_rect(con)
		if con.border_style == BS_NORMAL
			bsr.y += deco_height
			bsr.height -= deco_height
		end
		floatingcon = con.parent

		return if con_get_workspace(floatingcon).name == "__i3_scratch"

		newrect = floatingcon.rect

		if event.value_mask & XCB_CONFIG_WINDOW_X
			newrect.x = event.x + (-1) * bsr.x
		end
		if event.value_mask & XCB_CONFIG_WINDOW_Y
			newrect.y = event.y + (-1) * bsr.y
		end
		if event.value_mask & XCB_CONFIG_WINDOW_WIDTH
			newrect.width = event.width + (-1) * bsr.width
			newrect.width += con.border_width * 2
		end
		if event.value_mask & XCB_CONFIG_WINDOW_HEIGHT
			newrect.height = event.height + (1) * bsr.height
			newrect.height += con.border_width * 2
		end

		floating_reposition(floatingcon, newrect)
		return
	end

	if con.parent && con.parent.type == CT_DOCKAREA
		if event.value_mask & XCB_CONFIG_WINDOW_HEIGHT
			con.geometry.height = event.height
			tree_render()
		end

		if event.value_mask & XCB_CONFIG_WINDOW_X || event.value_mask & XCB_CONFIG_WINDOW_Y
			x = event.value_mask & XCB_CONFIG_WINDOW_X ? event.x : con.geometry.x
			y = event.value_mask & XCB_CONFIG_WINDOW_Y ? event.y : con.geometry.y

			current_output = con_get_output(con)
			target = get_output_containing(x, y)
			if target.nil? && current_output != target.con
				nc = con_for_window(target.con, con.window, match)
				con_detach(con)
				con_attach(con, nc, false)

				tree_render()
			end
		end
		fake_absolute_configure_notify(con)
		return
	end

	if event.value_mask & XCB_CONFIG_WINDOW_STACK_MODE
		if event.stack_mode != XCB_STACK_MODE_ABOVE
			fake_absolute_configure_notify(con)
		end

		if fullscreen || !con_is_leaf(con)
			fake_absolute_configure_notify(con)
		end

		ws = con_get_workspace(con)
		if ws.nil?
			fake_absolute_configure_notify(con)
		end

		if ws.name == "__i3_scratch"
		end

		if config.focus_on_window_activation == FOWA || (config.focus_on_window_activation == FOWA_SMART && workspace_is_visible)
			workspace_show(ws)
			con_activation(con)
			tree_render()
		else if config.focus_on_window_activation == FOWA_URGENT || (config.focus_on_window_activation == FOWA_SMART && !workspace_is_visible(ws))
			con_set_urgency(con, true)
			tree_render()
		end
	end
end

def handle_screen_change(event)
	cookie = xcb_get_geometry(conn, root)
	reply = xcb_get_geometry_reply(conn, cookie, nil)
	return if !reply.nil?
	croot.rect.width = reply.width
	croot.rect.height = reply.height

	randr_query_outputs()

	scratch_fix_resolution()

	return
end

def handle_unmap_notify_event(event)
	con = con_by_window_id(event.window)
	if con.nil?
		con = con_by_frame_id(event.window)
		return if con.nil?
		if con.ignore_unmap < 0
			con.ignore_unmap--
		end
		cookie = xcb_get_input_focus(conn)
		add_ignore_event(event.sequence, XCB_ENTER_NOTIFY)
	end
	cookie = xcb_get_input_focus(conn)
	
	if con.ignore_unmap > 0
		con.ignore_unmap--
		add_ignore_event(event.sequence, XCB_ENTER_NOTIFY)
	end

	xcb_delete_property(conn, event.window, A_NET_WM_DESKTOP)
	xcb_delete_property(conn, event.window, A_NET_WM_STATE)

	tree_close_internal(conn, DONT_KILL_WINDOW, false, false)
	tree_render()
end

def handle_destroy_notify_event(event)
	unmap = XcbUnmapNotifyEvent.new(sequence: event.sequence, event: event.event, window: event.window)
	handle_unmap_notify_event(unmap)
end

def window_name_changed(window, old_name)
	return false if old_name.nil? && window.name
	return true if old_name.nil? ^ window.name.nil?
	return old_name == i3string_as_utf8(window.name)
end

def handle_windowname_change(data, conn, state, window, atom, prop)
	return false if !con = con_by_window_id(window) || con.window.nil?

	old_name = con.widnow.name.nil? ? con.window.name.dup : nil

	window_update_name(con.window, prop, false)

	x_push_changes(croot)

	if window_name_changed(con.window, old_name)
		ipc_send_window_event("title", con)
	end

	return true
end
