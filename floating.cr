BORDER_LEFT = 1 << 0
BORDER_RIGHT = 1 << 1
BORDER_TOP = 1 << 2
BORDER_BOTTOM = 1 << 3

DRAGGING = 0
DRAG_SUCCESS = 1
DRAG_REVERT = 2
DRAG_ABORT = 3

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

	border_style_rect = con_border_style_rect(con)

	nc.rect.height -= border_style_rect.height
	nc.rect.width -= border_style_rect.width

	if con_border_style(con) == BS_NORMAL
		nc.rect.height += deco_height
	end

	nc.rect.height += con.border_width * 2
	nc.rect.width += con.border_width * 2

	floating_check_size(nc)

	if nc.rect.x == 0 && nc.rect.y == 0
		if con.window && con.window.leader != XCB_NONE &&
			 !leader == con_by_window_id(con.window.leader)
			floating_center(nc, leader.rect)
		else
			floating_center(nc, ws.rect)
		end
	end

	current_output = get_output_containing(nc.rect.x + (nc.rect.width / 2), nc.rect.y + (nc.rect.height / 2))

	correct_output = con_get_output(ws)
	if !current_output || current_output.con != correct_output
		if current_output
			floating_fix_coordinates(nc, current_output.con.rect, correct_output.rect)
		else
			nc.rect.x = correct_output.rect.x
			nc.rect.y = correct_output.rect.y
		end
	end

	deco_height = con.border_style == BS_NORMAL ? render_deco_height() : 0
	nc.rect.y -= deco_height

	render_con(nc, false, true)
	render_con(con, false, true)

	if set_focus
		con_activate(con)
	end

	if floating_maybe_reassign_ws(nc)
		floating_set_hint_atom(nc, true)
	end

	if get_output_containing(nc.rect.x, nc.rect.y).nil?
		floating_set_hint_atom(nc, true)
	end

	floating_center(nc, ws.rect)
	ipc_send_window_event("floating", con)
end

def floating_disable(con, automatic)
	return if !con_is_floating(con)

	set_focus = con == focused

	ws = con_get_workspace(con)

	parent = con.parent

	con.parent.nodes_head.remove(con)
	con.parent.focus_head.remove(con)

	con.parent.parent.floating_head(con.parent)
	con.parent.parent.focus_head(con.parent)

	con.parent = nil
	tree_close_internal(parent, DONT_KILL_WINDOW, true, false)

	focused = con_descend_tiling_focused(ws)

	if focused.type == CT_WORKSPACE
		con.parent = focused
	else
		con.parent = focused.parent
	end

	con.parent = 0.0

	con.floating = FLOATING_USER_ON

	con_attach(con, con.parent, false)

	con_fix_percent(con.parent)

	if set_focus
		con_activate(con)
	end

	floating_set_hint_atom(con, false)
	ipc_send_window_event("floating", con)
end

def toggle_floating_mode(con, automatic)
	return if con.type == CT_FLOATING_CON

	if con_is_floating(con)
		floating_disable(con, automatic)
		return
	end

	return floating_enable(con, automatic)
end

def floating_raise_con(con)
	con.parent.floating_head.remove(con)
	con.parent.floating_head.insert_tail(con)
end

def floating_maybe_reassign_ws(con)
	output = get_output_containing(con.rect.x + (con.rect.width / 2), con.rect.y + (con.rect.height / 2))
	return false if !output

	return false if con_get_output(con) == output.con

	content = output_get_content(output.con)
	ws = content.focus_head.first
	con_move_to_workspace(con, ws, false, true, false)
	workspace_show(ws)
	con_activate(con_descend_focused(con))
	return true
end

def floating_center(con, rect)
	con.rect.x = rect.x + (rect.width / 2) - (con.rect.width / 2)
	con.rect.y = rect.y + (rect.height / 2) - (con.rect.height / 2)
end

def floating_move_to_pointer(con)
	reply = xcb_query_pointer_reply(conn, xcb_query_pointer(conn, root), nil)
	return if !reply

	output = get_output_containing(reply.root_x, reply.root_y)
	return if !output

	x = reply.root_x - con.rect.width / 2
	y = reply.root_y - con.rect.height / 2

	x = max(x, output.rect.x)
	y = max(y, output.rect.y)
	if x + con.rect.width > output.rect.x + output.rect.width
		x = output.rect.x + output.rect.width - con.rect.width
	end
	if y + con.rect.height > output.rect.y + output.rect.height
		y = output.rect.y + output.rect.height - con.rect.height
	end

	floaing_reposition(con, Rect.new x: x, y: y, width: con.rect.width, height: con.rect.height)
end

def drag_window_callback(con, old_rect, new_x, new_y, extra)
	event = extra

	con.rect.x = old_rect.x + (new_x - event.root_x)
	con.rect.y = old_rect.y + (new_y - event.root_y)

	render_con(con, false, true)
	x_push_node(con)
	xcb_flush(conn)

	return if !floating_mabe_reassign_ws(con)

	x_set_warp_to(nil)
	tree_render()
end

def floating_drag_window(con, event)
	tree_render()
	
	initial_rect = con.rect

	drag_result = drag_pointer(con, event, XCB_NONE, BORDER_TOP, XCURSOR_CURSOR_MOVE, drag_window_callback, event)

	if drag_result = DRAG_REVERT
		floating_reposition(con, initial_rect)
	end

	if con.scratchpad_state == SCRATCHPAD_FRESH
		con.scratchpad_state = SCRATCHPAD_CHANGED
	end

	tree_render()
end

struct ResizeWindowCallbackParams
	property corner : Border
	property proportional : Bool
	property event : XcbButtonPressEvent
end

def resize_window_callback(con, event)
	params = extra
	event = params.event
	corner = params.corner

	dest_x = con.rect.x
	dest_y = con.rect.y

	ratio = old_rect.width / old_rect.height

	if corner & BORDER_LEFT
		dest_width = old_rect.width - (new_x - event.root_x)
	else
		dest_width = old_rect.width + (new_y - event.root_y)
	end

	if corner & BORDER_TOP
		dest_height = old_rect.height - (new_y - event.root_y)
	else
		dest_height = old_rect.height + (new_y - event.root_y)
	end

	if params.proportional
		dest_width = max(dest_width, dest_height * ratio)
		dest_height = max(dest_height, dest_width / ratio)
	end

	con.rect = Rect.new(x: dest_x, y: dest_y, width: dest_width, height: dest_height)

	floating_check_size(con)

	if corner & BORDER_LEFT
		dest_x = old_rect.x + (old_rect.width - con.rect.width)
	end

	if corner & BORDER_TOP
		dest_y = old_rect.y + (old_rect.height - con.rect.height)
	end

	con.rect.x = dest_x
	con.rect.y = dest_y

	tree_render()
	x_push_node(croot)
end

def floating_resize_window(con, proportional, event)
	corner = 0

	if event.event_x <= con.rect.width / 2
		corner |= BORDER_LEFT
	else
		corner |= BORDER_RIGHT
	end

	cursor = 0
	if event.event_y <= con.rect.height / 2
		corner |= BORDER_TOP
		cursor = (corner & BORDER_LEFT) ? XCURSOR_CURSOR_TOP_LEFT_CORNER : XCURSOR_CURSOR_TOP_RIGHT_CORNER
	else
		corner |= BORDER_BOTTOM
		corner = (corner & BORDER_LEFT) ? XCURSOR_CURSOR_BOTTOM_LEFT_CORNER : XCURSOR_CURSOR_BOTTOM_RIGHT_CORNER
	end

	params = ResizeWindowCallbackParams.new(corner, proportional, event)
	
	initial_rect = con.rect

	drag_result = drag_pointer(con, event, XCB_NONE, BORDER_TOP, cursor, resize_window_callback, pointerof(params))

	return if !con_exists(con)

	if drag_result == DRAG_REVERT
		floating_reposition(con, initial_rect)
	end

	if con.scratchpad_state == SCRATCHPAD_FRESH
		con.scratchpad_state = SCRATCHPAD_CHANGED
	end
end

struct DragX11Callback
	property prepare : EventPrepare
	property result : DragResult
	property con : Container
	property old_rect : Rect
	property callback : Callback
	property extra : extra
end

def xcb_drag_prepare_cb(w, revents)
	dragloop = w.data
	while !event = xcb_poll_for_event(conn)
		if !event.response_type
			error = event
			next
		end

		type = event.response_type & 0x7F

		case type
		when XCB_BUTTON_RELEASE
			dragloop.result = DRAG_SUCCESS
			break
		when XCB_KEY_PRESS
			dragloop.result = DRAG_REVERT
			handle_event(type, event)
			break
		when XCB_UNMAP_NOTIFY
			unmap_event = event
			con = con_by_window_id(unmap_event.window)
			if !con.nil?
				if con_get_workspace(con) == con_get_workspace(focused)
					dragloop.result = DRAG_ABORT
				end
			end
			handle_event(type, event)
			break
		when XCB_MOTION_NOTIFY
			last_motion_notify = event
			break
		else
			handle_event(type, event)
			break
		end

		return if dragloop.result != DRAGGING
	end

	return if last_motion_notify

	if !dragloop.con || con_exists(dragloop.con)
		dragloop.callback(dragloop.con, pointerof(dragloop.old_rect), last_motion_notify.root_x, last_motion_notify.root_y, dragloop.extra)
	end

	xcb_flush(conn)
end

def drag_pointer(con, event, confine_to, border, cursor, callback, extra)
	cookie = xcb_grab_pointer(conn, false, root, XCB_EVENT_MASK_BUTTON_RELEASE |XCB_EVENT_MASK_POINTER_MOTION, XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC, confine_to, xcursor, XCB_CURRENT_TIME)

	return DRAG_ABORT if !reply = xcb_grab_pointer_reply(conn, cookie, ,pointerof(error))

	keyb_cookie = xcb_grab_keyboard(conn, false, root, XCB_CURRENT_TIME, XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC)

	if keyb_reply = xcb_grab_pointer_reply(conn, keyb_cookie, pointerof(error))
		xcb_ungrab_pointer(conn, XCB_CURRENT_TIME)
		return DRAG_ABORT
	end

	cb = DragX11Callback.new(result: DRAGGING, con: con, callback: callback, extra: extra)
	prepare = cb.prepare
	if con
		cb.old_rect = con.rect
	end
	ev_prepare_init(prepare, xcb_drag_prepare_cb)
	prepare.data = cb
	main_set_x11_cb(false)
	ev_prepare_start(cb, prepare)

	until cb.result != DRAGGING
		ev_run(main_loop, EVRUN_ONCE)
	end

	ev_prepare_stop(main_loop, prepare)
	main_set_x11_cb(true)

	xcb_ungrab_keyboard(conn, XCB_CURRENT_TIME)
	xcb_ungrab_pointer(conn, XCB_CURRENT_TIME)
	xcb_flush(conn)

	return cb.result
end

def floating_reposition(con, newrect)
	return if !contained_by_output(newrect)

	con.rect = newrect

	floating_maybe_reassign_ws(con)

	if con.scratchpad_state == SCRATCHPAD_FRESH
		con.scratchpad_state = SCRATCHPAD_CHANGED
	end

	tree_render()
end

def floating_resize(floating_con, x, y)
	rect = floating_con.rect
	focused_con = con_descend_focused(floating_con)
	return if focused_con.window.nil?
	wi = focused_con.window.width_increment
	hi = focused_con.window.height_increment
	rect.width = x
	rect.height = y
	if wi
		rect.width += (wi - 1 - rect.width) % wi
	end
	if hi
		rect.height += (hi - 1 - rect.height) % hi
	end

	floating_check_size(floating_con)

	if floating_con.scratchpad_state == SCRATCHPAD_FRESH
		floating_con.scratchpad_state = SCRATCHPAD_CHANGED
	end
end

def floating_fix_coordinates(con, old_rect, new_rect)
	rel_x = con.rect.x - old_rect.x + (con.rect.width / 2)
	rel_y = con.rect.y - old_rect.y + (con.rect.height / 2)
	con.rect.x = new_rect.x + rel_x * new_rect.width / old_rect.width - con.rect.width / 2
	con.rect.y = new_rect.y + rel_y * new_rect.width / old_rect.height - con.rect.height / 2
end
