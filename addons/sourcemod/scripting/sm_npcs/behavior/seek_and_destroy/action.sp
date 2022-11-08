CustomBehaviorActionEntry seek_and_destroy_action;

void seek_and_destroy_action_init()
{
	seek_and_destroy_action = new CustomBehaviorActionEntry("SeekAndDestroy");
	seek_and_destroy_action.set_function("OnStart", action_start);
	seek_and_destroy_action.set_function("Update", action_update);
	seek_and_destroy_action.set_function("OnEnd", action_end);
	seek_and_destroy_action.set_function("OnResume", action_resume);
	seek_and_destroy_action.set_function("OnStuck", action_stuck);
	seek_and_destroy_action.set_function("OnMoveToSuccess", action_movesucc);
	seek_and_destroy_action.set_function("OnMoveToFailure", action_movefail);
	seek_and_destroy_action.set_function("ShouldHurry", action_hurry);
	seek_and_destroy_action.set_function("ShouldRetreat", action_retreat);
}

static CNavArea choose_goal_area(INextBot bot, int entity)
{
	ArrayList goalVector = new ArrayList();

	if(IsMannVsMachineMode()) {
		CTFNavMesh.CollectAreaWithinBombTravelRange(goalVector, 0.0, tf_populator_active_buffer_range.FloatValue);
	} else {
		int my_team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
		int enemy_team = TeamManager_GetEnemyTeam(my_team);

		CTFNavMesh.CollectSpawnRoomThresholdAreas(goalVector, enemy_team);
	}

	int len = goalVector.Length;

	CNavArea goalArea = CNavArea_Null;

	len = goalVector.Length;
	if(len > 0) {
		goalArea = goalVector.Get(GetURandomInt() % len);
	}

	delete goalVector;

	return goalArea;
}

static void recompute_seek_path(CustomBehaviorAction action, INextBot bot, entity)
{
	PathFollower path = action.get_data("m_path");

	CNavArea goalArea = choose_goal_area(bot, entity);
	action.set_data("m_goalArea", goalArea);

	if(goalArea != CNavArea_Null) {
		float center[3];
		goalArea.GetCenter(center);

		path.ComputeVector(bot, center, baseline_path_cost, cost_flags_safest);
	} else {
		path.Invalidate();
	}
}

static QueryResultType action_retreat(CustomBehaviorAction action, INextBot bot, int entity)
{
	return ANSWER_UNDEFINED;
}

static QueryResultType action_hurry(CustomBehaviorAction action, INextBot bot, int entity)
{
	return ANSWER_UNDEFINED;
}

static BehaviorResultType action_movefail(CustomBehaviorAction action, INextBot bot, int entity, MoveToFailureType type, BehaviorResult result)
{
	recompute_seek_path(action, bot, entity);
	return result.TryContinue();
}

static BehaviorResultType action_movesucc(CustomBehaviorAction action, INextBot bot, int entity, BehaviorResult result)
{
	recompute_seek_path(action, bot, entity);
	return result.TryContinue();
}

static BehaviorResultType action_stuck(CustomBehaviorAction action, INextBot bot, int entity, BehaviorResult result)
{
	recompute_seek_path(action, bot, entity);
	return result.TryContinue();
}

static BehaviorResultType action_resume(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	recompute_seek_path(action, bot, entity);
	return result.Continue();
}

static void action_end(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction next)
{
	PathFollower path = action.get_data("m_path");
	delete path;
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	float duration = -1.0;
	if(action.has_data("m_duration")) {
		duration = action.get_data("m_duration");
	} else {
		action.set_data("m_duration", -1.0);
	}

	if(duration > 0.0) {
		action.set_data("m_giveUpTimer", GetGameTime() + duration);
	} else {
		action.set_data("m_giveUpTimer", -1.0);
	}

	action.set_data("m_repathTimer", GetGameTime());

	PathFollower path = new PathFollower();
	path.MinLookAheadDistance = GetDesiredPathLookAheadRange(entity);
	action.set_data("m_path", path);

	recompute_seek_path(action, bot, entity);

	return result.Continue();
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	float giveUpTimer = action.get_data("m_giveUpTimer");
	if(giveUpTimer != -1.0 && giveUpTimer <= GetGameTime()) {
		return result.Done("Behavior duration elapsed");
	}

	IVision vision = bot.VisionInterface;

	CKnownEntity threat = vision.GetPrimaryKnownThreat();
	if(threat != CKnownEntity_Null) {
		float threat_pos[3];
		threat.GetLastKnownPosition(threat_pos);

		const float engageRange = 1000.0;
		if(bot.IsRangeLessThanVector(threat_pos, engageRange)) {
			BehaviorAction next_action = attack_action.create();
			return result.SuspendFor(next_action, "Going after an enemy");
		}
	}

	PathFollower path = action.get_data("m_path");

	path.Update(bot);

	float repathTimer = action.get_data("m_repathTimer");
	if(!path.Valid && repathTimer <= GetGameTime()) {
		repathTimer = GetGameTime() + 1.0;
		action.set_data("m_repathTimer", repathTimer);

		recompute_seek_path(action, bot, entity);
	}

	return result.Continue();
}