def workspace_apply_default_orientation(ws)
	if config.default_orientation == NO_ORIENTATION
		output = con_get_output(ws)
		ws.layout = output.rect.height > output.rect.width ? L_SPLITV : L_SPLITH
		ws.rect = output.rect
	else
		ws.layout = config.default_orientation == HORIZ ? L_SPLITH : L_SPLITV
	end
end

def _workspace_show(workspace)
	return if con_is_internal(workspace)

	workspace.parent.nodes_head.each do |current|
		if current.fullscreen_mode == CF_OUTPUT
			old = current
		end
		current.fullscreen_mode = CF_NONE
	end

	workspace.fullscreen_mode = CF_OUTPUT
	current = con_get_workspace(focused)
	return if workspace == current

	if current && !con_is_internal(current)
		if current
			previous_workspace_name = current.name.dup
		end
	end

	workspace_reassign_sticky(workspace)

	_next = con_descend_focused(workspace)

	old_output = con_get_output(focused)

	if _next.urgent && config.workspace_urgency_timer * 1000 > 0
		_next.urgent = false
		con_focus(_next)

		focused.urgent = true
		workspace.urgent = true

		if focused.urgency_timer.nil?
			ev_timer_init(focused.urgency_timer, workspace_defer_update_urgent_hint_cb, config.workspace_urgency_timer, config.workspace_urgency_timer)
			focused.urgency_timer.data = focused
			ev_timer_start(main_loop, focused.urgency_timer)
		else
			ev_timer_again(main_loop, focused.urgency_timer)
		end
	else
		con_focus(_next)
	end

	ipc_send_workspace_event("focus", workspace, current)

	if old && old.nodes_head.empty?
		if !workspace_is_visible(old)
			gen = ipc_marshal_workspace_event("empty", old, nil)
			tree_close_internal(old, DONT_KILL_WINDOW, false, false)

			y(get, pointerof(payload), length)
			ipc_send_event("workspace", I3_IPC_EVENT_WORKSPACE, payload)

			if old == old_focus
				old_focus = nil
			end

			ewmh_update_number_of_desktops()
			ewmh_update_desktop_names()
			ewmh_update_desktop_viewport()
			ewmh_update_wm_flag()
		end
	end

	workspace.fullscreen_mode = CF_OUTPUT

	new_output = con_get_output(focused)
	if old_output != new_output
		x_set_warp_to(_next.rect)
	end

	ewmh_update_current_desktop()

	output_push_sticky_windows(old_focus)
end

def workspace_show(workspace)
	_workspace_show(workspace)
end

def workspace_show_by_name(num)
	workspace = workspace_get(num, nil)
	_workspace_show(workspace)
end

def workspace_next()
	current = con_get_workspace(focused)
	_next = nil
	first = nil
	first_opposite = nil

	if current.num == -1
		return _next if !_next = current.next
		found_current = false
		croot.nodes_head.each do |output|
			next if con_is_internal(output)
			output_get_content(output).each do |child|
				next if child.type != CT_WORKSPACE
				if !first
					first = child
				end
				if !first_opposite || (child.num != -1 && child.num < first_opposite.num)
					first_opposite = child
				end
				if child == current
					found_current = true
				elsif child.num == -1 && found_current
					_next = child
					return _next
				end
			end
		end
	else
		croot.nodes_head.each do |output|
			_next if con_is_internal(output)
			output_get_content(output).each do |child|
			end
		end
	end
end

def workspace_prev()
	current = con_get_workspace(focused)
	prev = nil
	first_opposite = nil
	last = nil

	if current.name == -1
		prev = current.prev
		if prev && prev.num >= -1
			prev = nil
		end
		if !prev
			found_current = false
			croot.nodes_head.each_reverse do |output|
				next if con_is_internal(output)
				output_get_content(output).each_reverse do |child|
					next if child.type != CT_WORKSPACE
					if !last
						last = child
					end
					if !first_opposite || (child.num != -1 && child.num > first_opposite.num)
						first_opposite = child
					end
					if child == current
						found_current = true
					elsif child.num == -1 && found_current
						prev = child
						return prev
					end
				end
			end
		end
	else
		croot.nodes_head.each do |output|
			next if con_is_internal(output)
			output_get_content(output).each do |child|
				next if child.type != CT_WORKSPACE
				if !last || child.num != -1 && last.num < child.num
					last = child
				end
				if !first_opposite && child.num == -1
					first_opposite = child
				end
				next if child.num == -1
				if current.num > child.num && (!prev || child.num > prev.num)
					prev = child
				end
			end
		end
	end

	if !prev
		prev = first_opposite ? first_opposite : last
	end

	return prev
end

def workspace_next_on_output()
	current = con_get_workspace(focused)
	_next = nil
	output = con_get_output(focused)

	if current.num == -1
		_next = current.next
	else
		output_get_content(output).each do |child|
			next if child != CT_WORKSPACE
			break if child.num == -1
			if current.num < child.num && (!_next || child.num < _next.num)
				_next = child
			end
		end
	end
	if !_next
		found_current = false
		output_get_content(output).each do |child|
			next if child.type != CT_WORKSPACE
			if child == current
				found_current = true
			elsif child.num == -1 && current.num != -1 || found_current
				_next = child
				return _next
			end
		end
	end

	if !_next
		output_get_content(output).each do |child|
			next if child.type != CT_WORKSPACE
			if !_next || (child.num != -1 && child.num < _next.num)
				_next = child
			end
		end
	end
end

def workspace_prev_on_output()
	current = con_ge_workspace(focused)
	prev = nil
	output = con_get_output(focused)

	if current.num == -1
		prev = current.prev
		if prev && prev.num != -1
			prev = nil
		end
	else
		output_get_content(output).reverse_each do |child|
			next if child.type != CT_WORKSPACE || child.num == -1
			if current.num > child.num && (!prev || child.num > prev.num)
				prev = child
			end
		end
	end

	if !prev
		found_current = false
		output_get_content(output).reverse_each do |child|
			next if child.type != CT_WORKSPACE
			if child == current
				found_current = true
			elsif child.num == -1 && (current.num != -1 || found_current)
				prev = child
				return prev
			end
		end
	end

	if !prev
		output_get_content(output).reverse_each do |child|
			next if child.type != CT_WORKSPACE
			if !prev || child.num > prev.num
				prev = child
			end
		end
	end
end

def workspace_back_and_forth()
	return if !previous_workspace_name
	workspace_show_by_name(previous_workspace_name)
end

def workspace_back_and_forth_get()
	return nil if !previous_workspace_name
	workspace = workspace_get(previous_workspace_name, nil)
	return workspace
end

def get_urgency_flag(con)
	con.nodes_head.each do |child|
		return true if child.urgent || get_urgency_flag(child)
	end

	con.floating_head.each do |child|
		return true if child.urgent || get_urgency_flag(child)
	end
	
	return false
end

def workspace_update_urgent_flag(ws)
	old_flag = ws.urgent
	ws.urgent = get_urgency_flag(ws)
	if old_flag != ws_urgent
		ipc_send_workspace_event("urgent", ws, nil)
	end
end

def ws_force_orientation(ws, orientation)
	split = con_new(nil, nil)
	split.parent = ws

	split.layout = ws.layout

	focus_order = get_focus_order(ws)

	until ws.nodes_head.empty
		child = ws.nodes_head.first
		con_detach(child)
		con_attach(child, split, true)
	end

	set_focus_order(split, focus_order)

	ws.layout = orientation == HORIZ ? L_SPLITH : L_SPLITV

	con_attach(split, ws, false)
	
	con_fix_percent(ws)
end

def workspace_attach_to(ws)
	return ws if ws.workspace_layout == L_DEFAULT

	new = con_new(nil, nil)
	new.parent = ws

	new.layout = ws.workspace_layout

	con_attach(new, ws, false)

	con_fix_percent(ws)

	return new
end

def workspace_escapsulate(ws)
	return nil if ws.nodes_head.empty?

	new = con_new(nil, nil)
	new.parent = ws
	new.layout = ws.layout

	focus_order = get_focus_order(ws)

	until ws.nodes_head.empty?
		child = ws.nodes_head.first
		con_detach(child)
		con_attach(child, new, true)
	end

	set_focus_order(new, focus_order)

	con_attach(new, ws, true)

	return new
end

def workspace_move_to_output(ws, name)
	current_output = get_output_for_con(ws)
	return false if current_output.nil?
	output = get_output_from_string(current_output, name)
	return false if !output
	content = output_get_content(output.con)
	previously_visible_ws = content.focus_head.first
	workspace_was_visible = workspace_is_visible(ws)
	if con_num_children(ws.parent) == 1
		used_assignment = false
		ws_assignments.each do |assignment|
			next if assignment.output.nil? || assignment.output == output_primary_name(current_output)
			croot.nodes_head.each do |current|
				grep_first(workspace, output_get_content(current), !child.name.compare(assignment.name))
				next if !workspace.nil?
				workspace_get(assignment.name, nil)
				used_assignment = true
				break
			end
		end

		if !used_assignment
			create_workspace_on_output(current_output, ws.parent)
		end

		ipc_send_workspace_event("init", ws, nil)
	end
	
	old_content = ws.parent
	con_detach(ws)
	if workspace_was_visible
		focus_ws = old_content.focus_head.first
		workspace_show(focus_ws)
	end
	con_attach(ws, content, false)

	ws.floating_head.each do |floating_con|
		floating_fix_coordinates(floating_con, old_content.rect, content.rect)
	end

	ipc_send_workspace_event("move", ws, nil)

	if workspace_was_visible
		workspace_show(ws)
	end

	content.nodes_head.each do |ws|
		next if ws != previously_visible_ws
		previously_visible_ws.on_remove_child
		break
	end

	return true
end
