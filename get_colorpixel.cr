struct ColorPixel
	property hex : String
	property pixel : UInt32
	property colorpixels : Dequeue(ColorPixel)
end

def get_colorpixel(hex)
	if hex.size == "#rrggbbaa".size
		alpha[0] = hex[7]
		alpha[1] = hex[8]
	else
		alpha[0] = alpha[1] = 'F'
	end

	strgroups[4][3] = [
		[hex[1], hex[2], '\0'],
		[hex[3], hex[4], '\0'],
		[hex[5], hex[6], '\0'],
		[alpha[0], alpha[1], '\0'],
	]

	r = strtol(strgroups[0], nil, 16)
	g = strtol(strgroups[1], nil, 16)
	b = strtol(strgroups[2], nil, 16)
	a = strtol(strgroups[3], nil, 16)

	if root_screen.nil? || root_screen.root_depth == 24 || root_screen.root_depth == 32
		return (a << 24) | (r << 16 | g << 8 | b)
	end

	colorpixels.each do |colorpixel|
		return colorpixel.pixel if colorpixel.hex.compare(hex)
	end

	r16 = (65535 * ((r)&0xFF) / 255)
	g16 = (65535 * ((g)&0xFF) / 255)
	b16 = (65535 * ((b)&0xFF) / 255)

	reply = xcb_alloc_color_reply(conn, xcb_alloc_color(conn, root_screen, default_colormap, r16, g16, b16), nil)

	if !reply
		puts "Could not allocate color"
		exit(1)
	end

	pixel = reply.pixel
	cache_pixel = ColorPixel.new(hex: hex, pixel: pixel)
	cache_pixel.hex[7] = '\0'

	colorpixels.insert_head(cache_pixel)
	return pixel
end
