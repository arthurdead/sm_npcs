BehaviorActionEntry tyrant_exec = null;

void tyrant_exec_init()
{
	tyrant_exec = new BehaviorActionEntry("tyrant_exec");
	tyrant_exec.set_function("InitialContainedAction", TyrantExecInitialAction);
	//tyrant_exec.set_function("OnLeaveGround", TyrantExecLeaveGround);
}

BehaviorAction TyrantExecInitialAction(int entity)
{
	return tyrant_wander.create();
}

BehaviorResultType TyrantExecLeaveGround(BehaviorAction action, int entity, int ground, BehaviorResult result)
{
	result.action = BehaviorAction_Null;
	result.set_reason("falling off");
	return BEHAVIOR_CHANGE_TO;
}