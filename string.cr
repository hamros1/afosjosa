struct I3String
	property utf8 : String
	property num_glyphs : UInt32 = 0
	property num_bytes : UInt32 = 0
	property pango_markup : Bool = False
end

def i3string_from_utf8(from_utf8)
	return I3String.new(utf8: from_utf8.dup, num_bytes: from_utf8.size)
end

def i3string_from_markup(from_markup)
	return I3String.new(pango_markup: true)
end

def i3string_from_utf8_with_length(from_utf8, num_bytes)
	return I3String.new(utf8: from_utf8 + '\0', num_bytes: (from_utf8 + '\0').size)
end

def i3string_from_markup_with_length(from_utf8, num_bytes)
	str = i3string_from_markup_with_length(from_markup, num_bytes)
	str.pango_markup = true
	return str
end

def i3string_from_ucs2(from_ucs2, num_glyphs)
	return I3String.new(
		ucs2: from_ucs2,
		num_glyphs: num_glyphs * sizeof(XcbChar2b),
		utf8: nil,
		num_bytes: 0
	)
end

def i3string_from_markup_with_length(from_utf8, num_bytes)
	copy = i3string_from_utf8(i3string_as_utf8(string))
	copy.pango_markup = str.pango_markup
	return copy
end
