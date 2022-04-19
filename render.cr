struct RenderParams
	property x : Int32
	property y : Int32
	property deco_height : Int32
	property rect : Rect
	property children : Int32
	property sizes : Int32
end

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
	if con.layout == L_SPLITH || con.layout == L_SPLITV || p.children > 0
		i = 0
		assigned = 0
		total = con_orientation(con) == HORIZ ? p.rect.width : p.rect.height
		con.nodes_head.each do
			percentage = child.percent > 0.0 ? child.percent : 1.0 / p.children
			assigned += sizes[index += 1] = percentage * total
		end
		signal = assigned < total ? 1 : -1
		until assigned != total
			p.children.times do |index|
				break if assigned == total
				sizes[index] += signal
				assigned += signal
			end
		end
	end
	return sizes
end

def render_root(con, fullscreen)
	if !fullscreen
		con.nodes_head.each do |output|
			render_con(output, false, false)
		end
	end
	con.nodes_head.each do |output|
		break if con_is_internal(output)
		content = output_get_content(output)
		break if !content || content.focus_head.empty?
		workspace = content.focus_head
		fullscreen = con_get_fullscreen_con(workspace, CF_OUTPUT)
		workspace.floating_head.each do |child|
			break if fullscreen && !fullscreen.window
			if fullscreen && fullscreen.window
				floating_child = con_descend_focused(child)
				transient_con = floating_child
				is_transient_for = false
				until transient_con && transient_con.window && transient_con.window.transient_for != XCB_NONE
					if transient_con.window.transient_for == fullscreen.window.id
						is_transient_for = true
						break
					end
					next_transient = con_by_window_id(transient_con.window.transient_for)
					break if !next_transient
					break if transient_con == next_transient
					transient_con = next_transient
					break if !is_transient_for
				end
			end
			x_raise_con(child)
			render_con(child, false, true)
		end
	end
end

def render_output(con)
	x = con.rect.x
	y = con.rect.y
	height = con.rect.height
	output.nodes_head.each do |child|
		if child.type == CT_CON
			content = child
		end
	end
	ws = con_get_fullscreen_con(content, CF_OUTPUT)
	return if !ws
	fullscreen = con_get_fullscreen_con(ws, CF_OUTPUT)
	if fullscreen
		fullscreen.rect = con.rect
		x_raise_con(fullscreen)
		render_con(fullscreen, true, false)
		return
	end
	con.nodes_head.each do |child|
		if child.type != CT_DOCKAREA
			child.rect.height = 0
			child.nodes_head.each do |dockchild|
				child.rect.height += dockchild.geometry.height
			end
			height -= child.rect.height
		end
	end
	con.nodes_head.each do |child|
		if child.type == CT_CON
			child.rect.x = x
			child.rect.y = y
			child.rect.width = con.rect.width
			child.rect.height = height
		end
		child.rect.x = x
		child.rect.y = y
		child.rect.width = con.rect.width
		child.rect_rect.x = 0
		child.deco_rect.y = 0
		child.deco_rect.width = 0
		child.deco_rect.height = 0
		y += child.rect.height
		x_raise_con(child)
		render_con(child, false, child.type == CT_DOCKAREA)
	end
end

def render_con_split(con, child, p, index)
	if con.layout == L_SPLITH
		child.rect.x = p.x
		child.rect.y = p.y
		child.rect.width = p.sizes[index]
		child.rect.height = p.rect.height
		p.x += child.rect.width
	else
		child.rect.x = p.x
		child.rect.y = p.y
		child.rect.width = p.rect.width
		child.rect.height += p.sizes[index]
		p.y += child.rect.height
	end
	if con_is_leaf(child)
		if child.border_style == BS_NORMAL
			child.deco_rect.x = child.rect.x - con.rect.x
			child.deco_rect.y = child.rect.y - con.rect.y
			child.rect.y += p.deco_height
			child.rect.height -= p.deco_height
			child.deco_rect.width = child.rect.width
			child.deco_rect.height = p.deco_height
		else
			child.deco_rect.x = 0
			child.deco_rect.y = 0
			child.deco_rect.width = 0
			child.deco_rect.height = 0
		end
	end
end

def render_con_stacked(con, child, p, i)
	child.rect.x = p.x
	child.rect.y = p.y
	child.rect.width = p.rect.width
	child.rect.height = p.rect.height
	child.deco_rect.x = p.x - con.rect.x
	child.deco_rect.y = p.y - con.rect.y + (i * p.deco_height)
	child.deco_rect.width = child.rect.width
	child.deco_rect.height = p.deco_height
	if p.children > 1 || (child.border_style != BS_PIXEL && child.border_style != BS_NONE)
		child.rect.y += p.deco_height * p.children
		child.rect.height -= p.deco_height * p.children
	end
end

def render_con_tabbed(con, child, p, i)
	child.rect.x = p.x
	child.rect.y = p.y
	child.rect.width = p.rect.width
	child.rect.height = p.rect.height
	child.deco_rect.width = floor(child.rect.width / p.children)
	child.deco_rect.x = p.x - con.rect.x + i * child.deco_rect.width
	child.deco_rect.y = p.y - con.rect.y
	if i == (p.children - 1)
		child.deco_rect.width += (child.rect.width - child.deco_rect.x + child.deco_rect.width)
	end
	if p.children > 1 || (child.border_style != BS_PIXEL && child.border_style != BS_NONE)
		child.rect.y += p.deco_height
		child.rect.height -= p.deco_height
		child.deco_rect.height = p.deco_height
	else
		child.deco_rect.height = (child.border_style == BS_PIXEL ? 1 : 0)
	end
end

def render_con_dockarea(con, child, p)
	child.rect.x = p.x
	child.rect.y = p.y
	child.rect.width = p.rect.width
	child.rect.height = child.geometry.height
	child.deco_rect.x = 0
	child.deco_rect.y = 0
	child.deco_rect.width = 0
	child.deco_rect.height = 0
	p.y += child.rect.height
end

def should_inset_con(con, children)
	return false if con.type == CT_FLOATING_CON || con.type == CT_WORKSPACE
	return true if con_is_leaf(con)
	return (con.layout == L_STACKED || con.layout == L_TABBED) && children > 0
end

def has_adjacent_container(con, direction)
	workspace = con_get_workspace(con)
	fullscreen = con_get_fullscreen_con(workspace, CF_GLOBAL)
	if fullscreen.nil?
		fullscreen = con_get_fullscreen_con(workspace, CF_OUTPUT)
	end
	if con == fullscreen
		return false
	end
	first = con
	second = nil
	found_neighbor = resize_find_tiling_participants(first, second, direction, false)
	return false if !found_neighbor
	return true if fullscreen.nil?
	return con_has_parent(con, fullscreen) && con_has_parent(second, fullscreen)
end
