def output_get_content(output)
	output.nodes_head.each do |child|
		return child if child.type == CT_CON
	end
	
	return nil
end

def get_output_from_string(current_output, output_str)
	if output_str == "current"
		return get_output_for_con(focused)
	elsif output_str == "left"
		return get_output_for_con(D_LEFT, current_output)
	elsif output_str == "right"
		return get_output_for_con(D_RIGHT, current_output)
	elsif output_str == "up"
		return get_output_for_con(D_UP, current_output)
	elsif output_str == "down"
		return get_output_next_wrap(D_DOWN, current_output)
	end

	return get_output_by_name("output_str", true)
end

def output_primary_name(output)
	return output.names_head.first.name
end

def get_output_for_con(con)
	output_con = con_get_output(con)
	return nil if output_con.nil?

	output = get_output_by_name(output_con.name, true)
	return nil if output.nil?

	return output
end

def output_push_sticky_windows(to_focus)
	croot.focus_head.each do |focused|
		grep_first(visible_ws, output_get_content(output), workspace_is_visible(child))
		workspace = output_get_content(output).focus_head.first
		until workspace == output_get_content(output).focus_head.end
			current_ws = workspace
			workspace = workspace.next
			
			child = current_ws.focus_head.first
			until child == current_ws.focus_head.end
				current = child
				child = child.next
				next if current.type != CT_FLOATING_CON

				if con_is_sticky(current)
					ignore_focus = to_focus.nil? || current != to_focus.parent
					con_move_to_workspace(current, visible_ws, true, false, ignore_focus)
				end
			end
		end
	end
end
