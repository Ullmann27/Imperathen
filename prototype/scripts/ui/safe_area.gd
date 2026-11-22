extends RefCounted
## Convert display pixels (including letterboxing) to the root viewport's UI units.

static func for_viewport(viewport: Viewport) -> Rect2:
	var size := viewport.get_visible_rect().size
	if not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, size)
	return from_display(Rect2(DisplayServer.get_display_safe_area()), viewport.get_screen_transform(), size)


static func from_display(screen_safe: Rect2, screen_transform: Transform2D, viewport_size: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)
	if not screen_safe.has_area() or is_zero_approx(screen_transform.determinant()):
		return full
	var mapped: Rect2 = screen_transform.affine_inverse() * screen_safe
	var clipped := mapped.intersection(full)
	return clipped if clipped.has_area() else full
