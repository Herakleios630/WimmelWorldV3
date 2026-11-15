extends RefCounted

## Erzeugt ein kuratiertes 4-Bit-Kanten-Set (16 Varianten) aus einer
## 16x16-Textur. Die Textur wird nur innerhalb einer gerundeten Form
## gezeichnet; ausserhalb bleibt sie transparent, damit der Untergrund
## (Gras/Sand) durchscheint. Kein 47er-Blob, keine Laufzeit-Softkreise.

const SIZE: int = 16


static func build(source: Texture2D, inset: int, radius: int) -> Array:
	var src: Image = source.get_image()
	if src == null:
		return []
	if src.get_format() != Image.FORMAT_RGBA8:
		src = src.duplicate()
		src.convert(Image.FORMAT_RGBA8)
	var out: Array = []
	for mask in 16:
		var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var left: int = 0 if (mask & 8) != 0 else inset
		var right: int = SIZE if (mask & 2) != 0 else SIZE - inset
		var top: int = 0 if (mask & 1) != 0 else inset
		var bottom: int = SIZE if (mask & 4) != 0 else SIZE - inset
		for y in SIZE:
			for x in SIZE:
				if x < left or x >= right or y < top or y >= bottom:
					continue
				if _corner_cut(x, y, mask, left, right, top, bottom, radius):
					continue
				img.set_pixel(x, y, src.get_pixel(
					x % src.get_width(), y % src.get_height()))
		out.append(ImageTexture.create_from_image(img))
	return out


static func _corner_cut(x: int, y: int, mask: int, left: int, right: int,
		top: int, bottom: int, radius: int) -> bool:
	var r2: int = radius * radius
	# Nordwest: beide Kanten sind nicht verbunden.
	if (mask & 8) == 0 and (mask & 1) == 0:
		var cx: int = left + radius
		var cy: int = top + radius
		if x < cx and y < cy:
			var dx: int = cx - x
			var dy: int = cy - y
			if dx * dx + dy * dy > r2:
				return true
	# Nordost.
	if (mask & 2) == 0 and (mask & 1) == 0:
		var cx2: int = right - radius
		var cy2: int = top + radius
		if x >= cx2 and y < cy2:
			var dx2: int = x - cx2
			var dy2: int = cy2 - y
			if dx2 * dx2 + dy2 * dy2 > r2:
				return true
	# Suedwest.
	if (mask & 8) == 0 and (mask & 4) == 0:
		var cx3: int = left + radius
		var cy3: int = bottom - radius
		if x < cx3 and y >= cy3:
			var dx3: int = cx3 - x
			var dy3: int = y - cy3
			if dx3 * dx3 + dy3 * dy3 > r2:
				return true
	# Suedost.
	if (mask & 2) == 0 and (mask & 4) == 0:
		var cx4: int = right - radius
		var cy4: int = bottom - radius
		if x >= cx4 and y >= cy4:
			var dx4: int = x - cx4
			var dy4: int = y - cy4
			if dx4 * dx4 + dy4 * dy4 > r2:
				return true
	return false
