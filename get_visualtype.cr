def get_visualtype(screen)
	depth_iter = xcb_screen_allowed_depths_iterator(screen)
	until !depth_iter
		visual_iter = xcb_depth_visuals_iterator(depth_iter.data)
		until !visual_iter.rem
			return visual_iter.data if screen.root_visual == visual_iter.data.visual_id
			xcb_visualtype_next(pointerof(visual_iter))
		end
		xcb_depth_next(pointerof(depth_iter))
	end
end
