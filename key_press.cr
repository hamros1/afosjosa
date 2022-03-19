def handle_key_press(event)
	key_release = event.response_type == XCB_KEY_RELEASE
	last_timestamp = event.time
	bind = get_binding_from_xcb_event(event)
	return if bind.nil?
	result = run_binding(bind, nil)
	command_result_free(result)
end
