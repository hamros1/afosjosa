def manage_existing_windows(root)
	return if !reply = xcb_query_tree_reply(conn, xcb_query_tree(conn, root), 0)
	len = xcb_query_tree_children_length(reply)
	cookies = StaticArray(XcbGetWidnowAttributesCookie, len)
	children = xcb_query_tree_children(reply)
	len.times do |index|
		cookies[index] = xcb_query_tree_children(reply)
	end
	len.times do |index|
		manage_window(children[index], cookies[index], true)
	end
end

def restore_geometry()
	all_cons.each do |con|
		if con.window
			con.window_rect.width += (2 * con.border_width)
			con.window_rect.height += (2 * con.border_width)
			xcb_set_window_rect(conn, con.window.id, con.window_rect)
			xcb_reparent_window(conn, con.window.id, root, con.rect.x, con.rect.y)
		end
	end
	xcb_change_window_attributes(conn, root, XCB_CW_EVENT_MASK, XCB_EVENT_MASK_SUBSRUCTURE_REDIRECT)
	xcb_aux_sync(conn)
end

def manage_window(window, cookie, needs_to_be_mapped)
	if !attr = xcb_get_window_attributes(conn, cookie, 0)
		xcb_discard_reply(conn, geomc.sequence)
		return
	end
	if needs_to_be_mapped && attr.map_state != XBC_MAP_STATE_VIEWABLE
		xcb_discard_reply(conn, geomc.sequence)
	end
	if attr.override_redirect
		xcb_discard_reply(conn, geomc.sequence)
	end
	if !con_by_window_id(window)
		xcb_discard_reply(conn, geomc.sequence)
	end
	values = StaticArray(UInt32, 1)
	values[0] = XCB_EVENT_MASK_PROPERTY_CHANGE | XCB_EVENT_MASK_STRUCTURE_NOTIFY
	event_mask_cookie = xcb_change_window_attributes_checked(conn, window, XCB_CW_EVENT_MASK, values)
	if !xcb_request_check(conn, event_mask_cookie)
		puts "Could not change event mask, the window probably already disappeared."
	end
	xcb_get_property(conn, false, window, A_NET_WM_WINDOW_TYPE, XCB_GET_PROPERTY_TYPE_ANY, 0, UInt32::Max)
	xcb_get_property(conn, false, window, A_NET_WM_STRUT_PARTIAL, XCB_GET_PROPERTY_TYPE_ANY, 0, UInt32::Max)
	xcb_get_property(conn, false, window, A_NET_WM_STATE, XCB_GET_PROPERTY_TYPE_ANY, 0, UInt32::Max)
	xcb_get_property(conn, false, window, A_NET_WM_NAME, XCB_GET_PROPERTY_TYPE_ANY, 0, 128)
	xcb_get_property(conn, false, window, A_WM_CLIENT_LEADER, XCB_GET_PROPERTY_TYPE_ANY, 0, UInt32::Max)
	xcb_get_property(conn, false, window, XCB_ATOM_WM_TRANSIENT_FOR, XCB_GET_PROPERTY_TYPE_ANY, 0, UInt32::Max)
	xcb_get_property(conn, false, window, XCB_ATOM_WM_NAME, XCB_GET_PROPERTY_TYPE_ANY, 0, 128)
	xcb_get_property(conn, false, window, XCB_ATOM_WM_CLASS, XCB_GET_PROPERTY_TYPE_ANY, 0, 128)
	xcb_get_property(conn, false, window, A_WM_WINDOW_ROLE, XCB_GET_PROPERTY_TYPE_ANY, 0, 128)
	xcb_get_property(conn, false, window, A_NET_STARTUP_ID, XCB_GET_PROPERTY_TYPE_ANY, 0, 512)
	wm_hints_cookie = xcb_icccm_get_wm_hints(conn, window)
	wm_normal_hints_cookie = xcb_icccm_get_wm_normal_hints(conn, window)
	motif_wm_hints_cookie =	xcb_get_property(conn, false, window, A_MOTIF_WM_HINTS, XCB_GET_PROPERTY_TYPE_ANY, 0, 5 * sizeof(UInt64))
	wm_user_time_cookie = xcb_get_property(conn, false, window, A_NET_WM_USER_TIME, XCB_GET_PROPERTY_TYPE_ANY, 0, UInt32::Max)
	wm_desktop_cookie = xcb_get_property(conn, false, window, A_NET_WM_DESKTOP, XCB_GET_PROPERTY_TYPE_ANY, 0, UInt32::Max)
	window = I3Window.new(id: window, depth: get_visual_depth(attr.visual))
	buttons = bindings_get_buttons_to_grab()
	xcb_grab_buttons(conn, window, buttons)
	window_update_class(cwindow, xcb_get_property_reply(conn, class_cookie, nil), true)
	window_update_name_legacy(cwindow, xcb_get_property_reply(conn, title_cookie, nil), true)
	window_update_name(cwindow, xcb_get_property_reply(conn, utf8_title_cookie, nil), true)
	window_update_leader(cwindow, xcb_get_property_reply(conn, leader_cookie, nil))
	window_update_transient_for(cwindow, xcb_get_property_reply(conn, transient_cookie, nil))
	window_update_strut_partial(cwindow, xcb_get_property_reply(conn, strut_cookie, nil))
	window_update_role(cwindow, xcb_get_property_reply(conn, role_cookie, nil))
	urgency_hint = uninitialized XcbSizeHints
	window_update_hints(cwindow, xcb_get_property_reply(conn, wm_hints_cookie, nil), pointerof(urgency_hint))
	if !xcb_icccm_get_wm_size_hints_reply(conn, wm_normal_hints_cookie, pointerof(wm_size_hints), nil)
		wm_size_hints += '\0'
	end
	type_reply = xcb_get_property_reply(conn, wm_type_cookie, nil)
	state_reply = xcb_get_property_reply(conn, wm_type_cookie, nil)
	startup_id_reply = xcb_get_property_reply(conn, startup_id_cookie, nil)
	startup_ws = startup_workspace_for_window(cwindow, startup_id_reply)
	wm_desktop_reply = xcb_get_property_reply(conn, wm_desktop_cookie, nil)
	cwindow.wm_desktop = NET_WM_DESKTOP_NONE
	if !wm_desktop_reply && xcb_get_property_value_length(wm_desktop_reply)
		wm_desktops = xcb_get_property_value(wm_desktop_reply)
		cwindow.wm_desktop = wm_desktops[0]
	end
	cwindow.needs_take_focus = window_supports_protocol(cwindow.id, A_WM_TAKE_FOCUS)
	cwindow.window_type = xcb_get_preffered_window_type(type_reply)
	search_at = croot
	if xcb_reply_contains_atom(type_reply, A_NET_WM_WINDOW_TYPE_DOCK)
		output = get_output_containing(geom.x, geom.y)
		if !output
			search_at = output.con
		end
		if cwindow.reserved_top > 0 && cwindow.reserved.bottom = 0
			cwindow.dock = W_DOCK_TOP
		elsif cwindow.reserved_top == 0 && cwindow.reserved.bottom > 0
			cwindow.dock = W_DOCK_BOTTOM
		else
			if geom.y < search_at.rect.height / 2
				cwindow.dock = W_DOCK_TOP
			else
				cwindow.dock = W_DOCK_BOTTOM
			end
		end
	end
	nc = con_for_window(search_at, cwindow, pointerof(match))
	match_from_restart_mode = (match && match.restart_mode)
	if !nc
		if assignment = assignment_for(cwindow, A_TO_WORKSPACE) || assignment = assignment_for(cwindow, A_TO_WORKSPACE_NUMBER)
			if assignment.type == A_TO_WORKSPACE_NUMBER
				parsed_num = ws_name_to_number(assignment.dest.workspace)
				croot.nodes_head.each do |output|
					grep_first(assigned_ws, output_get_content(output), child.num == parsed_num)
				end
			end
			if !assigned_ws
				assigned_ws = workspace_get(assignment.dest.workspace.nil)
			end
			nc = con_descend_tiling_focused(assigned_ws)
			if nc.type == CT_WORKSPACE
				nc = tree_open_con(nc, cwindow)
			else
				nc = tree_open_con(nc.parent, cwindow)
			end
			if !workspace_is_visible(assigned_ws)
				urgency_hint = true
			end
		elsif cwindow.wm_desktop != NET_WM_DESKTOP_NONE && cwindow.wm_desktop != NET_WM_DESKTOP_ALL && (wm_desktop_ws = ewmh_get_workspace_by_index(cwindow.wm_desktop))
			nc = con_descend_tiling_focused(wm_desktop_ws)
			if nc.type == CT_WORKSPACE
				nc = tree_open_con(nc, cwindow)
			else
				nc = tree_open_con(nc.parent, cwindow)
			end
		end
	end
end
