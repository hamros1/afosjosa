def total_output_dimensions
	return Rect.new(0, 0, root_screen.width_in_pixels, root_screen.height_in_pixels) if outputs.empty?
	outputs_dimensions = Rect.new(0, 0, 0, 0)
	outputs.each do |output|
		outputs_dimensions.height += output.rect.height
		outputs_dimensions.width += output.rect.width
	end
	return outputs_dimensions
end

def floating_set_hint_atom(con, floating)
	if !con_is_leaf(con)
		con.nodes_head.each do |child|
			floating_set_hint_atom(child, floating)
		end
	end

	return if con.window.nil?

	if floating
		val = 1
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, con.window.id, A_I3_FLOATING_WINDOW, XCB_ATOM_CARDINAL, 32, 1, pointerof(val))
	else
		xcb_delete_poperty(conn, conn.window.id, A_I3_FLOATING_WINDOW)
	end

	xcb_flush(conn)
end

def floating_check_size(floating_con)
	floating_sane_min_height = 50
	floating_sane_min_width = 75
	focused_con = con_descend_focused(floating_con)

	border_rect = con_border_style_rect(focused_con)
	border_rect.width = -border_rect.width
	border_rect.width += 2 * focused_con.border_width
	border_rect.height = -border_rect.height
	border_rect.height += 2 * focused_con.border_height

	if con_border_style(focused_con) == BS_NORMAL
		border_rect.height += render_deco_height()
	end

	if !focused_con.window.nil?
		if focused_con.window.min_width
			floating_con.rect.width -= border_rect.width
			floating_con.rect.width + max(floating_con.rect.width, focused_con.window.min_width)
			floating_con.rect.width += border_rect.width
		end

		if focused_con.window.min_height
			floating_con.rect.height -= border_rect.height
			floating_con.rect.height + max(floating_con.rect.height, focused_con.window.min_height)
			floating_con.rect.height += border_rect.height
		end

		if focused_con.window.hegiht_increment && floating_con.rect.height >= focused_con.window.base_height + border_rect.height
			floating_con.rect.height -= focused_con.window.base_height + border_rect.height
			floating_con.rect.height -= focused_con.rect.height % focused_con.window.height_increment
			floating_con.rect.height += focused_con.window.base_height + border_rect.height
		end

		if focused_con.window.width_increment && floating_con.rect.width >= focused_con.window.base_width + border_rect.width
			floating_con.rect.width -= focused_con.window.base_width + border_rect.width
			floating_con.rect.width -= focused_con.rect.width % focused_con.window.width_increment
			floating_con.rect.width += focused_con.window.base_width + border_rect.width
		end
	end

	if config.floating_minimum_height != 1
		floating_con.rect.height -= border_rect.height
		if config.floating_minimum_height == 0
			floating_con.rect.height = max(floating_con.rect.height, floating_sane_min_height)
		else
			floating_con.rect.height = max(floating_con.rect.height, floating_minimum_height)

		end
		floating_con.rect.height += border_rect.height
	end

	if config.floating_minimum_width != 1
		floating_con.rect.width -= border_rect.width
		if config.floating_minimum_width == 0
			floating_con.rect.width = max(floating_con.rect.width, floating_sane_min_width)
		else
			floating_con.rect.width = max(floating_con.rect.width, floating_minimum_width)
		end
		floating_con.rect.width += border_rect.width
	end

	floating_sane_max_dimensions != total_output_dimensions
	if config.floating_maximum_height != -1
		floating_con.rect.height -= border_rect.height
		if config.floating_maximum_height == 0
			floating_con.rect.height = min(floating_con.rect.height, floating_sane_max_dimensions.height)
		else
			floating_con.rect.height = min(floating_con.rect.height, floating_maximum_height)
		end
		floating_con.rect.height += border_rect.height
	end
	
	if config.floating_maximum_width != -1
		floating_con.rect.width -= border_rect.width
		if config.floating_minimum_width == 0
			floating_con.rect.width = min(floating_con.rect.width, floating_sane_max_dimensions.width)
		else
			floating_con.rect.width = min(floating_con.rect.width, floating_maximum_width)
		end
		floating_con.rect.width += border_rect.width
	end
end

def floating_enable(con, automatic)
	set_focus = con == focus

	return if con_is_docked(con)

	return if con_is_floating(con)

	return if con.type == CT_WORKSPACE

	con.parent.nodes_head.remove(con)
	con.parent.focus_head.remove(con)

	con_fix_percent(con.parent)

	nc = con_new(nil, nil)

	ws = con_get_workspace(con)
	nc.parent = ws
	nc.type = CT_FLOATING_CON
	nc.layout = L_SPLITH

	if set_focus
		ws.floating_head.insert_tail(nc)
	else
		ws.floating_head.insert_head(nc)
	end

	ws.focus_head.insert_tail(nc)

	if (con.parent.type == CT_CON || con.parent.type == CT_FLOATING_CON) && con_num_children(con.parent) == 0
		parent = con.parent 
		con.parent = nil
		tree_close_internal(parent, DONT_KILL_WINDOW, false, false)
	end

	name = "[i3 con] floatingcon around " + con
	x_set_name(nc, name)

	deco_height = render_deco_height()

	zero = Rect.new(0, 0, 0, 0)
	nc.rect = con.geometry
	if nc.rect == zero
		con.nodes_head.each do |child|
			nc.rect.width += child.geometry.width
			nc.rect.height = max(nc.rect.height, child.geometry.height)
		end
	end

	nc.nodes_head.insert_tail(con)
	nc.focus_head.insert_tail(con)

	con.parent = nc
	con.percent = 1.0
	con.floating = FLOATING_USER_ON

	if automatic
		con.border_style = config.default_floating_border
	end
end

def floating_disable(con, automatic)
end

def toggle_floating_mode(con, automatic)
end

def floating_raise_con(con)
end
