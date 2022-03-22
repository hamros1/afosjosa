def mode_from_name(name, pango_markup)
end


def configure_binding(bindtype, modifiers, input_code, release, border, whole_window, exclude_titlebar, command, modename, pango_markup)
	new_binding.release = release.nil? B_UPON_KEYRELEASE : B_UPON_KEYPRESS
	new_binding.border = !border.nil?
	new_binding.whole_window = !whole_window.nil?
	new_binding.exclude_titlebar = !exclude_titlebar.nil?
	if bindtype == "bindsym"
		new_binding.input_type = input_code.includes? "button" ? B_KEYBOARD : B_MOUSE
		new_binding.symbol = input_code.dup
	else
		new_binding.keycode = keycode
		new_binding.input_type = B_KEYBOARD
	end
	new_binding.command = command.dup
	new_binding.event_state_mask = event_state_from_str(modifiers)
	group_bits_set = 0
	if new_binding.event_state_mask >> 16 & I3_XKB_GROUP_MASK_1
		group_bits_set += 1
	end
	if new_binding.event_state_mask >> 16 & I3_XKB_GROUP_MASK_2
		group_bits_set += 1
	end
	if new_binding.event_state_mask >> 16 & I3_XKB_GROUP_MASK_3
		group_bits_set += 1
	end
	if new_binding.event_state_mask >> 16 & I3_XKB_GROUP_MASK_4
		group_bits_set += 1
	end
	mode = mode_from_name(modename, pango_markup)
	mode.bindings.insert_tail(new_binding)
	return new_binding
end

def binding_in_current_group(bind)
	return true if bind.event_state_mask >> 16 == I3_XKB_GROUP_MASK_ANY
	case xkb_current_group
	when XCB_XKB_GROUP_1
		return bind.event_state_mask >> 16 && I3_XKB_GROUP_MASK_1
	when XCB_XKB_GROUP_2
		return bind.event_state_mask >> 16 && I3_XKB_GROUP_MASK_2
	when XCB_XKB_GROUP_3
		return bind.event_state_mask >> 16 && I3_XKB_GROUP_MASK_3
	when XCB_XKB_GROUP_4
		return bind.event_state_mask >> 16 && I3_XKB_GROUP_MASK_4
	else
		return false
	end
end

def grab_keycode_for_binding(conn, bind, keycode)
	mods = bind.event_state_mask & 0xFFFF
	xcb_grab_key(conn, 0, root, mods, keycode, XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC)
	xcb_grab_key(conn, 0, root, mods | xcb_numlock_mask, keycode, XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC)
	xcb_grab_key(conn, 0, root, mods | XCB_MOD_MASK_LOCK, keycode, XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC)
	xcb_grab_key(conn, 0, root, mods | xcb_numlock_mask, keycode, XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC)
end

def grab_all_keys(con)
	bindings.each do |bind|
		next if bind.input_type != B_KEYBOARD
		next if !binding_in_current_group(bind)

		if bind.keycode > 0
			grab_keycode_for_binding(conn, bind, bind.keycode)
			next
		end

		bind.keycodes_head.each do |keycode|
			keycode = binding_keycode.keycode
			mods = binding_keycode.modifiers & 0xFFFF
			xcb_grab_key(conn, 0, root, mods, keycode, XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC)
		end
	end
end

def regrab_all_buttons(conn)
	buttons = binding_get_buttons_to_grab()
	xcb_grab_server(conn)
	all_cons.each do |con|
		next if con.window.nil?
		xcb_ungrab_button(conn, XCB_BUTTON_INDEX_ANY, con.window.id, XCB_BUTTON_MASK_ANY)
		xcb_grab_buttons(conn, con.window.id, buttons)
	end
	xcb_ungrab_server(conn)
end

def get_binding(state_filtered, is_release, input_code, input_type)
	if !is_release
		bindings.each do |bind|
			next if bind.input_type != input_type
			if bind.release == B_UPON_KEYRELEASE_IGNORE_MODS
				bind.release == B_UPON_KEYRELEASE
			end
		end
	end
end
