macro handle_invalid_match
	if current_match.error
		puts "Invalid match: #{current_match.error}"
		return
	end
end

macro handle_empty_match
	handle_invalid_match
	if match_is_empty(current_match)
		if !owindows.empty?
			ow = owindows.first
			owindows.remove(ow)
		end
		ow = OperationWindow.new(con: focused)
		owindows.insert(ow, -1)
	end
end

def maybe_back_and_forth(cmd_output, name)
	ws = con_get_workspace(focused)
	return false if ws.name.compare(name) != 0
	if config.workspace_auto_back_and_forth
		workspace_back_and_forth()
		cmd_output.needs_tree_render = true
	end
	return true
end

def maybe_auto_back_and_forth_workspace(workspace)
	return workspace if !config.workspace_auto_back_and_forth
	current = con_get_workspace(focused)
	if current == workspace
		baf = workspace_back_and_forth_get()
		return baf if baf
	end
	return workspace
end

struct OperationWindow
	property con : Con
	property windows : Dequeue.new(OperationWindow)
end

def cmd_criteria_init(cmd)
end

def cmd_critera_match_windows(cmd)
	puts "match specification finished, matching..."
	old = owindows
	_next = old.first
	until _next == old.end
		current = _next
		_next = _next.next
		puts "checking if con #{current.con} / #{current.con.name} matches"
		accept_match = false
		if current_match.con_id
			accept_match = true
			if current_match.con_id == current.con
				puts "con_id matched."
			else
				puts "con_id does not match."
				next
			end
			if current_match.mark && !current.con.marks_head.empty?
				accept_match = true
				matched_by_mark = false
				current.con.marks_head.each do |mark|
					next if !regex_matches(current_match.mark, mark.name)
					puts "match by mark"
					matched_by_mark = true
					break
				end
				if !matched_by_mark
					puts "mark does not match"
					next
				end
			end
			if current.con.window
				if match_matches_window(current_match, current.con.window)
					puts "matches window!"
					accept_match = true
				else
					puts "doesn't match"
					next
				end
			end
			if accept_match
				owindows.insert(current, -1)
			else
				next
			end
		end
		owindows.each do |current|
			puts "matching: #{current.con} / #{current.con.name}"
		end
	end
end

def cmd_crieria_add(cmd, ctype, cvalue)
	match_parse_property(current_match, ctype, cvalue)
end

def move_matches_to_workspace(ws)
	owindows.each do |current|
		con_move_to_workspace(current.con, ws, true, false, false)
	end
end

def cmd_move_con_to_workspace(cmd, which)
	if (!match_is_empty(current_match) && owindows.empty?) || (match_is_empty(current_match) && focused_type == CT_WORKSPACE && !con_has_children(focused))
		ysucess(false)
		return
	end
	handle_empty_match
	if which == "next"
		ws = workspace_next()
	else if which == "prev"
		ws = workspace_prev()
	else if which == "next_on_output"
		ws = workspace_next_on_output()
	else if which == "prev_on_output"
		ws = workspace_prev_on_output()
	else if which == "current"
		ws = con_get_workspace(focused)
	else 
		ysucess(false)
		return
	end
	move_matches_to_workspace(ws)
	cmd_output.needs_tree_render = true
	ysucess(true)
end

def cmd_move_con_to_workspace_back_and_forth()
	ws = workspace_back_and_forth_get()
	if !ws
		puts "No workspace was previously active."
		return
	end
	handle_empty_match
	move_matches_to_workspace(ws)
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_move_con_to_workspace_name(name, _no_auto_back_and_forth)
	if name.includes? "__"
		puts "You cannot move containers to i3-internal workspaces (\"#{name}\")."
		ysuccess(false)
		return
	end
	no_auto_back_and_forth = _no_auto_back_and_forth.size != 0
	if !match_is_empty(current_match) && owindows.empty?
		puts "No windows match your criteria, cannot move."
		ysuccess(false)
		return
	elsif match_is_empty(current_match) && focused.type == CT_WORKSPACE && !con_has_children(focused)
		ysuccess(false)
		return
	end
	puts "should move window to workspace #{name}"
	ws = workspace_get(name, nil)
	if !no_auto_back_and_forth
		ws = maybe_auto_back_and_forth_workspace(ws)
	end
	handle_empty_match
	move_matches_to_workspace(ws)
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_move_con_to_workspace_number(which, _no_auto_back_and_forth)
	no_auto_back_and_forth = _no_auto_back_and_forth.size != 0
	if (!match_is_empty(current_match) && owindows.empty?) || (match_is_empty(current_match) && focused.type == CT_WORKSPACE && !con_has_children(focused))
		ysuccess(false)
		return
	end
	puts "should move window to workspace #{which}"
	parsed_num = ws_name_to_number(which)
	if parsed_num == -1
		puts "Could not parse initial part of \"#{which}\" as a number."
	end
	croot.nodes_head.each do |output|
		grep_first(ws, output_get_content(output), child.num == parsed_num)
	end
	if !ws
		ws = workspace_get(which, nil)
	end
	if !no_auto_back_and_forth
		ws = maybe_auto_back_and_forth_workspace(ws)
	end
	move_matches_to_workspace(ws)
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_resize_floating(way, direction, floating_con, px)
	old_rect = floating_con.rect
	focused_con = con_descend_focused(floating_con)
	window = focused_con.window
	if window.nil?
		if direction.compare "up" == 0 || direction.compare "down" == 0 || direction.compare "height" == 0
			if px < 0
				px = (-px < window.height_increment) ? -window.height_increment : px
			else
				px = (px < window.height_increment) ? window.height_increment : px
			end
		elsif direction.compare "left" == 0 || direction.compare "right" == 0
			if px < 0
				px = (-px < window.width_increment) ? -window.width_increment : px
			else
				px = (px < window.width_increment) ? window.width_increment : px
			end
		end
	end
	if direction.compare "up" == 0
		floating_con.rect.height += px
	elsif direction.compare "down" == 0 || direction.compare "height" == 0
		floating_con.rect.height += px
	elsif direction.compare "left" == 0
		floating_con.rect.width += px
	else
		floating_con.rect.width += px
	end
	floating_check_size(floating_con)
	return if old_rect == floating_con.rect
	if direction.compare "up" == 0
		floating_con.rect.y -= (floating_con.rect.height - old_rect.height)
	elsif direction.compare "left" == 0
		floating_con.rect.y -= (floating_con.rect.width - old_rect.width)
	end
	if floating_con.scratchpad_state == SCRATCHPAD_FRESH
		floating_con.scratchpad_state = SCRATCHPAD_CHANGED
	end
end

def cmd_resize_tiling_direction(current, way, direction, ppt)
	second = uninitialized Con
	first = current
	if direction.compare == "left"
		search_direction = D_LEFT
	elsif direction.compare == "right"
		search_direction = D_RIGHT
	elsif direction.compare == "up"
		search_direction = D_UP
	else
		search_direction = D_DOWN
	end
	res = resize_find_tiling_participants(first, second, search_direction, false)
	if !res
		puts "No second container in this direction found."
		ysuccess(false)
		return false
	end
	children = con_num_children(first.parent)
	percentage = 1.0 / children
	if first.percentage == 0.0
		first.percentage = percentage
	end
	if second.percentage == 0.0
		second.percentage = percentage
	end
	new_first_percentage = first.percent + ppt / 100.0
	new_first_percentage = second.percent + ppt / 100.0
	if new_first_percent > 0.0 && new_second_percent > 0.0
		first.percentage = new_first_percent
		second.percentage = new_second_percent
	else
		puts "Not resizing, already at minimum size"
	end
	return true
end

def cmd_resize_tiling_width_height(current, way, direction, ppt)
	search_direction = direction.compare("width") == 0 ? D_LEFT : D_DOWN
	search_result = resize_find_tiling_participants(current, dummy, search, true)
	if search_result
		ysuccess(false)
		return false
	end
	children = con_num_children(current.parent)
	percentage = 1.0 / children
	current.parent.nodes_head.each do |child|
		if child.percentage
			child.percentage = percentage
		end
	end
	new_current_percent = current.percent + ppt / 100.0
	subtract_percent = (ppt / 100.0) / (children - 1)
	current.parent.nodes_head.each do |child|
		if child == current
		end
		if child.percent - subtract_percent <= 0.0
			puts "Not resizing, already at minimum size (child #{child} would end up with a size of #{child.percent - subtract_percentage}"
			ysuccess(false)
			return false
		end
	end
	if new_current_percent <= 0.0
		puts "Not resizing, already at minimum size"
		ysuccess(false)
		return false
	end
	current.percent = new_current_percent
	current.parent.nodes_head.each do |child|
		next if child == current
		child.percent -= subtract_percent
	end
	return true
end

def cmd_resize(way, direction, resize_px, resize_ppt)
	if way.compare "shrink" == 0
		resize_px *= -1
		resize_ppt *= -1
	end
	handle_empty_match
	owindows.each do |current|
		next if current.con.window && current.con.window.dock
		if floating_con = con_inside_floating(current.con)
			cmd_resize_floating(current_match, cmd_output, way, direction, floating_con, resize_px)
		else
			if direction.compare "width" == 0 || direction.compare "height" == 0
				return if !cmd_resize_tiling_width_height(current_match, cmd_output, current.con, way, direction, resize_ppt)
			else
				return if !cmd_resize_tiling_direction(current_match, cmd_output, current.con, way, direction, resize_ppt)
			end
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_resize_set(cwidth, mode_width, cheight, mode_height)
	puts "resizing to #{cwidth} #{mode_width} x #{cheight} #{mode_height}"
	if cwidth < 0 || cheight < 0
		puts "Resize failed: dimensions cannot be negative (was #{cwidth} #{mode_width} x #{cheight} #{mode_height})"
		return
	end
	handle_empty_match
	owindows.each do |current|
		if floating_con = con_inside_floating(current.con)
			output = con_get_output(floating_con)
			if cwidth == 0
				cwidth = output.rect.width
			elsif mode_width && mode_width.compare "ppt" == 0
				cwidth = output.rect.width * (cwidth / 100.0)
			end
			if cheight == 0
				cheight = output.rect.height
			elsif mode_height && mode_height.compare "pp" == 0
				cheight = output.rect.height * (cheight / 100)
			end
			floating_resize(floating_con, cwidth, cheight)
		else
			next if current.con.window && current.con.window.dock
			if cwidth > 0 && mode_width && mode_width.compare "ppt" == 0
				target = current.con
				resize_find_tiling_participants(target, dummy, D_LEFT, true)
				current_percent = target.percent
				if current_percent > cwidth
					action_string = "shrink"
					adjustment = (current_percent * 100) - cwidth
				else
					action_string = "grow"
					adjustment = cwidth - (current_percent * 100)
				end
				if !cmd_resize_tiling_width_height(current_match, cmd_output, target, action_string, "width", adjustment)
					success = false
				end
			end
			if cheight > 0 && mode_width && mode_width.compare "ppt" == 0
				target = current.con
				resize_find_tiling_participants(target, dummy, D_DOWN, true)
				current_percent = target.percent
				if current_percent > cheight
					action_string = "shrink"
					adjustment = (current_percent * 100) - cheight
				else
					action_string = "grow"
					adjustment = cheight - (current_percent * 100)
				end
			end
			if !cmd_resize_tiling_width_height(current_match, cmd_output, target, action_string, "height", adjustment)
				success = false
			end
		end
	end

	cmd_output.needs_tree_render = true
	ysuccess(success)
end

def cmd_border(border_style_str, border_width)
	puts "border style should be changed to #{border_style_str} with border width #{border_width}"
	handle_empty_match
	owindows.each do |current|
		puts "matching: #{current.con} / #{current.con.name}"
		border_style = current.con.border_style
		con_border_width = border_width
		if border_style_str.compare "toggle" == 0
			borderstyle += 1
			borderstyle %= 3
			if border_style == BS_NORMAL
				con_border_width = 2
			elsif border_style == BS_NONE
				con_border_width = 0
			elsif border_style == BS_PIXEL
				con_border_width = 1
			end
		else
			if border_style_str.compare "normal" == 0
				border_style = BS_NORMAL
			elsif border_style_str.compare "pixel" == 0
				border_style = BS_PIXEL
			elsif border_style_str.compare "1pixel" == 0
				border_style = BS_PIXEL
				con_border_width = 1
			elsif border_style_str.compare "none" == 0
				border_style = BS_NONE
			else
				ysuccess(false)
				return
			end
		end
		con_set_border_style(current.con, border_style, logical_px(con_border_width))
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_append_layout(cpath)
	path = cpath.dup
	puts "Appending layout \"#{path}\""

	path = resolve_tilde(path)

	if !json_validate(buf, len)
		puts "Could not parse \"#{path}\" as JSON, not loading"
		puts "Could not parse \"#{path}\" as JSON."
		return
	end

	content = json_determine_content(buf, len)
	puts "JSON content = #{content}"
	if content = JSON_CONTENT_UNKNOWN
		puts "Could not determine the contents of \"#{path}\", not loading"
		puts "Could not determine the contents of \"#{path}\"."
	end

	parent = focused
	if content = JSON_CONTENT_WORKSPACE
		parent = output_get_content(con_get_output(parent))
	else
		while parent.type != CT_WORKSPACE && !con_accepts_window(parent)
			parent = parent.parent
		end
	end
	puts "Appending to parent=#{parent} instead of focused=#{focused}"
	tree_append_json(parent, buf, len, errormsg)
	if errormsg
		yerror(errormsg)
	else
		ysuccess(true)
	end
	render_con(croot, false, false)
	restore_open_placeholder_windows(parent)
	if content == JSON_CONTENT_WORKSPACE
		ipc_send_workspace_event("restored", parent, nil)
	end
	cmd_output.needs_tree_render = true
end

def cmd_workspace(which)
	if con_get_fullscreen_con(croot, CF_GLOBAL)
		puts "Cannot switch workspace while in global fullscreen"
		ysuccess(false)
		return
	end

	if which.compare "next" == 0
		ws = workspace_next()
	elsif which.compare "prev" == 0
		ws = workspace_prev()
	elsif which.compare "prev" == 0
		ws = workspace_next_on_output()
	elsif which.compare "prev" == 0
		ws = workspace_prev_on_output()
	else
		ysuccess(false)
		return
	end
	workspace_show(ws)
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_workspace_number(which, _no_auto_back_and_forth)
	no_auto_back_and_forth = _no_auto_back_and_forth.size != 0
	if con_get_fullscreen_con(croot, CF_GLOBAL)
		puts "Cannot switch workspace while in global fullscreen"
		ysuccess(false)
		return
	end
	parsed_num = ws_name_to_number(which)
	if parsed_num == -1
		puts "Could not parse initial part of \"#{which}\" as a number."
		puts "Could not parse number \"#{which}\""
		return
	end
	croot.nodes_head.each do |output|
		grep_first(workspace, output_get_content(output), child.num == parsed_num)
	end
	if !workspace
		puts "There is no workspace with number #{parsed_num}, creating a new one."
		ysuccess(true)
		workspace_show_by_name(which)
		cmd_output.needs_tree_render = true
		return
	end
	if !no_auto_back_and_forth && maybe_back_and_forth(cmd_output, workspace.name)
		ysuccess(true)
		return
	end
	workspace_show(workspace)
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_workspace_back_and_forth()
	if con_get_fullscreen_con(croot, CF_GLOBAL)
		puts "Cannot switch workspace while in global fullscreen"
		ysuccess(false)
		return
	end
	workspace_back_and_forth()
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_workspace_name(name, _no_auto_back_and_forth)
	no_auto_back_and_forth = _no_auto_back_and_forth.size == 0
	if name.compare "__" == 0
		puts "You cannot switch to the i3-internal workspaces (\"#{name}\")."
		ysuccess(false)
		return
	end
	if con_get_fullscreen_con(croot, CF_GLOBAL)
		puts "Cannot switch workspace while in global fullscreen"
		ysuccess(false)
		return
	end
	puts "should switch to workspace #{name}"
	if !no_auto_back_and_forth && maybe_back_and_forth(cmd_output, name)
		ysuccess(true)
		return
	end
	workspace_show_by_name(name)
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_mark(mark, mode, toggle)
	handle_empty_match
	current = owindows.first
	if !current
		ysuccess(false)
		return
	end
	if current != owindows.last
		puts "A mark must not be put onto more than one window"
		return
	end
	puts "matching: #{current.con} / #{current.con.name}"
	mark_mode = (!mode || mode.compare "--replace" == 0) ? MM_REPLACE : MM_ADD
	if !toggle
		con_mark_toggle(current.con, mark, mark_mode)
	else
		con_mark(current.con, mark, mark_mode)
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_unmark(mark)
	if match_is_empty(current_match)
		con_unmark(nil, mark)
	else
		owindows.each do |current|
			con_unmark(current.con, mark)
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_mode(mode)
	switch_mode(mode)
	ysuccess(true)
end

def cmd_move_con_to_output(name)
	puts "Should move window to output \"#{name}\"."
	handle_empty_match
	had_error = false
	owindows.each do |current|
		puts "matching: #{current.con} / #{current.con.name}"
		had_error |= !con_move_to_output_name(current.con, name, true)
	end
	cmd_output.needs_tree_render = true
	ysuccess(!had_error)
end

def cmd_move_con_to_mark(mark)
	puts "moving window to mark \"#{mark}\""
	handle_empty_match
	result = true
	owindows.each do |current|
		puts "moving matched window #{current.con} / #{current.con.name} to mark \"#{mark}\""
		result &= con_move_to_mark(current.con, mark)
	end
	cmd_output.needs_tree_render = true
	ysuccess(result)
end

def cmd_floating(floating_mode)
	puts "floating_mode=#{floating_mode}"
	handle_empty_match
	owindows.each do |current|
		puts "matching: #{current.con} / #{current.con.name}"
		if floating_mode.compare "toggle" == 0
			puts "should toggle mode"
			toggle_floating_mode(current.con, false)
		else
			puts "should switch mode to #{floating_mode}"
			if floating_mode.compare "enable" == 0
				floating_enable(current.con, false)
			else
				floating_disable(current.con, false)
			end
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_move_workspace_to_output(name)
	puts "should move workspace to output #{name}"
	handle_empty_match
	owindows.each do |current|
		ws = con_get_workspace(current.con)
		next if con_is_internal(ws)
		success = workspace_move_to_output(ws, name)
		if !success
			puts "Failed to move workspace to output"
			ysuccess(false)
			return
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_split(direction)
	puts "splitting in direction #{direction[0]}"
	owindows.each do |current|
		if con_is_docked(current.con)
			puts "Cannot split a docked container, skipping"
			next
		end
		puts "matching: #{current.con} / #{current.con.name}"
		if direction[0] == 't'
			if current.con.type == CT_WORKSPACE
				current_layout = current.con.layout
			else
				current_layout = current.con.parent.layout
			end
			if current_layout = L_SPLITH
				tree_split(current.con, VERT)
			else
				tree_split(current.con, HORIZ)
			end
		else
			tree_split(current.con, (direction[0] == 'v' ? VERT : HORIZ))
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_kill(kill_mode_str)
	if !kill_mode_str
		kill_mode_str = "window"
	end
	puts "kill_mode=#{kill_mode_str}"
	if kill_mode_str.compare "window" == 0
		kill_mode = KILL_WINDOW
	elsif kill_mode_str.compare "client" == 0
		kill_mode = KILL_CLIENT
	else
		ysuccess(false)
		return
	end
	handle_empty_match
	owindows.each do |current|
		con_close(current.con, kill_mode)
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_exec(nosn, command)
	no_startup_id = nosn.size != 0
	puts "should execute #{command}, no_startup_id = #{no_startup_id}"
	start_application(command, no_startup_id)
	ysuccess(true)
end

def cmd_focus_direction(direction)
	puts "direction = *#{direction}*"
	if direction.compare "left" == 0
		tree_next('p', HORIZ)
	elsif direction.compare "right" == 0
		tree_next('n', HORIZ)
	elsif direction.compare "up" == 0
		tree_next('p', VERT)
	elsif direction.compare "down" == 0
		tree_next('n', VERT)
	else
		puts "Invalid focus direction (#{direction})"
		ysuccess(false)
		return
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_focus_force_focus(con)
	ws = con_get_workspace(con)
	fullscreen_on_ws = focused && focused.fullscreen_mode == CF_GLOBAL ? focused : con_get_fullscreen_con(ws, CF_OUTPUT)
	if fullscreen_on_ws && fullscreen_on_ws != con && !con_has_parent(con, fullscreen_on_ws)
		con_disable_fullscreen(fullscreen_on_ws)
	end
	con_activate(con)
end

def cmd_focus_window_mode(window_mode)
	puts "window_mode = #{window_mode}"
	to_floating = false
	if window_mode.compare "mode_toggle" == 0
		to_floating = !con_inside_floating(focused)
	elsif window_mode.compare "floating" == 0
		to_floating = true
	elsif window_mode.compare "tiling" == 0
		to_floating = false
	end
	ws = con_get_workspace(focused)
	success = false
	ws.focus_head.each do |current|
		next if (to_floating && current.type != CF_FLOATING_CON) || (!to_floating && current.type == CT_FLOATING_CON)
		cmd_focus_force_focus(con_descend_focused(current))
		success = true
		break
	end
	if success
		cmd_output.needs_tree_render = true
		ysuccess(true)
	else
		yerror("Failed to find a #{to_floating ? "floating" : "tiling"} container in workspace."
	end
end

def cmd_focus_level(level)
	success = false
	if level.compare "parent" == 0
		if focused && focused.parent
			if con_fullscreen_permits_focusing(foucsed.parent)
				success = level_up()
			else
				puts "'focus parent': Currently in fullscreen, not going up"
			end
		end
	else
		success = level_down()
	end
	cmd_output.needs_tree_render = success
	ysuccess(success)
end

def cmd_focus()
	puts "current_match = #{current_match}"
	if match_is_empty(current_match)
		puts "You have to specify which window/container should be focused"
		puts "Example: [class=\"urxvt\" title=\"irssi\"] focus"
		puts "You have to specify which window/container should be focused"
		return
	end
	__i3_scratch = workspace_get("__i3_scratch", nil)
	count = 0
	owindows.each do |current|
		ws = con_get_workspace(current.con)
		next if !ws
		if ws == __i3_scratch
			scratchpad_show(current.con)
			count += 1
			break
		end
		currently_focused = focused
		cmd_focus_force_focus(current.con)
		con_activate(currently_focused)
		workspace_show(ws)
		puts "focusing #{current.con} / #{current.con.name}"
		con_activate(current.con)
		count += 1
	end
	if count > 1
		puts "WARNING: Your criteria for the focus command matches #{count} containers, "
		puts "while only exactly one container can be focused at a time."
	end
	cmd_output.needs_tree_render = true
	ysuccess(count > 0)
end

def cmd_fullscreen(action, fullscreen_mode)
	mode = fullscreen_mode.compare "global" == 0 ? CF_GLOBAL : CF_OUTPUT
	puts "#{action} fullscreen, mode = #{fullscreen_mode}"
	handle_empty_match
	owindows.each do |current|
		puts "matching: #{current.con} / #{current.con.name}"
		if action.compare "toggle" == 0
			con_toggle_fullscreen(current.con, mode)
		elsif action.compare "enable" == 0
			con_enable_fullscreen(current.con, mode)
		elsif action.compare "disable" == 0
			con_disable_fullscreen(current.con)
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_sticky(action)
	handle_empty_match
	owindows.each do |current|
		next if !current.con.window
		puts "setting sticky for container = #{current.con} / #{current.con.name}"
		sticky = false
		if action.compare "enable" == 0
			sticky = true
		elsif action.compare "disable" == 0
			sticky = false
		elsif action.compare "toggle" == 0
			sticky = !current.con.sticky
		end
		current.con.sticky = sticky
		ewmh_update_sticky(current.con.window.id, sticky)
	end
	output_push_sticky_windows(focused)
	ewmh_update_wm_desktop()
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_move_direction(direction, move_px)
	handle_empty_match
	initially_focused = focused
	owindows.each do |current|
		puts "moving in direction #{direction}, px #{move_px}"
		if con_inside_floating(current.con)
			puts "floating move with #{move_px} pixels"
			newrect = current.con.parent.rect
			if direction.compare "left" == 0
				newrect.x -= move_px
			elsif direction.compare "right" == 0
				newrect.x += move_px
			elsif direction.compare "up" == 0
				newrect.y -= move_px
			elsif direction.compare "down" == 0
				newrect.y += move_px
			end
			floating_reposition(current.con.parent, newrect)
		else
			tree_move(current.con, direction.compare == 0 ? D_RIGHT : direction.compare "left" == 0 ? D_LEFT : direction.compare "up" == 0 ? D_UP : D_DOWN)
			cmd_output.needs_tree_render = true
		end
	end
	if focused != initially_focused
		con_activate(initially_focused)
	end
	ysuccess(true)
end

def cmd_layout(layout_str)
	handle_empty_match
	if layout_from_name(layout_str, layout)
		puts "Unknown layout \"#{layout_str}\", this is a mismatch between code and parser spec."
		return
	end
	puts "changing layout to #{layout_str} (#{layout})\n"
	owindows.each do |current|
		if con_is_docked(current.con)
			puts "cannot change layout of a docked container, skipping it."
			next
		end
	end
	puts "matching: #{current.con} / #{current.con.name}"
	con_set_layout(current.con, layout)
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_layout_toggle(toggle_mode)
	if !toggle_mode
		toggle_mode = "default"
	end
	puts "toggling layout (mode = #{toggle_mode})"
	if match_is_empty(current_match)
		con_toggle_layout(focused, toggle_mode)
	else
		owindows.each do |current|
			puts "matching: #{current.con} / #{current.con.name}"
			con_toggle_layout(current.con, toggle_mode)
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_reload()
	puts "reloading"
	kill_nagbar(config_error_nagbar_pid, false)
	kill_nagbar(command_error_nagbar_pid, false)
	load_configuration(conn, nil, true)
	x_set_i3_atoms()
	ipc_send_workspace_event("reload", nil, nil)
	update_barconfig()
	ysuccess(true)
end

def cmd_restart()
	puts "restarting i3"
	ipc_shutdown(SHUTDOWN_REASON_RESTART)
	unlink(config.ipc_socket_path)
	purge_zerobyte_logfile()
	i3_restart(false)
	ysuccess(true)
end

def cmd_open()
	puts "opening new container"
	con = tree_open_con(nil, nil)
	con.layout = L_SPLITH
	con_activate(con)
	y(map_open)
	ystr("success")
	y(Bool, true)
	ystr("id")
	y(integer, con)
	y(map_close)
	cmd_output.needs_tree_render = true
end

def cmd_focus_output(name)
	puts "name = #{name}"
	handle_empty_match
	owindows.each do |current|
		current_output = get_output_for_con(current.con)
	end
	output = get_output_from_string(current_output, name)
	if !output
		puts "No such output found"
		ysuccess(false)
		return
	end
	grep_first(ws, output_get_content(output.con), workspace_is_visible(child))
	if !ws
		ysuccess(false)
		return
	end
	workspace_show(ws)
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_move_window_to_position(method, x, y)
	has_error = false
	handle_empty_match
	owindows.each do |current|
		if !con_is_floating(current.con)
			puts "Cannot change position. The window/container is not floating"
			if !has_error
				yerror("Cannot change position of a window/container because it is not floating.")
				has_error = true
			end
			next
		end
		if method.compare "absolute" == 0
			current.con.parent.rect.x = x
			current.con.parent.rect.y = y
			puts "moving to absolute position #{x} #{y}"
			floating_maybe_reassign_ws(current.con.parent)
			cmd_output.needs_tree_render = true
		end
		if method.compare "position" == 0
			newrect = current.con.parent.rect
			puts "moving to position #{x} #{y}"
			newrect.x = x
			newrect.y = y
			floating_reposition(current.con.parent, newrect)
		end
	end
	if !has_error
		ysuccess(true)
	end
end

def cmd_move_window_to_center(method)
	has_error = false
	handle_empty_match
	owindows.each do |current|
		floating_con = con_inside_floating(current.con)
		if !floating_con
			puts "con #{current.con} / #{current.con.name} is not floating, cannot move it to the center."
			if !has_error
				yerror("Cannot change position of a window/container because it is not floating")
				has_error = true
			end
			next
		end
		if method.compare "absolute" == 0
			puts "moving to absolute center"
			floating_center(floating_con, croot.rect)
			floating_maybe_reassign_ws(floating_con)
			cmd_output.needs_tree_render = true
		end
		if method.compare "position" == 0
			puts "moving to center"
			floating_center(floating_con, con_get_workspace(floating_con).rect)
			cmd_output.needs_tree_render = true
		end
	end
	if !has_error
		ysuccess(true)
	end
end

def cmd_move_window_to_mouse()
	owindows.each do |current|
		floating_con = con_inside_floating(current.con)
		if !floating_con
			puts "con #{current.con} / #{current.con.name} is not floating, cannot move it to the mouse position."
			next
		end
		puts "moving floating container #{floating_con} / #{floating_con.name} to cursor position"
		floating_move_to_pointer(floating_con)
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_move_scratchpad()
	puts "should move window to scratchpad"
	handle_empty_match
	owindows.each do |current|
		puts "matching: #{current.con} / #{current.con.name}"
		scratchpad_move(current.con)
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_scratchpad_show()
	puts "should show scratchpad window"
	if match_is_empty(current_match)
		scratchpad_show(nil)
	else
		owindows.each do |current|
			puts "matching: #{current.con} / #{current.con.name}"
			scratchpad_show(current.con)
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_swap(mode, arg)
	match = owindows.first
	if !match
		puts "No match found for swapping."
		return
	end
	if mode.compare "id" == 0
		if !arg.as(Int64) > 0
			yerror("Failed to parse #{arg} into a window id.")
			return
		end
		con = con_by_window_id(target)
	elsif mode.compare "con_id" == 0
		if !arg.as(Int64) > 0
			yerror("Failed to parse #{arg} into a container id.")
			return
		end
		con = con_by_con_id(target)
	elsif mode.compare "mark" == 0
		con = con_by_mark(arg)
	else
		yerror("Unhandled swap mode \"#{mode}\". This is a bug.")
		return
	end
	if con!
		puts "Could not find container for #{mode} = #{arg}"
		return
	end
	if match != owindows.last
		puts "More than one container matched the swap command, only using the first one."
	end
	if !match.con
		puts "Match #{match} has no container."
		ysuccess(false)
		return
	end
	puts "Swapping #{match.con} with #{con}"
	result = con_swap(match.con, con)
	cmd_output.needs_tree_render = true
	ysuccess(result)
end

def cmd_title_format(format)
	puts "setting title format to \"#{format}\""
	handle_empty_match
	owindows.each do |current|
		puts "setting title_format for #{current.con} / #{current.con.name}"
		if format.compare "%title" != 0
			current.con.title_format = format.dup
			if !current.con.window
				formatted_title = con_parse_title_format(current.con)
				ewmh_update_visible_name(current.con.window.id, i3string_as_utf8(formatted_title))
			else
				if current.con.window
					ewmh_update_visible_name(current.con.window.id, nil)
				end
			end
		end
		if current.con.window
			current.con.window.name_x_changed = true
		end
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end

def cmd_rename_workspace(old_name, new_name)
	if new_name.compare "__" == 0
		puts "Cannot rename workspace to \"#{new_name}\": names starting with __ are i3-internal."
		ysuccess(false)
		return
	end
	if old_name
		puts "Renaming workspace \"#{old_name}\" to \"#{new_name}\""
	else
		puts "Renaming workspace to \"#{new_name}\""
	end
	if old_name
		croot.nodes_head.each do |output|
			grep_first(workspace, output_get_content(output), !child.name.compare old_name)
		end
	else
		workspace = con_get_workspace(focused)
		old_name = workspace.name
	end
	if !workspace
		yerror("Old workspace \"#{old_name}\" not found")
		return
	end
	croot.nodes_head.each do |output|
		grep_first(check_dest, output_get_content(output), !child.name.compare(new_name))
	end
	if !check_dest && check_dest != workspace
		yerror("New workspace \"#{new_name}\" already exists")
		return
	end
	old_name_copy = old_name.dup
	workspace.name = new_name.dup
	workspace.num = ws_name_to_number(new_name)
	puts "num = #{workspace.num}"
	previously_focused = focused
	parent = workspace.parent
	con_detach(workspace)
	con_attach(workspace, parent, false)
	ws_assignments.each do |assignment|
		next if !assignment.output
		next if assignment.name.compare workspace.name != 0 && (!name_is_digits(assignment.name) || ws_name_to_number(assignment.name) != workspace.num)
		workspace_move_to_output(workspace, assignment.output)
		if previously_focused
			workspace_show(con_get_workspace(previously_focused))
		end
		break
	end
	con_activate(previously_focused)
	cmd_output.needs_tree_render = true
	ysuccess(true)
	ipc_send_workspace_event("rename", workspace, nil)
	ewmh_update_desktop_names()
	ewmh_update_desktop_viewport()
	ewmh_update_current_desktop()
	startup_sequence_rename_workspace(old_name_copy, new_name)
end

def cmd_bar_mode(bar_mode, bar_id)
	mode = M_DOCK
	toggle = false
	if bar_mode.compare "dock" == 0
		mode  = M_DOCK
	elsif bar_mode.compare "hide" == 0
		mode = M_INVISIBLE
	elsif bar_mode.compare "invisible" == 0
		toggle = true
	elsif bar_mode.compare "toggle" == 0
		puts "Unknown bar mode \"#{bar_mode}\", this is a mismatch between code and parser spec."
		return false
	end
	changed_sth = false
	barconfigs.each do |current|
		next if bar_id && current.id.compare bar_id != 0
		if toggle
			mode = (current.mode + 1) % 2
		end
		puts "Changing bar mode of bar_id '#{current.id}' to '#{bar_mode} (#{mode})'"
		current.mode = mode
		changed_sth
		next if bar_id
	end
	if bar_id && !changed_sth
		puts "Changing bar mode of bar_id #{bar_id} failed, bar_id not found"
		return false
	end
	return true
end

def cmd_bar_hidden_state(bar_hidden_state, bar_id)
	hidden_state = S_SHOW
	toggle = false
	if bar_hidden_state.compare "hide" == 0
		hidden_state = S_HIDE
	elsif bar_hidden_state.compare "show" == 0
		hidden_state = S_SHOW
	elsif bar_hidden_state.compare "toggle" == 0
		toggle = true
	else
		puts "Unknown bar state \"#{bar_hidden_state}\", this is a mismatch between code and parser spec."
		return false
	end
	changed_sth = false
	barconfigs.each do |current|
		next if bar_id && current.id.compare bar_id != 0
		if toggle
			hidden_state = (current.hidden_state + 1) % 2
		end
		puts "Changing bar hidden_state of bar_id '#{current.id}' to '#{bar_hidden_state} (#{hidden_state})'"
		current.hidden_state = hidden_state
		changed_sth = true
		next if bar_id
	end
	if bar_id && !changed_sth
		puts "Changing bar hidden_state of bar_id #{bar_id} failed, bar_id not found."
		return false
	end
	return true
end

def cmd_bar(bar_type, bar_value, bar_id)
	if bar_type.compare "mode" == 0
		ret = cmd_bar_mode(bar_value, bar_id)
	elsif bar_type.compare "hidden_state" == 0
		ret = cmd_bar_hidden_state(bar_value, bar_id)
	else
		puts "Unknown bar option type \"#{bar_type}\", this is a mismatch between code and parser spec."
		ret = false
	end
	ysuccess(ret)
	return if !ret
	update_barconfig()
end

def cmd_shmlog(argument)
	if bar_type.compare "mode" == 0
		ret = cmd_bar_mode(bar_value, bar_id)
	elsif bar_type.compare "hidden_state" == 0
		ret = cmd_bar_hidden_state(bar_value, bar_id)
	else
		puts "Unknown bar option type \"#{bar_type}\", this is a mismatch between code and parser spec."
		ret = false
	end
	ysuccess(ret)
	return if !ret
	update_barconfig()
end

def cmd_debuglog(argument)
	logging = get_debug_logging()
	if argument.compare "toggle"
		puts "#{logging ? "Disabling" : "Enabling"} debug logging"
		set_debug_logging(!logging)
	elsif argument.compare "on" && !logging
		puts "Enabling debug logging"
		set_debug_logging(true)
	elsif argument.compare "off" && !logging
		puts "Disabling debug logging"
		set_debug_logging(false)
	end
	ysuccess(false)
end

macro cmd_gaps(type, other)
	pixels = logical_px(value)
	workspace = con_get_workspace(focused)
	current_value = config.gaps.type
	if scope.compare "current" == 0
		current_value += workspace.gaps.type
	end
	reset = false
	if mode.compare "plus"
		current_value += pixels
	elsif mode.compare "minus"
		current_value -= pixels
	elsif mode.compare "set"
		current_value = pixels 
		reset = true
	else
		puts "Invalid mode #{mode} when changing gaps"
		ysuccess(false)
		return
	end
	if current_value < 0
		current_value = 0
	end
	if !scope.compare "all"
		croot.nodes_head.each do |output|
			content = output_get_content(output)
			content.nodes_head.each do |cur_ws|
				if reset
					cur_ws.gaps.type = 0
				elsif current_value + cur_ws.gaps.type < 0
					cur_ws.gaps.type = -current_value
				end
			end
		end
		config.gaps.type = current_value
	else
		workspace.gaps.type = urrent_value - config.gaps.type
	end
end

def cmd_gaps(type, scope, side, mode, value)
	if !type.compare "inner"
		cmd_gaps(inner, outer)
	elsif !type.compare "outer"
		if !side || side.compare "top" == 0 || side.compare "vertical" == 0
			cmd_gaps(outer.top, inner)
		end
		if !side || side.compare "left" == 0 || side.compare "horizontal" == 0
			cmd_gaps(outer.left, inner)
		end
		if !side || side.compare "bottom" == 0 || side.compare "vertical" == 0
			cmd_gaps(outer.bottom, inner)
		end
		if !side || side.compare "right" == 0 || side.compare "vertical" == 0
			cmd_gaps(outer.right, inner)
		end
	else
		puts "Invalid type #{type} when changing gaps"
		ysuccess(false)
		return
	end
	cmd_output.needs_tree_render = true
	ysuccess(true)
end
