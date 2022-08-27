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

	if(victim != -1) {
		bool sight_clear = vision.IsLineOfSightClearToEntity(victim);

		arousal = ALERT;

		if(bot.IsRangeGreaterThanEntity(victim, chase_range) || !sight_clear) {
			shared_update_chase(action, entity, bot, locomotion, body, victim);
		}

		if(sight_clear) {
			float victim_center[3];
			EntityWorldSpaceCenter(victim, victim_center);

			locomotion.FaceTowards(victim_center);

			float my_center[3];
			EntityWorldSpaceCenter(entity, my_center);

			static float next_attack = 0.0;
			if(next_attack < GetGameTime()) {
				FireBulletsInfo_t bullets;
				bullets.Init();
				bullets.m_vecSpread = view_as<float>({24.0, 24.0, 24.0});
				bullets.m_vecSrc = my_center;
				SubtractVectors(victim_center, my_center, bullets.m_vecDirShooting);
				bullets.m_nFlags |= FIRE_BULLETS_TEMPORARY_DANGER_SOUND;
				bullets.m_pAttacker = entity;
				bullets.m_flDistance = GetVectorLength(bullets.m_vecDirShooting) + 100.0;
				bullets.m_iTracerFreq = 1;
				FireBullets(entity, bullets);
				next_attack = GetGameTime() + 0.1;
			}

			arousal = INTENSE;
		}
	}

	body.Arousal = arousal;

	shared_handle_anim(locomotion, body);

	return BEHAVIOR_CONTINUE;
}