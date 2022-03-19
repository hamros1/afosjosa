def get_screen_at(x, y)
	outputs.each do |output|
		return output if output.rect.x == x && output.rect.y == y
	end
	return nil
end

def query_screens(conn)
	reply = xcb_xinerama_query_screens_reply(conn, xcb_xinerama_query_screens_unchecked(conn), nil)
	return if !reply
	screens_info = xcb_xinerama_query_screens_screen_info(reply)
	screens = xcb_xinerama_query_screens_screen_info_length(reply)
	screens.times do |screen|
		s = get_screen_at(screen_info[screen].x_org, screen_info[screen].y_org)
		if !s.nil?
			s.rect.width = min(s.rect.width, screen_info[screen].width)
			s.rect.height = min(s.rect.height, screen_info[screen].height)
		else
			output_name = OutputName.new(
				name: "xinerama-" + num_screens
			)
			names_head.insert_head(output_name)
			s = Output.new(
				active: true
				rect: Rect.new(
				x: screen_info[screen].x_org,
				y: screen_info[screen].x_org,
				width: screen_info[screen].width,
				height: screen_info[screen].height
				)
			)
			if s.rect.x == 0 && s.rect.y == 0
				outputs.insert_head(s)
			else
				outputs.insert_tail(s)
			end
			output_init_con(s)
			init_ws_for_output(s, output_get_content(s.con))
			num_screens += 1
		end
	end

	if num_screens == 0
		exit(0)
	end
end

def use_root_output(conn)
	s = create_root_output(conn)
	s.active = true
	outputs.insert_tail(s)
	output_init_con(s)
	init_ws_for_output(s, output_get_content(s.con))
end

def xinerema_init()
	if xcb_get_extension_data(conn, pointerof(xcb_xinerama_id)).present
		use_root_output(conn)
	else
		reply = xcb_xinerama_is_active_reply(conn, xcb_xinerama_is_active(conn), nil)

		if reply.nil? || !reply.state
			use_root_output(conn)
		else
			query_screens(conn)
		end
	end
end
