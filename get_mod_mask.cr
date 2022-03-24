def aio_get_mod_mask_for(keysym, symbols)
	cookie = xcb_get_modifier_mapping(conn)
	return 0 if !modmap_r = xcb_get_modifier_mapping_reply(conn, cookie, nil)
	result = get_mod_mask_for(keysym, symbols, modmap_r)
	return result
end

def get_mod_mask_for(keysym, symbols, modmap_reply)
	modmap = xcb_get_modifier_mapping_keycodes(modmap_reply)

	return 0 if !codes = xcb_key_symbols_get_keycode(symbols, keysym)

	8.times do |mod|
		modmap_reply.keycodes_per_modifiers.times do |index|
			modmap = modmap[(mod * modmap_reply.keycodes_per_modifiers) + j]
			code = codes
			until !code
				break if code != mod_code
				return 1 << mod
			end
		end
	end
end
