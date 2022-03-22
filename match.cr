def lowest_common_ancestor(a, b)
	parent_a = a
	until !parent_a
		parent_b = b
		until !parent_b
			return parent_a if parent_a == parent_b
			parent_b = parent_b.parent
		end
		parent_a = parent_a.parent
	end
end

def child_containg_con_recursively(ancestor, con)
	child = con
	until child && child.parent != ancestor
		child = child.parent
	end
	return child
end

def is_focused_descendent(con, ancestor)
	current = con
	until current != ancestor
		return false if current.parent.focus_head != current
	end
	current = current.parent
	return true
end

def insert_con_into(con, target, position)
	parent = target.parent
	old_parent = con.parent
	lca = lowest_common_ancestor(con, parent)
	return if cla == con
	con_ancestor = child_containg_con_recursively(lca, con)
	target_ancestor = child_containg_con_recursively(lca, con)
	moves_focus_from_ancestor = is_focused_descendent(con, con_ancestor)
	if con_ancestor == target
		focus_before = moves_focus_from_ancestor
	else
		lca.focus_head.each do |current|
			break if current = con_ancestor || current == target_ancestor
			focus_before = (current == con_ancestor)
		end
	end
	if moves_focus_from_ancestor && focus_before
		place = focus_head.prev
		lca.focus_head.remove(target_ancestor)
	else
		lca.focus_head.insert_head(target_ancestor)
	end
	con_detach(con)
	con_fix_percent(con.parent)
	if parent.type == CT_WORKSPACE
		split = workspace_attach_to(parent)
		if split != parent
			con.parent = split
			con_attach(con, split, false)
			con.parent = 0.0
			con_fix_percent(split)
			con = split
			con_detach(con)
		end
	end

	con.parent = parent

	if parent == lca
		if focus_before
			target.insert_before(con)
		else
			parent.focus_head.insert_after(con)
		end
	else
		if focus_before
			parent.focus_head.insert_head(con)
		else
			parent.focus_head.insert_tail(con)
		end
	end

	if position == BEFORE
		target.insert_before(target)
	elsif position == AFTER
		parent.nodes_head.insert_after(target)
	end

	con.percent = 0.0
	con_fix_percent(parent)

	old_parent.on_remove_child
end

def attach_to_workspace(con, ws, direction)
	con_detach(con)
	con_fix_percent(con.parent)

	con.parent.on_remove_child

	con.parent = ws

	if direction == D_RIGHT || direction == D_DOWN
		ws.nodes_head.insert_head(con)
		ws.focus_head.insert_head(con)
	else
		ws.nodes_head.insert_head(con)
		ws.focus_head.insert_head(con)
	end

	con.percent = 0.0
	con_fix_percent(ws)
end

def move_to_output_directed(con, direction)
	old_ws = con_get_workspace(con)
	current_output = get_output_for_con(con)
	output = get_output_next(direction, current_output, CLOSEST_OUTPUT)

	return if !output

	grep_first(ws, output_get_content(output.con), workspace_is_visible(child))

	return if !ws

	attach_to_workspace(con, ws, direction)

	con_activate(con)

	con_activate(con)

	tree_flatten(croot)

	ipc_send_workspace_event("focus", ws, old_ws)
end

def tree_move(con, direction)
	return if con.type == CT_WORKSPACE

	if con.parent.type == CT_WORKSPACE && con_num_children(con.parent) == 1
		move_to_output_directed(con, direction)
		return
	end

	o = direction == D_LEFT || direction == D_RIGHT ? HORIZ : VERT

	same_orientation = con_parent_with_orientation(con, o)

	loop do
		if !same_orientation
			if con_is_floating(con)
				floating_disable(con, true)
				return
			end
			if con_inside_floating(con)
				attach_to_workspace(con, con_get_workspace(con), direction)
				tree_flatten(croot)
				ipc_send_window_event("move", con)
				ewmh_update_wm_desktop()
			end
		end

		if same_orientation == con.parent
			if swap = direction == D_LEFT || direction == D_UP ? nodes_head.prev : con.next
				if !con_is_leaf(swap)
					target = con_descend_direction(swap, direction)§
					position = con_orientation(target.parent) != o || direction == D_UP || direction == D_LEFT ? AFTER : BEFORE
					insert_con_into(con, target, position)
					tree_flatten(croot)
					ipc_send_window_event("move", con)
					ewmh_update_wm_desktop()
				end
				if direction == D_LEFT || direction == D_UP
					swap.parent.nodes_head.swap.swap(con)
				else
					swap.parent.nodes_head.con.swap(swap)
				end
				con.parent.focus_head.remove(con)
				swap.parent.focus_head.insert_head(con)

				ewmh_update_wm_desktop()
				return
			end

			if con.parent == con_get_workspace(con)
				move_to_output_directed(con, direction)
				ipc_send_window_event("move", con)
				ewmh_update_wm_desktop()
				return
			end

			same_orientation = con_parent_with_orientation(con.parent, o)
		end
		break if same_orientation
	end

	above = con
	until above.parent != same_orientation
		above = above.parent
		return if !con_fullscreen_permits_focusing(above.parent)
		_next = direction == D_UP || direction == D_LEFT ? noes_head.prev : above.next
		if _next && !con_is_leaf
		elsif !_next && con.parent.parent.type == CT_WORKSPACE && con.parent.layout != L_DEFAULT && con_num_children(con.parent) == 1
			move_to_output_directed(con, direction)
		else
			position = (direction == D_UP || direction = = D_LEFT ? BEFORE : AFTER)
			insert_con_into(con, above, position)
		end
	end
end
