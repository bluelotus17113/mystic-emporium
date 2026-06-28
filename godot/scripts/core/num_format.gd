class_name NumFormat
extends RefCounted
## Helpers para formatear ints grandes en el HUD.

static func short(n: int) -> String:
	# 1234 → "1.2K", 1234567 → "1.2M", 1234567890 → "1.2B"
	var abs_n: int = abs(n)
	if abs_n >= 1_000_000_000:
		return "%s%.1fB" % [_sign(n), abs_n / 1_000_000_000.0]
	if abs_n >= 1_000_000:
		return "%s%.1fM" % [_sign(n), abs_n / 1_000_000.0]
	if abs_n >= 10_000:
		return "%s%.1fK" % [_sign(n), abs_n / 1000.0]
	return separated(n)


static func separated(n: int) -> String:
	# 1234567 → "1,234,567" — útil para valores medianos donde queremos exactitud.
	var s: String = str(abs(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count == 3 and i > 0:
			out = "," + out
			count = 0
	return _sign(n) + out


static func _sign(n: int) -> String:
	return "-" if n < 0 else ""
