CustomBehaviorActionEntry basic_melee_action;

void basic_melee_action_init()
{
	basic_melee_action = new CustomBehaviorActionEntry("BasicMelee");
	basic_melee_action.set_function("OnStart", action_start);
	basic_melee_action.set_function("Update", action_update);
	basic_melee_action.set_function("OnEnd", action_end);
	basic_melee_action.set_function("OnStuck", shared_stuck);
	basic_melee_action.set_function("OnKilled", shared_killed);
}

static void action_end(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction next)
{
	DirectChasePath path = action.get_data("path");
	delete path;
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("victim", INVALID_ENT_REFERENCE);
	action.set_data("victim_time", 0.0);

	action.set_data("attack_time", 0.0);
	action.set_data("swing_time", 0.0);

	action.set_data("move_while_swing", 0);

	DirectChasePath path = new DirectChasePath(LEAD_SUBJECT);
	shared_path_init(path);
	action.set_data("path", path);

	return BEHAVIOR_CONTINUE;
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	int victim = EntRefToEntIndex(action.get_data("victim"));
	float victim_time = action.get_data("victim_time");

	IVision vision = bot.VisionInterface;

	if(victim == -1 || !shared_is_victim_chaseable(bot, entity, victim) || (GetGameTime() - victim_time) > 10.0) {
		victim = shared_select_victim(entity, bot, vision);
		action.set_data("victim", victim == -1 ? INVALID_ENT_REFERENCE : EntIndexToEntRef(victim));
		action.set_data("victim_time", GetGameTime());
	}

	IBody body = bot.BodyInterface;
	IBodyCustom body_custom = view_as<IBodyCustom>(body);
	ILocomotion locomotion = bot.LocomotionInterface;

	float chase_range = MELEE_RANGE - 5.0;
	float attack_range = MELEE_RANGE;

	ArousalType arousal = NEUTRAL;

	bool sight_clear = false;

	shared_handle_speed(entity, bot, locomotion, body, victim);

	if(victim != -1) {
		sight_clear = vision.IsLineOfSightClearToEntity(victim);

		arousal = ALERT;

		bool in_attack_range = bot.IsRangeLessThanEntity(victim, attack_range);
		bool should_face = (in_attack_range && sight_clear);

		if(should_face) {
			float victim_center[3];
			EntityWorldSpaceCenter(victim, victim_center);

			locomotion.FaceTowards(victim_center);
		}

		if(bot.IsRangeGreaterThanEntity(victim, chase_range) || !sight_clear) {
			bool should_move = true;

			if(action.has_data("move_while_swing") && action.get_data("move_while_swing") == 0) {
				float swing_time = action.get_data("swing_time");
				if(swing_time > GetGameTime()) {
					should_move = false;
				}
			}

			if(should_move) {
				DirectChasePath path = action.get_data("path");
				path.AllowFacing = !should_face;
				path.Update(bot, victim, baseline_path_cost, cost_flags_safest|cost_flags_mod_small);
				path.AllowFacing = true;
			}
		}

		if(in_attack_range) {
			float ang[3];
			GetEntPropVector(entity, Prop_Data, "m_angRotation", ang);

			float fwd[3];
			GetAngleVectors(ang, fwd, NULL_VECTOR, NULL_VECTOR);

			float my_center[3];
			EntityWorldSpaceCenter(entity, my_center);

			float victim_center[3];
			EntityWorldSpaceCenter(victim, victim_center);

			float to_victim[3];
			SubtractVectors(victim_center, my_center, to_victim);

			if(victim >= 1 && victim <= MaxClients) {

			}

			float close_range = (0.5 * attack_range);
			float range = bot.GetRangeToEntity(victim);
			float closeness = ((range < close_range) ? 0.0 : ((range - close_range) / (attack_range - close_range)));
			float hit_angle = (0.0 + closeness * 0.27);

			if(GetVectorDotProduct(fwd, to_victim) > hit_angle) {
				if(sight_clear) {
					float attack_time = action.get_data("attack_time");
					if(attack_time < GetGameTime()) {
						SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);

						float swing_time = action.get_data("swing_time");
						if(swing_time < GetGameTime()) {
							if(body.StartActivity(ACT_MELEE_ATTACK1, NO_ACTIVITY_FLAGS)) {
								int sequence = body_custom.Sequence;
								if(sequence != -1) {
									float duration = AnimatingSequenceDuration(entity, sequence);
									swing_time = (GetGameTime() + duration);
									action.set_data("swing_time", swing_time);
									action.set_data("attack_time", swing_time);

									Handle pl;
									Function func = action.get_function("handle_swing", pl);
									if(func != INVALID_FUNCTION && pl != null) {
										Call_StartFunction(pl, func);
										Call_PushCell(entity);
										Call_Finish();
									}
								}
							}
						}
					}
				}
			}

			arousal = INTENSE;
		}
	}

	body.Arousal = arousal;

	float swing_time = action.get_data("swing_time");
	if(swing_time < GetGameTime()) {
		shared_handle_anim(locomotion, body, sight_clear, victim);

		Handle pl;
		Function func = action.get_function("handle_idle", pl);
		if(func != INVALID_FUNCTION && pl != null) {
			Call_StartFunction(pl, func);
			Call_PushCell(entity);
			Call_Finish();
		}
	}

	return BEHAVIOR_CONTINUE;
}