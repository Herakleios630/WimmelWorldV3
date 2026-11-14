class_name WorkSystem
extends RefCounted

## Arbeitsabschluss. Arbeit ist Fortschritt: volle Arbeitsstunden erzeugen
## Feldarbeit bzw. Werkstatt-Akkumulation; Reststunden werden über
## Unterbrechungen getragen. Verhalten unverändert zu G1b/G2/G3.

## Schwacher Rückverweis: DecisionSystem hält WorkSystem stark.
var _d_ref: WeakRef


func _init(host) -> void:
	_d_ref = weakref(host)


func _d():
	return _d_ref.get_ref()


func finish_work(row: int, now: int) -> void:
	if _d().store.work_start[row] >= 0:
		var worked: int = now - _d().store.work_start[row]
		if worked > 0:
			if _d().store.job_kind[row] == AgentStore.JOB_FIELD:
				_d().fields.add_work(_d().store.target_building_id[row], worked)
			else:
				_d().store.work_accum[row] += worked
		_d().store.work_start[row] = -1
	var field_stage: int = _d().fields.field_stage(_d().store.target_building_id[row])
	(_d()._host()).log_event(SimEvent.T_WORK_END, SimEvent.IMPORTANCE_NOTABLE,
		_d()._agent_id(row), "work_end", "Arbeit beendet", field_stage)
	_d().store.work_end[row] = -1
	_d().store.activity[row] = AgentStore.ACT_IDLE
