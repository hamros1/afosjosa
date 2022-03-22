def get_screen_at(x, y)
	return outputs.select! output.rect.x == x && output.rect.y == y
end

def fake_outputs_init(spec)
	new_output = get_screen_at(x, y)
	if new_output
		puts "Re-used old output #{num_screens}"
		new_output.rect.width = min(new_output.rect.width, width)
		new_output.rect.height = min(new_output.rect.height, height)
	else
		output_name = OutputName.new(name: "fake-#{num_screens}")
		new_output.insert_head(new_output.names_head, output_name, names)
		new_output.active = true
		new_output.rect.x = x
		new_output.rect.y = y
		new_output.rect.width = width
		new_output.rect.height = height
		if new_output.rect.x == 0 && new_output.rect.y == 0
			new_output.insert_head(outputs)
		else
			new_output.insert_tail(outputs)
		end
		output_init_con(new_outputs)
		init_ws_for_output(new_output, output_get_content(new_output.con))
		num_screens += 1
	end
	new_output.primary = primary

	exit(0) if num_screens == 0
end
