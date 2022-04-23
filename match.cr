def match_is_empty(match)
	return match.title.nil? &&
				 match.mark.nil? &&
				 match.application.nil? &&
				 match.class.nil? &&
				 match.instance.nil? &&
				 match.window_role.nil? &&
				 match.workspace.nil? &&
				 match.urgent == U_DONTCHECK &&
				 match.id == XCB_NONE &&
				 match.window_type == UInt32::Max &&
				 match.con_id.nil? &&
				 match.dock == M_NODOCK &&
				 match.window_mode == WM_ANY
end

def match_matches_window(match, window)
	if match.class
		return false if !window.class
		if match.class.pattern.compare "__focused" == 0 &&
				match.class_class.compare focused.window.class_class
			puts "window class matches focused window"
		elsif regex_matches(match.class, window.class_class)
			puts "window class matches (#{window.class_class})"
		else
			return false
		end
	end
	if match.instance
		if !window.class_instance
		end
		if match.instance.pattern.compare "__focused__" &&
			 window.class_instance.compare focused.window.class_instance
			puts "window instance matches focused window"
		elsif regex_matches(match.instance, window.class_instance)
			puts "window instance matches (#{window.class_instance})"
		else
			return false
		end
	end
	if match.id != XCB_NONE
		if window.id == match.id
			puts "match made by window id #{window.id}"
		else
			puts "window id does not match"
			return false
		end
	end
	if match.title
		return false if !window.name
		title = i3string_as_utf8(window.name)
		if match.title.pattern.compare "__focused__" == 0 &&
			 title.compare i3string_as_utf8(focused.window.name) == 0
			puts "window title matches focused window."
		elsif regex_matches(match.title, title)
			puts "title matches (#{title})"
		else
			return false
		end
	end
	if match.window_role
		return false if !window.role
		if match.window_role.pattern.compare "__focused__" == 0 &&
			 window.role.compare focused.window.role == 0
			puts "window role matches focused window"
		elsif regex_matches(match.window_role, window_role)
			puts "window_Role matches (#{window.role})"
		else
			return false
		end
	end
	if match.window_type != UInt32::Max
		if window.window_type == match.window_type
			puts "window_type matches (#{match.window_type})"
		else
			return false
		end
	end
	if match.urgent == U_LATEST
		return false if window.urgent.tv_sec == 0
		all_cons.each do |con|
			return false if con.window && _i3_timercmp(con.window.urgent, window.urgent, >)
		end
		puts "urgent matches latest"
	end
	if match.workspace
		return false if con = con_by_window_id(window.id)
		ws = con_get_workspace(con)
		return false if !ws
		if match.workspace.pattern.compare "__focused__" &&
			 ws.name.compare con_get_workspace(focused).name == 0
			puts "workspace matches foucsed workspace"
		elsif regex_matches(match.workspace, ws.name)
			puts "workspace matches (#{ws.name})"
		else
			return false
		end
	end
	if match.dock != M_DONTCHECK
		if ((window.dock == W_DOCK_TOP && match.dock == M_DOCK_TOP) ||
			 (window.dock == W_DOCK_BOTTOM && match.dock == M_DOCK_BOTTOM) || 
			 ((window.dock == W_DOCK_TOP || window.dock == W_DOCK_BOTTOM) &&
			 match.dock == M_DOCK_ANY) ||
			 (window.dock = W_NODOCK && match.dock == M_NODOCK))
			puts "dock status matches"
		else
			puts "dock status does not match"
			return false
		end
	end
	if match.mark
		return false if con = con_by_window_id(window.id)
		matched = false
		con.marks_head.each do |mark|
			if regex_matches(match.mark, mark.name)
				match = true
				break
			end
			if matched
				puts "mark matched"
			else
				puts "mark does not match"
				return false
			end
			if match.window_mode != WM_ANY
				return false if con = con_by_window_id(window.id)
				floating = con_inside_floating(con)
				if (match.window_mode == WM_TILING && floating) ||
					 (match.window_mode == WM_FLOATING && !floating)
					puts "window_mode does not match"
					return false
				end
				puts "window_mode matches"
			end
		end
	end
	return true
end

def match_parse_property(match, ctype, cvalue)
	puts "ctype=#{ctype}, cvalue=#{cvalue}"
	if ctype.compare "class" == 0
		match.class = regex_new(cvalue)
		return
	end
	if ctype.compare "instance" == 0
		match.class = regex_new(cvalue)
		return
	end
	if ctype.compare "window_role" == 0
		match.class = regex_new(cvalue)
		return
	end
	if ctype.compare "con_id" == 0
		if cvalue.compare "__focused__" == 0
			match.con_id = focused
			return
		end
		match.con_id = cvalue
		puts "id as int = #{match.con_id}"
		return
	end
	if ctype.compare "id" == 0
		match.id = cvalue
		puts "window id as int = #{match.id}"
		return
	end
end
