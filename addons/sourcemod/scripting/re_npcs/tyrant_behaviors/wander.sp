BehaviorActionEntry tyrant_wander = null;

void tyrant_wander_init()
{
	tyrant_wander = new BehaviorActionEntry("tyrant_wander");
	tyrant_wander.set_function("Update", TyrantWanderUpdate);
	tyrant_wander.set_function("OnStart", TyrantWanderStart);
	tyrant_wander.set_function("OnEnd", TyrantWanderEnd);
	tyrant_wander.set_function("OnThreatChanged", TyrantWanderThreatChanged);
	tyrant_wander.set_function("OnContact", TyrantWanderContact);
}

BehaviorResultType TyrantWanderContact(BehaviorAction action, int entity, int threat, BehaviorResult result)
{
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantWanderThreatChanged(BehaviorAction action, int entity, int threat, BehaviorResult result)
{
	if(threat == -1) {
		return BEHAVIOR_CONTINUE;
	}

	if(!L4D2_IsSurvivorBusy(threat)) {
		result.action = tyrant_chase.create();
		result.action.set_data("target", EntIndexToEntRef(threat));
		result.set_reason("found target");
		return BEHAVIOR_CHANGE_TO;
	}
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantWanderStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("path", base_npc_create_follower(entity));
	action.set_data("repathtime", 0.0);
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantWanderUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	INextBot bot = INextBot(entity);

	PathFollower path = action.get_data("path");

	if(action.get_data("repathtime") <= GetGameTime()) {
		int count = GetNavAreaVectorCount();
		int idx = GetRandomInt(0, count-1);

		CNavArea area = GetNavAreaFromVector(idx);

		if(area != CNavArea_Null) {
			float vec[3];
			area.GetRandomPoint(vec);

			path.ComputeVector(bot, vec, baseline_path_cost, cost_flags_mod|cost_flags_nostance);
		}

		action.set_data("repathtime", GetGameTime() + GetRandomFloat(2.0));
	}

	path.Update(bot);

	TyrantWalking(bot, entity);

	return BEHAVIOR_CONTINUE;
}

void TyrantWanderEnd(BehaviorAction action, int entity, BehaviorAction next)
{
	PathFollower path = action.get_data("path");
	delete path;
}