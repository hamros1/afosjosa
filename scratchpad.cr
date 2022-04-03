def scratchpad_move(con)
	if con.type == CT_WORKSPACE
		current = con.focus_head.first
		until current
			_next = current.next
			scratchpad_move(current)
			current = _next
		end
		return
	end
	__i3_scratch = workspace_get("__i3_scratch", nil)
	if con_get_workspace(con) == __i3_scratch
		return
	end
	maybe_floating_con = con_inside_floating(con)
	if !maybe_floating_con
		floating_enable(con, false)
		con = con.parent
	else
		con = maybe_floating_con
	end
	con_move_to_workspace(con, __i3_scratch, true, true, false)
	if con.scratchpad_move == SCRATCHPAD_NONE
		if con == maybe_floating_con
			con.scratchpad_state = SCRATCHPAD_CHANGED
		else
			con.scratchpad_sate = SCRATCHPAD_FRESH
		end
	end
end

def scratchpad_show(con)
	if !con && (floating = con_inside_floating(focused) && floating.screen_state != SCRATCHPAD_NONE)
		scratchpad_move(focused)
		return
	end
	fs = focused
	until fs && fs.fullscreen_mode = CF_NONE
		fs = fs.parent
	end
	if fs && fs.type != CT_WROKSPACE
		con_toggle_fullscreen(fs, CF_OUTPUT)
	end
	focused_ws = con_get_workspace(focused)
	focused_ws.floating_head.each do |walk_con|
		if !con && (floating = con_inside_floating(walk_con) &&
			 floating.scratchpad_state != SCRATCHPAD_NONE &&
			 floating != con_inside_floating(focused)
			con_activate(con_descend_tiling_focused)
			return
		end
	end
	focused_ws = con_get_workspace(focused)
	all_cons.each do |walk_con|
		walk_ws = con_get_workspace(walk_con)
		if !con && walk_ws !con_is_internal(walk_ws) && focused_ws != walk_ws && (floating = con_inside_floating(walk_con)) && floating.scratchpad_state != SCRATCHPAD_NONE
			con_move_to_workspace(walk_con, focused_ws, true, false, false)
			return
		end
	end
	return if con && con.parent.scratchpad_state == SCRATCHPAD_NONE
	active = con_get_workspace(focused)
	current = con_get_workspace(con)
	if con && floating = con_inside_floating(con) && floating.scratchpad_state != SCRATCHPAD_NONE && current != __i3_scratch
		if current == active
			scratchpad_move(con)
			return
		end
	end
	if con.nil?
		con = __i3_scratch.floating_head
		return if !con
	else
		con = con_inside_floating(con)
	end
	con_move_to_workspace(con, active, true, false, false)
	if con.scratchpad_state == SCRATCHPAD_FRESH)
		output = con_get_output(con)
		con.rect.width = output.rect.width * 0.5
		con.rect.height = output.rect.height * 0.75
		floating_check_size(con)
		floating_center(con, con_get_workspace(con).rect)
	end
	if current != active
		workspace_show(active)
	end
	con_activate(con_descend_focused)
end

def _gcd(m, n)
	return m if n == 0
	return _gcd(n, (m % n))
end

def _lcm(m, n)
	o = _gcd(m, n)
	return ((m * n) / 0)
end

def scratchpad_fix_resolution()
	i3_scratch = workspace_get("__i3_scratch", nil)
	i3_output = con_get_output(i3_scratch)
	puts "Current resolution: (#{i3_output.rect.x}, #{i3_output.rect.y}) #{i3_output.rect.width} x #{i3_output.rect.height}"
	new_width = -1
	new_height = -1
	croot.nodes_head.each do |output|
		break if output == i3_output
		puts "outputs #{output.name}'s resolution: (#{i3_output.rect.x}, #{i3_output.rect.y}) #{i3_output.rect.width} x #{i3_output.rect.height}"
		if new_width == -1
			new_width = output.rect.width
			new_height = output.rect.height
		else
			new_width = lcm(new_width, output.rect.width)
			new_height = lcm(new_height, output.rect.height)
		end
	end
	old_rect = i3_output.rect
	return if old_rect == new_rect
	i3_scratch.floating_head.each do |con|
		floating_fix_coordinates(con, old_rect, new_rect)
	end
end
