def maybe_back_and_forth(cmd_output, name)
end

def maybe_back_and_forth_workspace(workspace)
end

struct OperationWindow
	property con : Con
	property windows : Dequeue.new(OperationWindow)
end

def cmd_criteria_init(cmd)
end

def cmd_critera_match_windows(cmd)
end

def cmd_crieria_add(cmd, ctype, cvalue)
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
