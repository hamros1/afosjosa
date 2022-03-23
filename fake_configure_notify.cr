def fake_configure_notify(conn, r, window, border_width)
	event = XcbConfigureNotifyEvent.new(
		event: window,
		window: window,
		response_type: XCB_CONFIGURE_NOTIFY,
		x: r.x,
		y: r.y,
		width: r.width,
		height: r.height,
		border_width: border_width,
		above_sibling: XCB_NONE,
		override_redirect: false
	)

	xcb_send_event(conn, false, window, XCB_EVENT_MASK_STRUCTURE_NOTIFY, generated_event.as(Pointer(Char)))
	xcb_flush(conn)
end
