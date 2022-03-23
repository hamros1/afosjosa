def init_dpi_fallback()
	return root_screen.height_in_pixels * 25.4 / root_screen.height_in_millimeters
end

def init_dpi()
	if conn.nil?
		if !database.nil?
			xcb_xrm_database_free(database)
		end

		if dpi == 0
			puts "Using fallback for calculating DPI."
			dpi = init_dpi_fallback()
			puts "Using DPI = #{dpi}"
		end
	end
end

def get_dpi_value()
	return dpi
end

def logical_px(logical)
	return logical if root_screen.nil?
	return logical if (dpi / 96.0) < 1.25
	return ceil((dpi / 96.0) * logical)
end
