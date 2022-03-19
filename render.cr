def render_deco_height
	deco_height = config.font.height + 4
	if config.font.height & 0x01
		deco_height += 1
	end
	return deco_height
end

def render_con(con, render_fullscreen, already_in)
	params = RenderParams.new(
		rect: con.rect,
		x: con.rect.x,
		y: con.rect.y,
		children: con_num_children(con)
	)

	if con.type == CT_WORKSPACE
		gaps = calculate_effective_gaps(con)
		inset = Rect.new(
			gaps.outer.left,
			gaps.outer.top,
			-gaps.outer.left + -gaps.outer.right,
			-gaps.outer.left + -gaps.outer.bottom
		)

		con.rect = rect_add(con.rect, inset)
		params.rect = rect_add(params.rect, inset)
		params.x += inset.x
		params.y += inset.y
	end

	should_inset = should_inset_con(con, params.children)
	if !already_inset && should_inset
		gaps = calculate_effective_gaps(con)
		inset = Rect.new(
			has_adjacent_container(con, D_LEFT) ? gaps.inner : 0,
			has_adjacent_container(con, D_UP) ? gaps.inner : 0,
			has_adjacent_container(con, D_RIGHT) ? -2 * gaps.inner : 0,
			has_adjacent_container(con, D_DOWN) ? -2 * gaps.inner : 0
		)

		if !render_fullscreen
			params.rect = rect_add(params.rect, inset)
			con.rect = rect_add(con.rect, inset)
			if con.widnow
				con.window_rect = rect_add(con.window_rect, inset)
			end
		end
		inset.height = 0
		if con.deco_rect.width != 0 && con.deco_rect.height != 0
			con.deco_rect = rect_add(con.deco_rect, inset)
		end

		params.x = con.rect.x
		params.y = con.rect.y
	end

	i = 0
	con.mapped = true

	if con.window
		inset = con.window_rect
		inset = Rect.new(0, 0, con.rect.width, con.rect.height)
		if !render_fullscreen
			inset = rect_add(inset, con_border_style_rect)
		end
		inset.width = 2 * con.border_width
		inset.height = 2 * con.border_width

		if !render_fullscreen && con.window.aspect_ratio > 0.0
		end
	end
end

def precalculate_sizes(con, p)
end

def render_root(con, fullscreen)
end

def render_output(con)
end

def render_con_split(con, child, p, i)
end

def render_con_stacked(con, child, p, i)
end

def render_con_tabbed(con, child, p, i)
end

def render_con_dockarea(con, child, p)
end

def should_inset_con(con, children)
end

def has_adjacent_container(con, direction)
end
