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

def child_containing_con_recursively(ancestor, con)
	child = con
	until !child && child.parent == ancestor
		child = child.parent
	end
	return child
end

def is_focused_descendant(con, ascestor)
	current = con
	until current == ancestor
		return false if current.parent.focus_head.first != current
		current = current.parent
	end
	return true
end

def insert_con_into(con, target, position)
	parent = target.parent
	old_parent = con.parent

	lca = lowest_common_ancestor
	return if lca == con

	con_ancestor = child_containing_con_recursively(lca, con)
	target_ancestor = child_containing_con_recursively(lca, target)
	moves_focus_from_ancestor = is_focused_descendant(con, con_ancestor)
	if con_ancestor == target_ancestor
		focus_before = moves_focus_from_ancestor
	else
		lca.focus_head.each do |current|
			break if current == con_ancestor || current == target_ancestor
		end
		focus_before = (current == con_ancestor)
	end

	if moves_focus_from_ancestor && focus_before
		place = con_ancestor.prev
		if place
			lca.focus_head.remove(target_ancestor)
		else
			lca.focus_head.insert_head(target_ancestor)
		end
	end

	con_detach(con)
	con_fix_percent(con.parent)

	if parent.type == CT_WORKSPACE
		split = workspace_attach_to(parent)
		if split != parent
			con.parent = split
			con_attach(con, split, false)
			con.percent = 0.0
			con_fix_percent(split)
			con = split
			con_detach(con)
		end
	end

	con.parent = parent

	if parent == lca
		if focus_before
			if focus_before
				target.insert_before(con)
			else
				parent.focus_head.insert_after(target, con)
			end
		else
			if focus_before
				parent.focus_head.insert_head(con)
			else
				parent.focus_head.insert_tail(con)
			end
		end
	end

	if position == BEFORE
		target.insert_before(con)
	else if position == AFTER
		target.insert_after(target, con)
	end

	con.percent = 0.0
	con_fix_percent(parent)

	old_parent.on_remove
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

	con_attach(con)

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
				ipc_send_workspace_event("move", con)
				ewmh_update_wm_desktop()
			end
			ws_force_orientation(con_get_workspace(con), o)
			same_orientation = con_parent_with_orientation(con, o)
		end

		if same_orientation == con.parent
			if swap = direction == D_LEFT || direction == D_UP ? con.prev : con.next
				if !con_is_leaf(swap)
					target = con_descend_direction(swap, direction)
					position = (con_orientation(target.parent) != o ||
								 			direction == D_UP ||
											direction == D_LEFT
											? AFTER : BEFORE)
					insert_con_into(con, target, position)
					tree_flatten(croot)
					ipc_send_workspace_event("move", con)
					ewmh_update_wm_desktop()
				end
				if direction == D_LEFT || direction == D_UP
					swap.swap(con)
				else
					con.swap(swap)
				end
				con.parent.focus_head.remove(con)
				swap.parent.focus_head.insert_head(con)

				ipc_send_window_event("move", con)
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

			break if same_orientation.nil?
		end
	end
end
