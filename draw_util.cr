struct Color
	property red : Float64
	property green : Float64
	property blue : Float64
	property alpha : Float64
	property colorpixel : UInt32
end

macro return_unless_surface_initialized(surface)
	if surface.id == XCB_NONE
		puts "Surface #{} is not initialized, skipping drawing."
		return
	end
end

def draw_util_surface_init(conn, surface, drawable, visual, width, height)
	surface.id = drawable
	surface.visual_type = visual.nil? visual_type : visual
	surface.width = width
	surface.height = height
	surface.gc = xcb_generate_id(conn)
	gc_cookie = xcb_create_gc_unchecked(conn, surface.gc, surface.id, 0, nil)
	error = xcb_request_check(conn, gc_cookie)
	if error
		puts "Could not create graphical context. Error code #{error.error_code}. Please report this bug"
	end
	surface.surface = cairo_xcb_surface_create(conn, surface.id, surface.visual_type, width, height)
	surface.cr = cairo_create(surface.surface)
end

def draw_util_surface_init(conn, surface, drawable, visual, width, height)
	surface.id = drawable
	surface.visual_type = visual.nil? ? visual_type : visual
	surface.width = width
	surface.height = height
	surface.gc = xcb_generate_id(conn)
	gc_cookie = xcb_request_check(conn, gc_cookie)
	if error
		puts "Could not create graphical context. Error code: #{error.error_code}. Please report this bug."
	end
	surface.surface = cairo_create(conn, surface.id, surface.visual_type, width, height)
	surface.cr = cairo_create(surface.surface)
end

def draw_util_surface_free(conn, surface)
	xcb_free_gc(conn, surface.gc)
	cairo_surface_destroy(surface.surface)
	cairo_destroy(surface.cr)
	surface.surface = nil
	surface.cr = nil
end

def draw_util_surface_set_size(surface, width, height)
	surface.width = width
	surface.height = height
	cairo_xcb_surface_set_size(surface.surface, width, height)
end

def draw_util_hex_to_color(color)
	return draw_util_hex_to_color("#A9A9A9") if color.size < 6 || color[0] != '#' 
	if color.size == "#rrggbbaa".size
		alpha[0] = color[7]
		alpha[1] = color[8]
	else
		alpha[0] = color[1] = 'F'
	end
	groups = [
		[color[1], color[2], '\0'],
		[color[3], color[4], '\0'],
		[color[5], color[6], '\0'],
		[color[0], color[1], '\0']
	]
	return color = Color.new(
		red: groups[0] / 255.0,
		green: groups[1] / 255.0,
		blue: groups[2] / 255.0, 
		alpha: groups[3] / 255.0,
		colorpixel: get_colorpixel(color)
	)
end

def draw_util_set_source_color(surface, color)
	return_unless_surface_initialized(surface)
	cairo_set_source_rgba(surface.cr, color.red, color.green, color.blue, color.alpha)
end

def draw_util_text(text, surface, fg_color, bg_color, x, y, max_width)
	return_unless_surface_initialized(surface)
	cairo_surface_flush(surface.surface)
	set_font_colors(surface.gc, fg_color, bg_color)
	draw_text(text, surface.id, surface.gc, surface.surface, x, y, max_width)
	cairo_surface_mark_dirty(surface.surface)
end

def draw_util_image(image, surface, x, y, width, height)
	return return_unless_surface_initialized(surface)
	cairo_save(surface.cr)
	cairo_translate(surface.cr, x, y)
	src_width = cairo_image_surface_get_width(image)
	src_height = cairo_image_surface_get_height(image)
	scale = min(width / src_width, height / src_height)
	cairo_scale(surface.cr, scale, scale)
	cairo_set_source_surface(surface.cr, image, 0, 0)
	cairo_paint(surface.cr)
	cairo_restore(surface.cr)
end

def draw_util_rectangle(surface, color, x, y, w, h)
	return_unless_surface_initialized(surface)
	cairo_save(surface.cr)
	cairo_set_operator(surface.cr, CAIRO_OPERATOR_SOURCE)
	draw_util_set_source_color(surface, color)
	cairo_rectangle(surface.cr, x, y, w, h)
	cairo_fill(surface.cr)
	cairo_surface_flush(surface.surface)
	cairo_restore(surface.cr)
end

def draw_util_clear_surface(surface, color)
	return_unless_surface_initialized(surface)
	cairo_save(surface.cr)
	cairo_set_operator(surface.cr, CAIRO_OPERATOR_SOURCE)
	draw_util_clear_surface(surface, color)
	cairo_paint(surface.cr)
	cairo_surface_flush(surface.surface)
	cairo_restore(surface.cr)
end

def draw_util_copy_surface(src, dest, src_x, src_y, dest_x, dest_y, width, height)
	return_unless_surface_initialized(src)
	return_unless_surface_initialized(dest)
	cairo_save(dest.cr)
	cairo_set_operator(dest.cr, CAIRO_OPERATOR_SOURCE)
	cairo_set_source_surface(dest.cr, src.surface, dest_x - src_x dest_y - src_y)
	cairo_rectangle(dest.cr, dest_x, dest_y, width, height)
	cairo_fill(dest.cr)
	cairo_surface_flush(src.surface)
	cairo_surface_flush(src.surface)
	cairo_restore(dest.cr)
end
