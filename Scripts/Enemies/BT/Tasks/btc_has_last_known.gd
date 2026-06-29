extends BTCondition

## BTCondition that checks if there is a last known or heard position to investigate.

func _tick(_delta: float) -> Status:
	var has_lk = blackboard.get_var(&"has_last_known", false, false)
	var heard = blackboard.get_var(&"heard_position", null, false)
	if has_lk or heard != null:
		return SUCCESS
	return FAILURE
