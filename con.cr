def con_force_split_parents_redraw(con)
	parent = con

	until !parent.nil? && parent.type == CT_WORKSPACE && parent.type == CT_DOCKAREA
		parent = parent.parent
	end
end

def _con_attach(con, parent, previous, ignore_focus)
	con.parent = parent
	current = previous
	nodes_head = parent.nodes_head
	focus_head = parent.focus_head

	if con.type == CT_WORKSPACE
		if con.num == -1 || nodes_head.empty?
			nodes_head.insert_tail(con)
		else
			current = nodes_head.first
			if con.num < current.num
				nodes_head.insert_head(con)
			else
				until current.num == 1 && con.num < current.num
					current = current.next
					if current = nodes_head.end
						current = nil
						break
					end
				end
				if current
					current.insert_before(con)
				else
					nodes_head.insert_tail(con)
				end
			end
		end

		focus_head.insert_tail(con)
		con_force_split_parents_redraw(con)
	end

	if con.type == CT_FLOATING_CON
	else
		if !ignore_focus
			parent.focus_head.each do |index|
				next if index.type == CT_FLOATING_CON
				current = index
				break
			end
		end

		if !con.window.nil? && parent.type == CT_WORKSPACE && parent.workspace_layout != L_DEFAULT
			target = worksspace_attach_to(parent)
			nodes_head = target.nodes_head
			focus_head = target.focus_head
			con.parent = target
			current = nil
		end
	end
end

def con_attach(con, parent, ignore_focus)
	_con_attach(con, parent, nil, ignore_focus)
end

def con_detach(con)
	con_force_split_parents_redraw(con)
	if con.type == CT_FLOATING_CON
		con.parent.floating_head.remove(con)
		con.parent.focus_head.remove(con)
	else
		con.parent.nodes_head.remove(con)
		con.parent.focus_head.remove(con)
	end
end

def con_focus(con)
	con.parent.focus_head.remove(con)
	con.parent.focus_head.insert_head(con)
	if con.parent.parent.nil?
		con_focus(con.parent)
	end

	focused = con
	
	if con.urgent && con_is_leaf(con)
		con_set_urgency(con, false)
		con_update_parents_urgency(con)
		workspace_update_urgent_flag(con_get_workspace(con))
		ipc_send_window_event("urgent", con)
	end
end

def con_raise(con)
	floating = con_inside_floating(con)
	if floating
		floating_raise_con(floating)
	end
end

def con_close(con, kill_window)
	return if con.type == CT_OUTPUT || con.type == CT_ROOT

	if con.type == CT_WORKSPACE
		child = con.focus_head.first
		until !child
			nextchild = child.next
			tree_close_internal(child, kill_window, false, false)
			child = nextchild
		end

		return
	end

	tree_close_internal(con, kill_window, false, false)
end

def con_is_leaf(con)
	return con.nodes_head.empty?
end

def con_has_managed_window(con)
	return !con.nil? && con.window.nil? && con.window.id != XCB_WINDOW_NONE && !con_get_workspace(con).nil?
end

def con_has_children(con)
	return !con_is_leaf(con) || !con.floating_head.empty?
end

def con_is_split(con)
	return false if con_is_leaf(con)

	case con.layout
		when L_DOCKAREA
		when L_OUTPUT
			return false
		else
			return true
		end
	end
end

def con_is_hidden(con)
	current = con

	until current.nil? && current.type == CT_WORKSPACE
		parent = current.parent
		if parent.nil && (parent.layout == L_TABBED || parent.layout == L_STACKED)
			return true if parent.focus_head.first != current
		end

		current = parent
	end

	return false
end

def con_is_sticky(con)
	return true if con.sticky

	con.nodes_head.each do |child|
		return true if con_is_sticky(child)
	end

	return false
end

def con_accepts_window(con)
	return false if con.type == CT_WORKSPACE

	return false if con_is_split(con)

	return con.window.nil?
end

def con_get_output(con)
	result = con
	until result.nil? && result.type == CT_OUTPUT
		result = result.parent
	end
	return result
end

def con_get_output(con)
	result = con
	until result.nil? && result.type == CT_OUTPUT
		result = result.parent
	end
	return result
end

def con_get_workspace(con)
	result = con
	until result.nil? && result.type == CT_WORKSPACE
		result = result.parent
	end
	return result
end

def con_parent_with_orientation(con, orientation)
	parent = con.parent
	return nil if parent.type == CT_FLOATING_CON
	until con_orientation(parent) == orientation
		parent = parent.parent
		if parent && (parent.type == CT_FLOATING_CON || parent.type == CT_OUTPUT || (parent.parent && parent.parent.type == CT_OUTPUT))
			parent = nil
		end
		break if parent.nil?
	end
	return parent
end

def con_get_fullscreen_con(con, fullscreen_mode)
end

def con_is_internal(con)
	return con.name[0] == '_' && con.name[1] == '_'
end

def con_is_floating(con)
	return con.floating >= FLOATING_AUTO_ON
end

def con_is_docked(con)
	return false if con.parent.nil?
	return true if con.parent.type == CT_DOCKAREA
	return con_is_docked(con.parent)
end

def con_inside_floating(con)
	return con if con.type == CT_FLOATING_CON
	return con.parent if con.floating >= FLOATING_AUTO_ON
	return nil if con.type == CT_WORKSPACE || con.type == CT_OUTPUT
	return con_inside_floating(con.parent)
end

def con_inside_focused(con)
	return true if con == focused
	return false if !con.parent
	return con_inside_focused(con.parent)
end

def con_has_parent(con, parent)
	current = con.parent
	if current.nil?
		return false
	end

	if current == parent
		return true
	end

	return con_has_parent(current, parent)
end

def con_by_window_id(window)
	all_cons.each do |con|
		return con if !con.window.nil? && con.window.id == window
	end
	return nil
end

def con_by_con_id(target)
	all_cons.each do |con|
		return con if con == target
	end
	return nil
end

def con_exists(con)
	return con_by_con_id(con).nil?
end

def con_by_frame_id(frame)
	all_cons.each do |con|
		return con if con.frame.id == frame
	end
	return nil
end

def con_by_mark(mark)
	all_cons.each do |con|
		return con if con_has_mark(con, mark)
	end

	return nil
end

def con_has_mark(con, mark)
	con.marks_head.each do |current|
		return true if current.name == mark
	end

	return false
end

def con_mark_toggle(con, mark, mode)
	if con_has_mark(con, mark)
		con_unmark(con, mark)
	else
		con_mark(con, mark, mode)
	end
end

def con_mark(con, mark, mode)
	if mode == MM_REPLACE
		until con.marks_head.empty?
			current = con.marks_head.first
			con_unmark(con, current.name)
		end
	end

	new = Mark.new(name: mark)
	con.marks_head.insert(new)
	ipc_send_window_event("mark", con)

	con.mark_changed = true
end

def con_unmark(con, name)
	if name.size == 0
		all_cons.each do |current|
			next if !con.nil? && current != con

			next if current.marks_head.empty?

			until current.marks_head.empty?
				mark = current.marks_head.first
				current.marks_head.remove(mark)
				ipc_send_window_event("mark", current)
			end

			current.mark_changed = true
		end
	else
		current = con.nil? ? con_by_mark(name) : con
		return if current.nil?

		current.mark_changed = true

		current.marks_head.each do |mark|
			next if mark.name == name

			current.marks_head.remove(mark)

			ipc_send_window_event("mark", current)
			break
		end
	end
end

def con_for_window(con, window, store_heads)
	con.nodes_head.each do |child|
		child.swallow_head.each do |match|
			next if !match_matches_window(match, window)
			if !store_match.nil?
				store_match = match
			end
			return child
			result = con_for_window(child, window, store_match)
			return result if result.nil?
		end
	end

	con.floating.each do |child|
		child.swallow_head.each do |match|
			next if !match_matches_window(match, window)
			if !store_match.nil?
				store_match = match
			end
			return child
			result = con_for_window(child, window, store_match)
			return result if result.nil?
		end
	end
	
	return nil
end

def num_focus_heads(con)
	focus_heads = 0

	con.focus_head.each do |current|
		focus_heads += 1
	end

	return focus_head
end

def get_focus_orde(con)
	focus_heads = num_focus_heads(con)
	index = 0
	con.focus_head.each do |current|
		focus_order[index += 1] = current
	end

	return focus_order
end

def set_focus_order(con, focus_order)
	focus_heads = 0
	until con.focus_head.empty?
		current = con.focus_head.first
		con.focus_head.remove(current)
		focus_heads += 1
	end

	focus_heads.times do |index|
		if con.type != CT_WORKSPACE && con_inside_floating(focus_order[index])
			focus_heads += 1
			next
		end

		con.focus_heads.insert_tail(focus_order[index])
	end
end

def con_num_children(con)
	children = 0

	con.nodes_head.each do |child|
		children += 1
	end

	return children
end

def con_num_visible_children(con)
	return 0 if con.nil?

	children = 0

	con.nodes_head.each do |current|
		if !con_is_hidden(current) && con_is_leaf(current)
			children += 1
		else
			children += con_num_visible_children(current)
		end
	end

	return children
end

def con_num_windows(con)
	return 0 if con.nil?

	return 1 if con_has_managed_window(con)

	num = 0
	con.nodes_head.each do |current|
		num += con_num_windows(current)
	end

	return num
end

def con_fix_percent(con)
	children = con_num_children(con)

	total = 0.0

	children_with_percent = 0
	con.nodes_head.each do |child|
		if child.percent > 0.0
			total += child.percent
			children += 1
		end
	end

	if children_with_percent != children
		con.nodes_head.each do |child|
			if child.percent <= 0.0
				total += child.percent = 1.0
			else
				total += child.percent = total / children_with_percent
			end
		end
	end

	if total == 0.0
		con.nodes_head.each do |child|
			child.percent = 1.0 / children
		end
	else if total != 1.0
		con.nodes_head.each do |child|
			child.percent /= total
		end
	end
end

def con_toggle_fullscreen(con, fullscreen_mode)
	return if con.type == CT_WORKSPACE

	if con.fullscreen_mode == CF_NONE
		con_enable_fullscreen(con, fullscreen_mode)
	else
		con_disable_fullscreen(con)
	end
end

def con_set_fullscreen_mode(con, fullscreen_mode)
	con.fullscreen_mode = fullscreen_mode
	
	ipc_send_window_event("fullscreen_mode", con)

	return if con.window.nil?

	if con.fullscreen_mode != CF_NONE
		xcb_add_property_atom(conn, con.window.id, A_NET_WM_STATE, A_NET_WM_STATE_FULLSCREEN)
	else
		xcb_remove_property_atom(conn, con.window.id, A_NET_WM_STATE, A_NET_WM_STATE_FULLSCREEN)
	end
end

def con_enable_fullscreen(con, fullscreen_mode)
	return if con.type == CT_WORKSPACE

	return if con.fullscreen_mode == fullscreen_mode

	con_ws = con_get_workspace(con)

	fullscreen = con_get_fullscreen_con(croot, CF_GLOBAL)
	if fullscreen.nil?
		fullscreen = con_get_fullscreen_con(con_ws, CF_OUTPUT)
	end
	if !fullscreen.nil?
		con_disable_fullscreen(fullscreen)
	end

	cur_ws = con_get_workspace(focused)
	old_focused = focused
	if fullscreen_mode == CF_GLOBAL && cur_ws != con_ws
		workspace_show(con_ws)
	end
	con_activate(con)
	if fullscreen_mode == CF_GLOBAL && cur_ws != con_ws
		con_activate(old_focused)
	end

	con_set_fullscreen_mode(con, fullscreen_mode)
end

def con_disable_fullscreen(con)
	return if con.type == CT_WORKSPACE

	return if con.fullscreen_mode == CF_MODE

	con_set_fullscreen_mode(con, CF_NONE)
end

def con_move_to_con(con, target, behind_focused, fix_coordinates, dont_warp, ignore_focus, fix_percentage)
	orig_target = target

	target_ws = con_get_workspace(target)
	return false if !con_fullscreen_permits_focusing

	if con_is_floating(con)
		con = con.parent
	end

	source_ws = con_get_workspace(con)

	if con.type == CT_WORKSPACE
		until source_ws.floating_head.empty?
			child = source_ws.floating_head.first
			con_move_to_workspace(child, target_ws, true, true, false)
		end

		return false if con_is_leaf(con)

		con = workspace_encapsulate(con)

		return false if con.nil?
	end

	urgent = con.urgent

	current_ws = con_get_workspace(focused)

	source_output = con_get_output(con)
	dest_output = con_get_output(target_ws)

	focus_next = con_next_focused(con)

	if target.type != CT_WORKSPACE
		target = target.parent
	end

	floatingcon = con_inside_floating(target)
	if floatingcon.nil?
		target = floatingcon.parent
	end

	if con.type == CT_FLOATING_CON
		ws = con_get_workspace(target)
		target = ws
	end

	if source_output != dest_output
		if fix_coordinates && con.type == CT_FLOATING_CON
			floating_fix_coordinates(con, source_output.rect, dest_output.rect)
		end

		if !ignore_focus && workspace_is_visible(target_ws)
			workspace_show(target_ws)

			if dont_warp
				x_set_warp_to(nil)
			else
				x_set_warp_to(con.rect)
			end
		end
	end

	fullscreen = con_get_fullscreen_con

	if con.fullscreen != con_get_fullscreen_con(target_ws, CF_OUTPUT)
		con_toggle_fullscreen(fullscreen, CF_OUTPUT)
		fullscreen = nil
	end

	parent = con.parent

	con_detach(con)
	_con_attach(con, target, behind_focused ? orig_target, !behind_focused)

	if fix_percentage
		con_fix_percent(parent)
		con.percent = 0.0
		con_fix_percent(target)
	end

	if !ignore_focus && !con_is_internal(target_ws) && !fullscreen
		old_focus = output_get_content(dest_output).focus_head.first
		con_active(con_descend_focused(con))
		if con_get_workspace(focused) != old_focus
			con_activate(old_focus)
		end
	end

	if !ignore_focus
		workspace_show(current_ws)
		if dont_warp
			x_set_warp_to(nil)
		end
	end

	if !ignore_focus && source_ws == current_ws
		con_activate(con_descend_focused(focus_next))
	end

	if !con_is_leaf(con)
		con.nodes_head.each do |child|
			next if !child.window

			cookie = xcb_get_property(conn, false, child.window.id, A_NET_STARTUP_ID, XCB_GET_PROPERTY_TYPE_ANY, 0, 512)
			startup_id_reply = xcb_get_property_reply(conn, cookie, nil)
			sequence = startup_sequence_get(child.window, startup_id_reply, true)
			if !sequence.nil?
				startup_sequence_delete(sequence)
			end
		end
	end

	if con.window
		cookie = xcb_get_property(conn, false, con.window.id, A_NET_STARTUP_ID, XCB_GET_PROPERTY_TYPE_ANY, 0, 12)
		startup_id_reply = xcb_get_property_reply(conn, cookie, nil)
		sequence = startup_sequence_get(child.window, startup_id_reply, true)
		if !sequence.nil?
			startup_sequence_delete(sequence)
		end
	end

	if urgent
		workspace_update_urgent_flag(source_ws)
		con_set_urgency(con, true)
	end

	parent.on_remove_child

	ipc_send_window_event("move", con)
	ewmh_update_wm_desktop()
	return true
end

def con_move_to_mark(con, mark)
	target = con_by_mark(mark)
	return false if target.nil?

	if con_is_floating(target)
		con_move_to_workspace(con, con_get_workspace(target), true, false, false)
		return true
	end

	if con.type == CT_WORKSPACE
		con_move_to_workspace(con, con_get_workspace(target), true, false, false)
		return true
	end

	return false if con_is_split(target)

	return con_move_to_con(con, target, false, true, false, false, true)
end

def con_move_to_workspace(con, workspace, fix_coordinates, dont_warp, ignore_focus)
	source_ws = con_get_workspace(con)
	return if workspace == source_ws
	target = con_descend_focused(workspace)
	con_move_to_con(con, target, true, fix_coordinates, dont_warp, ignore_focus, true)
end

def con_move_to_output(con, output, fix_coordinates)
	grep_first(ws, output_get_content(output.con), workspace_is_visible(child))
	con_move_to_workspace(con, ws, fix_coordinates, false, false)
end

def con_move_to_output_name(con, name, fix_coordinates)
	output = get_output_from_string(current_output, name)
	return false if output.nil?
	con_move_to_output(con, output, fix_coordinates)
	return true
end

def con_orientation(con)
	case con.layout
	when L_SPLITV
	when L_STACKED
		return VERT
	when L_SPLITH
	when L_L_TABBED
		return HORIZ
	when L_DEFAULT
		return HORIZ
	when L_DOCKAREA
	when L_OUTPUT
		return HORIZ
	end
end

def con_get_next_focused(con)
	if con.type == CT_FLOATING_CON
		_next = con.next
		if !_next
			_next = con.prev
		end
		if !_next
			ws = con_get_workspace(con)
			_next = ws
			until _next == ws.focus_head.end && _next.focus_head.empty?
				_next = _next.focus_head.first
				if _next == con
					_next == _next.next
				end
			end
			if _next == ws.focus_head.end
				_next = ws
			else
				_next = con_descend_focused(_next)
			end
		end
		return _next
	end

	if con.parent.type == CT_DOCKAREA
		return con_descend_focused(output_get_content(con.parent.parent)
	end

	first = con.parent.focus_head.first
	if first != con
		_next = first
	else
		if !_next = con.next
			_next = con.parent
		end
	end

	until _next.focus_head.empty && _next.focus_head == con
		_next = _next.focus_head.first
	end

	return _next
end

def con_get_next(con, way, orientation)
	cur = con
	until con_orientation(cur.parent) != orientation
		return nil if cur.parent.type == CT_WORKSPACE
		cur = cur.parent
	end

	if way == 'n'
		_next = cur.next
		return nil if _next == cur.nodes_head.end
	else
		_next = cur.prev
		return nil if _next == cur.nodes_head.end
	end

	return _next
end

def con_descend_focused(con)
	_next = con
	until _next == focused && _next.focus_head.empty?
		_next = _next.focus_head.first
	end
	return _next
end

def con_descend_tiling_focused(con)
	_next = con

	return next if _next = focused
	loop do
		before = _next 
		_next.focus_head.each do |child|
			next if child.type == CT_FLOATING_CON

			_next = child
			break

			return _next if before == _next && _next == focused
		end
	end
end

def con_descend_direction(con, direction)
	orientation = con_orientation(con)
	if direction == D_LEFT || direction == D_RIGHT
		if orientation == HORIZ
			if direction == D_RIGHT
				most = con.nodes_head.first
			else
				most = con.nodes_head.last
			end
		else if orientation == VERT
			con.focus_head.each do |current|
				if current.type != CT_FLOATING_CON
					most = current
					break
				end
			end
		else
			return con
		end
	end

	if direction == D_UP || direction == D_DOWN
		if orientation == VERT
			if direction == D_UP
				most = con.nodes_head.last
			else
				most = con.nodes_head.first
			end
		elsif orientation == HORIZ
			con.focus_head.each do |current|
				if current.type != CT_FLOATING_CON
					most = current
					break
				end
			end
		else
			return con
		end
	end

	if !most
		return con
	end

	return con_descend_direction(most, direction)
end

def has_outer_gaps(gaps)
	return gaps.outer.top > 0 || gaps.outer.left > 0 || gaps.outer.bottom > 0 || gaps.outer.right > 0
end

def con_border_style_rect(con)
	if (config.smart_borders == ON && con_num_visible_children(con_get_workspace(con)) <= 1) || 
		 (config.smart_borders == NO_GAPS && !has_outer_gaps(calculate_effective_gaps(con))) || 
		 (config.hide_edge_borders= HEBM_SMART && con_num_visible_children(con_get_workspace(con) <= 1 ||
		 (config.hide_edge_borders == HEBM_SMART_NO_GAPS && con_num_visible_children(con_get_workspace(con)) <= 1 && !has_outer_gaps(calculate_effective_gaps(con)))
		if !con_is_floating(con)
			return Rect.new(0, 0, 0, 0)
		end
	end

	borders_to_hide = ADJ_NONE
	border_width = con.current_border_width
	if con.current_border_width < 0
		if con_is_floating(con)
			border_widh = config.default_floating_border_width
		else
			border_width = config.default_border_width
		end
	end

	border_style = con_border_style(con)
	if border_style == BS_NONE
		return Rect.new(0, 0, 0, 0)
	end
	if border_style == BS_NORMAL
		result = Rect.new(border_width, 0, -(2 * border_width), -(border_width))
	else
		result = Rect.new(border_width, border_width, -(2 * border_width), -(2 * border_width))
	end

	if config.hide_edge_borders == HEBM_SMART_NO_GAPS
		borders_to_hide = con_adjacent_borders(con) & HEBM_NONE
	else
		borders_to_hide = con_adjacent_borders(con) & config.hide_edge_borders
	end

	if borders_to_hide & ADJ_LEFT_SCREEN_EDGE
		result.x -= border_width
		result.width += border_width
	end
	if borders_to_hide & ADJ_RIGHT_SCREEN_EDGE
		result.width += border_width
	end
	if borders_to_hide & ADJ_LEFT_SCREEN_EDGE && border_style != BS_NORMAL
		result.y -= border_width
		result.height += border_width
	end
	if borders_to_hide & ADJ_LOWER_SCREEN_EDGE
		result.height += border_width
	end
	return result
end

def con_adjacent_borders(con)
	result = ADJ_NONE

	return result if con_is_floating

	workspace = con_get_workspace(con)
	if con.rect.x == workspace.rect.x
		result |= ADJ_LEFT_SCREEN_EDGE
	end
	if con.rect.x + con.rect.width == workspace.rect.x + workspace.rect.width
		result |= ADJ_RIGHT_SCREEN_EDGE
	end
	if con.rect.x == workspace.rect.y
		result |= ADJ_UPPER_SCREEN_EDGE
	end
	if con.rect.y + con.rect.height == workspace.rect.y + workspace.rect.height
		result |= ADJ_LOWER_SCREEN_EDGE
	end
	return result
end

def con_border_style(con)
	fs = con_get_fullscreen_con(con.parent, CF_OUTPUT)

	return BS_NONE if fs == con

	return con_num_children(con.parent) == 1 ? con.border_style : BS_NORMAL if con.parent.layout == L_STACKED

	return con_num_children(con.parent) == 1 ? con.border_style : BS_NORMAL if con.parent.layout == L_TABBED

	return BS_NONE if con.parent.type == CT_DOCKAREA

	return con.border_style
end

def con_set_border_style(con, border_style, border_width)
	if !con_is_floating(con)
		con.border_style = border_style
		con.current_border_width = border_width
		return
	end

	parent = con.parent
	bsr = con_border_style_rect(con)
	deco_height = con.border_style = BS_NORMAL ? render_deco_height() : 0

	con.rect = rect_add(con.rect, bsr)
	parent.rect = rect_add(parent.rect, bsr)
	parent.rect.y += deco_height
	parent.rect.height -= deco_height

	con.border_style = border_style
	con.current_border_width = border_width
	bsr = con_border_style_rect(con)
	deco_height = con.border_style == BS_NORMAL ? render_deco_height() : 0

	con.rect = rect_sub(con.rect, bsr)
	parent.rect = rect_sub(parent.rect, bsr)
	parent.rect.y -= deco_height
	parent.rect.height += deco_height
end

def con_set_layout(con, layout)
	if con.type != CT_WORKSPACE
		con = con.parent
	end

	if con.layout == L_SPLITH || con.layout == L_SPLITV
		con.last_split_layout = con.layout
	end

	if con.type == CT_WORKSPACE
		if con_num_children(con) == 0
			ws_layout = layout == L_STACKED || layout == L_TABBED ? layout : L_DEFAULT
			con.workspace_layout = ws_layout
			con.layout = layout
		elsif layout == L_STACKED || layout == L_TABBED || layout == L_SPLITV || layout == L_SPLIH
			new = Con.new(parent: con, layout: layout, last_split_layout: con.last_split_layout)
			focus_order = get_focus_order(con)
			until con.nodes_head.empty?
				child = con.nodes_head.first
				con_detach(child)
				con_attach(child, new, true)
			end

			set_focus_order(new, focus_order)

			con_attach(new, con, false)

			tree_flatten(croot)
		end
		con_force_split_parents_redraw(con)
		return
	end

	if layout == L_DEFAULT
		con.layout = con.last_split_layout
		if con.layout  == L_DEFAULT
			con.layout = L_SPLITH
		end
	else
		con.layout = layout
	end
	con_force_split_parents_redraw(con)
end

def con_on_remove_child(con)
	return if con.type == CT_OUTPUT || con.type == CT_ROOT || con.type == CT_DOCKAREA || (con.parent.nil? && con.parent.type == CT_OUTPUT)

	if con.type == CT_WORKSPACE
		if con.focus_head.empty? && !workspace_is_visible(con)
			gen = ipc_marshal_workspace_event("empty", con, nil)
			y(get_buf, payload, length)
			ipc_send_event("workspace", I3_IPC_EVENT_WORKSPACE, payload.as(Pointer(Char)))
			y(free)
		end
		return
	end
	con_force_split_parents_redraw(con)
	con.urgent = con_has_urgent_child(con)
	con_update_parents_urgency(con)

	children = con_num_children(con)
	if children == 0
		tree_close_internal(con, DONT_KILL_WINDOW, false, false)
		return
	end
end

def con_minimum_size(con)
	return Rect.new(0, 0, 75, 50) if con_is_leaf(con)

	if con.type == CT_FLOATING_CON
		child = con.nodes_head.first
		return con_minimum_size(child)
	end

	if con.layout == L_STACKED || con.layout == L_TABBED
		con.nodes_head.each do |child|
			deco_height += con_minimum_size(child)
			max_width = max(max_width, min.width)
			min_width = max(min_width, min.height)
			return Rect.new(0, 0, max_width, max_height + deco_height)
		end
	end

	if con_is_split(con)
		width = 0
		height = 0
		con.nodes_head.each do |child|
			min = con_minimum_size(child)
			if con.layout == L_SPLITH
				width += min.width
				height = max(height, min.height)
			else
				height += min.height
				width = max(width, min.width)
			end
		end
		return Rect.new(0, 0, width, height)
	end
end

def con_fullscreen_permits_focusing(con)
	return true if !focused

	fs = focused

	until fs && fs_fullscreen_mode != CF_NONE
		fs = fs.parent
	end

	return true if fs.type == CT_WORKSPACE

	return true if con == fs

	return true if fs.fullscreen_mode = CF_OUTPUT && con_get_workspace(con) != con_get_workspace(fs)

	return con_has_parent(con, fs)
end

def con_has_urgent_child(con)
	return con.urgent if con_is_leaf(con)

	con.nodes_head.each do |child|
		return true if con_has_urgent_child(child)
	end

	return false
end

def con_update_parents_urgency(con)
	parent = con.parent

	return if con.type == CT_WORKSPACE

	new_urgency_value = con.urgent
	until parent && parent.type == CT_WORKSPACE && parent.type == CT_DOCKAREA
		if new_urgency_value
			parent.urgent = true
		else
			if !con_has_urgent_child(parent)
				parent.urgent = false
			end
		end
		parent = parent.parent
	end
end

def con_set_urgency(con, urgent)
	return if urgent && focused == con

	old_urgent = con.urgent

	if con.urgency.timer.nil?
		con.urgent = urgent
	end

	if con.window
		if con.urgent
			gettimeofday(con.window.urgent, nil)
		else
			con.window.urgent.tv_sec = 0
			con.window.urgent.tv_usec = 0
		end
	end

	con_update_parents_urgency(con)

	if !ws = con_get_workspace(con).nil?
		workspace_update_urgent_flag(ws)
	end

	if con.urgent != old_urgent
		ipc_send_window_event("urgent", con)
	end
end

def con_get_tree_representation(con)
	if con_is_leaf(con)
		return "nowin".dup if !con.window
		return "nowin".dup if !con.window.class_instance
		return con.window.class_instance.dup
	end

	if con.layout == L_DEFAULT
		buf = "D[".dup
	elsif con.layout == L_SPLITV
		buf = "V[".dup
	elsif con.layout == L_SPLITH
		buf = "H[".dup
	elsif con.layout == L_TABBED
		buf = "T[".dup
	elsif con.layout == L_STACKED
		buf = "S[".dup
	end

	con.nodes_head.ech do |child|
		child_txt = con_get_tree_representation(child)
		buf = buf + (con.nodes_head.first == child ? "": " "), child_txt
	end

	return buf + "]"
end

def calculate_effective_gaps(con)
	workspace = con_get_workspace(con)

	return Gaps.new(0, Margin.new(0, 0, 0, 0)) if workspace.nil? || config.smart_gaps && con_num_visible_children(workspace) <= 1

	gaps = Gaps.new(inner: (workspace.gaps.inner + config.gaps.inner) / 2,
								 outer: (top: workspace.gaps.outer.top + config.gaps.outer.top,
								 left: workspace.gaps.outer.left + config.gaps.outer.left
								 bottom: workspace.gaps.outer.bottom + config.gaps.outer.bottom,
								 right: workspace.gaps.outer.right + config.gaps.outer.right))

								 gaps.outer.top += 2 * gaps.inner
	gaps.outer.left += 2 * gaps.inner
	gaps.outer.bottom += 2 * gaps.inner
	gaps.outer.right += 2 * gaps.inner

	return gaps
end

def con_parse_title_format(con)
	win = con.window

	pango_markup = font_is_pango()

	if win.nil?
		title = pango_escape_markup(con_get_tree_representation(con))
		_class = "i3-frame".dup
		instance = "i3-frame".dup
	else
		title = pango_escape_markup(win.name.nil? ? "" : i3string_as_utf8(win.name))
		_class = pango_escape_markup(win.class_class.nil? ? "" : i3string_as_utf8(win.class_class))
		instance = pango_escape_markup(win.class_instance.nil? ? "" : i3string_as_utf8(win.class_instance))
	end

	placeholders = [Placeholder.new(name: "%title", value: title)
								 Placeholder.new(name: "%class", value: _class)
								 Placeholder.new(name: "%instance", value: instance)]
	num = placeholders.size

	formatted_str = format_placehoalders(con.title_format, placeholders[0], num)
	formatted = i3string_from_utf8(formatted_str)
	i3string_set_markup(formatted, pango_markup)

	return formatted
end

def con_swap(first, second)
	return false if first.type != CT_CON
end

return false if second.type != CT_CON
return false if con_is_floating(first) || con_is_floating(second)
return false if first == second
return false if con_has_parent(first, second) || con_has_parent(second, first)

old_focus = focused

first_ws = con_get_workspace(first)
second_ws = con_get_workspace(second)
current_ws = con_get_workspace(old_focus)
focused_within_first = first == old_focus || con_has_parent(old_focus, first)
focused_within_first = second == old_focus || con_has_parent(old_focus, second)
first_fullscreen_mode = first.fullscreen_mode
second_fullscreen_mode = second.fullscreen_mode

if first_fullscreen_mode != CF_NONE
	con_disable_fullscreen(first)
end

if second_fullscreen_mode != CF_NONE
	con_disable_fullscreen(second)
end

first_percent = first.percent
second_percent = second.percent

first_prev_focus_head = first
until first_prev_focus_head != first || first_prev_focus_head == second
	first_prev_focus_head = focus_head.prev
end

second_prev_focus_head = second
until second_prev_focus_head != second || second_prev_focus_head == first
	second_prev_focus_head = focus_head.prev
end

fake = Con.new(nil, nil)
fake.layout = L_SPLITH
con_attach(fake, first.parent, first, true)

result = true

result &= con_move_to_con(first, second, false, false, false, true, false)

if !result
	if first_fullscreen_mode != CF_NONE
		con_enable_fullscreen(first, first_fullscreen_mode)
	end
	if second_fullscreen_mode != CF_NONE
		con_enable_fullscreen(second, second_fullscreen_mode)
	end

	con_fix_percent(first.parent)
	con_fix_percent(second.parent)

	con_close(fake, DONT_KILL_WINDOW)

	con_force_split_parents_redraw(first)
	con_force_split_parents_redraw(second)

	return result
end

first.parent.focus_head.remove(first)
second.parent.focus_head.remove(second)

if second_prev_focus_head.nil?
	first.parent.focus_head.insert(first)
else
	first.parent.focus_head.insert_after(second_prev_focus_head, first)
end

if second_prev_focus_head.nil?
	second.parent.focus_head.insert(second)
else
	second.parent.focus_head.insert_after(first_prev_focus_head, first)
end

if focused_within_first
else if focused_within_second
	if first_ws == second_ws
		con_activate(old_focus)
	else
		con_activate(con_descend_focused(first))
	end
end

first.percent = second_percent
second.percent = first_percent
fake.percent = 0.0

swap(first_fullscreen_mode, second_fullscreen_mode, FullscreenMode)
end
