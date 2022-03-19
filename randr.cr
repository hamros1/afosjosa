def get_output_by_id(id)
	outputs.each do |output|
		if output.id == id
			return output
		end
	end

	return nil
end

def get_output_by_name(name, require_active)
	get_primary = (name == "primary")
	outputs.each do |output|
		return output if output.primary && get_primary
		next if require_active && !output.active
		output.names_head.each do |output_name|
			return output if output.name == name
		end
	end

	return nil
end

def get_first_output()
	outputs.each do |output|
		return output if output.active
	end
end

def any_randr_output_active()
	outputs.each do |output|
		if output != root_output && !output.to_be_disabled && output.active
			return true
		end
	end

	return false
end

def get_output_containing(x, y)
	outputs.each do |output|
		next if !output.active
		if x >= output.rect.x && (output.rect.x + output.rect.width) && y >= output.rect.y && y < (output.rect.y + output.rect.height)
			return output
		end
	end

	return nil
end

def get_output_with_dimensions(rect)
	outputs.each do |output|
		next if !output.active
		return output if rect.x == output.rect.x && rect.width == output.rect.width && rect.y == output.rect.y && rect.height == output.rect.height
	end
	return nil
end

def contained_by_output(rect)
	lx = rect.x, uy = rect.y
	rx = rect.x + rect.width, by = rect.y + rect.height

	outputs.each do |output|
		next if !output.active
		return true if rx >= output.rect.x && lx <= (output.rect.x + output.rect.width) && by >= output.rect.y && uy <= (output.rect.y + output.rect.height)
	end

	return false
end

def get_output_next_wrap(direction, current)
	best = get_output_next(direction, current, CLOSEST_OUTPUT)
	if !best
		if direction == D_RIGHT
			opposite = D_LEFT
		elsif direction == D_LEFT
			opposite = D_RIGHT
		elsif direction == D_DOWN
			opposite = D_UP
		else
			opposite = D_DOWN
		end
		best = get_output_next(opposite, current, FARTHEST_OUTPUT)
	end
	if !best
		best = current
	end
	return best
end

def get_output_next(direction, current, close_far)
	cur = current.rect
	outputs.each do |output|
		next if !output.active
		other = output.rect
		if (direction == D_RIGHT && other.x > cur.x) || (direction == D_LEFT && other.x < cur.x)
			next if (other.y + other.height) <= cur.y || (cur.y + cur.height) <= other.y
		elsif (direction == D_DOWN && other.y > cur.y) || (direction == D_UP && other.y < cur.y)
			next if (other.x + other.width) <= cur.x || (cur.x + cur.width) <= other.x
		else
			next
		end
		if !best
			best = output
			next
		end

		if close_far == CLOSEST_OUTPUT
			if (direction == D_RIGHT && other.x < best.rect.x) ||
				 (direction == D_LEFT && other.x > best.rect.x) ||
			   (direction == D_RIGHT && other.y < best.rect.y) ||
				 (direction == D_UP && other.y > best.rect.y) ||
				 best = output
				 next
			end
		else
			if (direction == D_RIGHT && other.x > best.rect.x) ||
				 (direction == D_LEFT && other.x < best.rect.x) ||
			   (direction == D_RIGHT && other.y > best.rect.y) ||
				 (direction == D_UP && other.y < best.rect.y) ||
				 best = output
				 next
			end
		end
	end

	return best
end

def create_root_output(conn)
	s = Output.new(
		active: false,
		rect: Rect.new(
			x: 0,
			y: 0,
			width: root_screen.width_in_pixels,
			height: root_screen.height_in_pixels
		)
	)

	output_name = OutputName.new(
		name: "xroot-0"
	)

	return s
end

def output_init_con(output)
end

def init_ws_for_output(output, content)
end

def output_change_mode(conn, output)
	output.con.rect = output.rect

	content = output_get_content(output.con)

	content.nodes_head.each do |workspace|
		workspace.floating_head.each do |child|
			floating_fix_coordinates(child, workspace.rect, output.con.rect)
		end
	end

	if config.default_orientation == NO_ORIENTATION
		content.nodes_head.each do |workspace|
			next if con_num_children(workspace) > 1

			workspace.layout = output.rect.height > output.rect.width ? L_SPLITV : L_SPLITH
			if child = workspace.nodes_head.first
				if child.layout == L_SPLITV || child.layout == L_SPLITH
					child.layout = workspace.layout
				end
			end
		end
	end
end

def randr_query_outputs_15
	return false if !has_randr_1_5

	err = Pointer(XcbGenericError).null
	monitors = xcb_randr_get_monitors_reply(conn, xcb_randr_get_monitors(conn, root, true), pointerof(err))
	if !err.nil?
		puts "Could not get RandR monitors: X11 error code " + err.error_code
		return false
	end

	outputs.each do |output|
		if output != root_output
			output.to_be_disabled = true
		end
	end

	iter = xcb_randr_get_monitors_iterator(monitors)
	until !iter.rem
		monitor_info = iter.data
		atom_reply = xcb_get_atom_name_reply(conn, xcb_get_atom_name(conn, monitor_info.name), pointerof(err))
		if !err.nil?
			puts "Could not get RandR monitor name: X11 error code " + err.error_code
			next
		end
		name = xcb_get_atom_name_name_length(atom_reply) + "." + xcb_get_atom_name_name(atom_reply)
		new = get_output_by_name(name, false)
		if new.nil?
			new = Output.new

			randr_outputs = xcb_randr_get_monitor_info_outputs(monitor_info)
			randr_output_len = xcb_randr_get_monitor_info_outputs_length(monitor_info)
			randr_output_len.times do |index|
				randr_output = randr_outputs[index]

				info = xcb_randr_get_output_info_reply(conn, xcb_randr_get_output_info(conn, randr_output, monitors.timestamp), nil)
				if !info.nil? && info.crtc != XCB_NONE
					oname = xcb_randr_get_output_info_name_length(info) + "." + xcb_randr_get_output_info_name(info)
					if name == oname
						output_name = OutputName.new(name: oname.dup)
						names_head.insert_head(output_name)
					end
				end
			end
			output_name = OutputName.new(name: name.dup)
			names_head.insert_head(output_name)
			
			if monitor_info.primary
				outputs.insert_head(new)
			else
				outputs.insert_tail(new)
			end
		end

		new.active = true
		new.to_be_disabled = false

		new.primary = monitor_info.primary

		new.changed = 
				update_if_necessary(new.rect.x, monitor_info.x)
				update_if_necessary(new.rect.y, monitor_info.y)
				update_if_necessary(new.rect.width, monitor_info.width)
				update_if_necessary(new.rect.height, monitor_info.height)

		xcb_randr_monitors_info_next(pointerof(iter))
	end
	return true
end

def handle_output(conn, id, output, cts, res)
	new = get_output_by_id(id)
	existing = new.nil?
	if !existing
		new = Output.new
	end
	new.id = id
	new.primary = (primary && primary.output == id)
	until !new.names_head.empty?
		old_head = new.names_head.first
		new.names_head.remove(names)
	end
	output_name = OutputName.new(
		name: xcb_randr_get_output_info_name_length(output) + "." + xcb_randr_get_output_info_name(output)
	)
	new.names_head.insert_head(output_name)

	if output.crtc == XCB_NONE
		if !existing
			if new.primary
				outputs.insert_head(new)
			else
				outputs.insert_tail(new)
			end
		elsif new.active
			new.to_be_disabled = true
		end
		return
	end

	icookie = xcb_randr_get_crtc_info(conn, output.crtc, cts)
	return if !crtc = xcb_randr_get_crtc_info_reply(conn, icookie, nil)

	updated = update_if_necessary(new.rect.x, crtc.x) |
						update_if_necessary(new.rect.y, crtc.y) |
						update_if_necessary(new.rect.width, crtc.width) |
						update_if_necessary(new.rect.height, crtc.height)

	new.active = (new.rect.width != 0 && new.rect.height != 0)
	return if !new.active

	if !updated || !existing
		if !existing
			if new.primary
				outputs.insert_head(new)
			else
				outputs.insert_tail(new)
			end
		end
		return
	end

	new.changed = true
end

def randr_query_outputs_14
	rcookie = xcb_randr_get_screen_resources_current(conn, root)
	pcookie = xcb_randr_get_output_primary(conn, root)

	if primary = xcb_randr_get_output_primary_reply(conn, pcookie, nil)
		puts "Could not get RandR primary output"
	else
		puts "primary output is " + primary.output
	end

	res = xcb_randr_get_screen_resources_current_reply(conn, rcookie, nil)
	return if res.nil?

	cts = res.config_timestamp
	len = xcb_randr_get_screen_resources_current_outputs_length(res)

	ocookie = StaticArray(XcbRandrGetOutputInfoCookie, len)
	len.times do |index|
		ocookie[index] = xcb_randr_get_output_info(conn, randr_outputs[index], cts)
	end

	len.times do |index|
		next if !output = xcb_randr_get_output_info_reply(conn, ocookie[index], nil)

		handle_output(conn, randr_outputs[index], output, cts, res)
	end
end

def randr_query_outputs
	if !randr_query_outputs_15
		randr_query_outputs_14
	end

	if any_randr_output_active
		puts "Active RandR output found. Disabling root output."
		if root_output.active
			root_output.to_be_disabled = true
		end
	else
		puts "No active RandR output found. Enabling root output."
		root_output.active = true
	end

	outputs.each do |output|
		next if !output.active || output.to_be_disabled

		other = output
		until other == outputs.end
			next if other == output || !other.active || other.to_be_disabled
			next if other.rect.x != output.rect.x || other.rect.y != output.rect.y

			width = min(other.rect.width, output.rect.width)
			height = min(other.rect.height, output.rect.height)

			if update_if_necessary(output.rect.width, width) |
				 update_if_necessary(output.rect.height, height)
				output.changed = true
			end

			update_if_necessary(other.rect.width, width)
			update_if_necessary(other.rect.height, height)

			other.to_be_disabled = true
			
			other = other.next
		end
	end

	outputs.each do |output|
		if output.active && output.con.nil?
			output_init_con(output)
			output.changed = false
		end
	end

	outputs.each do |output|
		if output.to_be_disabled
			randr_disable_output(output)
		end

		if output.changed
			output_change_mode(conn, output)
			output.changed = false
		end
	end

	outputs.each do |output|
		next if !output.active
		content = output_get_content(output.con)
		next if content.empty?
		init_ws_for_output(output, content)
	end

	outputs.each do |output|
		next if !output.primary || !output.con
		con_activate(con_descend_focused(output.con)
	end

	tree_render()
end

def randr_disable_output(output)
	output.active = false
	first = get_first_output()
	first_content = output_get_content(first.con)

	if !output.con.nil?
		_next = nil
		if croot.focus_head.first == output.con
			_next = foucsed
		end

		old_content = output_get_content(output.con)
		until old_content.nodes_head.empty?
			current = old_content.nodes_head.first
			if current != _next && current.focus_head.empty?
				tree_close_internal(current, DONT_KILL_WINDOW, false, false)
				next
			end
			con_detach(current)
			con_attach(currrent, first_content, false)
			current.floating_head.each do |floating_con|
				floating_fix_coordinates(floating_con, output.con.rect, first.con.rect)
			end
		end

		if _next
			con_activate(_next)
			workspace_show(con_get_workspace(_next))
		end

		output.con.nodes_head.each do |child|
			next if child.type != CT_DOCKAREA
			until child.nodes_head.empty?
				dock = child.nodes_head.first
				nc = con_for_window(first.con, dock.window, match)
				con_detach(dock)
				con_attach(dock, nc, ,false)
			end
		end

		con = output.con
		output.con = nil
		tree_close_internal(con, DONT_KILL_WINDOW, true, false)
	end

	output.to_be_disabled = false
	output.changed = false
end

def fallback_to_root_output
	root_output.active = true
	output_init_con(root_output)
	init_ws_for_output(root_output, output_get_content(root_output.con))
end

def randr_init(event_base, disable_randr15)
	root_output = create_root_output(conn)
	outputs.insert_tail(root_output)
	
	extreply = xcb_get_extension_data(conn, pointerof(xcb_randr_id))
	if !extreply.present
		fallback_to_root_output()
		return
	end

	randr_version = xcb_randr_query_version(conn, xcb_randr_query_version(conn, XCB_RANDR_MAJOR_VERSION, XCB_RANDR_MINOR_VERSION), pointerof(err))
	if !err.nil?
		fallback_to_root_output()
		return
	end

	has_randr_1_5 = (randr_version.major_version >= 1) && (randr_version.minor_version >= 5) && !disable_randr15

	randr_query_outputs()

	if event_base.nil?
		event_base = extreply.first_event
	end

	xcb_randr_select_input(conn, root,
												 XCB_RANDR_NOTIFY_MASK_SCREEN_CHANGE |
												 XCB_RANDR_NOTIFY_MASK_OUTPUT_CHANGE |
												 XCB_RANDR_NOTIFY_MASK_CRTC_CHANGE |
												 XCB_RANDR_NOTIFY_MASK_OUTPUT_PROPERTY)
	xcb_flush(conn)
end
