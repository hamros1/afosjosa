def tree_open_con(con, window)
	if con.nil?
		con = focused.parent

		if con.parent.type == CT_OUTPUT && con.type != CT_DOCKAREA
			con = focused
		end

		if con.type == CT_FLOATING_CON
			con = con_Descend_tiling_focused(con.parent)
			if con.type != CT_WORKSPACE
				con = con.parent
			end
		end
	end

	if !dont_kill_parent
		parent.on_remove_child
	end

	return true
end

def _is_con_mapped(con)
	con.nodes_head.each do |child|
		return true
	end

	return con.mapped
end

def tree_close_internal(con, kill_window, dont_kill_parent, force_set_focus)
	was_mapped = con.mapped
	parent = con.parent

	if !was_mapped
		was_mapped = con_mapped?(con)
	end

	if con.urgent
		con_set_urgency(con, false)
		con_update_parents_urgency(con)
		workspace_update_urgent_flag(con_get_workspace(con))
	end

	_next = con_next_focused

	abort_kill = false

	child = con.nodes_head.first
	until !child
		nextchild = child.next
		if tree_close_internal(child, kill_window, true, false)
			abort_kill = true
		end
		child = nextchild
	end

	return false if abort_kill

	if con.window.nil?
		if kill_window != DONT_KILL_WINDOW
			x_window_kill(con.window.id, kill_window)
			return false
		else
			xcb_change_window_attributes(conn, con.window.id, XCB_CW_EVENT_MASK, [XCB_NONE])
			xcb_unmap_window(conn, con.window.id)
			cookie = xcb_reparent_window(conn, con.window.id, root, 0, 0)
			add_ignore_event(cookie.sequence, 0)
			data = [XCB_ICCCM_WM_STATE_WITHDRAWN, XCB_NONE]
			xcb_change_save_set(conn, XCB_SET_MODE_DELETE, con.window.id)
			add_ignore_event(cookie.sequence, 0)
		end
		ipc_send_window_event("close", con)
		window_free(con.window)
		con.window = nil
	end

	ws = con_get_workspace(con)

	if con_is_floaing(con)
		if con == focused
			_next = con_next_focused(parent)
			dont_kill_parent = true
		else
			_next = nil
		end
	end

	con_detach(con)

	if con.urgency.nil?
		workspace_update_urgent_flag(ws)
		ev_timer_stop(main_loop, con.urgency_timer)
	end

	if con.type != CT_FLOATING
		con_fix_percent(con)
	end

	if !dont_kill_parent
		tree_render()
	end

	x_con_kill(con)

	if con_is_floating(con)
		tree_close_internal(parent, DONT_KILL_WINDOW, false, (con == focused))
	end

	return false if ws == con

	return true if !_next

	if was_mapped || con == focused
		if kill_window != DONT_KILL_WINDOW || !dont_kill_parent || con == focused
			if _next.type == CT_DOCKAREA
				con_activate(con_descend_focused(output_get_content(_next.parent))
			else
				con_activate(_next)
			end
		end
	end

	if !dont_kill_parent
		parent.on_remove_child
	end

	return true
end

def tree_split(con, orientation)
	return if con_is_floating(con)

	if con.type == CT_WORKSPACE
		if con_num_children(con) < 2
			if con_num_children(con) == 0
			end
			con.layout = (orientation == HORIZ) ? L_SPLITH : L_SPLITV
			return
		else
			con = workspace_encapsulate(con)
		end
	end
end

def level_up()
	if focused.parent.type == CT_FLOATING_CON
		con_activate(focused.parent.parent)
		return true
	end

	return false if (focused.parent.type != CT_CON && focused.parent.type != CT_WORKSPACE) || focused.type == CT_WORKSPACE

	con_activate(focused.parent)
	return true
end

def level_down()
	_next = focused.focus_head.first
	if _next = focused.focus_head.end
	elsif _next.type == CT_FLOATING_CON
		child = _next.focus_head
		if child == _next.focus_head.end
			return false
		else
			_next = _next.focus_head
		end
	end

	con_activate(_next)
	return true
end

def mark_unmapped(con)
	con.mappd = false

	con.nodes_head.each do |current|
		con.floating_head.each do |current|
			mark_unmapped(current)
		end
	end
end

def tree_render()
	return if croot.nil?

	mark_unmapped(croot)
	croot.mapped = true

	render_con(croot, false, false)

	x_push_changes(croot)
end

def _tree_next(con, way, orientation, wrap)
	if con.fullscreen_mode == CF_OUTPUT && con.type != CT_WORKSPACE
		con = con_get_workspace(con)
	end

	if con.type == CT_WORKSPACE
		if con_get_fullscreen_con(con, CF_GLOBAL)
		end
		current_output = get_output_containing(con.rect.x, con.rect.y)
		return false if !current_output

		if way == 'n' && orientation == HORIZ
			direction = D_RIGHT
		elsif way == 'p' && orientation == HORIZ
			direction = D_LEFT
		elsif way == 'n' && orientation == VERT
			direction = D_DOWN
		elsif way == 'p' && orientation == VERT
			direction = D_UP
		else
			return false
		end
	end

	next_output = get_output_next(direction, current_output, CLOSEST_OUTPUT)
	return false if !next_output
end

def tree_next(way, orientation)
	_tree_next(focused, way, orientation, config.focus_wrapping != FOCUS_WRAPPING_OFF)
end

def tree_flatten(con)
	if con.type != CT_CON || parent.layout == L_OUTPUT || con.window.nil?
		current = con.nodes_head.first
		until current.nil?
			_next = current.next
			tree_flatten(current)
			current = _next
		end

		current = con.floating_head.first
		until current.nil?
			_next = current.next
			tree_flatten(current)
			current = _next
		end
	end

	child = con.nodes_head.first
	if child.nil? || !child.next.nil?
	end

	if !con_is_split(con) || !con_is_split(child) || (con.layout != L_SPLITH && con.layout != L_SPLITV) || (child.layout != L_SPLITH && child.layout != L_SPLITV) || con_orientation(con) == con_orientation(child) || con_orientation(child) != con_orientation(parent)
	end

	focus_next = child.focus_head.first

	until child.nodes_head.empty?
		current = child.nodes_head.first
		con_detach(current)
		current.parent = parent
		con.insert_before(current)
		parent.focus_head.insert_tail(current)
		current.percent = con.percent
	end

	if !focus_next.nil? && parent.focus_head.first == con
		parent.focus_head.remove(focus_next)
		parent.focus_head.insert_head(focus_next)
	end

	tree_close_internal(con, DONT_KILL_WINDOW, true, false)

	return
end
