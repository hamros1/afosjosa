XCURSOR_CURSOR_POINTER = 0 
XCURSOR_CURSOR_RESIZE_HORIZONTAL = 1
XCURSOR_CURSOR_RESIZE_VERTICAL = 2
XCURSOR_CURSOR_TOP_LEFT_CORNER = 3
XCURSOR_CURSOR_TOP_RIGHT_CORNER = 4
XCURSOR_CURSOR_BOTTOM_LEFT_CORNER = 5
XCURSOR_CURSOR_BOTTOM_RIGHT_CORNER = 6
XCURSOR_CURSOR_WATCH = 7
XCURSOR_CURSOR_MOVE = 8
XCURSOR_CURSOR_MAX = 9

def xcursor_load_cursors()
	if xcb_cursor_context_new(conn, root_screen, pointerof(ctx) < 0)
		xcursor_supported = false
		return
	end

	cursors[XCURSOR_CURSOR_POINTER] = xcb_cursor_load_cursor(ctx, "left_ptr")
	cursors[XCURSOR_CURSOR_RESIZE_HORIZONTAL] = xcb_cursor_load_cursor(ctx, "sh_h_double_arrow")
	cursors[XCURSOR_CURSOR_RESIZE_VERTICAL] = xcb_cursor_load_cursor(ctx, "sb_v_double_arrow")
	cursors[XCURSOR_CURSOR_WATCH] = xcb_cursor_load_cursor(ctx, "watch")
	cursors[XCURSOR_CURSOR_MOVE] = xcb_cursor_load_cursor(ctx, "fleur")
	cursors[XCURSOR_CURSOR_TOP_LEFT_CORNER] = xcb_cursor_load_cursor(ctx, "top_left_corner")
	cursors[XCURSOR_CURSOR_TOP_RIGHT_CORNER] = xcb_cursor_load_cursor(ctx, "top_right_corner")
	cursors[XCURSOR_CURSOR_BOTTOM_LEFT_CORNER] = xcb_cursor_load_cursor(ctx, "bottom_left_corner")
	cursors[XCURSOR_CURSOR_BOTTOM_RIGHT_CORNER] = xcb_cursor_load_cursor(ctx, "bottom_right_corner")
end

def xcursor_set_root_cursor(cursor_id)
	xcb_change_window_attributes(conn, root, XCB_CW_CURSOR, xcursor_get_cursor(cursor_id))
end

def xcursor_get_cursor(c)
	return cursors[c]
end

def xcursor_get_xcb_cursor(c)
	return xcb_cursors[c]
end
