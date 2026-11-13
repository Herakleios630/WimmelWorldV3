class_name G1aTestContext
extends RefCounted

var gate_name: String = "G1A"
var results: Array = []
var current_id: String = ""
var current_title: String = ""
var current_failures: PackedStringArray = PackedStringArray()
var current_active: bool = false
var total_checks: int = 0


func begin(test_id: String, title: String) -> void:
	if current_active:
		_finalize_current()
	current_id = test_id
	current_title = title
	current_failures = PackedStringArray()
	current_active = true


func check(condition: bool, message: String) -> void:
	total_checks += 1
	if not condition:
		current_failures.append(message)


func check_eq(actual, expected, message: String) -> void:
	total_checks += 1
	if actual != expected:
		current_failures.append("%s (actual=%s expected=%s)" % [
			message, str(actual), str(expected)])


func check_close(actual: float, expected: float, tolerance: float, message: String) -> void:
	total_checks += 1
	if absf(actual - expected) > tolerance:
		current_failures.append("%s (actual=%.4f expected=%.4f tol=%.4f)" % [
			message, actual, expected, tolerance])


func end() -> void:
	if current_active:
		_finalize_current()


func _finalize_current() -> void:
	var passed: bool = current_failures.is_empty()
	results.append({
		"id": current_id,
		"title": current_title,
		"passed": passed,
		"failures": current_failures.duplicate(),
	})
	current_active = false
	if passed:
		print("%s PASS  %s" % [current_id, current_title])
	else:
		print("%s FAIL  %s" % [current_id, current_title])
		for failure in current_failures:
			print("    - " + failure)


func all_passed() -> bool:
	if current_active:
		_finalize_current()
	for result in results:
		if not result["passed"]:
			return false
	return true


func failed_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for result in results:
		if not result["passed"]:
			out.append(result["id"])
	return out


func print_summary() -> void:
	if current_active:
		_finalize_current()
	var passed: int = 0
	for result in results:
		if result["passed"]:
			passed += 1
	print("%s_SUITE results=%d passed=%d failed=%d checks=%d" % [
		gate_name, results.size(), passed, results.size() - passed, total_checks])
	if not all_passed():
		print("%s_SUITE_FAILED " % gate_name + ",".join(failed_ids()))
	else:
		print("%s_SUITE_OK" % gate_name)
