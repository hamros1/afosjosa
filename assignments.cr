def run_assignments(window)
	needs_tree_render = false
	assignments.each do |current|
		next if !match_matches_window(current.match, window)
		skip = false
		window.nr_assignments.times do |index|
			next if window.ran_assignments[index] != current
			skip = true
			break
		end
		next if skip
		window.nr_assignments += 1
		window.ran_assignments = StaticArray(Assignment, window.nr_assignments)
		window.ran_assignments[window.nr_assignments - 1] = current
		if current.type == A_COMMAND
			result = parse_command(full_command, nil)
			if result.needs_tree_render
				needs_tree_render = true
			end
			command_result_free(result)
		end
	end
end

def assignment_for(window, type)
	assignments.each do |assignment|
		next if type != A_ANY && assignment.type & type == 0 || !match_matches_window(assignment.match, window)
		return assignment
	end
	return
end
