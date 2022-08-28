BehaviorActionEntry basic_range_action;

void basic_range_action_init()
{
	basic_range_action = new BehaviorActionEntry("BasicRange");
	basic_range_action.set_function("OnStart", action_start);
	basic_range_action.set_function("Update", action_update);
	basic_range_action.set_function("OnEnd", shared_end_chase);
	basic_range_action.set_function("OnStuck", shared_stuck_chase);
	basic_range_action.set_function("OnKilled", shared_killed);
}

static BehaviorResultType action_start(BehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("victim", INVALID_ENT_REFERENCE);
	action.set_data("victim_time", 0.0);

	action.set_data("attack_time", 0.0);

	return shared_start_chase(action, bot, entity, prior, result);
}

static BehaviorResultType action_update(BehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	int victim = EntRefToEntIndex(action.get_data("victim"));
	float victim_time = action.get_data("victim_time");

	IVision vision = bot.VisionInterface;

	if(victim == -1 || !shared_is_victim_chaseable(bot, entity, victim, false) || (GetGameTime() - victim_time) > 10.0) {
		victim = shared_select_victim(entity, bot, vision);
		action.set_data("victim", victim == -1 ? INVALID_ENT_REFERENCE : EntIndexToEntRef(victim));
		action.set_data("victim_time", GetGameTime());
	}

	IBody body = bot.BodyInterface;
	IBodyCustom body_custom = view_as<IBodyCustom>(body);
	ILocomotion locomotion = bot.LocomotionInterface;

	float chase_range = RANGED_RANGE - 5.0;

	ArousalType arousal = NEUTRAL;

	bool sight_clear = false;

	if(victim != -1) {
		sight_clear = vision.IsLineOfSightClearToEntity(victim);

		arousal = ALERT;

		if(bot.IsRangeGreaterThanEntity(victim, chase_range) || !sight_clear) {
			shared_update_chase(action, entity, bot, locomotion, body, victim);
		}

		if(sight_clear) {
			float victim_center[3];
			EntityWorldSpaceCenter(victim, victim_center);

			locomotion.FaceTowards(victim_center);

			if(action.has_function("handle_fire")) {
				Function func = action.get_function("handle_fire");
				Call_StartFunction(null, func);
				Call_PushCell(action);
				Call_PushCell(entity);
				Call_PushCell(victim);
				Call_Finish();
			}

			arousal = INTENSE;
		}
	}

	body.Arousal = arousal;

	shared_handle_anim(locomotion, body, sight_clear, victim);

	return BEHAVIOR_CONTINUE;
}