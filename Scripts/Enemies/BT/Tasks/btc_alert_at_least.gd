extends BTCondition

## BTCondition that checks if the alert level is at least the specified value.

@export var min_level: int = 3 # COMBAT by default

func _tick(_delta: float) -> Status:
	var alert = blackboard.get_var(&"alert_state", 0, false)
	if alert >= min_level:
		return SUCCESS
	return FAILURE
