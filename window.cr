def window_update_name(win, prop, before_mgmt)
	return if prop.nil? || xcb_get_property_value_length(prop) == 0

	win.name = i3string_from_utf8_with_length(xcb_get_property_value(prop), xcb_get_property_value_length(prop))

	con = con_by_window_id(win.id)
	if !con.nil? && !con.title_format.nil?
		name = con_parse_title_format(con)
		ewmh_update_visible_name(win.id, i3string_as_utf8)
	end
	win.name_x_changed = true
	win.uses_net_wm_name = true

	return if before_mgmt

	run_assignments(win)
end

def window_update_name_legacy(win, prop, before_mgmt)
	return if prop.nil? || xcb_get_property_value_length(prop) == 0

	return if win.uses_net_wm_name

	win.name = i3string_from_utf8_with_length(xcb_get_property_value(prop), xcb_get_property_value_length(prop))

	con = con_by_window_id(win.id)
	if !con.nil? && !con.title_format.nil?
		name = con_parse_title_format(con)
		ewmh_update_visible_name(win.id, i3string_as_utf8(name))
	end

	win.name_x_changed = true

	return if before_mgmt

	run_assignments
end

def window_update_leader(win, prop)
	if prop.nil? || xcb_get_property_value(prop) == 0
		win.leader = XCB_NONE
		return
	end

	leader = xcb_get_property_value(prop)
	return if leader.nil?

	win.leader = leader
end

def window_update_transient(win, prop)
	if prop.nil? || xcb_get_property_value_length(prop) == 0
		win.transient_for = XCB_NONE
		return
	end

	transient_for = uninitialized XcbWindow
	return if !xcb_icccm_get_wm_transient_for_from_reply(pointerof(transient_for), prop)

	win.transient_for = transient_for
end

def window_update_strut_partial(win, prop)
	return if prop.nil? || xcb_get_property_value_length(prop) == 0
	return if !strut = xcb_get_property_value(prop)
	win.reserved = ReservedPixel.new(strut[0], strut[1], strut[2], strut[3])
end

def window_update_role(win, prop, before_mgmt)
	return if prop.nil? || xcb_get_property_value_length(prop)
	win.role = new_role
	return if before_mgmt
	run_assignments(win)
end

def window_update_type(window, reply)
	new_type = xcb_get_preferred_window_type(reply)
	return if new_type == XCB_NONE
	window.window_type = new_type
	run_assignments(window)
end

def window_update_hints(win, prop, urgency_hint)
	if !urgency_hint.nil?
		urgency_hint = false
	end

	return if prop.nil? || xcb_get_property_value_length(prop)

	return if !xcb_icccm_get_wm_hints_from_reply(pointerof(hints), prop)

	if hints.flags & XCB_ICCCM_WM_HINTS_INPUT
		win.doesnt_accept_focus = !hints.input
	end

	if !urgency_hint.nil?
		urgency_hint = hints != 0
	end
end

def window_update_motif_hints(win, prop, motif_border_style)
	if !motif_border_style.nil?
		motif_border_style = BS_NORMAL
	end

	return if prop.nil? || xcb_get_property_value(prop) == 0

	motif_hints = xcb_get_property_value(prop)

	if motif_border_style.nil? && motif_hints[MWM_HINTS_FLAGS_FIELD] & MWM_HINTS_DECORATIONS
		if motif_hints[MWM_HINTS_DECORATIONS_FIELD] & MWM_DECOR_ALL || motif_hints[MWM_HINTS_DECORATIONS_FIELD] & MWM_DECOR_TITLE
			motif_border_style = BS_NORMAL
		elsif motif_hints[MWM_HINTS_DECORATIONS_FIELD] & MWM_DECOR_BORDER
			motif_border_style = BS_PIXEL
		else
			motif_border_style = BS_NONE
		end
	end
end
