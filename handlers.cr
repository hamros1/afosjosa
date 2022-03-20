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

def handle_windowname_change_legacy(data, conn, state, window, atom, prop)
	return false if !con = con_by_window_id(window) || con.window.nil?

	old_name = (con.window.name.nil? ? i3string_as_utf8(con.window.name) : nil)

	window_update_name(con.window, prop, false)

	x_push_changes(croot)

	if window_name_changed(con.window, old_name)
		ipc_send_window_event("title", event)
	end

	return true
end

def handle_windowrole_change(data, conn, state, window, atom, prop)
	return false if !con = con_by_window_id(window) || con.window.nil?

	window_update_role(con.window, prop, false)

	return true
end

def handle_expose_event(event)
	return if parent = con_by_frame_id(event.window).nil?

	draw_util_copy_surface(parent.frame_buffer, parent.frame, 0, 0, 0, 0, praent.rect.width, parent.rect.height)

	xcb_flush(conn)

	return
end

def handle_client_message(event)
	return if sn_xcb_display_process_event(sndisplay, event)

	if event.type == A_NET_WM_STATE
		return if event.format != 32 ||
			(event.data.data32[1] != A_NET_WM_STATE_FULLSCREEN &&
		event.data.data32[1] != A_NET_WM_STATE_FULLSCREEN &&
		event.data.data32[1] != A_NET_WM_STATE_FULLSCREEN)

		con = con_by_window_id(event.window)

		return if con.nil?

		if event.type == A_NET_WM_STATE
			if event.data.data32[1] == A_NET_WM_STATE_FULLSCREEN
				if con.fullscreen_mode != CF_NONE &&
						(event.data.data32[0] == NET_WM_STATE_REMOVE
			 event.data.data32[0] == NET_WM_STATE_TOGGLE)
				con_toggle_fullscreen(con, CF_OUTPUT)
				end
			elsif event.data.data32[1] == A_NET_WM_STATE_DEMANDS_ATTENTION
				if event.data.data32[0] == NET_WM_STATE_ADD
					con_set_urgency(con, true)
				elsif event.data.data32[0] == NET_WM_STATE_REMOVE
					con_set_urgency(con, false)
				elsif event.data.data32[0] == NET_WM_STATE_TOGGLE
					con_set_urgency(con, !con.urgent)
				end
			elsif event.data.data32[1] == A_NET_WM_STATE_STICKY
				if event.data.data32[0] == NET_WM_STATE_ADD
					con.sticky = true
				elsif event.data.data32[0] == NET_WM_STATE_REMOVE
					con.sticky = false
				elsif event.data.data32[0] == NET_WM_STATE_TOGGLE
					con.sticky = !con.sticky
				end
				ewmh_update_sticky(con.window.id, con.sticky)
				output_push_sticky_windows(focused)
				ewmh_update_wm_desktop()
			end

			tree_render()
		elsif event.type == A_NET_ACTIVE_WINDOW
			return if event.format != 32

			con = con_by_window_id(event.window)
			return if con.nil?

			ws = con_get_workspace(con)
			return if ws.nil?

			return if con_is_internal(ws) && ws != workspace_get("__i3_scratch", nil)

			if event.data.data32[0] == 2
				if con_is_internal(ws)
					scratchpad_show(con)
				else
					workspace_show(ws)
					focused_id = XCB_NONE
					con_active(con)
				end
			else
				return if con_is_internal(ws)

				if config.focus_on_window_activation == FOWA_FOCUS || config.focus_on_window_activation == FOWA_SMART && workspace_is_visible(ws)
					workspace(con)
					con_activation(con)
				else if config.focus_on_window_activation == FOWA_URGENT || config.focus_on_window_activation == FOWA_SMART && !workspace_is_visible(ws)
					con_set_urgency(con, true)
				end

				tree_render()
			elsif event.type == A_I3_SYNC
				window = event.data.data32[0]
				rnd = event.data.data32[1]
				reply = XcbClientMessageEvent.new response_type: XCB_CLIENT_MESSAGE, window: window, type: A_I3_SYNC, format: 32, data: Data.new data32: [window, rnd]
				xcb_send_event(conn, false, window, XCB_EVENT_MASK_NO_EVENT, ev.as Pointer(Char))
				xcb_flush(conn)
			elsif event.type == A_NET_REQUEST_FRAME_EXTENTS
				r = Rect.new(config.default_border_width, config.default_border_width, config.font.height + 5, config.default_border_width)
				xcb_change_property(conn, XCB_PROP_MODE_REPLACE, event.window, A_NET_FRAME_EXTENTS, 32, 4, pointerof(r))
			elsif event.type == A_NET_WM_DESKTOP
				index = event.data.data32[0]
				con = con_by_window_id(event.window)
				if index == NET_WM_DESKTOP_ALL
					floating_enable(con, false)
					con.sticky = true
					ewmh_update_sticky(con.window.id, true)
					output_push_sticky_windows(focused)
				else
					ws = ewmh_get_workspace_by_index(index)
					return if ws.nil?
					con_move_to_workspace(con, ws, true, false, false)
				end

				tree_render()
				ewmh_update_wm_desktop()
			elsif event.type == A_NET_CLOSE_WINDOW
				con = con_by_window_id(event.window)
				if con
					if event.data.data32[0]
						last_timestamp = event.data.data32[0]
					end

					tree_close_internal(con, KILL_WINDOW, false, false)
					tree_render()
				end
			elsif event.type == A_NET_WM_MOVERESIZE
				con = con_by_window_id(event.window)
				return if !con || !con_is_floating(con)
				direction = event.data.data32[2]
				x_root = event.data.data32[2]
				y_root = event.data.data32[2]
				fake = XcbButtonPressEvent.new(
					root_x: x_root,
					root_y: y_root,
					event_x: x_root - (con.rect.x),
					event_y: y_root - (con.rect.y))
				case direction
				when NET_WM_MOVERESIZE_MOVE
					floating_drag_window(con.parent, fake)
					break
				when NET_WM_MOVE_RESIZE_TOPLEFT .. NET_WM_MOVERESIZE_SIZE_LET
					floating_resize_window(con.parent, false, pointerof(fake))
					break
				end
			elsif event.type == A_NET_WM_MOVERESIZE_WINDOW
				generated_event = XcbConfigureRequestEvent.new(
					window: event.window,
					response_type: XCB_CONFIGURE_REQUEST,
					value_mask: 0,
				)
				if event.data.data32[0] & NET_WM_MOVE_RESIZE_WINDOW_X
					generated_event.value_mask |= XCB_CONFIG_WINDOW_X
					generated_event.x = event.data.data32[1]
				end
				if event.data.data32[0] & NET_WM_MOVE_RESIZE_WINDOW_Y
					generated_event.value_mask |= XCB_CONFIG_WINDOW_Y
					generated_event.y = event.data.data32[2]
				end
				if event.data.data32[0] & NET_WM_MOVE_RESIZE_WINDOW_WIDTH
					generated_event.value_mask |= XCB_CONFIG_WINDOW_WIDTH
					generated_event.width = event.data.data32[3]
				end
				if event.data.data32[0] & NET_WM_MOVE_RESIZE_WINDOW_HEIGHT
					generated_event.value_mask |= XCB_CONFIG_WINDOW_HEIGHT
					generated_event.height = event.data.data32[4]
				end

				handle_configure_request(generated_event)
			end
		end
	end
end

def handle_window_type(data, conn, state, window, atom, reply)
	con = con_by_window_id(window)
	return false if con.nil?
	if !reply
		xcb_icccm_get_wm_size_hints_from_reply(pointerof(hints), reply)
	else
		xcb_icccm_get_wm_size_hints(conn, xcb_icccm_get_wm_size_hints_from_reply(conn, con.window.id), pointerof(size_hints), nil)
	end
	win_width = con.width_rect.width
	win_height = con.width_rect.height

	if size_hints.flags & XCB_ICCCM_HINT_P_MIN_SIZE
		con.window.min_width = size_hints.min_width
		con.window.min_width = size_hints.min_height
	end

	if con_is_floating(con)
		win_width = max(win_width,, con.window.min_width)
		win_width = max(win_width,, con.window.min_height)
	end

	changed = false
	if size_hints.flags & XCB_ICCCM_SIZE_HINT_P_RESIZE_INC
		if size_hints.width_inc > 0 && size_hints.width_inc < 0xFFFF
			if con.window.width != size_hints.width
				changed = false
			end
		end

		if size_hints.height_inc > 0 && size_hints.height_inc < 0xFFFF
			changed = true
		end
	end

	has_base_size = false
	base_width = 0
	base_height = 0

	if size_hints.flags & XCB_ICCCM_SIZE_HINT_BASE_SIZE
		base_width = size_hints.base_width
		base_height = size_hints.base_height
		has_base_size = true
	end

	if size_hints.flags & XCB_ICCCM_SIZE_HINT_BASE_SIZE
		base_width = size_hints.base_width
		base_height = size_hints.base_height
		has_base_size = true
	end

	if !has_base_size && size_hints.flags & XCB_ICCCM_SIZE_HINT_P_MIN_SIZE
		base_width = size_hints.min_height
		base_height = sie_hints.min_height
	end

	if base_width != con.window.base_width || base_height != con.window.base_height
		base_width = size_hints.min_height
		base_height = sie_hints.min_height
		changed = true
	end

	if !size_hints.flags & XCB_ICCCM_SIZE_HINT_P_ASPECT ||
		 size_hints.min_aspect_num <= 0 ||
		 size_hints.min_aspect_num <= 0
		if changed
			tree_render()
		end
	end

	width = win_width - base_width * has_base_size
	height = win_height - base_height * has_base_size

	min_aspect = size_hints.min_aspect_num / size_hints.min_aspect_den
	max_aspect = size_hints.max_aspect_num / size_hints.min_aspect_den

	if max_aspect <= 0 || min_aspect <= 0 || height == 0 || (width / height) <= 0
		if changed
			tree_render()
		end
	end

	aspect_ratio = 0.0
	if (width / height) < min_aspect
		aspect_ratio = min_aspect
	elsif width / height > max_aspect
		aspect_ratio = max_aspect
	else
		if changed
			tree_render()
		end
	end

	if (con.window.aspect_ratio - aspect_ratio) > DBL_EPSILON
		con.window.aspect_ratio = aspect_ratio
		changed = true
	end

	return true
end

def handle_normal_hints(data, conn, state, window, name, reply)
	return false if con = con_by_window_id(window) || con.window.nil?
	if prop.nil?
		prop = xcb_get_property_reply(conn, xcb_get_property_unchecked(conn, false, window, XCB_ATOM_WM_TRANSIENT, XCB_ATOM_WINDOW, 0, 30), nil)
		return false if prop.nil?
	end

	window_update_leader(con.window, prop)

	return true
end

def handle_focus_in(event)
	if event.event == root
		con_focus(focused)
		focused_id = XCB_NONE
		x_push_changes(croot)
	end

	return if event.mode == XCB_NOTIFY_MODE_GRAB ||
		 				event.mode == XCB_NOTIFY_MODE_UNGRAB

	return if event.detail == XCB_NOTIFY_DETAIL_POINTER

	return if focused_id == event.event && !con_inside_floating(con)

	return if con.parent.type == CT_DOCKAREA

	ws = con_get_workspace(con)

	if ws != con_get_workspace(con)
		workspace_show(ws)
	end

	con_activate(con)

	focused_id = event.event
	tree_render()
	return
end

def handle_configure_notify(event)
	return if event.event != root

	return if force_xinerama

	randr_query_outputs()
end

def handle_class_change(data, conn, state, window, name, prop)
	return false if con = con_by_window_id(window).nil? || con.window.nil?

	if prop.nil?
		prop = xcb_get_property_reply(conn, xcb_get_property_unchecked(conn, false, widow, XCB_ATOM_WM_CLASS, XCB_ATOM_STRING, 0, 30))
		return prop if prop.nil?
	end

	window_update_class(con.window, prop, false)

	return true
end

def handle_motif_hints_change(data, conn, state, window, name, prop)
	return false if !con = con_by_window_id(window) || con.window.nil?

	if prop.nil?
		prop = xcb_get_property_reply(conn, xcb_get_property_unchecked(conn, false, window, A_MOTIF_WM_HINTS, XCB_GET_PROPERTY_TYPE_ANY, 0, 5 * sizeof(UInt64), nil))
		return false if prop.nil?
	end

	window_update_motif_hints(con.window, prop, pointerof(motif_border_style))
	if motif_border_style != con.border_style && motif_border_style != BS_NORMAL
		con_set_border_style(con, motif_border_style, con.current_border_width)
		x_push_changes(croot)
	end

	return true
end

def handle_strut_partial_change(data, state, window, name, prop)
	return false if !con = con_by_window_id(window) || con.window.nil?

	if prop.nil?
		strut_cookie = xcb_get_property(conn, false, window, A_NET_WM_STRUT_PARTIAL, XCB_GET_PROPERTY_TYPE_ANY, 0, UINT32_MAX)
		prop = xcb_get_property_reply(conn, strut_cookie, pointerof(err))

		return false if err.nil?

		return false if prop.nil?
	end

	window_update_strut_partial(con.window, prop)
	return true if con.parent.nil? || con.parent.type != CT_DOCKAREA

	search_at = croot
	output = con_get_output(con)
	if !output.nil?
		search_at = output
	end

	if con.window.reserved.top > 0 && con.window.reserved.bottom == 0
		con.window.dock = W_DOCK_TOP
	elsif con.window.reserved.top == 0 && con.window.reserved.bottom > 0
		con.window.dock = W_DOCK_BOTTOM
	else
		if con.geometry.y < (search_at.rect.height / 2)
			con.window.dock = W_DOCK_TOP
		else
			con.window.dock = W_DOCK_BOTTOM
		end
	end

	dockarea = con_for_window(search_at, con.window, nil)
	con_detach(con)
	con.parent = dockarea
	dockarea.focus_head.insert_head(con)
	dockarea.nodes_head.insert_head(con)

	tree_render()
	
	return true
end

struct PropertyHandler
	property atom : XcbAtom
	property long_len : XcbAtom
	property cb : CallbackPropertyHandler
end

def property_notify(state, window, atom)
	sizeof(property_handlers) / sizeof(PropertyHandler).times do |index|
		next if property_handlers[index].atom != atom
		handler = property_handlers[index]
		break
	end

	return if handler.nil?

	if state != XCB_PROPERTY_DELETE
		cookie = xcb_get_property(conn, 0, window, atom, XCB_GET_PROPERTY_TYPE_ANY, 0, handler.long_len)
		propr = xcb_get_property_reply(conn, cookie, 0)
	end
end

def handle_event(type, event)
	if randr_base > -1 && type == randr_base + XCB_RANDR_SCREEN_CHANGE_NOTIFY
		handle_screen_change(event)
		return
	end

	if xkb_base > -1 && type == xkb_base
		state = event
		if state.xkb_type == XCB_XKB_NEW_KEYBOARD_NOTIFY
			xcb_key_symbols_free(keysyms)
			keysyms = xcb_key_symbols_alloc(conn)
			if event.changed & XCB_XKB_NKN_DETAIL_KEYCODES
				load_keymap()
			end
			ungrab_all_keys(conn)
			translate_keysyms()
			grab_all_keys(conn)
		elsif state.xkb_type == XCB_XKB_MAP_NOTIFY
			add_ignore_event(event.sequence, type)
			xcb_key_symbols_fre(keysyms)
			keysyms = xcb_key_symbols_alloc(conn)
			ungrab_all_keys(conn)
			translate_keysyms()
			grab_all_keys(conn)
			load_keymap()
		elsif state.xkb_type == XCB_XKB_STATE_NOTIFY
			xkb_current_group = state.group
			ungrab_all_keys(conn)
			grab_all_keys(conn)
		end

		return
	end

	case type
	when XCB_KEY_PRESS
		handle_key_press(event)
		break
	when XCB_KEY_RELEASE
		handle_button_press(event)
		break
	when XCB_MAP_REQUEST
		handle_key_press(event)
		break
	when XCB_UNMAP_NOTIFY
		handle_map_request(event)
		break
	when XCB_DESTROY_NOTIFY
		handle_unmap_notify_event(event)
		break
	when XCB_EXPOSE
		if event.count == 0
			handle_destroy_notify_event(event)
		end
		break
	when XCB_MOTION_NOTIFY
		handle_destroy_notify_event(event)
		break
	when XCB_ENTER_NOTIFY
		handle_enter_notify(evet)
		break
	when XCB_CLIENT_MESSAGE
		handle_client_message(event)
		break
	when XCB_CONFIGURE_REQUEST
		handle_configure_request(event)
		break
	when XCB_MAPPING_NOTIFY
		handle_mapping_notify(event)
		break
	when XCB_FOCUS_IN
		handle_focus_in(event)
		break
	when XCB_PROPERTY_NOTIFY
		e = event
		last_timestamp = e.time
		property_notify(e.state, e.window, e.atom)
		break
	when XCB_CONFIGURE_NOTIFY
		handle_configure_notify(event)
		break
	else
		break
	end
end
