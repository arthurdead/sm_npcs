BehaviorActionEntry basic_melee_action;

void basic_melee_action_init()
{
	basic_melee_action = new BehaviorActionEntry("BasicMelee");
	basic_melee_action.set_function("OnStart", basic_melee_start);
	basic_melee_action.set_function("Update", basic_melee_update);
	basic_melee_action.set_function("OnEnd", shared_end_chase);
	basic_melee_action.set_function("OnStuck", shared_stuck_chase);
	basic_melee_action.set_function("OnKilled", shared_killed);
}

static BehaviorResultType basic_melee_start(BehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("victim", INVALID_ENT_REFERENCE);
	action.set_data("victim_time", 0.0);

	action.set_data("attack_time", 0.0);
	action.set_data("swing_time", 0.0);

	return shared_start_chase(action, bot, entity, prior, result);
}

static BehaviorResultType basic_melee_update(BehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
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

	if(victim != -1) {
		bool sight_clear = vision.IsLineOfSightClearToEntity(victim);

		arousal = ALERT;

		if(bot.IsRangeGreaterThanEntity(victim, chase_range) || !sight_clear) {
			shared_update_chase(action, entity, bot, locomotion, body, victim);
		}

		if(bot.IsRangeLessThanEntity(victim, attack_range)) {
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
						float swing_time = action.get_data("swing_time");
						if(swing_time < GetGameTime()) {
							if(body.StartActivity(ACT_MELEE_ATTACK1, NO_ACTIVITY_FLAGS)) {
								int sequence = body_custom.Sequence;
								if(sequence != -1) {
									float duration = AnimatingSequenceDuration(entity, sequence);
									swing_time = (GetGameTime() + duration);
									action.set_data("swing_time", swing_time);
									action.set_data("attack_time", swing_time);
								}
							}
						}
					}
				}
			}

			if(sight_clear) {
				locomotion.FaceTowards(victim_center);
			}

			arousal = INTENSE;
		}
	}

	body.Arousal = arousal;

	float swing_time = action.get_data("swing_time");
	if(swing_time < GetGameTime()) {
		shared_handle_anim(locomotion, body);
	}

	return BEHAVIOR_CONTINUE;
}