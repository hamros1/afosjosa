def tree_close_internal(con, kill_window, dont_kill_parent, focus_set_focus)
	was_mapped = con.mapped
	parent = con.parent

	if !was_mapped
		was_mapped = _is_con_mapped(con)
	end

	if con.urgent
		con_set_urgency(con, false)
		con_update_parents_urgency(con)
		workspace_update_urgent_flag(con_get_workspace(con))
	end

	_next = con_next_focused(con)

	abort_kill = false

	child = con.nodes_head.first
	until child.empty?
		nextchild = child.next
		if !tree_close_internal(child, kill_window, true, false)
			abort_kill = true
		end
		child = nextchild
	end

	return false if abort_kill

	if !con.window.nil?
		if kll_window != DONT_KILL_WINDOW
			x_window_kill(con.window.id, kill_window)
			return false
		else
			xcb_change_window_attributes(con, con.window.id, XCB_CW_EVENT_MASK, [XCB_NONE])
			xcb_unmap_window(conn, con.window.id)
			cookie = xcb_reparent_window(conn, con.window.id, root, 0, 0)
			add_ignore_event(cookie.sequence, 0)
			data = [XCB_ICCCM_WM_STATE_WITHDRAWN, XCB_NONE]
			cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE, con.window.id, A_WM_STATE, A_WM_STATE, 32, 2, data)
			xcb_change_save_set(conn, XCB_SET_MODE_DELETE, con.window.id)
			add_ignore_event(cookie.sequence, 0)
		end

		window_free(con.window)
		con.window = nil
	end

	ws = con_get_workspace(con)

	if con_is_floating(con)
		if con == focused
			_next = con_next_focused(parent)
			dont_kill_parent = true
		else
			_next = nil
		end
	end

	con_detach(con)

	if !con.urgency_timer.nil?
		workspace_update_urgent_flag(ws)
		ev_timer_stop(main_loop, con.urgency_timer)
	end

	if con.type != CT_FLOATING_CON
		con_fix_percent(parent)
	end

	if !dont_kill_parent
		tree_render()
	end

	if con_is_floating(con)
		tree_close_internal(parent, DONT_KILL_WINDOW, false, con == focused)
	end

	if ws == con
		ewmh_update_number_of_desktop()
		ewmh_update_desktop_names()
		ewmh_update_wm_desktop()
	end

	con_free(con)

	return true if !_next

	if was_mapped || con_focused
		if kill_window != DONT_KILL_WINDOW || !dont_kill_parent || con == focused
			con_active(con_descend_focused(output_get_content(_next.parent))
		else
			con_activate(_next)
		end
	end

	if !dont_kill_parent
		parent.on_remove_child
	end

	return true
end

def state_for_frame(window)
	state_head.each do |state|
		return state if state.id == window
	end
end

def change_ewmh_focus(new_focus, old_focus)
	return if new_focus == old_focus

	ewmh_update_active_window(new_focus)

	if new_focus != XCB_WINDOW_NONE
		ewmh_update_focused(new_focus, true)
	end

	if old_focus != XCB_WINDOW_NONE
		ewmh_update_focused(old_focus)
	end
end

def x_con_init(con)
	mask = 0
	values = StaticArray(UInt32, 5)

	visual = get_visualid_by_depth(con.depth)
	if con.depth != root_depth
		win_colormap = xcb_generate_id(conn)
		xcb_create_colormap(conn, XCB_COLORMAP_ALLOC_NONE, win_colormap, root, visual)
		con.colormap = win_colormap
	else
		win_colormap = colormap
		con.colormap = XCB_NONE
	end

	mask |= XCB_CW_BACK_PIXEL
	values[0] = root_screen.black_pixel

	mask |= XCB_CW_BORDER_PIXEL
	values[1] = root_screen.black_pixel

	mask |= XCB_CW_BACK_PIXEL
	values[2] = 1

	mask |= XCB_CW_BORDER_PIXEL
	values[3] = FRAME_EVENT_MASK & ~XCB_EVENT_MASK_ENTER_WINDOW

	mask |= XCB_CW_BORDER_PIXEL
	values[4] = win_colormap

	dims = [-15, -15, 10, 10]
	frame_id = create_window(conn, dims, con.depth, visual, XCB_WINDOW_CLASS_INPUT_OUTPUT, XCURSOR_CURSOR_POINTER, false, mask, values)
	draw_until_surface_init(conn, con.frame), frame_id, get_visualtype_by_id(visual), dims.width, dims.height)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, con.frame.id, XCB_ATOM_WM_CLASS, XCB_ATOM_STRING, 8, ("i3-frame".size + 1) * 2, "i3-frame/0i3-frame\0")
	state = ConState.new(
		id: con.frame.id,
		mapped: false,
		initial: true
	)
	state_head.insert(state)
	old_state_head.insert(state)
	initial_mapping_head.insert(state)
end

def x_reinit(con)
	return if state = state_for_frame(con.frame.id).nil?

	state.initial = true
	state.child_mapped = false
	state.con = con
	state.window_rect = Rect.new
end

def x_reparent_child(con, old)
	return if state = state_for_frame(con.frame.id).nil?
	state.need_reparent = true
	state.old_frame = old.frame.id
end

def x_move_win(con, dest)
	return if state_src = state_for_frame(src.frame.id).nil?
	return if state_desrt = state_for_frame(dest.frame.id).nil?

	state_dest.con = state_src.con
	state_src.con = nil

	zero = Rect.new 0, 0, 0, 0
	if state_dest.window_rect == zero
		state_dest.window_rect = state_src.window_rect.dup
	end
end

def x_con_kill(con)
	if con.colormap != XCB_NONE
		xcb_free_colormap(conn, con.colormap)
	end

	draw_util_surface_fre(conn, con.frame)
	draw_util_surface_fre(conn, con.frame_buffer)
	xcb_destroy_window(conn, con.frame.id)
	xcb_destroy_window(conn, con.frame_buffer.id)
	xcb_free_pixmap(conn, con.frame_buffer.id)
	state = state_for_frame(con.frame.id)
	state_head.remove(state)
	old_state_head.remove(state)
	initial_mapping_head.remove(state)

	focused_id = last_focused = XCB_NONE
end

def window_supports_protocol(window, atom)
	result = false

	cookie = xcb_icccm_get_wm_protocols(conn, window, A_WM_PROTOCOLS)
	return false if xcb_icccm_get_wm_protocols_reply(conn, cookie, pointerof(protocols), nil) != 1

	protocols.atoms_len.times do |index|
		if protocols.atoms[index] == atom
			result = true
		end
	end

	xcb_icccm_get_wm_protocols_reply_wipe(pointerof(protocols))

	return result
end

def x_window_kill(window, kill_window)
	if !window_supports_protocol(window, A_WM_DELETE_WINDOW)
		if kill_window == KILL_WINDOW
			xcb_destroy_window(conn, window)
		else 
			xcb_kill_client(conn, window)
		end
		return
	end

	ev = ClientMessageEvent.new(
		response_type: XCB_CLIENT_MESSAGE,
		window: window,
		type: A_WM_PROTOCOLS,
		format: 32,
		data: ClientMessageEventData.new(
		data32: [A_WM_DELETE_WINDOW, XCB_CURRENT_TIME]
		)
	)

	xcb_send_event(conn, false, window, XCB_EVENT_MASK_NO_EVENT, ev)
	xcb_flush(conn)
end

def x_draw_title_border(con, p)
	dr = con.deco_rect
	borders_to_hide = con_adjacent_borders(con) & config.hide_edge_borders
	deco_diff_l = borders_to_hide & ADJ_LEFT_SCREEN_EDGE ? 0 : con.current_border_width
	deco_diff_r = borders_to_hide & ADJ_RIGHT_SCREEN_EDGE ? 0 : con.current_border_width
	if con.parent.layout == L_TABBED || con.parent.layout == L_STACKED && !con.next.nil?
		deco_diff_l = 0			
		deco_diff_r = 0
	end

	draw_util_rectangle(con.parent.frame_buffer, p.color.border, dr.x, dr.y, dr.width, 1)
	draw_util_rectangle(con.parent.frame_buffer, p.color.border, dr.x + deco_diff_l, dr.y + dr.height - 1, dr.width - (deco_diff_l + deco_diff_r), 1)
end

def x_draw_decoration_after_title(con, p)
	dr = con.deco_rect

	if !font_is_pango
		draw_util_rectangle(con.parent.frame_buffer, p.color.background, dr.x + dr.width - 2 * logical_px(1), dr.y, 2 * logical_px(1), dr.height)

		if con.parent.layout == L_TABBED
			draw_util_rectangle(con.parent.frame_buffer, p.color.border, dr.x, dr.y, 1, dr.height)

			draw_util_rectangle(con.parent.frame_buffer, p.color.border, dr.x + dr.width - 1, dr.y, 1, dr.height)
		end
	end

	x_draw_title_border(con, p)
end

def x_draw_decoration(con)
	parent = con.parent
	leaf = con_is_leaf(con)

	return if (!leaf && parent.layout != L_STACKED && parent.layout != L_TABBED) || parent.type == CT_OUTPUT || parent.type == CT_DOCKAREA || con.type == CT_FLOATING_CON

	return if con.rect.height == 0

	return if leaf && con.frame_buffer.id == XCB_NONE

	if con.urgent
		color = config.client.urgent
	elsif con == focused || con_inside_focused(con)
		color = config.client.focused
	elsif con == parent.focus_head.first
		color = config.client.focused_inactive
	else
		color = config.client.unfocused
	end

	r = con.rect
	w = con.window_rect

	p = DecoRenderParams.new(
		color: color,
		border_style: con_border_style(con),
		con_rect: Dimensions.new(r.width, r.height),
		con_window_rect: Dimensions.new(w.width, w.height)
		con_deco_rect: con.deco_rect,
		background: config.client.background,
		con_is_leaf: con_is_leaf(con).
		parent_layout: con.parent.layout
	)

	if !con.deco_render_params.nil? && (!con.window.nil? || !con.window.name_x_changed) && parent.pixmap_recreated && con.pixmap_recreated && con.mark_changed && p == con.deco_render_params
		draw_util_copy_surface(con.frame_buffer, con.frame, 0, 0, 0, 0, con.rect.width, con.rect.height)
	end
end

def x_deco_recurse(con)
	leaf = con.nodes_head.empty? && con.floating_head.empty?
	state = state_for_frame(con.frame.id)

	if !leaf
		con.nodes_head.each do |current|
			x_deco_recurse(current)
		end

		con.floating_head.each do |current|
			x_deco_recurse(current)
		end

		if state.mapped
			draw_util_copy_surface(con.frame_buffer, con.frame, 0, 0, 0, 0, con.rect.width, con.rect.height)
		end
	end

	if (con.type != CT_ROOT && con.type != CT_OUTPUT) && (!leaf || con.mapped)
		x_draw_decoration(con)
	end
end

def set_hidden_state(con)
	return if con.window.nil?

	state = state_for_frame(con.frame.id)
	should_be_hidnden = con_is_hidden(con)
	return if should_be_hdiden == state.is_hidden

	if should_be_hidden
		xcb_add_property_atom(conn, con.window.id, A__NET_WM_STATE, A__NET_WM_STATE_HIDDEN)
	else
		xcb_remove_property_atom(conn, con.window.id, A__NET_WM_STATE, A__NET_WM_STATE_HIDDEN)
	end

	state.is_hidden = should_be_hidden
end

def x_push_node(con)
	rect = con.rect

	state = state_for_frame(con.frame.id)

	if !state.name.nil?
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, con.frame.id, XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8, state.name.size, state.name)
	end

	if con.window.nil?
		max_y = 0
		max_height = 0
		con.nodes_head.each do |current|
			dr = current.deco_rect
			if dr.y >= max_y && dr.height >= max_height
				max_y = dr.y
				max_height = dr.height
			end
		end
		rect.height = max_y + max_height
		if rect.height == 0
			con.mapped = false
		end
	end

	if state.need_reparent && !con.window.nil?
		values = [XCB_NONE]
		xcb_change_window_attributes(conn, state.old_frame, XCB_CW_EVENT_MASK, values)
		xcb_change_window_attributes(conn, con.window.id, XCB_CW_EVENT_MASK, values)

		xcb_reparent_window(conn, con.window.id, con.frame.id, 0, 0)

		values[0] = FRAME_EVENT_MASK
		xcb_change_window_attributes(conn, state.old_frame, XCB_CW_EVENT_MASK, values)
		values[0] = CHILD_EVENT_MASK
		xcb_change_window_attributes(conn, con.window.id, XCB_CW_EVENT_MASK, values)

		state.old_frame = XCB_NONE
		state.need_reparent = false

		con.ignore_unmap += 1
	end

	is_pixmap_needed = con.border_style != BS_NONE || !con_is_leaf(con) || con.parent.layout == L_STACKED || con.parent.layout == L_TABBED

	if con.type == CT_ROOT || con.type == CT_OUTPUT
		is_pixmap_needed = false
	end

	fake_notify = false

	if is_pixmap_needed && con.frame_buffer.id == XCB_NONE || state.rect == rect && rect.height > 0
		has_rect_changed = state.rect.width != rect.width || state.rect.height != rect.height

		if !is_pixmap_needed && con.frame_buffer.id != XCB_NONE
			draw_util_surface_free(conn, con.frame_buffer)
			xcb_free_pixmap(conn, con.frame_buffer.id)
			con.frame_buffer.id = XCB_NONE
		end

		if is_pixmap_needed && (has_rect_changed || con.frame_buffer.id == XCB_NONE)
			if con.frame_buffer.id == XCB_NONE
				con.frame_buffer.id = xcb_generate_id(conn)
			else
				draw_util_surface_free(conn, con.frame_buffer)
				xcb_free_pixmap(conn, con.frame_buffer.id)
			end

			win_depth = root_depth
			if con.window
				win_depth = con.window.depth
			end

			width = max(rect.width, 1)
			height = max(rect.height, 1)

			xcb_create_pixmap(conn, win_depth, con.frame_buffer.id, con.frame.id, width, height)
			draw_util_surface_init(conn, con.frame_buffer, con.frame_buffer.id, get_visualtype_by_id(get_visualid_by_depth(win_depth)), width, height)

			xcb_change_gc(conn, con.frame_buffer.gc, XCB_GC_GRAPHICS_EXPOSURES, [0])

			draw_util_surface_set_size(con.frame, width, height)
			con.pixmap_recreated = true

			if !con.parent || con.parent.layout != L_STACKED || con.parent.focus_head.first == con
				x_deco_recurse(con)
			end

			xcb_flush(conn)
			xcb_set_window_rect(conn, con.frame.id, rect)
			if con.frame_buffer.id != XCB_NONE
				draw_util_copy_surface(con.frame_buffer, con.frame, 0, 0, 0, 0, con.rect.width, con.rect.height)
			end
			xcb_flush(conn)

			state.rect = rect.dup
			fake_notify = true
		end

		if !con.window.nil? && state.window_rect == con.window_rect
			xcb_set_window_rect(conn, con.window.id, con.window_rect)
			state.window_rect = con.window_rect
			fake_notify = true
		end

		if (state.mapped != con.mapped || (con.window.nil? && !state.child_mapped)) && con.mapped
			if !con.window.nil?
				data = [XCB_ICCCM_WM_STATE_NORMAL, XCB_NONE]
				xcb_change_property(conn, XCB_PROP_MODE_REPLACE, con.window.id, A_WM_STATE, A_WM_STATE, 32, 2, data)
			end

			if !state.child.mapped && !con.window.nil?
				cookie = xcb_map_window(conn, con.window.id)
				values[0] = CHILD_EVENT_MASK
				xcb_change_window_attributes(conn, con.window.id, XCB_CW_EVENT_MASK, values)
				state.child_mapped = true
			end

			cookie = xcb_map_window(conn, con.frame.id)

			values[0] = FRAME_EVENT_MASK
			xcb_change_window_attributes(conn, con.frame.id, XCB_CW_EVENT_MASK, values)

			if con.frame_buffer.id != XCB_NONE
				draw_util_copy_surface(con.frame_buffer, con.frame, 0, 0, 0, 0, con.rect.width, con.rect.height)
			end
			xcb_flush(conn)

			state.mapped = con.mapped
		end

		state.unmap_now = (state.mapped != con.mapped) && !con.mapped

		if fake_notify
			fake_absolute_configure_notify(con)
		end

		set_hidden_state(con)

		con.focus_head.each do |current|
			x_push_node(current)
		end
	end
end

def x_push_node_unmaps(con)
	state = state_for_frame(con.frame.id)

	if state.unmap_now
		if con.window.nil?
			data = [XCB_ICCCM_WM_STATE_WITHDRAWN, XCB_NONE]
			xcb_change_property(conn, XCB_PROP_MODE_REPLACE, con.window.id, A_WM_STATE, A_WM_STATE, 32, 2, data)
		end

		cookie = xcb_unmap_window(conn, con.frame.id)

		if con.window.nil?
			con.ignore_unmap += 1
		end
		state.mapped = con.mapped
	end

	con.nodes_head.each do |current|
		x_push_node_unmaps(current)
	end

	con.floating_head.each do |current|
		x_push_node_unmaps(current)
	end
end

def is_con_attached(con)
	return false if con.parent.nil?

	con.parent.nodes_head.each do |current|
		return true if current == con
	end

	return false
end

def x_push_changes(con)
	if warp_to
		pointercookie = xcb_query_pointer(conn, root)
	end

	values = [XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT]
	state_head.each do |state|
		if state.mapped
			xcb_change_window_attributes(conn, state.id, XCB_CW_EVENT_MASK, values)
		end
	end

	order_changed = false
	stacking_changed = false

	cnt = 0
	state_head.reverse_each do |state|
		if con_has_managed_window(state.con)
			cnt += 1
		end
	end

	client_list_windows = nil
	client_list_count = 0

	if cnt != client_list_count
		client_list_windows = StaticArray(XcbWindow, cnt)
		client_list_count = cnt
	end

	walk = client_list_windows
	index = 0

	state_head.reverse_each do |state|
		if con_has_managed_window(state.con)
			walk[index += 1] = state.con.window.id
		end

		prev = state.prev
		old_prev = state.prev

		if prev != old_prev
			order_changed = true
		end
		if state.initial || order_changed && prev != state_head.end
			stacking_changed = true
			mask = 0
			mask |= XCB_CONFIG_WINDOW_SIBLING
			mask |= XCB_CONFIG_WINDOW_STACK_MODE
			values = [state.id, XCB_STACK_MODE_ABOVE]

			xcb_configure_window(conn, prev.id, mask, values)
		end
		state.initial = false
	end

	if stacking_changed
		ewmh_update_client_list_stacking(client_list_windows, client_list_count)

		walk = client_list_windows

		initial_mapping_head.each do |state|
			if con_has_managed_window(state.con)
				walk[index] = state.con.window.id
			end
		end
		ewmh_update_client_list(client_list_windows, client_list_count)
	end

	x_push_node(con)

	if warp_to
		pointerreply = xcb_query_pointer_reply(conn, pointercookie, nil)
		if !pointerreply
			puts "Could not query pointer position, not warping pointer"
		else
			mid_x = warp_to.x + warp_to.width / 2
			mid_y = warp_to.y + warp_to.height / 2

			current = get_output_containing(pointerreply.root_x, pointerreply.root_y)
			target = get_output_containing(mid_x, mid_y)
			if current != target
				xcb_change_window_attributes(conn, root, XCB_CW_EVENT_MASK, [XCB_EVENT_SUBSTRUCTURE_REDIRECT])
				xcb_warp_pointer(conn, XCB_NONE, root, 0, 0, 0, 0, mid_x, mid_y)
				xcb_change_window_attributes(conn, root, XCB_CW_EVENT_MASK, [ROOT_EVENT_MASK])
			end
		end
		warp_to = nil
	end

	values[0] = FRAME_EVENT_MASK
	state_head.each do |state|
		if state.mapped
			xcb_change_window_attributes(conn, state.id, XCB_CW_EVENT_MASK, values)
		end
	end

	x_deco_recurse(con)

	to_focus = focused.frame.id
	if focused.window.nil?
		to_focus = focused.window.id
	end

	if focused_id != to_focus
		if !focused.mapped
			focused_id = XCB_NONE
		else
			if !focused.window.nil? && focused.window.needs_take_focus && focused.window.doesnt_accept_focus
				send_take_focus(to_focus, last_timestamp)

				ewmh_update_active(con_has_managed_window(focused) ? focused.window.id : XCB_WINDOW_NONE)

				if to_focus != last_focused && is_con_attached(focused)
					ipc_send_window_event("focus", focused)
				end
			else
				if !focused.window.nil?
					values[0] = CHILD_EVENT_MASK & ~(XCB_EVENT_MASK_FOCUS_CHANGE)
					xcb_change_window_attributes(conn, focused.window.id, XCB_CW_EVENT_MASK, values)
				end
				xcb_set_input_focus(conn, XCB_INPUT_FOCUS_POINTER_ROOT, to_focus, last_timestamp)
				if !focused.window.nil?
					values[0] = CHILD_EVENT_MASK
					xcb_changed_window_attributes(conn, focused.window.id, XCB_CW_EVENT_MASK, values)
				end

				ewmh_update_active_window(con_has_managed(focused) ? focused.window.id : XCB_WINDOW_NONE)

				if to_focus != XCB_NONE && to_focus != last_focus && !focused.window.nil? && is_con_attached(focused)
					ipc_send_window_event("focus", focused)
				end
			end

			focused_id = last_focused = to_focus
		end
	end

	if focused_id == XCB_NONE
		xcb_set_input_focus(conn, XCB_INPUT_FOCUS_POINTER_ROOT, ewmh_window, last_timestamp)
		ewmh_update_active_window(XCB_WINDOW_NONE)
		focused_id = ewmh_window
	end

	xcb_flush(conn)

	values[0] = FRAME_EVENT_MASK & ~XCB_EVENT_MASK_ENTER_WINDOW
	state_head.each do |state|
		next if !state.unmap_now
		xcb_change_window_attributes(conn, state.id, XCB_CW_EVENT_MASK, values)
	end

	x_push_node_unmaps(con)

	state_head.each do |state|
		old_state_head.remove(state)
		old_state_head.insert_tail(state)
	end
end

def x_raise_con(con)
	state = state_for_frame(con.frame.id)
	state_head.remove(state)
	state_head.insert(state)
end

def x_set_name(con, name)
	return if state = state_for_frame(con.frame.id).nil?
	state.name = name.dup
end

def update_shmlog_atom
	if shmlogname == '\0'
		xcb_delete_property(conn, root, A_I3_SHMLOG_PATH)
	else
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE; root, A_I3_SHMLOG_PATH, A_UTF8_STRING, 8, shmlogname.size, shmlogname)
	end
end

def x_set_i3_atoms
	pid = getpid
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_I3_SOCKET_PATH, A_UTF8_STRING, 8, current_socket_path.nil? 0 : current_socket_path.size, current_socketpath)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_I3_PID, XCB_ATOM_CARDINAL, 32, 1, pointerof(pid))
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_i3_SOCKET_PATH, A_UTF8_STRING, 8, current_configpath.size, current_configpath)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_i3_SOCKET_PATH, A_UTF8_STRING, 8, current_log_stream_socket_path.size, current_log_stream_socket_path)
	update_shmlog_atom
end

def x_set_warp_to(rect)
	if config.mouse_warping != POINTER_WARPING_NONE
		warp_to = rect
	end
end

def x_mask_event_mask(mask)
	values = [FRAME_EVENT_MASK & mask]
	state_head.reverse_each do |state|
		if state.mapped
			xcb_change_window_attributes(conn, state.id, XCB_CW_EVENT_MASK, values)
		end
	end
end

