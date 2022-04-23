def rect_contains(rect, x, y)
	return x >= rect.x &&
				 x <= (rect.x + rect.width) && 
				 y >= rect.y &&
				 y <= (rect.y + rect.height)
end

def rect_add(a, b)
	return Rect.new(
		a.x + b.x,
		a.y + b.y,
		a.width + b.width,
		a.height + b.height
	)
end

def rect_sub(a, b)
	return Rect.new(
		a.x - b.x,
		a.y - b.y,
		a.width - b.width,
		a.height - b.height
	)
end

def pango_escape_markup(input)
	return input if !font_is_pango
	escaped = g_markup_escape_text(input, -1)
	return escaped
end
