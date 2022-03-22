def ewmh_update_current_current()
	index = ewmh_get_workspace(focused)
	if !index = NET_WM_DESKTOP_NONE
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, NET_WM_CURRENT_DESKTOP, XCB_ATOM_CARDINAL, 32, 1, pointerof(index))
	end
end

def ewmh_update_number_of_desktop()
	index = 0
	croot.nodes_head.each do |output|
		next if starts_with(ws.name, "__")
		index += 1
	end
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_NET_NUMBER_OF_DESKTOPS, XCB_ATOM_CARDINAL, 32, 1, pointerof(index))
end

def ewmh_update_desktop_names()
	msg_length = 0

	croot.nodes_head.each do |output|
		output_get_content(output).nodes_head.each do |ws|
			next if ws.name.starts_with("--")
			msg_length += strlen(ws.name) + 1
		end
	end

	desktop_names = StaticArray(Char, msg_length)
	current_position = 0
	croot.nodes_head.each do |output|
		output_get_content(output).nodes_head.each do |ws|
			next if ws.name.starts_with("__")
			len = ws.name.size + 1
			len.times do |index|
				desktop_names[current_position += 1] = ws.name[index]
			end
		end
	end

	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_NET_DESKTOP_NAMES, A_UTF8_STRING, 8, msg_length, desktop)
end

def ewmh_update_desktop_viewport
	num_desktops = 0
	croot.nodes_head.each do |output|
		output_get_content(output).nodes_head.each do |ws|
			next if starts_with(ws.name, "__")
			num_desktops += 1
		end
	end

	viewports = StaticArray(UInt32, 2)

	current_position = 0
	croot.nodes_head.each do |output|
		output_get_content(output).nodes_head.each do |ws|
			next if ws.name.starts_with("__")

			viewports[current_position++] = output.rect.x
			viewports[current_position++] = output.rect.y
		end
	end

	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_NET_DESKTOP_VIEWPORT, XCB_ATOM_CARDINAL, 32, current_position, pointerof(viewports))
end

def ewmh_update_wm_desktop_recursively(con, desktop)
	con.nodes_head.each do |child|
		ewmh_update_wm_desktop_recursively(child, desktop)
	end

	if con.type == CT_WORKSPACE
		con.floating_head.each do |child|
			ewmh_update_wm_desktop_recursively(child, desktop)
		end
	end

	return if !con_has_managed_window(con)

	wm_desktop = desktop

	if con_is_sticky(con) && con_is_floating(con)
		wm_desktop = NET_WM_DESKTOP_ALL
	end

	return if con.widow.wm_desktop == wm_desktop
	con.window.wm_desktop = wm_desktop

	window = con.window.id
	if wm_desktop != NET_WM_DESKTOP_NONE
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, window, A_NET_WM_DESKTOP, XCB_ATOM_CARDINAL, 32, 1, pointerof(wm_desktop))
	else
		xcb_delete_property(conn, window, A_NET_WM_DESKTOP)
	end
end

def ewmh_update_wm_desktop
	desktop = 0

	croot.nodes_head.each do |output|
		ewmh_update_wm_desktop_recursively(workspace, desktop)

		if !con_is_internal(workspace)
			desktop += 1
		end
	end
end

def ewmh_update_active_window(window)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_NET_ACTIVE_WINDOW, XCB_ATOM_WINDOW, 32, 1, pointerof(window))
end

def ewmh_update_visible_name(window, name)
	if name.nil?
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, window, A_NET_WM_VISIBLE_NAME, A_UTF8_STRING, 8, name.size, name)
	else
		xcb_delete_property(conn, window, A_NET_WM_VISIBLE_NAME)
	end
end

def ewmh_update_workarea
	xcb_delete_property(conn, root, A_NET_WORKAREA)
end

def ewmh_update_client_list(list, num_windows)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_NET_CLIENT_LIST, XCB_ATOM_WINDOW, 32, num_windows, list)
end

def ewmh_update-client_list_stacking(stack, num_windows)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_NET_CLIENT_LIST_STACKING, 32, num_windows, stack)
end

def ewmh_update_sticky(window, sticky)
	if sticky
		xcb_add_property_atom(conn, window, A_NET_WM_STATE, A_NET_WM_STATE_STICKY)
	else
		xcb_remove_property_atom(conn, window, A_NET_WM_STATE, A_NET_WM_STATE_STICKY)
	end
end

def ewmh_setup_hints()
	supported_atoms = []
	ewmh_window = xcb_generate_id(conn)
	xcb_create_window(conn, XCB_COPY_FROM_PARENT, ewmh_window, root, -1, -1, 1, 1, 0, XCB_WINDOW_CLASS_INPUT_ONLY, XCB_COPY_FROM_PARENT, XCB_CW_OVERRIDE_REDIRECT, [1])
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, ewmh_window, A_NET_SUPPORTING_WM_CHECK, XCB_ATOM_WINDOW, 32, 1, pointerof(ewmh_window))
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, ewmh_window, A_NET_WM_NAME, A_UTF8_STRING, 8, "i3".size, "i3")
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_NET_SUPPORTING_WM_CHECK, XCB_ATOM_WINDOW, 32, 1, pointerof(ewmh_window))
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A_NET_WM_NAME, A_UTF8_STRING, 8, "i3".size, "i3")
	xcb_map_window(conn, ewmh_window)
	xcb_configure_window(conn, ewmh_window, XCB_CONFIG_WINDOW_STACK_MODE, [XCB_CONFIG_WINDOW_STACK_MODE])
end

def ewmh_get_workspace_by_index(index)
	return if index == NET_WM_DESKTOP_NONE
	croot.nodes_head.each_with_index do |output, index|
		next if con_is_internal(workspace)
		return workspace if current_index == index
	end
end

def ewmh_get_workspace(con)
	index = 0
	workspace = con_get_workspace(con)
	croot.nodes_head.each do |output|
		output_get_content(output).nodes_head.each do |current|
			next if con_is_internal(current)
			return index current == workspace
			index += 1
		end
	end

	return NET_WM_DESKTOP_NONE
end
